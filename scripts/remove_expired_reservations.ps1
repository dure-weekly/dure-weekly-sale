# 공급일이 8/13(목) 또는 그 이전인 사전예약 항목을 제거한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\reservations.json"

$removeIds = @("r036","r037","r038","r048","r063","r046","r045","r047","r068","r070","r061","r062","r028","r027","r030","r025","r026","r023","r024","r029","r022")

function Find-MatchingBracket($text, $startBracketIndex) {
    $depth = 0
    $inString = $false
    $escaped = $false
    for ($i = $startBracketIndex; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($inString) {
            if ($escaped) { $escaped = $false }
            elseif ($ch -eq '\') { $escaped = $true }
            elseif ($ch -eq '"') { $inString = $false }
            continue
        }
        if ($ch -eq '"') { $inString = $true; continue }
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }
    return -1
}

$text = Get-Content $dataPath -Raw -Encoding UTF8

$removals = @()
$notFound = @()
foreach ($id in $removeIds) {
    $idMarker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($idMarker)
    if ($idIdx -eq -1) { $notFound += $id; continue }
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $blockEnd = $closeBraceIdx + 1
    if ($text.Substring($blockEnd, 1) -eq ",") { $blockEnd++ }
    $lineStart = $text.LastIndexOf("`n", $openBraceIdx) + 1
    $removals += [PSCustomObject]@{ Start = $lineStart; End = $blockEnd }
}

Write-Output "제거 대상: $($removeIds.Count) / 찾음: $($removals.Count) / 못찾음: $($notFound.Count)"
if ($notFound.Count -gt 0) { Write-Output ("못찾은 id: " + ($notFound -join ", ")) }

$removals = $removals | Sort-Object Start -Descending
foreach ($r in $removals) {
    $text = $text.Remove($r.Start, $r.End - $r.Start)
}

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
