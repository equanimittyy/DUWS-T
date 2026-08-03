# duws_eden.ps1 - DUWS composition TUI
#
# Two modes over the same marker-fence idea, because the mission has two kinds of composition and
# both had to be hand-edited in source.
#
# STATIC (read-only): scans src/ for
#   // --DUWS-COMPOSITION BEGIN name="..." schema=A [anchor=hqInComp] [z=snap|keep]--
#   <array literal>
#   // --DUWS-COMPOSITION END--
# and emits a paste-ready Eden import (create3DENEntity + rotation) copied to the clipboard.
# Every composition is schema A -- [class, X, Y, Z, dir_deg] with any trailing fields its own
# consumer needs (isWeapon and the like), which this tool ignores.
#
# UNIT (read-write): scans src/ for
#   // --DUWS-UNITCOMP BEGIN name="..." kind=composition|team|rule row="..." [rowname="Tier %1"]
#                          [fields="a, b, c"] [prefix=opfor_]--
#   <name> = [ <row>, <row>, ... ];
#   // --DUWS-UNITCOMP END--
# and edits the rows in place. These are the spawn tables -- tier compositions, team rosters, the
# purchasable squads, the radius multipliers -- which are data, not layout, so there is nothing to
# round-trip through Eden.
#
# kind= sorts a table's rows into one of three menus, because the unit of work is a row rather than
# the table it lives in: every zone tier, town tier and squad is listed together as a composition,
# every roster as a team, and the scaling tables on their own.
#
# A table declaring `fields=` has fixed columns rather than a free-length list, and is edited a
# field at a time with the current value seeded into the line. `prefix=` is the faction prefix its
# role names carry: it is stripped for display and re-applied on write, and names are checked
# against the slots the faction tables actually define.
#
# Only the fenced body is ever rewritten, so the reasoning above each table survives editing. A
# write is refused unless the regenerated text parses back to exactly the model it came from, and
# git is the undo for everything past that.
#
# Launch via duws_eden.cmd at the repo root, or run scripts\duws_eden.ps1 directly.
# See docs/info/composition_tooling.md.
$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot   # script lives in scripts/; repo root is its parent
$srcDir  = Join-Path $root "src"
$outFile = Join-Path $root "temp\eden_import.sqf"

# One origin for the whole run. An import and its export have to use the same one -- the export
# subtracts it back out -- so it is session state shown on the menu, not a per-generate prompt that
# can be answered differently the second time and hand back rows offset by the difference.
$script:originX = 23100.0
$script:originY = 18700.0

$inv   = [System.Globalization.CultureInfo]::InvariantCulture
$numRe = '-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'
$rowRe = '"([^"]+)"\s*,\s*({0})\s*,\s*({0})\s*,\s*({0})\s*,\s*({0})' -f $numRe

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

# Invariant-culture number formatting: a comma-decimal locale must not corrupt SQF floats.
function Fmt($v) { ([double]$v).ToString($inv) }

function Get-Compositions {
    $comps = @()
    $blockRe = [regex]'(?s)--DUWS-COMPOSITION BEGIN\s+(.*?)--\r?\n(.*?)\r?\n[ \t]*//\s*--DUWS-COMPOSITION END--'
    foreach ($file in (Get-SourceFiles)) {
        $text = $file.Text
        if ($text -notmatch 'DUWS-COMPOSITION BEGIN') { continue }
        foreach ($m in $blockRe.Matches($text)) {
            $attrs  = $m.Groups[1].Value
            $comps += [pscustomobject]@{
                Name   = Get-Attr $attrs 'name="([^"]*)"' '(unnamed)'
                Schema = Get-Attr $attrs 'schema=(\w+)' 'A'
                Anchor = Get-Attr $attrs 'anchor=(\w+)' ''
                ZMode  = Get-Attr $attrs 'z=(\w+)' 'snap'
                ZBase  = Get-Attr $attrs 'zbase=(\w+)' ''
                Body   = $m.Groups[2].Value
                Text   = $text
            }
        }
    }
    return $comps
}

