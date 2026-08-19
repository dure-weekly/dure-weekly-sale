# 사전예약과 겹치는 주간할인/수산쿠폰/농할쿠폰 6개를 id 기준으로 삭제한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$idsToDelete = @("p632","p700","p757","p793","n2001","p117")

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
$deleted = 0
foreach ($id in $idsToDelete) {
    $marker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($marker)
    if ($idIdx -eq -1) { Write-Output "경고: $id 못찾음"; continue }
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $afterIdx = $closeBraceIdx + 1
    $removeEnd = $afterIdx
    if ($text.Substring($afterIdx, 1) -eq ",") { $removeEnd = $afterIdx + 1 }
    $before = $text.Substring(0, $openBraceIdx)
    $after = $text.Substring($removeEnd)
    $text = $before + $after
    $deleted++
}
Write-Output "삭제 완료: $deleted 개"

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
