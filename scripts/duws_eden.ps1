# duws_eden.ps1 - DUWS composition TUI
#
# Two modes over the same marker-fence idea, because the mission has two kinds of composition and
# both had to be hand-edited in source.
#
# STATIC: scans src/ for
#   // --DUWS-COMPOSITION BEGIN name="..." schema=A [anchor=hqInComp] [z=snap|keep]--
#   <array literal>
#   // --DUWS-COMPOSITION END--
# and emits a paste-ready Eden import (create3DENEntity + rotation) copied to the clipboard.
# Every composition is schema A -- [class, X, Y, Z, dir_deg] with any trailing fields its own
# consumer needs (isWeapon and the like), which this tool ignores. A new one is written from rows
# pasted back out of Eden; what consumes it is still a hand edit.
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
# See docs/info/composition_tooling.md.
$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot   # script lives in scripts/; repo root is its parent
$srcDir  = Join-Path $root "src"
$outFile = Join-Path $root "temp\eden_import.sqf"
$expFile = Join-Path $root "temp\eden_export.sqf"

# One origin for the whole run. An import and its export have to use the same one -- the export
# subtracts it back out -- so it is session state shown on the menu, not a per-generate prompt that
# can be answered differently the second time and hand back rows offset by the difference.
$script:originX = 23100.0
$script:originY = 18700.0
# Z rides along for the same reason, and it is the last import's rather than a constant: a zbase=
# composition is generated at its own altitude, and an export that subtracts zero instead hands back
# every floor offset with a thousand metres added to it.
$script:originZ = 0.0

$inv   = [System.Globalization.CultureInfo]::InvariantCulture
$numRe = '-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'
$rowRe = '"([^"]+)"\s*,\s*({0})\s*,\s*({0})\s*,\s*({0})\s*,\s*({0})' -f $numRe

# How far DUWS_ORIGIN's getPosWorld sits above the ground it stands on: a FlagPole_F reports a
# bounding-box centre, so the marker reads this high. New-ExportScript subtracts it so exported rows
# datum to the marker's base -- the ground -- rather than its centre, which is what keeps origin at
# ground and closes the round trip. Measured against two classes whose authored Z is already in the
# tree -- Land_HBarrier_5_F at 0.74071 and Land_BagFence_Short_F at 0.41548 -- agreeing to a millimetre.
$markerZ = 3.9775

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
    $script:staticWeapons = $null
}

# Invariant-culture number formatting: a comma-decimal locale must not corrupt SQF floats.
function Fmt($v) { ([double]$v).ToString($inv) }

# The line ending a file already uses, so a rewritten fence keeps it. This script is CRLF and the SQF
# it writes into is LF (.gitattributes), so a block joined with the script's own convention leaves a
# file half in each -- which git then reports across every line in the fence, not just the edited
# ones, and normalises away on the next commit so the mess is invisible until someone reads a diff.
function Get-Newline($text) { if ($text -match "`r`n") { "`r`n" } else { "`n" } }

# A fence may glue its first row onto the declaration -- VAR = [ ["class", ...]. Valid SQF, but the
# row scans here identify a row by its line starting with ["...], so that first row's line starts with
# the variable name, fails the test, and is dropped with no warning -- the skip lands before the
# row-like counter. Split it off at the one place a body is captured, so both readers and the writer's
# row window see one row per line, and a later rewrite stores it un-glued.
function Split-GluedFirstRow($body) {
    $nl = Get-Newline $body
    return [regex]::Replace($body,
        '(?m)^([ \t]*(?:private[ \t]+)?[A-Za-z_]\w*[ \t]*=[ \t]*\[)[ \t]*(?=\[")',
        ('$1' + $nl + '    '))
}

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
                Body   = Split-GluedFirstRow $m.Groups[2].Value
                Text   = $text
                File   = $file.Path
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

# Whatever each row carries past the fifth column, indexed alongside ConvertTo-Rows' output. Those
# columns are the consumer's own -- isWeapon on the zone prefabs, and a gun demoted to a prop is a
# gun that never gets a gunner -- and nothing upstream of here knows they exist, so a rewrite has to
# carry them across rather than regenerate them.
function Get-RowTails($body) {
    $tails = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($body -split "`n")) {
        if ($line -notmatch '^\s*\["') { continue }
        if ($line -notmatch $rowRe) { continue }
        $rest = $line.Substring($line.IndexOf($Matches[0]) + $Matches[0].Length)
        $end  = $rest.LastIndexOf(']')
        $tails.Add($(if ($end -ge 0) { $rest.Substring(0, $end) } else { '' }))
    }
    return ,$tails
}