function Get-AnchorXY($comp) {
    if ($comp.Anchor -eq 'hqInComp') {
        $ax = if ($comp.Text -match '_hqInCompX\s*=\s*([\d.]+)') { [double]$Matches[1] } else { 0.0 }
        $ay = if ($comp.Text -match '_hqInCompY\s*=\s*([\d.]+)') { [double]$Matches[1] } else { 0.0 }
        return ,@($ax, $ay)
    }
    return ,@(0.0, 0.0)
}

# -> { Rows = [ {Class,OX,OY,OZ,Dir}... ]; Seen = <row-like lines seen> }
function ConvertTo-Rows($comp) {
    $anchor = Get-AnchorXY $comp
    $ax = $anchor[0]; $ay = $anchor[1]
    $rows = New-Object System.Collections.Generic.List[object]
    $seen = 0
    foreach ($line in ($comp.Body -split "`n")) {
        if ($line -notmatch '^\s*\["') { continue }
        $seen++
        if ($line -notmatch $rowRe) { continue }
        $c=$Matches[1]; $x=[double]$Matches[2]; $y=[double]$Matches[3]; $z=[double]$Matches[4]; $d=[double]$Matches[5]
        $rows.Add([pscustomobject]@{ Class=$c; OX=($x-$ax); OY=($y-$ay); OZ=$z; Dir=$d })
    }
    return [pscustomobject]@{ Rows=$rows; Seen=$seen }
}

# How far out the front marker stands: clear of the composition's own footprint, so it reads as a
# bearing rather than as one of its props. Measured from the rows rather than fixed, because a
# 300-object base and a five-prop outpost need very different distances to be "outside".
function Get-MarkerDistance($rows) {
    $reach = 0.0
    foreach ($r in $rows) {
        $d = [math]::Sqrt(($r.OX * $r.OX) + ($r.OY * $r.OY))
        if ($d -gt $reach) { $reach = $d }
    }
    return [math]::Round($reach + 15, 2)
}

