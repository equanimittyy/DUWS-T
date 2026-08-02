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
#   // --DUWS-UNITCOMP BEGIN name="..." row="<what a row means>" [fields="a, b, c"] [prefix=opfor_]--
#   <name> = [ <row>, <row>, ... ];
#   // --DUWS-UNITCOMP END--
# and edits the rows in place. These are the spawn tables -- tier compositions, radius multipliers,
# the category map, the group rosters -- which are data, not layout, so there is nothing to
# round-trip through Eden.
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

# Invariant-culture number formatting: a comma-decimal locale must not corrupt SQF floats.
function Fmt($v) { ([double]$v).ToString($inv) }

function Get-Compositions {
    $comps = @()
    $blockRe = [regex]'(?s)--DUWS-COMPOSITION BEGIN\s+(.*?)--\r?\n(.*?)\r?\n[ \t]*//\s*--DUWS-COMPOSITION END--'
    foreach ($file in (Get-ChildItem -Path $srcDir -Recurse -Filter *.sqf -File)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
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
    $out = @()
    foreach ($file in (Get-ChildItem -Path $srcDir -Recurse -Filter *.sqf -File)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        if ($text -notmatch 'DUWS-UNITCOMP BEGIN') { continue }
        foreach ($m in $unitFenceRe.Matches($text)) {
            $out += [pscustomobject]@{
                Name   = Get-Attr $m.Groups[2].Value 'name="([^"]*)"' '(unnamed)'
                RowOf  = Get-Attr $m.Groups[2].Value 'row="([^"]*)"' 'row'
                Fields = Get-Attr $m.Groups[2].Value 'fields="([^"]*)"' ''
                Prefix = Get-Attr $m.Groups[2].Value 'prefix=([A-Za-z0-9_]+)' ''
                File   = $file.FullName
                Body   = $m.Groups[3].Value
            }
        }
    }
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
        foreach ($f in (Get-ChildItem -Path $dir -Recurse -Filter *.sqf -File)) {
            # No -Encoding: only ASCII slot names are matched, and nothing here is ever written.
            $seen = @{}
            foreach ($m in $re.Matches((Get-Content -LiteralPath $f.FullName -Raw))) {
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

# Rebuild a field's literal from typed text, keeping the kind it already had: a list stays a list,
# a quoted name stays quoted, a number stays a number. Inferred from the current value rather than
# declared per table, because the fence has no schema and every table would have to repeat one.
# Returns $null when the text cannot be that kind -- refusing beats writing a table that will not
# compile. Coverage notes for every role slot named are appended to $notes.
function Format-FieldLiteral($current, $text, $prefix, [ref]$notes) {
    $qualify = {
        param($s)
        $r = Resolve-Role $s.Trim().Trim('"') $prefix
        if ($r.Coverage -ge 0) { $notes.Value += ,$r }
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
            Write-Host ("  {0}. {1,-20} {2}" -f ($i + 1), $label, (Show-Field $entries[$i] $prefix))
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
            Write-Host "  That field holds a number; leaving it as it was." -ForegroundColor Yellow
            Read-Host "  Press Enter to continue" | Out-Null
            continue
        }
        # Coverage is reported before the row is touched, not after the write: a roster naming a
        # slot only some factions fill still compiles, and the only sign at runtime is a group that
        # spawns short on those factions.
        $bad = @($notes | Where-Object { $_.Coverage -lt $_.Total })
        if ($bad.Count -gt 0) {
            Write-Host ""
            foreach ($n in $bad) {
                if ($n.Coverage -eq 0) {
                    Write-Host ("  {0}: no faction file defines this slot -- it would spawn nothing." -f $n.Name) -ForegroundColor Red
                } else {
                    Write-Host ("  {0}: defined by {1} of {2} faction files -- thins on the rest." -f $n.Name, $n.Coverage, $n.Total) -ForegroundColor Yellow
                }
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

# ---- main loop ----
$comps = @(Get-Compositions | Sort-Object Schema, Name)
foreach ($c in $comps) {
    $c | Add-Member -NotePropertyName Count -NotePropertyValue ((ConvertTo-Rows $c).Rows.Count) -Force
}
if ($comps.Count -eq 0) { Write-Host "No marked static compositions found under $srcDir." -ForegroundColor Yellow }

while ($true) {
    # Re-read each pass: an edit rewrites source, and a stale body would show the pre-edit table.
    $ucs = @(Get-UnitComps | Sort-Object Name)

    Clear-Host
    Write-Host "DUWS Composition TUI" -ForegroundColor Cyan
    Write-Host "===================="
    Write-Host ("Origin: {0} {1}" -f (Fmt $script:originX), (Fmt $script:originY)) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " Static compositions (Eden round-trip, read-only)" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $comps.Count; $i++) {
        $c = $comps[$i]
        Write-Host ("  {0,2}. {1,-26} [schema {2}, {3,4} objs]" -f ($i + 1), $c.Name, $c.Schema, $c.Count)
    }
    Write-Host ""
    Write-Host " Unit compositions (spawn tables, editable)" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $ucs.Count; $i++) {
        $u = $ucs[$i]
        Write-Host ("  U{0,-2}. {1,-26} [{2,2} rows]" -f ($i + 1), $u.Name, (Split-Rows $u.Body).Count)
    }
    Write-Host ""
    Write-Host "   O. Set the import origin      P. Paste your own array (schema A)"
    Write-Host "   Q. Quit"
    Write-Host ""
    $sel = Read-Host "Select"

    if ($sel -match '^\s*[Qq]\s*$') { break }
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
    elseif ($sel -match '^\s*[Uu]\s*(\d+)\s*$' -and [int]$Matches[1] -ge 1 -and [int]$Matches[1] -le $ucs.Count) {
        Invoke-EditUnitComp $ucs[[int]$Matches[1] - 1]
    }
    elseif ($sel -match '^\s*\d+\s*$' -and [int]$sel -ge 1 -and [int]$sel -le $comps.Count) {
        Invoke-Generate $comps[[int]$sel - 1]
        Read-Host "Press Enter to continue" | Out-Null
    }
}