# The single transform a whole paste shares, and how much of it agrees. An export taken after the
# layout was dragged or spun in Eden carries that as a constant on every row, and a constant is
# indistinguishable from deliberate editing until it is counted.
# The classes DUWS_staticRoles maps to a turret role. That table is the mission's own answer to "is
# this a gun", so a row's sixth column is derived from it rather than asked about: every class the
# shipped compositions flag as a weapon appears in it, and no class they flag as scenery does.
#
# Scoped to the fence rather than run over the whole file: the resolver and the placer sit below it,
# and a bare row regex would pick up whatever array literal either grows later.
function Get-StaticWeaponClasses {
    if ($null -ne $script:staticWeapons) { return $script:staticWeapons }
    $names = @{}
    $f = Join-Path $srcDir "duws\shared\functions\fnc_static_roles.sqf"
    if (Test-Path -LiteralPath $f) {
        $m = [regex]::Match([System.IO.File]::ReadAllText($f),
            '(?s)--DUWS-UNITCOMP BEGIN.*?--\r?\n(.*?)\r?\n[ \t]*//\s*--DUWS-UNITCOMP END--')
        if ($m.Success) {
            foreach ($r in [regex]::Matches($m.Groups[1].Value, '(?m)^\s*\[\s*"([A-Za-z0-9_]+)"\s*,\s*"')) {
                $names[$r.Groups[1].Value] = $true
            }
        }
    }
    $script:staticWeapons = $names
    return $script:staticWeapons
}