function New-ImportScript($name, $schema, $rows, $originX, $originY, $originZ, $zKeep) {
    $rowStrs = foreach ($r in $rows) {
        '    ["{0}", {1}, {2}, {3}, {4}]' -f $r.Class, (Fmt $r.OX), (Fmt $r.OY), (Fmt $r.OZ), (Fmt $r.Dir)
    }
    $markerY = Get-MarkerDistance $rows
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('// RUN FROM THE EDEN DEBUG CONSOLE (3D editor toolbar > {}), not the in-game console.')
    [void]$sb.AppendLine("// Generated by duws_eden.ps1 from composition `"$name`" (schema $schema).")
    [void]$sb.AppendLine("private _origin = [$(Fmt $originX), $(Fmt $originY), $(Fmt $originZ)];")
    [void]$sb.AppendLine("private _zKeep  = $(if ($zKeep) {'true'} else {'false'});")
    [void]$sb.AppendLine('private _rows = [')
    [void]$sb.AppendLine(($rowStrs -join ",`r`n"))
    [void]$sb.AppendLine('];')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('private _made = 0;')
    [void]$sb.AppendLine('{')
    [void]$sb.AppendLine('    _x params ["_class","_ox","_oy","_oz","_dir"];')
    [void]$sb.AppendLine('    private _z = if (_zKeep) then { (_origin select 2) + _oz } else { 0 };')
    [void]$sb.AppendLine('    private _pos = [(_origin select 0) + _ox, (_origin select 1) + _oy, _z];')
    [void]$sb.AppendLine('    private _ent = create3DENEntity ["Object", _class, _pos];')
    [void]$sb.AppendLine('    _ent set3DENAttribute ["rotation", [0, 0, _dir]];   // [pitch, roll, yaw]; bare number = pitch, not heading')
    [void]$sb.AppendLine('    _ent set3DENAttribute ["position", _pos];   // re-assert after rotating: create3DENEntity + rotate can shift the origin')
    [void]$sb.AppendLine('    _made = _made + 1;')
    [void]$sb.AppendLine('} forEach _rows;')
    [void]$sb.AppendLine('')
    # A composition's rows are offsets in a frame whose +Y is the way it faces once placed, and
    # nothing in the 3D view shows where that frame points -- so a rearrange is done blind and the
    # whole layout can come back rotated without anybody noticing until it is in play.
    [void]$sb.AppendLine('// FRONT MARKER -- not part of the composition. It marks +Y, the direction')
    [void]$sb.AppendLine('// this composition faces when it is placed at heading 0. The export')
    [void]$sb.AppendLine('// snippet drops it by name, so it is safe to leave selected.')
    [void]$sb.AppendLine("private _mz = if (_zKeep) then { _origin select 2 } else { 0 };")
    [void]$sb.AppendLine("private _mpos = [(_origin select 0), (_origin select 1) + $markerY, _mz];")
    [void]$sb.AppendLine('private _mark = create3DENEntity ["Object", "FlagPole_F", _mpos];')
    [void]$sb.AppendLine('_mark set3DENAttribute ["position", _mpos];')
    # Named so it is obvious in Eden's entity list, which is the one place a stray object is easy to
    # spot before it reaches the export.
    [void]$sb.AppendLine('_mark set3DENAttribute ["name", "DUWS_FRONT"];')
    [void]$sb.AppendLine("systemChat `"DUWS_FRONT stands $markerY m along +Y and marks the front. The export drops it by name, so Ctrl+A is safe.`";")
    [void]$sb.AppendLine('hint format ["DUWS import: created %1 of %2 objects.", _made, count _rows];')
    return $sb.ToString()
}

function Save-And-Copy($script) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outFile) | Out-Null
    [System.IO.File]::WriteAllText($outFile, $script, (New-Object System.Text.UTF8Encoding($false)))
    try { Set-Clipboard -Value $script; return $true } catch { return $false }
}

function Set-Origin {
    # Accepts "X Y" or a pasted Arma position like [1689.31,5603.31,0]: pull the first
    # two numbers and ignore any Z. Brackets/commas/spaces are all just separators.
    while ($true) {
        $in = Read-Host ("Origin (X Y, or paste [x,y,z]; blank = keep {0} {1})" -f (Fmt $script:originX), (Fmt $script:originY))
        if ([string]::IsNullOrWhiteSpace($in)) { return }
        $nums = @([regex]::Matches($in, '-?\d+(?:\.\d+)?') | ForEach-Object { [double]$_.Value })
        if ($nums.Count -ge 2) { $script:originX = $nums[0]; $script:originY = $nums[1]; return }
        Write-Host "Enter at least X and Y (e.g. 23100 18700 or [1689.31,5603.31,0])." -ForegroundColor Yellow
    }
}

