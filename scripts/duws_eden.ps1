# duws_eden.ps1 - DUWS composition TUI
#
# STATIC: object layouts are Eden compositions under src/duws/compositions/, edited in Eden itself.
# This links them into an Arma profile so Eden lists them and saves straight back into the tree.
#
# UNIT (read-write): scans src/ for
#   // --DUWS-UNITCOMP BEGIN name="..." kind=composition|team row="..." [rowname="Tier %1"]
#                          [fields="a, b, c"] [prefix=opfor_|blufor_,opfor_]--
#   <name> = [ <row>, <row>, ... ];
#   // --DUWS-UNITCOMP END--
# and edits the rows in place. These are the spawn tables -- tier compositions, team rosters, the
# purchasable squads, the static-weapon role map -- which are data, not layout, so there is nothing
# to round-trip through Eden.
#
# kind= sorts a table's rows into one of two menus, because the unit of work is a row rather than
# the table it lives in: every zone tier, town tier and squad is listed together as a composition,
# and everything a composition names by token is listed together as a team.
#
# A table declaring `fields=` has fixed columns rather than a free-length list, and is edited a
# field at a time with the current value seeded into the line. `prefix=` is the faction prefix its
# role names carry: it is stripped for display and re-applied on write, and names are checked
# against the slots the faction tables actually define. Two prefixes mean a table both armies raise
# out of -- its names are stored bare, the side is prepended at spawn time, and the check runs
# against both armies with the worse answer reported.
#
# Only the fenced body is ever rewritten, so the reasoning above each table survives editing. A
# write is refused unless the regenerated text parses back to exactly the model it came from, and
# git is the undo for everything past that.
#
# Launch via duws_eden.cmd at the repo root, or run scripts\duws_eden.ps1 directly.
# See docs/info/architecture/composition_tooling.md.
$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot   # script lives in scripts/; repo root is its parent
$srcDir  = Join-Path $root "src"
$compDir = Join-Path $srcDir "duws\compositions"

function Get-Attr($s, $pattern, $default) {
    if ($s -match $pattern) { return $Matches[1] } else { return $default }
}

# Every .sqf under src/, read once. Get-Content costs about 40 ms a file and there are 800-odd of
# them, so a scan that way is half a minute; through .NET the same read is a fraction of a second.
# It has to be cheap because the menus re-scan on every draw -- what is on screen is then what is on
# disk, rather than a snapshot that goes stale the moment something else edits the source.
$script:fileCache = $null
$script:unitCache = $null

function Get-SourceFiles {
    if ($null -ne $script:fileCache) { return $script:fileCache }
    $out = New-Object System.Collections.Generic.List[object]
    # EnumerateFiles rather than Get-ChildItem: the same 800-odd paths cost 3 s as FileInfo objects
    # through the provider stack and a fraction of that as strings.
    foreach ($p in [System.IO.Directory]::EnumerateFiles($srcDir, "*.sqf", [System.IO.SearchOption]::AllDirectories)) {
        $out.Add([pscustomobject]@{ Path = $p; Text = [System.IO.File]::ReadAllText($p) })
    }
    $script:fileCache = $out
    return $out
}

# Dropped after a write, because the next menu draw has to show what was just written.
function Clear-SourceCache {
    $script:fileCache = $null
    $script:unitCache = $null
}

# The line ending a file already uses, so a rewritten fence keeps it. This script is CRLF and the SQF
# it writes into is LF (.gitattributes), so a block joined with the script's own convention leaves a
# file half in each -- which git then reports across every line in the fence, not just the edited
# ones, and normalises away on the next commit so the mess is invisible until someone reads a diff.
function Get-Newline($text) { if ($text -match "`r`n") { "`r`n" } else { "`n" } }

# ---- creating a fence ----

