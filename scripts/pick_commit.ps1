# repack.cmd source picker: renders a menu of the last five commits to the console and
# reads a choice, then emits exactly one token on stdout for repack.cmd to consume:
#   WORKING       pack the live src\ working tree (default -- Enter or 0)
#   <short-hash>  pack src\ as it stood at that commit
#   INVALID       the typed value did not resolve to a commit
#
# The menu and prompt go through Write-Host / Read-Host (the console), so stdout carries
# only the result token and repack.cmd can capture it with a for /f. Written for Windows
# PowerShell 5.1: no `u{} escapes, no ternary, no Expand-Archive-only features.
$ErrorActionPreference = 'SilentlyContinue'

$sep = [char]31   # git %x1f field separator; a subject can hold spaces, this cannot.
$log = @(git log -5 --format='%h%x1f%s' 2>$null)
$hashes = @()

Write-Host ''
Write-Host '[repack] Pick a source to pack:'
Write-Host '   0) working tree (current src\)   [default -- press Enter]'
for ($i = 0; $i -lt $log.Count; $i++) {
    $parts = $log[$i] -split $sep, 2
    $hashes += $parts[0]
    $desc = ''
    if ($parts.Count -gt 1) { $desc = $parts[1] }
    Write-Host ('   {0}) {1}  {2}' -f ($i + 1), $parts[0], $desc)
}
Write-Host '   or paste a full commit hash'

$c = Read-Host '[repack] Choice'
if ($null -eq $c) { $c = '' }
$c = $c.Trim()

if ($c -eq '' -or $c -eq '0') { Write-Output 'WORKING'; exit 0 }

# A single 1-5 is a menu pick. Anything longer falls through to the commit-ish resolver,
# so an all-digit short hash is not mistaken for a menu number.
if ($c -match '^[1-5]$') {
    $idx = [int]$c - 1
    if ($idx -lt $hashes.Count) { Write-Output $hashes[$idx]; exit 0 }
    Write-Output 'INVALID'; exit 0
}

# Any other input: resolve it as a commit and hand back its short hash, or INVALID.
$short = git rev-parse --short "$c^{commit}" 2>$null
if ($LASTEXITCODE -eq 0 -and $short) { Write-Output $short.Trim(); exit 0 }
Write-Output 'INVALID'
exit 0