function Invoke-Generate($comp) {
    $res = ConvertTo-Rows $comp
    if ($res.Rows.Count -eq 0) { Write-Host "No rows parsed." -ForegroundColor Yellow; return }
    # zbase=<var> anchors this composition's Z to a source constant (e.g. the killhouse's
    # off-map _centerSpawnZ) instead of the terrain, keeping its native altitude.
    $originZ = 0.0
    if ($comp.ZBase) {
        $zrx = [regex]([regex]::Escape($comp.ZBase) + '\s*=\s*(-?[\d.]+)')
        if ($zrx.IsMatch($comp.Text)) { $originZ = [double]$zrx.Match($comp.Text).Groups[1].Value }
    }
    $importScript = New-ImportScript $comp.Name $comp.Schema $res.Rows $script:originX $script:originY $originZ ($comp.ZMode -eq 'keep')
    $clip         = Save-And-Copy $importScript
    Write-Host ""
    Write-Host ("Generated {0} objects from '{1}' (schema {2}, z={3}) at origin {4} {5}." -f $res.Rows.Count, $comp.Name, $comp.Schema, $comp.ZMode, (Fmt $script:originX), (Fmt $script:originY)) -ForegroundColor Green
    if ($res.Rows.Count -lt $res.Seen) {
        Write-Host ("WARNING: {0} row-like line(s) did not parse and were skipped." -f ($res.Seen - $res.Rows.Count)) -ForegroundColor Yellow
    }
    Write-Host ("Wrote $outFile" + $(if ($clip) { " and copied to clipboard." } else { " (clipboard unavailable; copy the file)." }))
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
                Prefix = Get-Attr $m.Groups[2].Value 'prefix=([A-Za-z0-9_]+)' ''
                # Unclassified tables land under the scaling rules rather than vanishing from the
                # menu: a table nobody labelled is still one somebody has to be able to edit.
                Kind   = Get-Attr $m.Groups[2].Value 'kind=(\w+)' 'rule'
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
# Split by depth rather than by regex: a row may itself hold a nested array (the category map does),
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

function Format-UnitBody($varName, $rows, $indent) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("$varName = [")
    if ($rows.Count -gt 0) { [void]$sb.Append("`r`n") }
    for ($i = 0; $i -lt $rows.Count; $i++) {
        [void]$sb.Append($indent + $rows[$i])
        if ($i -lt $rows.Count - 1) { [void]$sb.Append(',') }
        [void]$sb.Append("`r`n")
    }
    [void]$sb.Append('];')
    return $sb.ToString()
}

# A bare number stays a number; anything else is a token and gets quoted. Nested arrays typed by
# hand keep whatever the user wrote, which is the escape hatch for the category map.
function Format-Entry($s) {
    if ($s -match '^-?\d+(\.\d+)?([eE][+-]?\d+)?$') { return $s }
    if ($s.StartsWith('[') -or $s.StartsWith('"')) { return $s }
    return '"' + $s.Trim('"') + '"'
}

function Show-UnitComp($uc, $rows) {
    # Relative to the repo root rather than the working directory: the launcher may be started from
    # anywhere, and Resolve-Path -Relative would then print a path back out of the tree.
    $rel = if ($uc.File.StartsWith($root)) { $uc.File.Substring($root.Length).TrimStart('\', '/') } else { $uc.File }
    Write-Host ""
    Write-Host ("  {0}" -f $uc.Name) -ForegroundColor Cyan
    Write-Host ("  file: {0}" -f $rel)
    Write-Host ("  row : {0}" -f $uc.RowOf)
    Write-Host ""
    for ($i = 0; $i -lt $rows.Count; $i++) {
        Write-Host ("  {0,2}. {1}" -f ($i + 1), $rows[$i])
    }
    Write-Host ""
}

# Refuses on anything it cannot re-read. The rows are written back into a source file the mission
# compiles, so the guard is that the regenerated text splits into exactly the rows that produced it.
function Save-UnitComp($uc, $varName, $rows, $indent) {
    $newBody = Format-UnitBody $varName $rows $indent
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

# The role vocabulary, read from the faction tables rather than hardcoded. Every faction file fills
# the same slots, so a name none of them defines is a typo that would spawn nothing, and a name only
# some define is a roster that quietly thins on the rest -- which is the failure mode the whole
# faction auto-detection exists to avoid. Both are worth saying out loud before a write.
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
    $script:roleVocab = [pscustomobject]@{ Counts = $counts; Files = $files }
    return $script:roleVocab
}

# The placer vocabulary: the globals server_fnc_init.sqf compiles. A specials row names its placer by
# global name and the spawn path falls back to {grpNull} for a name nothing defines, so a typo there
# is a row that raises nothing, silently -- the same failure the role check below exists to catch.
function Get-PlacerVocab {
    if ($null -ne $script:placerVocab) { return $script:placerVocab }
    $names = @{}
    $f = Join-Path $srcDir "duws\server\server_fnc_init.sqf"
    if (Test-Path -LiteralPath $f) {
        foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($f), '(?m)^\s*(fnc_\w+)\s*=\s*compile')) {
            $names[$m.Groups[1].Value] = $true
        }
    }
    $script:placerVocab = $names
    return $script:placerVocab
}