# Appends a new fence to a source file, creating the file when it does not exist yet.
#
# Under src/ and .sqf only, refused rather than corrected. The scan enumerates *.sqf beneath src/,
# so a fence written anywhere else is invisible to the tool that wrote it -- which reads as the write
# having silently done nothing rather than as a path mistake.
function Add-FenceToFile($relPath, $block, $newFileHeader) {
    $rel = $relPath.Trim().Trim('"').Replace('/', '\')
    if ($rel -eq '') { Write-Host "  A file is required." -ForegroundColor Red; return $false }
    if ($rel -notmatch '\.sqf$') {
        Write-Host "  The file has to be .sqf -- the scan that finds fences enumerates nothing else." -ForegroundColor Red
        return $false
    }
    if ($rel -notmatch '^src\\') { $rel = "src\$rel" }
    # Caught rather than allowed to propagate: $ErrorActionPreference is Stop, so a drive letter or a
    # stray character in a pasted path would end the whole session instead of the prompt.
    try { $full = [System.IO.Path]::GetFullPath((Join-Path $root $rel)) }
    catch { Write-Host "  That is not a usable path." -ForegroundColor Red; return $false }
    if (-not $full.StartsWith($srcDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "  The file has to sit under src/ to be found again." -ForegroundColor Red
        return $false
    }

    $existing = ''
    if (Test-Path -LiteralPath $full) {
        # Strict, and refused rather than repaired: rewriting a file whose other bytes cannot be
        # decoded would replace every one of them for the sake of an appended block. Same guard as
        # the unit-table writer, for the same reason.
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        try { $existing = $strict.GetString([System.IO.File]::ReadAllBytes($full)) }
        catch {
            Write-Host "  Refusing to write: $rel is not valid UTF-8, and appending would corrupt the rest of it." -ForegroundColor Red
            return $false
        }
        if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { $existing += (Get-Newline $existing) }
    } else {
        $existing = $newFileHeader
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full) | Out-Null
    }

    # The block and header are built CRLF by their callers; an existing file decides, and a new one
    # gets LF because that is what .gitattributes holds every .sqf to.
    $nl = if ($existing -match "`r`n") { "`r`n" } else { "`n" }
    $out = ($existing + $block) -replace "`r`n", "`n"
    if ($nl -eq "`r`n") { $out = $out -replace "`n", "`r`n" }

    # No BOM: this sits beside SQF the mission compiles, and a BOM in front of a preprocessor
    # directive is an error Arma reports from the wrong line.
    [System.IO.File]::WriteAllText($full, $out, (New-Object System.Text.UTF8Encoding($false)))
    Clear-SourceCache
    Write-Host ("  Wrote {0}. Review the diff before committing." -f $rel) -ForegroundColor Green
    return $true
}

# ================= unit compositions =================
# The spawn tables: rows of tokens or numbers, edited in place rather than round-tripped.

$unitFenceRe = [regex]'(?s)(//[ \t]*--DUWS-UNITCOMP BEGIN\s+(.*?)--\r?\n)(.*?)(\r?\n[ \t]*//[ \t]*--DUWS-UNITCOMP END--)'

function Get-UnitComps {
    if ($null -ne $script:unitCache) { return $script:unitCache }
    $out = @()
    foreach ($file in (Get-SourceFiles)) {
        $text = $file.Text
        if ($text -notmatch 'DUWS-UNITCOMP BEGIN') { continue }
        foreach ($m in $unitFenceRe.Matches($text)) {
            $out += [pscustomobject]@{
                Name   = Get-Attr $m.Groups[2].Value 'name="([^"]*)"' '(unnamed)'
                RowOf  = Get-Attr $m.Groups[2].Value 'row="([^"]*)"' 'row'
                Fields = Get-Attr $m.Groups[2].Value 'fields="([^"]*)"' ''
                Prefix = Get-Attr $m.Groups[2].Value 'prefix=([A-Za-z0-9_,]+)' ''
                # Unclassified tables land under Tokens rather than vanishing from the menu: a table
                # nobody labelled is still one somebody has to be able to edit.
                Kind   = Get-Attr $m.Groups[2].Value 'kind=(\w+)' 'team'
                RowName = Get-Attr $m.Groups[2].Value 'rowname="([^"]*)"' ''
                File   = $file.Path
                Body   = $m.Groups[3].Value
            }
        }
    }
    $script:unitCache = $out
    return $out
}

# The fenced body is "<var> = [ <row>, <row> ];". Rows are the top-level bracket groups inside it.
# Split by depth rather than by regex: a row may itself hold a nested array (a team's role lists do),
# and a comma-splitting pass would cut those in half.
function Split-Rows($body) {
    $open = $body.IndexOf('[')
    $close = $body.LastIndexOf(']')
    if ($open -lt 0 -or $close -le $open) { return ,@() }
    $inner = $body.Substring($open + 1, $close - $open - 1)

    $rows = New-Object System.Collections.Generic.List[string]
    $depth = 0; $start = 0; $inStr = $false
    for ($i = 0; $i -lt $inner.Length; $i++) {
        $ch = $inner[$i]
        if ($ch -eq '"') { $inStr = -not $inStr; continue }
        if ($inStr) { continue }
        if ($ch -eq '[') { if ($depth -eq 0) { $start = $i }; $depth++ }
        elseif ($ch -eq ']') {
            $depth--
            if ($depth -eq 0) { $rows.Add($inner.Substring($start, $i - $start + 1)) }
        }
    }
    # Returned comma-wrapped so a one-row table arrives as an array rather than a bare string, and
    # as a real string[] rather than the builder, so a caller can assign into it. Callers must NOT
    # wrap the call in @() or pipe it directly: the wrapper protects the array from being unrolled,
    # so both would hand back one element holding the whole table.
    return ,$rows.ToArray()
}

# A row's entries, as the text between its brackets at depth 0 -- quoted strings keep their quotes so
# a rewrite cannot turn a token into a bare word, and numbers stay verbatim so 1e11 survives.
function Split-Entries($row) {
    $inner = $row.Substring(1, $row.Length - 2)
    $parts = New-Object System.Collections.Generic.List[string]
    $depth = 0; $start = 0; $inStr = $false
    for ($i = 0; $i -lt $inner.Length; $i++) {
        $ch = $inner[$i]
        if ($ch -eq '"') { $inStr = -not $inStr; continue }
        if ($inStr) { continue }
        if ($ch -eq '[') { $depth++ }
        elseif ($ch -eq ']') { $depth-- }
        elseif ($ch -eq ',' -and $depth -eq 0) {
            $parts.Add($inner.Substring($start, $i - $start).Trim()); $start = $i + 1
        }
    }
    $tail = $inner.Substring($start).Trim()
    if ($tail -ne '' -or $parts.Count -gt 0) { $parts.Add($tail) }
    # Cast, so a row holding a single entry is still an array: += on a bare string concatenates it
    # instead of appending, which would quietly fuse two tokens into one. Same no-@()/no-pipe rule
    # as Split-Rows above.
    return ,([string[]]($parts | Where-Object { $_ -ne '' }))
}

function Format-UnitBody($varName, $rows, $indent, $nl = "`n") {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("$varName = [")
    if ($rows.Count -gt 0) { [void]$sb.Append($nl) }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        [void]$sb.Append($indent + $rows[$i])
        if ($i -lt $rows.Count - 1) { [void]$sb.Append(',') }
        [void]$sb.Append($nl)
    }
    [void]$sb.Append('];')
    return $sb.ToString()
}

# A bare number stays a number; anything else is a token and gets quoted. Nested arrays typed by
# hand keep whatever the user wrote, which is the escape hatch for a roster's role lists.
function Format-Entry($s) {
    if ($s -match '^-?\d+(\.\d+)?([eE][+-]?\d+)?$') { return $s }
    if ($s.StartsWith('[') -or $s.StartsWith('"')) { return $s }
    return '"' + $s.Trim('"') + '"'
}

# Refuses on anything it cannot re-read. The rows are written back into a source file the mission
# compiles, so the guard is that the regenerated text splits into exactly the rows that produced it.
function Save-UnitComp($uc, $varName, $rows, $indent) {
    $newBody = Format-UnitBody $varName $rows $indent (Get-Newline $uc.Body)
    $check = Split-Rows $newBody
    if ($check.Count -ne $rows.Count) {
        Write-Host "Refusing to write: the regenerated table does not read back as the same rows." -ForegroundColor Red
        return $false
    }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($check[$i] -ne $rows[$i]) {
            Write-Host ("Refusing to write: row {0} did not survive the round trip." -f ($i + 1)) -ForegroundColor Red
            return $false
        }
    }
    # Re-read strictly, and refuse a file that is not valid UTF-8. Thirty-five .sqf files under
    # src/modules carry legacy single-byte encodings, and Get-Content -Encoding UTF8 silently turns
    # every non-ASCII byte in them into a replacement character. Reading that is harmless -- the
    # scan above only looks for an ASCII fence -- but writing it back would corrupt the whole file
    # for the sake of one edited table. None of today's fences live in such a file; this is what
    # keeps that from becoming a trap the first time one does.
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try { $text = $strict.GetString([System.IO.File]::ReadAllBytes($uc.File)) }
    catch {
        Write-Host "Refusing to write: $($uc.File) is not valid UTF-8, and rewriting it would corrupt the rest of the file." -ForegroundColor Red
        return $false
    }
    # Matched by fence name rather than by position, and every other fence in the file is returned
    # untouched. Names are the identity the menu selected on, so a duplicate name is a data error
    # that would rewrite two tables with one body -- which the round-trip check above cannot catch.
    $target = $uc.Name
    $updated = $unitFenceRe.Replace($text, {
        param($m)
        if ((Get-Attr $m.Groups[2].Value 'name="([^"]*)"' '') -ne $target) { return $m.Value }
        return $m.Groups[1].Value + $newBody + $m.Groups[4].Value
    })
    if ($updated -eq $text) {
        Write-Host "Nothing written: the fence was not found or the body is unchanged." -ForegroundColor Yellow
        return $false
    }
    # No trailing-newline normalisation and no BOM: this file sits beside SQF the mission compiles,
    # and a BOM in front of a preprocessor directive is an error Arma reports from the wrong line.
    [System.IO.File]::WriteAllText($uc.File, $updated, (New-Object System.Text.UTF8Encoding($false)))
    Clear-SourceCache
    return $true
}