function Get-ModalDelta($values, $places) {
    if ($values.Count -eq 0) { return $null }
    $g = @($values | Group-Object { [math]::Round($_, $places) } | Sort-Object Count -Descending)
    return [pscustomobject]@{ Value = [math]::Round($g[0].Group[0], $places); Rows = $g[0].Count; Total = $values.Count }
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

function New-ImportScript($name, $schema, $rows, $originX, $originY, $originZ, $zKeep, $flags) {
    $rowStrs = foreach ($i in 0..($rows.Count - 1)) {
        '    ["{0}", {1}, {2}, {3}, {4}, {5}]' -f $rows[$i].Class, (Fmt $rows[$i].OX), (Fmt $rows[$i].OY),
            (Fmt $rows[$i].OZ), (Fmt $rows[$i].Dir), $(if ($flags[$i]) { 'true' } else { 'false' })
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
    # The terrain the mission measures a weapon's height from: fnc_static_place adds the row's Z to
    # the site centre's ground, not to whatever happens to be under the gun. Read once, so a gun on a
    # roof and a gun on open dirt are both placed against the same datum here as they are in play.
    [void]$sb.AppendLine('private _groundZ = getTerrainHeightASL [(_origin select 0), (_origin select 1)];')
    [void]$sb.AppendLine('{')
    [void]$sb.AppendLine('    _x params ["_class","_ox","_oy","_oz","_dir",["_isWeapon", false]];')
    # A ground row is placed on the surface because that is what the mission does with it -- its Z is
    # discarded at spawn, so honouring it here would arrange the layout against heights the game never
    # uses. A weapon row is the opposite: its Z is the one number the mission reads off the row, so
    # flattening it drops every roof gun inside the building it was meant to stand on.
    [void]$sb.AppendLine('    private _z = if (_zKeep) then { (_origin select 2) + _oz }')
    [void]$sb.AppendLine('                 else { if (_isWeapon) then { _oz } else { 0 } };')
    [void]$sb.AppendLine('    private _pos = [(_origin select 0) + _ox, (_origin select 1) + _oy, _z];')
    [void]$sb.AppendLine('    private _ent = create3DENEntity ["Object", _class, _pos];')
    [void]$sb.AppendLine('    _ent set3DENAttribute ["rotation", [0, 0, _dir]];   // [pitch, roll, yaw]; bare number = pitch, not heading')
    [void]$sb.AppendLine('    _ent set3DENAttribute ["position", _pos];   // re-assert after rotating: create3DENEntity + rotate can shift the origin')
    # Two reference points, reconciled by measurement rather than by assuming they agree: the mission
    # writes a weapon's absolute getPosWorld, while the position attribute moves the model's base, so
    # setting one and reading the other leaves a gun standing half its own height too high. Corrected
    # against getPosWorld because that is what the export reads back, which closes the round trip.
    [void]$sb.AppendLine('    if (_isWeapon && {!_zKeep}) then {')
    [void]$sb.AppendLine('        private _want = _groundZ + _oz;')
    [void]$sb.AppendLine('        private _have = (getPosWorld _ent) select 2;')
    [void]$sb.AppendLine('        _ent set3DENAttribute ["position", [_pos select 0, _pos select 1, (_pos select 2) + (_want - _have)]];')
    [void]$sb.AppendLine('    };')
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
    # The frame itself, standing at the origin. The export reads its position rather than being told
    # a coordinate, so dragging or rotating the selection carries the frame with it and the offsets
    # still come out in the composition's own terms.
    #
    # Its X and Y are exact. Its Z reads about four metres high -- getPosWorld reports a bounding-box
    # centre and this marker is a tall pole -- but the export drops the origin to the pole's base
    # before measuring, so rows come back grounded rather than that much low. That is what lets the
    # pole stay tall enough to see in the 3D view instead of being traded for a flat marker nobody can.
    [void]$sb.AppendLine('// ORIGIN MARKER -- not part of the composition. The export takes its own')
    [void]$sb.AppendLine('// origin from this, so keep it selected with everything else: move it and')
    [void]$sb.AppendLine('// the whole layout moves with it, which is the point.')
    [void]$sb.AppendLine("private _apos = [(_origin select 0), (_origin select 1), _mz];")
    [void]$sb.AppendLine('private _anchor = create3DENEntity ["Object", "FlagPole_F", _apos];')
    [void]$sb.AppendLine('_anchor set3DENAttribute ["position", _apos];')
    [void]$sb.AppendLine('_anchor set3DENAttribute ["name", "DUWS_ORIGIN"];')
    [void]$sb.AppendLine("systemChat `"DUWS_FRONT stands $markerY m along +Y and marks the front; DUWS_ORIGIN stands at the origin. The export drops both by name, so Ctrl+A is safe.`";")
    [void]$sb.AppendLine('hint format ["DUWS import: created %1 of %2 objects.", _made, count _rows];')
    return $sb.ToString()
}

# The counterpart to the import above, handed over ready to run rather than copied out of the docs
# and hand-edited: its _origin has to be the one the import used, and a mistyped digit there comes
# back as a whole composition shifted, which reads as a rearrange nobody made.
function New-ExportScript($originX, $originY, $originZ) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('// RUN FROM THE EDEN DEBUG CONSOLE (3D editor toolbar > {}), not the in-game console.')
    [void]$sb.AppendLine('// Select the composition first: click an object in the 3D view, then Ctrl+A.')
    # Read off the scene rather than typed, because the alternative is a coordinate that was true
    # when the import ran: drag or rotate the layout after that and every row carries the difference,
    # which folds back in as a rearrange nobody made. The marker moves with the composition, so the
    # offsets stay in its own frame however far it has been shoved around Eden.
    [void]$sb.AppendLine('// Generated by duws_eden.ps1. The origin comes from the DUWS_ORIGIN marker;')
    [void]$sb.AppendLine('// the coordinate below is only the fallback for a scene that has none.')
    [void]$sb.AppendLine("private _fallback = [$(Fmt $originX), $(Fmt $originY), $(Fmt $originZ)];")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('private _named = { ((_x get3DENAttribute "name") param [0, ""]) };')
    [void]$sb.AppendLine('private _anchor = ((all3DENEntities select 0) select { (_x call _named) == "DUWS_ORIGIN" }) param [0, objNull];')
    # getPosWorld reports a bounding-box centre, so the pole reads $markerZ m above the ground it
    # stands on. Drop the origin's Z to that base, so a row's exported Z is its height over the
    # ground -- what the import and the mission both read it as -- and origin rests at ground. X/Y
    # are exact off getPosWorld and stay. Subtracting the constant works at any altitude, so a
    # zbase= layout off-map keeps datuming to its own floor rather than a terrain lookup that misses.
    [void]$sb.AppendLine('private _origin = if (isNull _anchor) then { _fallback } else {')
    [void]$sb.AppendLine('    private _w = getPosWorld _anchor;')
    [void]$sb.AppendLine("    [_w select 0, _w select 1, (_w select 2) - $(Fmt $markerZ)]   // pole centre -> base (ground)")
    [void]$sb.AppendLine('};')
    [void]$sb.AppendLine('if (isNull _anchor) then {')
    [void]$sb.AppendLine('    systemChat "No DUWS_ORIGIN marker: falling back to the import coordinate. If the layout was moved or rotated since, these rows are wrong.";')
    [void]$sb.AppendLine('};')
    [void]$sb.AppendLine('')
    # Same reason the import names them: a composition may legitimately hold a flagpole, so a marker
    # is dropped by the name that is its identity rather than by the class it happens to wear.
    [void]$sb.AppendLine('private _objs = (get3DENSelected "Object") select {')
    [void]$sb.AppendLine('    !((_x call _named) in ["DUWS_FRONT", "DUWS_ORIGIN"])')
    [void]$sb.AppendLine('};')
    [void]$sb.AppendLine('if (_objs isEqualTo []) exitWith { systemChat "Nothing selected: click an object in the 3D view, then Ctrl+A."; };')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('private _rows = _objs apply {')
    [void]$sb.AppendLine('    private _p = getPosWorld _x;')
    [void]$sb.AppendLine('    format ["[""%1"", %2, %3, %4, %5]",')
    [void]$sb.AppendLine('        typeOf _x,')
    [void]$sb.AppendLine('        (_p select 0) - (_origin select 0),')
    [void]$sb.AppendLine('        (_p select 1) - (_origin select 1),')
    [void]$sb.AppendLine('        (_p select 2) - (_origin select 2),')
    [void]$sb.AppendLine('        getDir _x]')
    [void]$sb.AppendLine('};')
    [void]$sb.AppendLine('copyToClipboard (_rows joinString ("," + endl));')
    # Named here because this is the moment the numbers are in hand: with the marker, every row's Z is
    # its height over the ground the marker stands on; a markerless fallback measures from Z 0, so its
    # rows carry the site's terrain baseline instead and want Update's constant-Z subtract.
    [void]$sb.AppendLine('systemChat format ["Copied %1 objects, origin %2.", count _objs, if (isNull _anchor) then {"the import coordinate"} else {"DUWS_ORIGIN"}];')
    return $sb.ToString()
}

function Save-And-Copy($script, $path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    [System.IO.File]::WriteAllText($path, $script, (New-Object System.Text.UTF8Encoding($false)))
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
    # Kept so the export below subtracts what this import added, without asking again.
    $script:originZ = $originZ
    # Column 6 as the zone prefabs mean it, which is a bare boolean. The HQ and FOB turret fences put
    # a role name in the same slot, and matching only `, true` leaves those rows alone -- they sit at
    # Z 0 regardless, so there is nothing there to preserve.
    $tails = Get-RowTails $comp.Body
    $flags = @()
    for ($i = 0; $i -lt $res.Rows.Count; $i++) {
        $flags += ($i -lt $tails.Count -and $tails[$i] -match '^\s*,\s*true\s*$')
    }
    $importScript = New-ImportScript $comp.Name $comp.Schema $res.Rows $script:originX $script:originY $originZ ($comp.ZMode -eq 'keep') $flags
    $clip         = Save-And-Copy $importScript $outFile
    Write-Host ""
    Write-Host ("Generated {0} objects from '{1}' (schema {2}, z={3}) at origin {4} {5}." -f $res.Rows.Count, $comp.Name, $comp.Schema, $comp.ZMode, (Fmt $script:originX), (Fmt $script:originY)) -ForegroundColor Green
    if ($res.Rows.Count -lt $res.Seen) {
        Write-Host ("WARNING: {0} row-like line(s) did not parse and were skipped." -f ($res.Seen - $res.Rows.Count)) -ForegroundColor Yellow
    }
    Write-Host ("Wrote $outFile" + $(if ($clip) { " and copied to clipboard." } else { " (clipboard unavailable; copy the file)." }))
}

# ---- creating a fence ----

# Appends a new fence to a source file, creating the file when it does not exist yet. Shared by both
# kinds, because where a fence may live and how it is written are the same question for each.
#
# Under src/ and .sqf only, refused rather than corrected. Both scans enumerate *.sqf beneath src/,
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

# Rows pasted back from the Eden export snippet. Returns the parsed rows, or $null if nothing usable
# arrived -- the caller has a name and a file by then and should not write an empty fence.
function Read-PastedRows {
    Write-Host ""
    Write-Host "  Paste the export rows. Blank line to finish." -ForegroundColor DarkGray
    Write-Host "  The snippet in docs/info/composition_tooling.md copies them to the clipboard." -ForegroundColor DarkGray
    Write-Host ""
    $lines = @()
    while ($true) { $l = Read-Host; if ([string]::IsNullOrWhiteSpace($l)) { break }; $lines += $l }
    if ($lines.Count -eq 0) { return $null }
    $pseudo = [pscustomobject]@{ Anchor=''; Body=($lines -join "`n"); Text='' }
    $res = ConvertTo-Rows $pseudo
    if ($res.Rows.Count -eq 0) {
        Write-Host "  No rows parsed. Expected lines of the form [`"class`", x, y, z, dir]." -ForegroundColor Yellow
        return $null
    }
    if ($res.Rows.Count -lt $res.Seen) {
        Write-Host ("  WARNING: {0} row-like line(s) did not parse and were dropped." -f ($res.Seen - $res.Rows.Count)) -ForegroundColor Yellow
    }
    # Comma-wrapped, like every other list this script hands back: a returned list is unrolled by
    # the pipeline, so a one-row paste would arrive as a bare row object rather than as rows.
    #
    # The comma alone, with no @() inside it. Wrapping an already-enumerable value that way throws
    # "Argument types do not match" at the comma -- which is not what ,@($x, $y) does a few lines up,
    # where @() is building the array out of scalars rather than being handed one.
    return ,$res.Rows
}

# The variable a new composition's array is assigned to. A leading underscore is a local, and a local
# at file scope is only readable by an #include -- which is what the killhouse does and what a prefab
# builder holding its own array does. Anything else is a global the rest of the mission can read.
function Format-Declaration($varName) {
    if ($varName.StartsWith('_')) { return "private $varName" }
    return $varName
}

# Create a static composition from rows arranged in Eden. The tool could only ever open one that
# already existed, so a new layout meant hand-writing the fence and pasting rows under it, and a
# mistyped attribute failed by the composition never appearing in the menu.
# Replaces one composition's row lines in place. The declaration and the closing bracket are carried
# over rather than regenerated: a fence's array may be declared private, or named something the tool
# never saw, and rewriting that from a guess turns an edited layout into a file that will not compile.
#
# Matched by fence name, like the unit tables, and every other fence in the file is handed back
# untouched. Strict UTF-8 for the same reason Save-UnitComp is: reading a legacy single-byte file is
# harmless, writing one back would corrupt everything in it that is not this array.
function Save-CompFence($comp, $newBody) {
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try { $text = $strict.GetString([System.IO.File]::ReadAllBytes($comp.File)) }
    catch {
        Write-Host "Refusing to write: $($comp.File) is not valid UTF-8, and rewriting it would corrupt the rest of the file." -ForegroundColor Red
        return $false
    }
    $target = $comp.Name
    $re = [regex]'(?s)(//[ \t]*--DUWS-COMPOSITION BEGIN\s+(.*?)--\r?\n)(.*?)(\r?\n[ \t]*//\s*--DUWS-COMPOSITION END--)'
    $updated = $re.Replace($text, {
        param($m)
        if ((Get-Attr $m.Groups[2].Value 'name="([^"]*)"' '') -ne $target) { return $m.Value }
        return $m.Groups[1].Value + $newBody + $m.Groups[4].Value
    })
    if ($updated -eq $text) {
        Write-Host "Nothing written: the fence was not found or the body is unchanged." -ForegroundColor Yellow
        return $false
    }
    [System.IO.File]::WriteAllText($comp.File, $updated, (New-Object System.Text.UTF8Encoding($false)))
    Clear-SourceCache
    return $true
}

# The return leg the round trip never had: pasted Eden rows folded back into the fence they came
# from. Doing it by hand is what this replaces, and the reason it goes wrong is that an export is
# taken against the origin and heading the layout happened to be sitting at -- drag or rotate the
# selection between import and export and every row carries that, which reads as a rearrange rather
# than as the whole composition having moved.
#
# So the systematic differences are counted and shown before anything is written. Reconciled by
# index and never merged by class: two HBarriers are interchangeable to a reader and separate rows
# to the array, so a paste one row short has to read as a gap rather than silently re-key every row
# after it.
function Update-StaticFence($comp) {
    # Taken in steps, and the row list used as it comes back rather than wrapped in @(). The tool
    # runs with $ErrorActionPreference = "Stop", so a chained one-liner reports the whole line as the
    # site of a fault and says nothing about which half of it failed. A List indexes and counts the
    # way an array does, so there was nothing to convert in the first place.
    $conv  = ConvertTo-Rows $comp
    $old   = $conv.Rows
    $tails = Get-RowTails $comp.Body
    if ($old.Count -eq 0) { Write-Host "  That composition has no rows this tool can read." -ForegroundColor Red; return }

    $new = Read-PastedRows
    if ($null -eq $new) { return }

    Write-Host ""
    Write-Host ("  {0}: {1} rows in the source, {2} pasted." -f $comp.Name, $old.Count, $new.Count)

    $pairs = New-Object System.Collections.Generic.List[object]
    $bad   = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $new.Count; $i++) {
        $o = if ($i -lt $old.Count) { $old[$i] } else { $null }
        if ($null -ne $o -and $o.Class -eq $new[$i].Class) {
            $pairs.Add([pscustomobject]@{ O = $o; N = $new[$i] })
        } else {
            $bad.Add(("    [{0}] source {1} / paste {2}" -f $i, $(if ($o) { $o.Class } else { '(none)' }), $new[$i].Class))
        }
    }
    if ($bad.Count -gt 0) {
        Write-Host ("  {0} row(s) do not line up by index:" -f $bad.Count) -ForegroundColor Yellow
        foreach ($b in ($bad | Select-Object -First 8)) { Write-Host $b -ForegroundColor Yellow }
        if ($bad.Count -gt 8) { Write-Host ("    ... and {0} more" -f ($bad.Count - 8)) -ForegroundColor Yellow }
    }
    # Nothing lining up is what a stub fence looks like -- one placeholder row, written so this tool
    # has something to import and raise its markers from -- and equally what a paste dropped into the
    # wrong composition looks like. The rows cannot tell the two apart, so it is asked rather than
    # decided: only whoever ran the export knows which fence it came out of.
    if ($pairs.Count -eq 0) {
        Write-Host "  Nothing lines up by index." -ForegroundColor Red
        $q = "  Replace all {0} row(s) of '{1}' with the {2} pasted? (y/N)" -f $old.Count, $comp.Name, $new.Count
        if ((Read-Host $q) -notmatch '^\s*[Yy]') { Write-Host "  Nothing written." -ForegroundColor Yellow; return }
    }

    # A row that lines up inherits column 6 from the row it replaces, which is the author's own
    # answer. A row that does not has no such source, and leaving the column off is not a milder
    # version of the same row: a nil isWeapon makes both of a prefab's guards evaluate to nothing, so
    # neither pass skips it and the object is built twice -- once ground-snapped as a prop, once
    # through fnc_static_place as a resolved gun with a gunner seated in it. Derived from the class
    # rather than asked about, because DUWS_staticRoles already knows which classes are guns.
    $usesTails = @($tails | Where-Object { $_.Trim() -ne '' }).Count -gt 0
    $weapons   = Get-StaticWeaponClasses
    $rowTails  = @()
    $derived   = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $new.Count; $i++) {
        if ($i -lt $old.Count -and $i -lt $tails.Count -and $old[$i].Class -eq $new[$i].Class) {
            $rowTails += $tails[$i]
        } elseif ($usesTails) {
            $isW = $weapons.ContainsKey($new[$i].Class)
            $rowTails += $(if ($isW) { ', true' } else { ', false' })
            $derived.Add(("    [{0}] {1} -> {2}" -f $i, $new[$i].Class, $(if ($isW) { 'weapon' } else { 'scenery' })))
        } else {
            $rowTails += ''
        }
    }
    if ($derived.Count -gt 0) {
        Write-Host ("  Column 6 derived from DUWS_staticRoles for {0} row(s):" -f $derived.Count) -ForegroundColor Cyan
        foreach ($d in $derived) { Write-Host $d -ForegroundColor Cyan }
    }

    $dir = Get-ModalDelta @($pairs | ForEach-Object { (($_.N.Dir - $_.O.Dir) % 360 + 360) % 360 }) 2
    $dz  = Get-ModalDelta @($pairs | ForEach-Object { $_.N.OZ - $_.O.OZ }) 3
    $rot = ($null -ne $dir -and $dir.Value -gt 0.05 -and $dir.Value -lt 359.95 -and $dir.Rows * 2 -ge $dir.Total)

    if ($rot) {
        Write-Host ("  The layout was rotated {0} deg as a whole ({1} of {2} rows agree)." -f (Fmt $dir.Value), $dir.Rows, $dir.Total) -ForegroundColor Red
        Write-Host "  Folding this in stores it rotated, and its X/Y are offsets in the rotated frame." -ForegroundColor Red
    }

    # Offered rather than applied: a constant Z across the paste is nearly always the sea-level
    # baseline an export carries when its origin Z is 0, but it is equally what raising the whole
    # layout by hand looks like, and only the person who moved it knows which.
    $zDrop = 0.0
    if ($null -ne $dz -and [math]::Abs($dz.Value) -gt 0.001 -and $dz.Rows * 2 -ge $dz.Total) {
        Write-Host ("  {0} of {1} rows shifted by exactly {2} m in Z -- the terrain the export measured from." -f $dz.Rows, $dz.Total, (Fmt $dz.Value)) -ForegroundColor Yellow
        if ((Read-Host ("  Subtract {0} from every Z? (Y/n)" -f (Fmt $dz.Value))) -notmatch '^\s*[Nn]') { $zDrop = $dz.Value }
    }
    Write-Host ""
    if ((Read-Host ("  Rewrite '{0}' with {1} rows? (y/N)" -f $comp.Name, $new.Count)) -notmatch '^\s*[Yy]') {
        Write-Host "  Nothing written." -ForegroundColor Yellow
        return
    }

    # The anchor ConvertTo-Rows took off the source rows goes back on: the HQ array stores
    # composition coordinates, and a paste is offsets.
    $anchor = Get-AnchorXY $comp
    $nl     = Get-Newline $comp.Body

    # Row indent from the first clean row line the body has, else the canonical four spaces. Only the
    # leading whitespace of the rebuilt rows rides on it.
    $rowLine = @($comp.Body -split "`r?`n" | Where-Object { $_ -match '^\s*\["' })
    $indent  = if ($rowLine.Count -gt 0 -and $rowLine[0] -match '^([ \t]+)') { $Matches[1] } else { '    ' }

    # A rebuild from the paste keeps only rows: an interior comment line -- not a row, the declaration
    # or the close -- does not survive.
    $dropped = @($comp.Body -split "`r?`n" | Where-Object {
        $_ -notmatch '^\s*\["' -and $_ -notmatch '=\s*\[' -and $_ -notmatch '\];?\s*$' -and $_.Trim() -ne ''
    }).Count
    if ($dropped -gt 0) {
        Write-Host ("  Note: {0} comment line(s) inside the array are not carried over." -f $dropped) -ForegroundColor Yellow
    }

    $rowStrs = @()
    for ($i = 0; $i -lt $new.Count; $i++) {
        $tail = $rowTails[$i]
        $rowStrs += ('{0}["{1}", {2}, {3}, {4}, {5}{6}]' -f $indent, $new[$i].Class,
            (Fmt ($new[$i].OX + $anchor[0])), (Fmt ($new[$i].OY + $anchor[1])),
            (Fmt ($new[$i].OZ - $zDrop)), (Fmt $new[$i].Dir), $tail)
    }

    # Rebuilt canonically rather than by splicing the old row span. An export can glue the declaration
    # onto the first row and the closing "];" onto the last; locating rows by pattern then mis-reads
    # either as a row -- dropping the "];" or folding a row into the declaration. The declaration is
    # the body up to and including the array's opening "[" (a variable name carries none), the rows are
    # the paste, and the close is always its own "];".
    $decl = ($comp.Body.Substring(0, $comp.Body.IndexOf('[') + 1)).TrimEnd()
    $body = $decl + $nl + ($rowStrs -join ",$nl") + $nl + '];'

    if (Save-CompFence $comp $body) {
        Write-Host ("  Rewrote '{0}' in {1}. Review the diff before committing." -f $comp.Name, (Split-Path -Leaf $comp.File)) -ForegroundColor Green
    }
}

function New-StaticFence {
    Clear-Host
    Write-Host "New static composition" -ForegroundColor Cyan
    Write-Host "======================================"
    Write-Host "  Arrange it in Eden, run the export snippet, and paste the rows here." -ForegroundColor DarkGray
    Write-Host ""

    $name = (Read-Host "  Name (as it appears in the menu)").Trim()
    if ($name -eq '') { return }
    if ($name.Contains('"')) { Write-Host "  A name cannot contain a quote." -ForegroundColor Red; return }
    # Refused rather than allowed through: the menu selects a composition by name, so a second one
    # under the same name is a row nobody can reach on purpose.
    if (@(Get-Compositions | Where-Object { $_.Name -eq $name }).Count -gt 0) {
        Write-Host ("  A composition called '{0}' already exists." -f $name) -ForegroundColor Red
        return
    }

    # Derived from the name rather than prompted blind, because the answer is nearly always the same
    # shape and a global is what a placer outside this file can read.
    $suggest = 'DUWS_comp_' + (($name -replace '[^A-Za-z0-9]', ''))
    $varName = (Read-Host ("  Variable (blank = {0})" -f $suggest)).Trim()
    if ($varName -eq '') { $varName = $suggest }
    if ($varName -notmatch '^_?[A-Za-z]\w*$') { Write-Host "  That is not a variable name." -ForegroundColor Red; return }

    $file = Read-Host "  File under src/ (existing or new), e.g. src\duws\server\init_zones\hardpoint_compositions.sqf"
    if ([string]::IsNullOrWhiteSpace($file)) { return }

    $rows = Read-PastedRows
    if ($null -eq $rows) { return }

    $rowStrs = foreach ($r in $rows) {
        '    ["{0}", {1}, {2}, {3}, {4}]' -f $r.Class, (Fmt $r.OX), (Fmt $r.OY), (Fmt $r.OZ), (Fmt $r.Dir)
    }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("`r`n")
    [void]$sb.Append("// --DUWS-COMPOSITION BEGIN name=`"$name`" schema=A--`r`n")
    [void]$sb.Append((Format-Declaration $varName) + " = [`r`n")
    [void]$sb.Append(($rowStrs -join ",`r`n"))
    [void]$sb.Append("`r`n];`r`n")
    [void]$sb.Append("// --DUWS-COMPOSITION END--`r`n")

    $header = "// Composition data. The fences are comments, so the preprocessor discards them and the" + "`r`n" +
              "// markup costs nothing at runtime; scripts/duws_eden.ps1 reads them to round-trip a layout" + "`r`n" +
              "// through the 3D editor. See docs/info/composition_tooling.md." + "`r`n"

    if (Add-FenceToFile $file $sb.ToString() $header) {
        Write-Host ("  {0}: {1} rows." -f $name, $rows.Count) -ForegroundColor Green
        # Said once, here, because it is the one thing the export cannot carry: the snippet emits five
        # columns and a consumer that wants more -- an isWeapon flag, a faction role -- reads them off
        # positions the export never wrote.
        Write-Host "  Trailing columns a consumer needs (isWeapon, a faction role) are added by hand." -ForegroundColor DarkGray
    }
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

# Re-scanned on every draw rather than captured once at startup, for the reason the unit menus
# already are: a composition created in this session has to appear in the menu that created it.
function Get-StaticList {
    $list = @(Get-Compositions | Sort-Object Schema, Name)
    foreach ($c in $list) {
        $c | Add-Member -NotePropertyName Count -NotePropertyValue ((ConvertTo-Rows $c).Rows.Count) -Force
    }
    return ,$list
}

function Show-StaticMenu {
    while ($true) {
        $comps = Get-StaticList
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
        Write-Host "   E. Copy the Eden export snippet"
        Write-Host "   U. Update a composition from pasted rows"
        Write-Host "   N. New composition from an Eden export"
        Write-Host "   B. Back"
        Write-Host ""
        $sel = Read-Host "Select"

        if ($sel -match '^\s*[Bb]\s*$') { break }
        elseif ($sel -match '^\s*[Oo]\s*$') { Set-Origin }
        elseif ($sel -match '^\s*[Ee]\s*$') {
            $clip = Save-And-Copy (New-ExportScript $script:originX $script:originY $script:originZ) $expFile
            Write-Host ""
            Write-Host ("Export snippet at origin {0} {1} {2}." -f (Fmt $script:originX), (Fmt $script:originY), (Fmt $script:originZ)) -ForegroundColor Green
            Write-Host ("Wrote $expFile" + $(if ($clip) { " and copied to clipboard." } else { " (clipboard unavailable; copy the file)." }))
            Read-Host "Press Enter to continue" | Out-Null
        }
        elseif ($sel -match '^\s*[Uu]\s*$') {
            $which = Read-Host "  Which composition (number)"
            if ($which -match '^\s*\d+\s*$' -and [int]$which -ge 1 -and [int]$which -le $comps.Count) {
                # Caught rather than allowed to terminate: this script runs with
                # $ErrorActionPreference = "Stop", so any fault anywhere below takes the whole TUI
                # down and the rows just pasted go with it. The site of the failure is worth more
                # than the stack, so both the message and the offending line are reported.
                try { Update-StaticFence $comps[[int]$which - 1] }
                catch {
                    Write-Host ("  Update failed: {0} ({1})" -f $_.Exception.Message, $_.Exception.GetType().FullName) -ForegroundColor Red
                    Write-Host ("  line {0}: {1}" -f $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.Line.Trim()) -ForegroundColor DarkGray
                    # The frame chain, not just the top frame: PowerShell reports the statement in
                    # the failing scope, which names a whole pipeline rather than the call inside it
                    # that threw.
                    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
                }
            } else {
                Write-Host "  No such composition." -ForegroundColor Yellow
            }
            Read-Host "Press Enter to continue" | Out-Null
        }
        elseif ($sel -match '^\s*[Nn]\s*$') {
            New-StaticFence
            Read-Host "Press Enter to continue" | Out-Null
        }
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

# ---- main loop ----
if ((Get-StaticList).Count -eq 0) { Write-Host "No marked static compositions found under $srcDir." -ForegroundColor Yellow }

while ($true) {
    Clear-Host
    Write-Host "DUWS Composition TUI" -ForegroundColor Cyan
    Write-Host "===================="
    Write-Host ""
    Write-Host ("  1. Static compositions   ({0} object layouts, Eden round-trip)" -f (Get-StaticList).Count)
    Write-Host "  2. Unit compositions     (what a zone, town or squad fields)"
    Write-Host "  3. Tokens                (what one name stands for: men, a vehicle, a gun)"
    Write-Host ""
    Write-Host "   Q. Quit"
    Write-Host ""
    $sel = Read-Host "Select"

    if ($sel -match '^\s*[Qq]\s*$') { break }
    elseif ($sel -match '^\s*1\s*$') { Show-StaticMenu }
    elseif ($sel -match '^\s*2\s*$') {
        Show-RowMenu 'composition' 'Unit compositions' 'A composition is a list of teams and vehicles. Open one to see what it fields.'
    }
    elseif ($sel -match '^\s*3\s*$') {
        Show-RowMenu 'team' 'Tokens' 'What a name stands for: a team of men, one vehicle, or the role a static class fills. Open one, or add a row.'
    }
}
