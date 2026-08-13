# 지혜님이 지목한 14개 품목에 note="냉동"을 채운다(모두 현재 note가 빈 문자열임을 사전 확인함).
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$targetNames = @(
    "제주은갈치(420g)",
    "새우살(300g)",
    "동태(전부침용)(1kg)",
    "얼린오징어(500g)",
    "순살삼치(1kg)",
    "가시없는삼치(600g)",
    "수제손질민어살(400g)",
    "바지락살(250g)",
    "대구전부침용(400g)",
    "대구전부침용(350g)",
    "가시없는고등어(600g)",
    "손질 붕장어(500g)",
    "국산새우살(300g)",
    "채썬오징어몸통살(400g)"
)

$text = Get-Content $dataPath -Raw -Encoding UTF8

$updated = 0
$notFound = @()
foreach ($name in $targetNames) {
    $nameMarker = '"name": "' + $name + '",'
    $nameIdx = $text.IndexOf($nameMarker)
    if ($nameIdx -eq -1) { $notFound += $name; continue }

    $noteMarker = '"note": "",'
    $noteIdx = $text.IndexOf($noteMarker, $nameIdx)
    if ($noteIdx -eq -1 -or ($noteIdx - $nameIdx) -gt 400) { $notFound += "$name(note 못찾음)"; continue }

    $newNote = '"note": "냉동",'
    $text = $text.Substring(0, $noteIdx) + $newNote + $text.Substring($noteIdx + $noteMarker.Length)
    $updated++
}

Write-Output "갱신 완료: $updated / $($targetNames.Count)"
if ($notFound.Count -gt 0) { Write-Output ("실패: " + ($notFound -join " | ")) }

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