# A whole new table, empty, for rows to be added to afterwards.
#
# Its attributes are the whole of what the tool knows about a table, and every one of them fails
# quietly when it is wrong: an unknown kind lands the rows under Tokens, a missing row= leaves them
# described as "row", and a fields= that does not match what the rows hold switches the editor into
# field mode against columns that are not there. So they are prompted rather than hand-written into
# a fence, and the two that cannot be recovered from are refused outright.
function New-UnitTable {
    Clear-Host
    Write-Host "New unit table" -ForegroundColor Cyan
    Write-Host "======================================"
    Write-Host "  An empty fenced table. Add its rows from the menu afterwards." -ForegroundColor DarkGray
    Write-Host ""

    $ask = {
        param($label, $default)
        $v = (Read-Host $label).Trim()
        if ($v -eq '') { $v = $default }
        return $v
    }

    $name = (Read-Host "  Name (as it appears in the menu)").Trim()
    if ($name -eq '') { return }
    # Refused, and this is the one that cannot be recovered from by editing: the writer matches a
    # fence by name, so two under one name means every write to either rewrites both bodies.
    if (@(Get-UnitComps | Where-Object { $_.Name -eq $name }).Count -gt 0) {
        Write-Host ("  A table called '{0}' already exists." -f $name) -ForegroundColor Red
        return
    }

    $varName = (Read-Host "  Variable, e.g. DUWS_hardpointTiers").Trim()
    if ($varName -eq '') { return }
    if ($varName -notmatch '^[A-Za-z]\w*$') { Write-Host "  That is not a global variable name." -ForegroundColor Red; return }
    # A second assignment to the same global is the other unrecoverable one: whichever file the
    # mission compiles last wins, and the table the tool edits may not be the one that is live.
    $assignRe = [regex]('(?m)^\s*' + [regex]::Escape($varName) + '\s*=')
    foreach ($f in (Get-SourceFiles)) {
        if ($assignRe.IsMatch($f.Text)) {
            Write-Host ("  {0} is already assigned in {1}." -f $varName, (Split-Path -Leaf $f.Path)) -ForegroundColor Red
            return
        }
    }

    Write-Host ""
    Write-Host "  kind: composition (a list of tokens -- a tier, a squad), team (what one name" -ForegroundColor DarkGray
    Write-Host "        stands for -- a roster, a vehicle, a role map)." -ForegroundColor DarkGray
    $kind = & $ask "  kind (blank = composition)" 'composition'
    if (@('composition', 'team') -notcontains $kind) {
        Write-Host "  kind has to be composition or team." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  row: what one row of this table IS, since a row is a tier in one table and a" -ForegroundColor DarkGray
    Write-Host "       vehicle in another." -ForegroundColor DarkGray
    $rowOf = & $ask "  row (blank = row)" 'row'

    Write-Host ""
    Write-Host "  fields: the columns, for a table whose rows are fixed-shape rather than a" -ForegroundColor DarkGray
    Write-Host "          free-length list. Blank leaves rows as plain lists." -ForegroundColor DarkGray
    $fields = & $ask "  fields (blank = none)" ''

    Write-Host ""
    Write-Host "  rowname: how a row is named in the menu, %1 being its index in roman. Blank" -ForegroundColor DarkGray
    Write-Host "           lets the first column name the row." -ForegroundColor DarkGray
    $rowName = & $ask "  rowname (blank = none)" ''

    Write-Host ""
    Write-Host "  prefix: the faction prefix this table's role names carry. List two, comma" -ForegroundColor DarkGray
    Write-Host "          separated, for a table both armies raise out of -- its names are then" -ForegroundColor DarkGray
    Write-Host "          stored bare and checked against both." -ForegroundColor DarkGray
    $prefix = & $ask "  prefix, e.g. opfor_ or blufor_,opfor_ (blank = none)" ''
    if ($prefix -ne '' -and $prefix -notmatch '^[A-Za-z0-9_]+(,[A-Za-z0-9_]+)*$') {
        Write-Host "  A prefix is letters, digits and underscores, or a comma-separated list of them." -ForegroundColor Red
        return
    }

    foreach ($v in @($name, $rowOf, $fields, $rowName)) {
        if ($v.Contains('"')) { Write-Host "  Attribute values cannot contain a quote." -ForegroundColor Red; return }
    }

    $file = Read-Host "  File under src/ (existing or new)"
    if ([string]::IsNullOrWhiteSpace($file)) { return }

    $attrs = "name=`"$name`" kind=$kind row=`"$rowOf`""
    if ($rowName -ne '') { $attrs += " rowname=`"$rowName`"" }
    if ($fields  -ne '') { $attrs += " fields=`"$fields`"" }
    if ($prefix  -ne '') { $attrs += " prefix=$prefix" }

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("`r`n")
    [void]$sb.Append("// --DUWS-UNITCOMP BEGIN $attrs--`r`n")
    [void]$sb.Append("$varName = [];`r`n")
    [void]$sb.Append("// --DUWS-UNITCOMP END--`r`n")

    $header = "// Spawn tables. The fences are comments, so the preprocessor discards them and the markup" + "`r`n" +
              "// costs nothing at runtime; scripts/duws_eden.ps1 edits the rows in place." + "`r`n" +
              "// See docs/info/composition_tooling.md." + "`r`n"

    if (Add-FenceToFile $file $sb.ToString() $header) {
        # Said plainly, because a table that spawns nothing looks identical to one that is broken:
        # the tables are asked what a token is, so a new ROW is live at once, while a new TABLE is
        # inert until something reads its global.
        Write-Host ("  {0} is empty until you add rows, and inert until code reads {1}." -f $name, $varName) -ForegroundColor DarkGray
    }
}

# A table's prefixes. One table's role names now serve both armies, so `prefix=` may list more than
# one -- and a listed pair means the names are stored bare, with the side prepended at spawn time.
function Split-Prefixes($prefix) {
    if (-not $prefix) { return @() }
    return @($prefix -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

# The role vocabulary, read from the faction tables rather than hardcoded. Every faction file fills
# the same slots, so a name none of them defines is a typo that would spawn nothing, and a name only
# some define is a roster that quietly thins on the rest -- which is the failure mode the whole
# faction auto-detection exists to avoid. Both are worth saying out loud before a write.
#
# Backfilled roles are counted as covered. A role in DUWS_roleFallbacks is one no faction file on
# some side has ever named and that fnc_faction_backfill borrows for at load -- flagging it as
# undefined would put a hard warning on the tool's own answer to the gap, which is the fastest way
# to teach someone to ignore the warnings.
function Get-RoleVocab {
    if ($script:roleVocab) { return $script:roleVocab }
    $counts = @{}   # slot name -> how many faction files define it
    $files  = @{}   # prefix    -> how many faction files carry that prefix at all
    $re = [regex]'(?m)^\s*((?:opfor|blufor)_[A-Za-z0-9_]+_X)\s*='
    $dir = Join-Path $srcDir "duws\shared\factions"
    if (Test-Path -LiteralPath $dir) {
        foreach ($f in [System.IO.Directory]::EnumerateFiles($dir, "*.sqf", [System.IO.SearchOption]::AllDirectories)) {
            # Read through .NET, and not for speed alone: several faction files carry legacy
            # single-byte encodings, and only ASCII slot names are matched here. Nothing under this
            # directory is ever written back.
            $seen = @{}
            foreach ($m in $re.Matches([System.IO.File]::ReadAllText($f))) {
                $seen[$m.Groups[1].Value] = $true
            }
            foreach ($n in $seen.Keys) { $counts[$n] = 1 + [int]$counts[$n] }
            foreach ($p in @('opfor_', 'blufor_')) {
                if (@($seen.Keys | Where-Object { $_.StartsWith($p) }).Count -gt 0) { $files[$p] = 1 + [int]$files[$p] }
            }
        }
    }
    $borrowed = @{}
    $bf = Join-Path $srcDir "duws\shared\functions\fnc_faction_backfill.sqf"
    if (Test-Path -LiteralPath $bf) {
        foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($bf), '(?m)^\s*\[\s*"([A-Za-z0-9_]+_X)"\s*,')) {
            $borrowed[$m.Groups[1].Value] = $true
        }
    }
    $script:roleVocab = [pscustomobject]@{ Counts = $counts; Files = $files; Borrowed = $borrowed }
    return $script:roleVocab
}

# What a typed name is written back as, and how many faction files define it. Coverage -1 means the
# value is not a role slot at all: a field may legitimately hold a group token or a team key, and
# those end in neither _X nor a faction prefix, so they are passed through unchecked.
#
# A table listing two prefixes stores its names bare and is checked against both armies, with the
# worse answer reported: a role every BLUFOR file defines and a handful of OPFOR files do is a
# roster that thins on OPFOR, and saying so is the whole point of the check.
function Resolve-Role($name, $prefix) {
    if ($name -notmatch '_X$') { return [pscustomobject]@{ Name = $name; Coverage = -1; Total = 0 } }
    $v = Get-RoleVocab
    $prefixes = Split-Prefixes $prefix
    $bare = $name
    foreach ($p in $prefixes) { if ($bare.StartsWith($p)) { $bare = $bare.Substring($p.Length); break } }

    if ($prefixes.Count -gt 1) {
        # Stored bare, because no one prefix is the table's: the side is prepended when a team is
        # raised, and writing either one back here would pin the row to one army.
        $worst = $null
        foreach ($p in $prefixes) {
            $cov = [int]$v.Counts[($p + $bare)]
            $tot = [int]$v.Files[$p]
            if ($cov -eq 0 -and $v.Borrowed.ContainsKey($bare)) { $cov = $tot }
            if ($null -eq $worst -or ($cov - $tot) -lt ($worst.Coverage - $worst.Total)) {
                $worst = [pscustomobject]@{ Name = $bare; Coverage = $cov; Total = $tot }
            }
        }
        return $worst
    }

    $cands = @($name)
    if ($prefix -and -not $name.StartsWith($prefix)) { $cands += ($prefix + $name) }
    foreach ($c in $cands) {
        if ($v.Counts.ContainsKey($c)) {
            $p = if ($c -match '^(opfor_|blufor_)') { $Matches[1] } else { '' }
            return [pscustomobject]@{ Name = $c; Coverage = [int]$v.Counts[$c]; Total = [int]$v.Files[$p] }
        }
    }
    # Unknown, so qualify it the way the table stores its other names: a name written bare would
    # resolve to nothing at runtime and read as the roster silently losing a man.
    $out = if ($prefix -and -not $name.StartsWith($prefix)) { $prefix + $name } else { $name }
    $cov = 0
    if ($v.Borrowed.ContainsKey($bare)) { $cov = [int]$v.Files[$prefix] }
    return [pscustomobject]@{ Name = $out; Coverage = $cov; Total = [int]$v.Files[$prefix] }
}

# What is wrong with a resolved name, or $null when nothing is. A slot no faction file fills spawns
# nothing: the table still compiles and nothing is said at runtime, which is what makes it worth a
# prompt here.
function Get-NameWarning($r) {
    if ($r.Coverage -lt 0) { return $null }
    if ($r.Coverage -eq 0) {
        return [pscustomobject]@{ Name = $r.Name; Hard = $true; Note = "no faction file defines this slot -- it would spawn nothing." }
    }
    if ($r.Coverage -lt $r.Total) {
        return [pscustomobject]@{ Name = $r.Name; Hard = $false; Note = ("defined by {0} of {1} faction files -- thins on the rest." -f $r.Coverage, $r.Total) }
    }
    return $null
}

# A field's literal, shown with quotes and the faction prefix taken off. An empty list or string
# shows as a dash: "no leader" has to be visible rather than reading as a rendering gap.
function Show-Field($literal, $prefix) {
    $prefixes = Split-Prefixes $prefix
    $strip = {
        param($s)
        $t = $s.Trim().Trim('"')
        foreach ($p in $prefixes) { if ($t.StartsWith($p)) { return $t.Substring($p.Length) } }
        return $t
    }
    if ($literal.StartsWith('[')) {
        # Bound to a variable before piping: Split-Entries returns its array comma-wrapped, so
        # piping the call directly would hand ForEach-Object the whole row as one item.
        $parts = Split-Entries $literal
        if ($parts.Count -eq 0) { return '-' }
        return (($parts | ForEach-Object { & $strip $_ }) -join ', ')
    }
    if ($literal.StartsWith('"')) {
        $t = & $strip $literal
        if ($t -eq '') { return '-' }
        return $t
    }
    return $literal
}

# Rebuild a field's literal from typed text, keeping the kind it already had: a list stays a list, a
# quoted name stays quoted and a number stays a number. Inferred from the current value rather than
# declared per table, because the fence has no schema and every table would have to repeat one.
# Returns $null when the text cannot be that kind -- refusing beats writing a table that will not
# compile. Warnings for every name written are appended to $notes.
function Format-FieldLiteral($current, $text, $prefix, [ref]$notes) {
    $qualify = {
        param($s)
        $r = Resolve-Role $s.Trim().Trim('"') $prefix
        $w = Get-NameWarning $r
        if ($null -ne $w) { $notes.Value += ,$w }
        if ($r.Name -match '^-?\d+(\.\d+)?([eE][+-]?\d+)?$') { $r.Name } else { '"' + $r.Name + '"' }
    }
    if ($current.StartsWith('[')) {
        $parts = @($text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        return '[' + (($parts | ForEach-Object { & $qualify $_ }) -join ', ') + ']'
    }
    if ($current.StartsWith('"')) {
        if ($text.Trim() -eq '') { return '""' }
        return (& $qualify $text)
    }
    if ($text.Trim() -match '^-?\d+(\.\d+)?([eE][+-]?\d+)?$') { return $text.Trim() }
    return $null
}

# Read a line with the current value already in the buffer, so a field is tweaked rather than
# retyped from scratch -- retyping an eight-role squad to change one man is the friction this tool
# exists to remove, and Read-Host cannot seed its buffer. Enter accepts, Escape cancels.
# Redrawn from a fixed origin so a value that wraps past the console width still repaints; the
# caller draws this on a cleared screen with room below it for that reason.
function Read-Seeded($prompt, $seed) {
    $buf = New-Object System.Text.StringBuilder
    [void]$buf.Append($seed)
    $pos = $buf.Length
    $top = [Console]::CursorTop
    $prev = 0
    while ($true) {
        $text = $prompt + $buf.ToString()
        [Console]::SetCursorPosition(0, $top)
        Write-Host -NoNewline ($text.PadRight([Math]::Max($prev, $text.Length)))
        $prev = $text.Length
        $abs = $prompt.Length + $pos
        $w = [Console]::WindowWidth
        [Console]::SetCursorPosition($abs % $w, $top + [Math]::Floor($abs / $w))

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            'Enter'      { Write-Host ""; return $buf.ToString() }
            'Escape'     { Write-Host ""; return $null }
            'Backspace'  { if ($pos -gt 0) { [void]$buf.Remove($pos - 1, 1); $pos-- } }
            'Delete'     { if ($pos -lt $buf.Length) { [void]$buf.Remove($pos, 1) } }
            'LeftArrow'  { if ($pos -gt 0) { $pos-- } }
            'RightArrow' { if ($pos -lt $buf.Length) { $pos++ } }
            'Home'       { $pos = 0 }
            'End'        { $pos = $buf.Length }
            default {
                if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
                    [void]$buf.Insert($pos, $key.KeyChar); $pos++
                }
            }
        }
    }
}

# What a value that names a team contains, or '' when it names no team. Compositions and teams are
# deliberately separate menus -- a team is edited in one place and referred to from many -- but a
# reference showing nothing of what it points at is a dead end, which is exactly how the split reads
# the first time you meet it.
function Get-TeamHint($value) {
    if ($value -eq '' -or $value -eq '-') { return '' }
    foreach ($uc in (Get-UnitComps | Where-Object { $_.Kind -eq 'team' })) {
        foreach ($row in (Split-Rows $uc.Body)) {
            $e = Split-Entries $row
            if ($e.Count -gt 0 -and $e[0].Trim('"') -eq $value) {
                # The men only. A team's other columns -- how it patrols, how it scales -- are its
                # own business and belong on its own screen; here the question being answered is
                # "who turns up". A roster column is a list, and a single man is a slot name.
                $parts = @()
                for ($j = 1; $j -lt $e.Count; $j++) {
                    if (-not ($e[$j].StartsWith('[') -or $e[$j].Trim('"') -match '_X$')) { continue }
                    $v = Show-Field $e[$j] $uc.Prefix
                    if ($v -ne '-') { $parts += $v }
                }
                return ($parts -join ', ')
            }
        }
    }
    return ''
}

# One row, one field at a time. Returns the rebuilt row literal, or $null if nothing changed.
function Invoke-EditRow($row, $fields, $prefix, $title) {
    $entries = Split-Entries $row
    $changed = $false
    while ($true) {
        Clear-Host
        Write-Host $title -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ""
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $label = if ($i -lt $fields.Count) { $fields[$i] } else { "field $($i + 1)" }
            $val = Show-Field $entries[$i] $prefix
            $hint = Get-TeamHint $val
            Write-Host ("  {0}. {1,-20} {2}" -f ($i + 1), $label, $val) -NoNewline
            if ($hint -ne '') { Write-Host ("   -> {0}" -f $hint) -ForegroundColor DarkGray } else { Write-Host "" }
        }
        Write-Host ""
        if ($prefix) { Write-Host ("  names are shown without their {0} prefix and may be typed either way" -f $prefix) -ForegroundColor DarkGray }
        Write-Host "  Field number to edit, or Enter to go back." -ForegroundColor DarkGray
        Write-Host ""
        $sel = Read-Host "Select"
        if ($sel -notmatch '^\s*\d+\s*$') { break }
        $k = [int]$sel
        if ($k -lt 1 -or $k -gt $entries.Count) { continue }

        $label = if (($k - 1) -lt $fields.Count) { $fields[$k - 1] } else { "field $k" }
        Clear-Host
        Write-Host $title -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ""
        Write-Host ("  {0}" -f $label) -ForegroundColor Cyan
        Write-Host "  Enter accepts, Escape cancels. Comma separates a list." -ForegroundColor DarkGray
        Write-Host ""
        $seed = Show-Field $entries[$k - 1] $prefix
        if ($seed -eq '-') { $seed = '' }
        $notes = @()
        $typed = Read-Seeded "  > " $seed
        if ($null -eq $typed) { continue }

        $literal = Format-FieldLiteral $entries[$k - 1] $typed $prefix ([ref]$notes)
        if ($null -eq $literal) {
            $holds = if ($entries[$k - 1] -match '^(true|false)$') { "true or false" } else { "a number" }
            Write-Host ("  That field holds {0}; leaving it as it was." -f $holds) -ForegroundColor Yellow
            Read-Host "  Press Enter to continue" | Out-Null
            continue
        }
        # Reported before the row is touched, not after the write: a roster naming a slot only some
        # factions fill still compiles, and the only sign at runtime is a group that spawns short on
        # those factions.
        if ($notes.Count -gt 0) {
            Write-Host ""
            foreach ($n in $notes) {
                Write-Host ("  {0}: {1}" -f $n.Name, $n.Note) -ForegroundColor $(if ($n.Hard) { 'Red' } else { 'Yellow' })
            }
            Write-Host ""
            if ((Read-Host "  Keep it anyway? (y/N)") -notmatch '^\s*[Yy]') { continue }
        }
        if ($literal -ne $entries[$k - 1]) { $entries[$k - 1] = $literal; $changed = $true }
    }
    if (-not $changed) { return $null }
    return '[' + ($entries -join ', ') + ']'
}