# What a typed name is written back as, and how many faction files define it. Coverage -1 means the
# value is not a role slot at all: a field may legitimately hold a group token or a team key, and
# those end in neither _X nor a faction prefix, so they are passed through unchecked.
function Resolve-Role($name, $prefix) {
    if ($name -notmatch '_X$') { return [pscustomobject]@{ Name = $name; Coverage = -1; Total = 0 } }
    $v = Get-RoleVocab
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
    return [pscustomobject]@{ Name = $out; Coverage = 0; Total = [int]$v.Files[$prefix] }
}

# What is wrong with a resolved name, or $null when nothing is. Two vocabularies, one question: a
# slot no faction file fills spawns nothing, and a placer nothing compiles raises nothing. Both write
# a table that compiles, and neither says anything at runtime, so both are worth a prompt.
function Get-NameWarning($r) {
    if ($r.Name -match '^fnc_') {
        if ((Get-PlacerVocab).ContainsKey($r.Name)) { return $null }
        return [pscustomobject]@{ Name = $r.Name; Hard = $true; Note = "nothing compiles this name -- the row would raise nothing." }
    }
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
    $strip = { param($s) $t = $s.Trim().Trim('"'); if ($prefix -and $t.StartsWith($prefix)) { $t.Substring($prefix.Length) } else { $t } }
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
# quoted name stays quoted, a number stays a number and a boolean stays a boolean. Inferred from the
# current value rather than declared per table, because the fence has no schema and every table would
# have to repeat one.
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
        # A bare true/false is left bare here and not in $qualify below, which also serves string
        # fields: a placer parameter list carries booleans, and a quoted one is a type the spawner
        # substitutes its default for, which reads as a parameter that stopped taking effect.
        return '[' + (($parts | ForEach-Object {
            if ($_ -match '^(true|false)$') { $_.ToLower() } else { & $qualify $_ }
        }) -join ', ') + ']'
    }
    if ($current.StartsWith('"')) {
        if ($text.Trim() -eq '') { return '""' }
        return (& $qualify $text)
    }
    if ($current -match '^(true|false)$') {
        $t = $text.Trim().ToLower()
        if ($t -eq 'true' -or $t -eq 'false') { return $t }
        return $null
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

# Fixed-column tables: a row is a thing with named parts (a group kind, a purchasable squad) rather
# than a free-length list, so it is picked apart by field instead of by entry index.
function Invoke-EditFieldComp($uc) {
    $varName = if ($uc.Body -match '(?m)^\s*(\w+)\s*=') { $Matches[1] } else { $null }
    if (-not $varName) { Write-Host "Could not read the table's variable name." -ForegroundColor Red; return }
    $indent = if ($uc.Body -match '(?m)^([ \t]+)\[') { $Matches[1] } else { '    ' }
    $rows   = Split-Rows $uc.Body
    $fields = @($uc.Fields -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $rel    = if ($uc.File.StartsWith($root)) { $uc.File.Substring($root.Length).TrimStart('\', '/') } else { $uc.File }
    $dirty  = $false

    while ($true) {
        Clear-Host
        Write-Host "Unit composition: $varName" -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ""
        Write-Host ("  {0}" -f $uc.Name) -ForegroundColor Cyan
        Write-Host ("  file: {0}" -f $rel)
        Write-Host ""
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $entries = Split-Entries $rows[$i]
            Write-Host ("  {0,2}. {1}" -f ($i + 1), (Show-Field $entries[0] $uc.Prefix)) -ForegroundColor White
            for ($j = 1; $j -lt $entries.Count; $j++) {
                $label = if ($j -lt $fields.Count) { $fields[$j] } else { "field $($j + 1)" }
                Write-Host ("        {0,-20} {1}" -f $label, (Show-Field $entries[$j] $uc.Prefix)) -ForegroundColor Gray
            }
        }
        Write-Host ""
        if ($dirty) { Write-Host "  * unsaved changes" -ForegroundColor Yellow; Write-Host "" }
        Write-Host "   <n>. Edit that row        W. Write back to source"
        Write-Host "   B. Back (discards unsaved changes)"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*[Ww]\s*$') {
            if (-not $dirty) { Write-Host "No changes to write." -ForegroundColor Yellow }
            elseif (Save-UnitComp $uc $varName $rows $indent) {
                Write-Host "Written. Review the diff before committing." -ForegroundColor Green
                $uc.Body = Format-UnitBody $varName $rows $indent
                $dirty = $false
            }
            Read-Host "Press Enter to continue" | Out-Null
        }
        elseif ($sel -match '^\s*(\d+)\s*$' -and [int]$Matches[1] -ge 1 -and [int]$Matches[1] -le $rows.Count) {
            $n = [int]$Matches[1]
            $new = Invoke-EditRow $rows[$n - 1] $fields $uc.Prefix ("{0} -- row {1}" -f $uc.Name, $n)
            if ($null -ne $new) { $rows[$n - 1] = $new; $dirty = $true }
        }
    }
}

function Invoke-EditUnitComp($uc) {
    if ($uc.Fields -ne '') { Invoke-EditFieldComp $uc; return }
    $varName = if ($uc.Body -match '(?m)^\s*(\w+)\s*=') { $Matches[1] } else { $null }
    if (-not $varName) { Write-Host "Could not read the table's variable name." -ForegroundColor Red; return }
    $indent = if ($uc.Body -match '(?m)^([ \t]+)\[') { $Matches[1] } else { '    ' }
    $rows = Split-Rows $uc.Body
    $dirty = $false

    while ($true) {
        Clear-Host
        Write-Host "Unit composition: $varName" -ForegroundColor Cyan
        Write-Host "======================================"
        Show-UnitComp $uc $rows
        if ($dirty) { Write-Host "  * unsaved changes" -ForegroundColor Yellow; Write-Host "" }
        Write-Host "   A. Add an entry to a row      D. Drop an entry from a row"
        Write-Host "   R. Replace a whole row        W. Write back to source"
        Write-Host "   B. Back (discards unsaved changes)"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*[Ww]\s*$') {
            if (-not $dirty) { Write-Host "No changes to write." -ForegroundColor Yellow }
            elseif (Save-UnitComp $uc $varName $rows $indent) {
                Write-Host "Written. Review the diff before committing." -ForegroundColor Green
                $uc.Body = Format-UnitBody $varName $rows $indent
                $dirty = $false
            }
            Read-Host "Press Enter to continue" | Out-Null
        }
        elseif ($sel -match '^\s*([AaDdRr])\s*(\d+)?\s*$') {
            $act = $Matches[1].ToString().ToUpper()
            $n = if ($Matches[2]) { [int]$Matches[2] } else { [int](Read-Host "Row number") }
            if ($n -lt 1 -or $n -gt $rows.Count) {
                Write-Host "No such row." -ForegroundColor Yellow
                Read-Host "Press Enter to continue" | Out-Null
                continue
            }
            $entries = Split-Entries $rows[$n - 1]

            if ($act -eq 'R') {
                Clear-Host
                Write-Host ("{0} -- row {1}" -f $uc.Name, $n) -ForegroundColor Cyan
                Write-Host "======================================"
                Write-Host ""
                Write-Host "  Comma separated, tokens unquoted. Enter accepts, Escape cancels." -ForegroundColor DarkGray
                Write-Host ""
                $raw = Read-Seeded "  > " ((($entries | ForEach-Object { $_.Trim().Trim('"') }) -join ', '))
                if ($null -ne $raw) {
                    $new = @($raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
                    $rows[$n - 1] = '[' + (($new | ForEach-Object { Format-Entry $_ }) -join ', ') + ']'
                    $dirty = $true
                }
            }
            elseif ($act -eq 'A') {
                $raw = Read-Host 'Entry to add'
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $entries += (Format-Entry $raw.Trim())
                    $rows[$n - 1] = '[' + ($entries -join ', ') + ']'
                    $dirty = $true
                }
            }
            else {
                for ($i = 0; $i -lt $entries.Count; $i++) { Write-Host ("  {0,2}. {1}" -f ($i + 1), $entries[$i]) }
                $k = Read-Host "Entry to drop"
                if ($k -match '^\d+$' -and [int]$k -ge 1 -and [int]$k -le $entries.Count) {
                    # Dropped by index, not by value: a tier legitimately holds the same token twice,
                    # and matching on value would take the wrong one of a pair.
                    $kept = @(); for ($i = 0; $i -lt $entries.Count; $i++) { if ($i -ne ([int]$k - 1)) { $kept += $entries[$i] } }
                    $rows[$n - 1] = '[' + ($kept -join ', ') + ']'
                    $dirty = $true
                }
            }
        }
    }
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
# than hardcoded: category names are the spawner's vocabulary, and a list here would rot the first
# time one is added.
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

# Append a row, field by field, starting from an existing row blanked out so each field keeps its
# kind. A team or a vehicle added here is spawnable as it stands -- the spawn path reads the tables
# for what a token is, so nothing in the mission has to learn the new name. A special is the one
# exception: its placer column names code, which is why a name nothing compiles is prompted on.
function Invoke-AddRow($uc) {
    $rows = Split-Rows $uc.Body
    if ($rows.Count -eq 0) { Write-Host "Nothing to copy a shape from." -ForegroundColor Yellow; return }
    $fields = @($uc.Fields -split ',' | ForEach-Object { $_.Trim() })
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
        if ($null -eq $typed) { return }

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

    $varName = if ($uc.Body -match '(?m)^\s*(\w+)\s*=') { $Matches[1] } else { $null }
    $indent = if ($uc.Body -match '(?m)^([ \t]+)\[') { $Matches[1] } else { '    ' }
    $all = @($rows) + ('[' + ($new -join ', ') + ']')
    if (Save-UnitComp $uc $varName $all $indent) {
        Write-Host "Added. Review the diff before committing." -ForegroundColor Green
    }
    Read-Host "Press Enter to continue" | Out-Null
}

# One menu over every row of a kind, grouped by the table each came from.
function Show-RowMenu($kind, $title, $blurb, $canAdd) {
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
        if ($canAdd) { Write-Host "   A. Add" }
        Write-Host "   B. Back"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($canAdd -and $sel -match '^\s*[Aa]\s*$') {
            # Which table to add to is a question only when there is more than one of this kind.
            $tables = @(Get-UnitComps | Where-Object { $_.Kind -eq $kind } | Sort-Object Name)
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

function Show-StaticMenu($comps) {
    while ($true) {
        Clear-Host
        Write-Host "Static compositions" -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host ("  Object layouts, round-tripped through Eden. Origin: {0} {1}" -f (Fmt $script:originX), (Fmt $script:originY)) -ForegroundColor DarkGray
        Write-Host ""
        for ($i = 0; $i -lt $comps.Count; $i++) {
            Write-Host ("  {0,2}. {1,-26} [schema {2}, {3,4} objs]" -f ($i + 1), $comps[$i].Name, $comps[$i].Schema, $comps[$i].Count)
        }
        Write-Host ""
        Write-Host "   O. Set the import origin      P. Paste your own array (schema A)"
        Write-Host "   B. Back"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*[Oo]\s*$') { Set-Origin }
        elseif ($sel -match '^\s*[Pp]\s*$') {
            Write-Host 'Paste rows in schema A form: ["class", x, y, z, dir, ...]. Blank line to finish.'
            $lines = @()
            while ($true) { $l = Read-Host; if ([string]::IsNullOrWhiteSpace($l)) { break }; $lines += $l }
            if ($lines.Count -gt 0) {
                $pasted = [pscustomobject]@{ Name='(pasted)'; Schema='A'; Anchor=''; ZMode='snap'; ZBase=''; Body=($lines -join "`n"); Text='' }
                Invoke-Generate $pasted
            }
            Read-Host "Press Enter to continue" | Out-Null
        }
        elseif ($sel -match '^\s*\d+\s*$' -and [int]$sel -ge 1 -and [int]$sel -le $comps.Count) {
            Invoke-Generate $comps[[int]$sel - 1]
            Read-Host "Press Enter to continue" | Out-Null
        }
    }
}

# Scaling rules are whole tables rather than a list of rows: a radius band is only meaningful beside
# the bands above and below it, so it is edited in place with the whole table on screen.
function Show-RuleMenu {
    while ($true) {
        $ucs = @(Get-UnitComps | Where-Object { $_.Kind -eq 'rule' } | Sort-Object Name)
        Clear-Host
        Write-Host "Scaling rules" -ForegroundColor Cyan
        Write-Host "======================================"
        Write-Host "  How a composition is scaled, not what is in one." -ForegroundColor DarkGray
        Write-Host ""
        for ($i = 0; $i -lt $ucs.Count; $i++) {
            Write-Host ("  {0,2}. {1,-26} [{2,2} rows]" -f ($i + 1), $ucs[$i].Name, (Split-Rows $ucs[$i].Body).Count)
        }
        Write-Host ""
        Write-Host "   B. Back"
        Write-Host ""
        $sel = Read-Host "Select"
        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*\d+\s*$' -and [int]$sel -ge 1 -and [int]$sel -le $ucs.Count) {
            Invoke-EditUnitComp $ucs[[int]$sel - 1]
        }
    }
}

# ---- main loop ----
$comps = @(Get-Compositions | Sort-Object Schema, Name)
foreach ($c in $comps) {
    $c | Add-Member -NotePropertyName Count -NotePropertyValue ((ConvertTo-Rows $c).Rows.Count) -Force
}
if ($comps.Count -eq 0) { Write-Host "No marked static compositions found under $srcDir." -ForegroundColor Yellow }

while ($true) {
    Clear-Host
    Write-Host "DUWS Composition TUI" -ForegroundColor Cyan
    Write-Host "===================="
    Write-Host ""
    Write-Host ("  1. Static compositions   ({0} object layouts, Eden round-trip)" -f $comps.Count)
    Write-Host "  2. Unit compositions     (what a zone, town or squad fields)"
    Write-Host "  3. Tokens                (what one name raises: men, a vehicle, a placer)"
    Write-Host "  4. Scaling rules         (radius multipliers)"
    Write-Host ""
    Write-Host "   Q. Quit"
    Write-Host ""
    $sel = Read-Host "Select"

    if ($sel -match '^\s*[Qq]\s*$') { break }
    elseif ($sel -match '^\s*1\s*$') { Show-StaticMenu $comps }
    elseif ($sel -match '^\s*2\s*$') {
        Show-RowMenu 'composition' 'Unit compositions' 'A composition is a list of teams and vehicles. Open one to see what it fields.' $false
    }
    elseif ($sel -match '^\s*3\s*$') {
        Show-RowMenu 'team' 'Tokens' 'What a composition names: a team of men, one vehicle, or a placer. Open one, or add a row.' $true
    }
    elseif ($sel -match '^\s*4\s*$') { Show-RuleMenu }
}
