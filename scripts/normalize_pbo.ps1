# normalize_pbo.ps1  <pbo-path>
#
# pboman3 (pboc.exe, used by repack.cmd) stores FORWARD-slash paths inside the PBO,
# but Arma's convention — and this mission's own load paths ("duws\functions\...") —
# use BACKslashes. This rewrites '/' -> '\' inside stored filenames only, then
# recomputes the trailing SHA1.
#
# It is a same-length byte swap (0x2F -> 0x5C), so every header offset and all data
# blocks are untouched; only the filename bytes and the recomputed checksum change.
# The algorithm was verified byte-for-byte against a packed pbo before this port.
param([Parameter(Mandatory = $true)][string]$Path)
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Path)) { Write-Error "pbo not found: $Path"; exit 1 }
$d = [System.IO.File]::ReadAllBytes($Path)

$i = 0
$first = $true
$ranges = New-Object System.Collections.Generic.List[object]
$totalData = [long]0

while ($true) {
    $nameStart = $i
    while ($d[$i] -ne 0) { $i++ }
    $nameEnd = $i                 # index of the null terminator
    $nameLen = $nameEnd - $nameStart
    $i++                          # skip the null

    $packing = [BitConverter]::ToUInt32($d, $i)
    $orig    = [BitConverter]::ToUInt32($d, $i + 4)
    $res     = [BitConverter]::ToUInt32($d, $i + 8)
    $ts      = [BitConverter]::ToUInt32($d, $i + 12)
    $dsize   = [BitConverter]::ToUInt32($d, $i + 16)
    $i += 20

    # header terminator: empty name + all-zero fields
    if ($nameLen -eq 0 -and $packing -eq 0 -and $orig -eq 0 -and $res -eq 0 -and $ts -eq 0 -and $dsize -eq 0) {
        break
    }
    # 'Vers' properties entry: skip its key/value null-terminated strings, don't touch them
    if ($first -and $nameLen -eq 0 -and $packing -eq 0x56657273) {
        while ($true) {
            $ks = $i
            while ($d[$i] -ne 0) { $i++ }
            $kl = $i - $ks; $i++
            if ($kl -eq 0) { break }
            while ($d[$i] -ne 0) { $i++ }; $i++    # value string
        }
        $first = $false
        continue
    }
    $first = $false
    $ranges.Add(@($nameStart, $nameEnd))
    $totalData += [long]$dsize
}

$dataStart = $i
$trailerStart = [int]([long]$dataStart + $totalData)
$trailerLen = $d.Length - $trailerStart

# '/' (0x2F) -> '\' (0x5C) inside filenames only
$changed = 0
foreach ($r in $ranges) {
    for ($k = $r[0]; $k -lt $r[1]; $k++) {
        if ($d[$k] -eq 0x2F) { $d[$k] = 0x5C; $changed++ }
    }
}

# recompute the trailing SHA1 over the body [0 .. trailerStart)
if ($trailerLen -eq 21 -and $d[$trailerStart] -eq 0) {
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $hash = $sha1.ComputeHash($d, 0, $trailerStart)
    [Array]::Copy($hash, 0, $d, $trailerStart + 1, 20)
}

[System.IO.File]::WriteAllBytes($Path, $d)
Write-Host "[repack] normalized $changed path separators across $($ranges.Count) entries"