# ---- the composition and team menus ----
#
# A row is the unit of work, not the table it lives in: "Zone tiers" and "BLUFOR squads" are both
# lists of compositions, and which file a composition sits in is not something the person editing it
# should have to know. The kind= attribute is what sorts them, so a table added later lands in the
# right menu without this code changing.

$romans = @('I','II','III','IV','V','VI','VII','VIII','IX','X','XI','XII')
function Get-Roman($n) { if ($n -ge 1 -and $n -le $romans.Count) { $romans[$n - 1] } else { "$n" } }

# What one row is called. rowname="Tier %1" numbers them; otherwise the first column names itself,
# which is how a team and a squad both read as what they are.
function Get-RowLabel($uc, $row, $i) {
    if ($uc.RowName -ne '') { return ($uc.RowName -replace '%1', (Get-Roman ($i + 1))) }
    $e = Split-Entries $row
    if ($e.Count -gt 0) { return (Show-Field $e[0] $uc.Prefix) }
    return ("Row {0}" -f ($i + 1))
}

# The one-line "what is in it" the menus show. Everything past the name, so a composition reads as
# its teams and a team reads as its men without opening it.
function Get-RowSummary($uc, $row) {
    $e = Split-Entries $row
    if ($uc.Fields -eq '') { return ((Show-Field $row $uc.Prefix)) }
    $fields = @($uc.Fields -split ',' | ForEach-Object { $_.Trim() })
    $parts = @()
    for ($j = 1; $j -lt $e.Count; $j++) {
        $v = Show-Field $e[$j] $uc.Prefix
        if ($v -eq '-') { continue }
        $label = ''
        if ($j -lt $fields.Count) { $label = $fields[$j] + ': ' }
        $parts += ($label + $v)
    }
    return ($parts -join '  ')
}

# Every row of every table of one kind, flattened into one list.
function Get-RowEntries($kind) {
    $out = @()
    foreach ($uc in (Get-UnitComps | Where-Object { $_.Kind -eq $kind } | Sort-Object Name)) {
        $rows = Split-Rows $uc.Body
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $out += [pscustomobject]@{
                Comp = $uc; Index = $i; Row = $rows[$i]
                Label = (Get-RowLabel $uc $rows[$i] $i)
                Summary = (Get-RowSummary $uc $rows[$i])
            }
        }
    }
    return ,$out
}

# One row back into its table. Re-split from the body rather than kept from the menu pass, so the
# write is against what is on disk now.
function Save-Row($uc, $index, $newRow) {
    $varName = if ($uc.Body -match '(?m)^\s*(\w+)\s*=') { $Matches[1] } else { $null }
    if (-not $varName) { Write-Host "Could not read the table's variable name." -ForegroundColor Red; return $false }
    $indent = if ($uc.Body -match '(?m)^([ \t]+)\[') { $Matches[1] } else { '    ' }
    $rows = Split-Rows $uc.Body
    if ($index -ge $rows.Count) { Write-Host "That row is gone; nothing written." -ForegroundColor Yellow; return $false }
    $rows[$index] = $newRow
    return (Save-UnitComp $uc $varName $rows $indent)
}

# A row that is a plain list -- a zone tier's teams and vehicles. Add, drop, or retype the lot.
function Invoke-EditListRow($entry) {
    $uc = $entry.Comp
    $row = $entry.Row
    while ($true) {
        $e = Split-Entries $row
        Clear-Host
        Write-Host ("{0} -- {1}" -f $uc.Name, $entry.Label) -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ""
        Write-Host ("  {0}" -f $uc.RowOf) -ForegroundColor DarkGray
        Write-Host ""
        if ($e.Count -eq 0) { Write-Host "  (empty)" -ForegroundColor DarkGray }
        for ($i = 0; $i -lt $e.Count; $i++) {
            $val = Show-Field $e[$i] $uc.Prefix
            $hint = Get-TeamHint $val
            Write-Host ("  {0,2}. {1,-14}" -f ($i + 1), $val) -NoNewline
            if ($hint -ne '') { Write-Host (" {0}" -f $hint) -ForegroundColor DarkGray } else { Write-Host "" }
        }
        Write-Host ""
        Write-Host "   A. Add an entry     D. Drop an entry     R. Retype the row"
        Write-Host "   B. Back"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*[Aa]\s*$') {
            $raw = Read-Host "Entry to add"
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $new = @($e) + (Format-Entry $raw.Trim())
                $row = '[' + ($new -join ', ') + ']'
                if (Save-Row $uc $entry.Index $row) { $uc.Body = (Get-UnitComps | Where-Object { $_.Name -eq $uc.Name }).Body }
            }
        }
        elseif ($sel -match '^\s*[Dd]\s*(\d+)?\s*$') {
            $k = if ($Matches[1]) { [int]$Matches[1] } else { [int](Read-Host "Entry to drop") }
            if ($k -ge 1 -and $k -le $e.Count) {
                # Dropped by index, not by value: a tier legitimately holds the same team twice, and
                # matching on value would take the wrong one of a pair.
                $kept = @(); for ($i = 0; $i -lt $e.Count; $i++) { if ($i -ne ($k - 1)) { $kept += $e[$i] } }
                $row = '[' + ($kept -join ', ') + ']'
                if (Save-Row $uc $entry.Index $row) { $uc.Body = (Get-UnitComps | Where-Object { $_.Name -eq $uc.Name }).Body }
            }
        }
        elseif ($sel -match '^\s*[Rr]\s*$') {
            Clear-Host
            Write-Host ("{0} -- {1}" -f $uc.Name, $entry.Label) -ForegroundColor Cyan
            Write-Host "======================================"
            Write-Host ""
            Write-Host "  Comma separated. Enter accepts, Escape cancels." -ForegroundColor DarkGray
            Write-Host ""
            $seed = (@($e | ForEach-Object { $_.Trim().Trim('"') }) -join ', ')
            $raw = Read-Seeded "  > " $seed
            if ($null -ne $raw) {
                $new = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
                $row = '[' + (($new | ForEach-Object { Format-Entry $_ }) -join ', ') + ']'
                if (Save-Row $uc $entry.Index $row) { $uc.Body = (Get-UnitComps | Where-Object { $_.Name -eq $uc.Name }).Body }
            }
        }
    }
}

function Invoke-OpenRow($entry) {
    if ($entry.Comp.Fields -ne '') {
        $new = Invoke-EditRow $entry.Row ((@($entry.Comp.Fields -split ',' | ForEach-Object { $_.Trim() }))) $entry.Comp.Prefix `
            ("{0} -- {1}" -f $entry.Comp.Name, $entry.Label)
        if ($null -ne $new) {
            if (Save-Row $entry.Comp $entry.Index $new) {
                Write-Host "Written. Review the diff before committing." -ForegroundColor Green
                Read-Host "Press Enter to continue" | Out-Null
            }
        }
    } else {
        Invoke-EditListRow $entry
    }
}

# The values a column already holds, as a hint when typing a new one. Read from the table rather
# than hardcoded: a column's vocabulary is whatever the rows have made it, and a list here would rot
# the first time one is added.
function Get-ColumnValues($uc, $j) {
    $seen = @()
    foreach ($row in (Split-Rows $uc.Body)) {
        $e = Split-Entries $row
        if ($j -lt $e.Count -and $e[$j].StartsWith('"')) {
            $v = $e[$j].Trim('"')
            if ($v -ne '' -and $seen -notcontains $v) { $seen += $v }
        }
    }
    return ,$seen
}

# A row that is a plain list: typed in one line, entries comma separated. Returns the row literal, or
# $null if nothing usable was typed.
#
# Used for a table that declares no columns, and for one that declares columns but holds no rows yet:
# the field walk below reads each field's kind off the row above it, so a table created a moment ago
# has nothing to read and there is no shape to copy.
function Add-FlatRow($uc) {
    Clear-Host
    Write-Host ("{0} -- new row" -f $uc.Name) -ForegroundColor Cyan
    Write-Host "======================================"
    Write-Host ""
    Write-Host ("  {0}" -f $uc.RowOf) -ForegroundColor DarkGray
    if ($uc.Fields -ne '') { Write-Host ("  columns: {0}" -f $uc.Fields) -ForegroundColor DarkGray }
    Write-Host "  Comma separated, tokens unquoted. Enter accepts, Escape cancels." -ForegroundColor DarkGray
    Write-Host ""
    $raw = Read-Seeded "  > " ''
    if ($null -eq $raw) { return $null }
    $new = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($new.Count -eq 0) { return $null }
    return '[' + (($new | ForEach-Object { Format-Entry $_ }) -join ', ') + ']'
}

# A row of a fixed-column table, field by field, starting from an existing row blanked out so each
# field keeps its kind. Returns the row literal, or $null if the row was cancelled.
function Add-FieldRow($uc, $rows, $fields) {
    $tpl = Split-Entries $rows[0]
    $new = @()
    for ($j = 0; $j -lt $tpl.Count; $j++) {
        $label = if ($j -lt $fields.Count) { $fields[$j] } else { "field $($j + 1)" }
        $blank = if ($tpl[$j].StartsWith('[')) { '[]' } elseif ($tpl[$j].StartsWith('"')) { '""' } elseif ($tpl[$j] -match '^(true|false)$') { 'false' } else { '0' }

        Clear-Host
        Write-Host ("{0} -- new row" -f $uc.Name) -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ""
        for ($k = 0; $k -lt $new.Count; $k++) {
            Write-Host ("  {0,-20} {1}" -f $fields[$k], (Show-Field $new[$k] $uc.Prefix)) -ForegroundColor DarkGray
        }
        Write-Host ("  {0}" -f $label) -ForegroundColor Cyan
        $known = Get-ColumnValues $uc $j
        if ($known.Count -gt 0 -and $blank -eq '""') {
            Write-Host ("  in use: {0}" -f ($known -join ', ')) -ForegroundColor DarkGray
        }
        Write-Host "  Enter accepts, Escape cancels the whole row. Comma separates a list." -ForegroundColor DarkGray
        Write-Host ""
        $notes = @()
        $typed = Read-Seeded "  > " ''
        if ($null -eq $typed) { return $null }

        $literal = Format-FieldLiteral $blank $typed $uc.Prefix ([ref]$notes)
        if ($null -eq $literal) { $literal = $blank }
        # The first column is the name every other table refers to, so a duplicate would shadow the
        # row already there and a blank one could never be referenced at all.
        if ($j -eq 0) {
            $name = $literal.Trim('"')
            if ($name -eq '') { Write-Host "  A name is required." -ForegroundColor Red; Read-Host "  Press Enter" | Out-Null; $j--; continue }
            if ((Get-ColumnValues $uc 0) -contains $name) {
                Write-Host ("  {0} already exists." -f $name) -ForegroundColor Red
                Read-Host "  Press Enter" | Out-Null; $j--; continue
            }
        }
        if ($notes.Count -gt 0) {
            Write-Host ""
            foreach ($n in $notes) {
                Write-Host ("  {0}: {1}" -f $n.Name, $n.Note) -ForegroundColor $(if ($n.Hard) { 'Red' } else { 'Yellow' })
            }
            if ((Read-Host "  Keep it anyway? (y/N)") -notmatch '^\s*[Yy]') { $j--; continue }
        }
        $new += $literal
    }
    return '[' + ($new -join ', ') + ']'
}

# Append a row. A team or a vehicle added here is spawnable as it stands -- the spawn path reads the
# tables for what a token is, so nothing in the mission has to learn the new name.
function Invoke-AddRow($uc) {
    $rows = Split-Rows $uc.Body
    $fields = @($uc.Fields -split ',' | ForEach-Object { $_.Trim() })

    $rowLiteral = if ($uc.Fields -eq '' -or $rows.Count -eq 0) {
        Add-FlatRow $uc
    } else {
        Add-FieldRow $uc $rows $fields
    }
    if ($null -eq $rowLiteral) { return }

    $varName = if ($uc.Body -match '(?m)^\s*(\w+)\s*=') { $Matches[1] } else { $null }
    $indent = if ($uc.Body -match '(?m)^([ \t]+)\[') { $Matches[1] } else { '    ' }
    if (Save-UnitComp $uc $varName (@($rows) + $rowLiteral) $indent) {
        Write-Host "Added. Review the diff before committing." -ForegroundColor Green
    }
    Read-Host "Press Enter to continue" | Out-Null
}

# One menu over every row of a kind, grouped by the table each came from.
function Show-RowMenu($kind, $title, $blurb) {
    while ($true) {
        # Re-read each pass: an edit rewrites source, and a stale body would show the pre-edit table.
        $entries = Get-RowEntries $kind
        Clear-Host
        Write-Host $title -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ("  {0}" -f $blurb) -ForegroundColor DarkGray
        Write-Host ""
        if ($entries.Count -eq 0) { Write-Host "  Nothing marked kind=$kind under $srcDir." -ForegroundColor Yellow }
        $last = ''
        for ($i = 0; $i -lt $entries.Count; $i++) {
            if ($entries[$i].Comp.Name -ne $last) {
                $last = $entries[$i].Comp.Name
                Write-Host ""
                Write-Host ("  {0}" -f $last.ToUpper()) -ForegroundColor DarkGray
            }
            Write-Host ("  {0,2}. {1,-16} {2}" -f ($i + 1), $entries[$i].Label, $entries[$i].Summary)
        }
        Write-Host ""
        Write-Host "   A. Add a row       N. New table"
        Write-Host "   B. Back"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*[Nn]\s*$') {
            New-UnitTable
            Read-Host "Press Enter to continue" | Out-Null
        }
        elseif ($sel -match '^\s*[Aa]\s*$') {
            # Which table to add to is a question only when there is more than one of this kind.
            $tables = @(Get-UnitComps | Where-Object { $_.Kind -eq $kind } | Sort-Object Name)
            if ($tables.Count -eq 0) {
                Write-Host "No table of this kind to add to. Create one first." -ForegroundColor Yellow
                Read-Host "Press Enter to continue" | Out-Null
                continue
            }
            $target = $tables[0]
            if ($tables.Count -gt 1) {
                Write-Host ""
                for ($i = 0; $i -lt $tables.Count; $i++) { Write-Host ("  {0}. {1}" -f ($i + 1), $tables[$i].Name) }
                $t = Read-Host "Add to which"
                if ($t -notmatch '^\d+$' -or [int]$t -lt 1 -or [int]$t -gt $tables.Count) { continue }
                $target = $tables[[int]$t - 1]
            }
            Invoke-AddRow $target
        }
        elseif ($sel -match '^\s*(\d+)\s*$' -and [int]$Matches[1] -ge 1 -and [int]$Matches[1] -le $entries.Count) {
            Invoke-OpenRow $entries[[int]$Matches[1] - 1]
        }
    }
}

# ================= static compositions =================
# Eden lists and saves custom compositions only in a profile's Compositions folder. A directory junction
# per composition puts the tree's copy there, so there is no second copy to fall out of step.

function Get-ProfileCompositionDirs {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $dirs = @()
    $default = Join-Path $docs "Arma 3"
    if (Test-Path -LiteralPath $default) { $dirs += (Join-Path $default "Compositions") }
    $others = Join-Path $docs "Arma 3 - Other Profiles"
    if (Test-Path -LiteralPath $others) {
        foreach ($p in (Get-ChildItem -LiteralPath $others -Directory)) { $dirs += (Join-Path $p.FullName "Compositions") }
    }
    return ,$dirs
}

function Invoke-LinkCompositions {
    $comps = @(Get-ChildItem -LiteralPath $compDir -Directory)
    $targets = Get-ProfileCompositionDirs
    Clear-Host
    Write-Host "Static compositions" -ForegroundColor Cyan
    Write-Host "======================================"
    Write-Host ("  {0} layouts under {1}. Linked into a profile, Eden lists them with its custom" -f $comps.Count, $compDir) -ForegroundColor DarkGray
    Write-Host "  compositions and saves them straight back into the tree." -ForegroundColor DarkGray
    Write-Host ""
    if ($targets.Count -eq 0) { Write-Host "  No Arma 3 profile folder under Documents." -ForegroundColor Yellow; return }
    for ($i = 0; $i -lt $targets.Count; $i++) { Write-Host ("  {0}. {1}" -f ($i + 1), $targets[$i]) }
    Write-Host ""
    $t = Read-Host "Link into which profile (blank = back)"
    if ($t -notmatch '^\s*\d+\s*$' -or [int]$t -lt 1 -or [int]$t -gt $targets.Count) { return }
    $dest = $targets[[int]$t - 1]
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($c in $comps) {
        $link = Join-Path $dest $c.Name
        $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            New-Item -ItemType Junction -Path $link -Target $c.FullName | Out-Null
            Write-Host ("  linked   {0}" -f $c.Name) -ForegroundColor Green
        } elseif ($item.LinkType -eq 'Junction' -and @($item.Target) -contains $c.FullName) {
            Write-Host ("  ok       {0}" -f $c.Name) -ForegroundColor DarkGray
        } else {
            # A real folder of that name is a composition someone saved there; replacing it would delete it.
            Write-Host ("  skipped  {0}: that name is already taken in the profile" -f $c.Name) -ForegroundColor Yellow
        }
    }
}

# ---- main loop ----
while ($true) {
    Clear-Host
    Write-Host "DUWS Composition TUI" -ForegroundColor Cyan
    Write-Host "===================="
    Write-Host ""
    Write-Host "  1. Static compositions   (object layouts: link them into Eden)"
    Write-Host "  2. Unit compositions     (what a zone, town or squad fields)"
    Write-Host "  3. Tokens                (what one name stands for: men, a vehicle, a gun)"
    Write-Host ""
    Write-Host "   Q. Quit"
    Write-Host ""
    $sel = Read-Host "Select"

    if ($sel -match '^\s*[Qq]\s*$') { break }
    elseif ($sel -match '^\s*1\s*$') {
        Invoke-LinkCompositions
        Read-Host "Press Enter to continue" | Out-Null
    }
    elseif ($sel -match '^\s*2\s*$') {
        Show-RowMenu 'composition' 'Unit compositions' 'A composition is a list of teams and vehicles. Open one to see what it fields.'
    }
    elseif ($sel -match '^\s*3\s*$') {
        Show-RowMenu 'team' 'Tokens' 'What a name stands for: a team of men, one vehicle, or the role a static class fills. Open one, or add a row.'
    }
}
