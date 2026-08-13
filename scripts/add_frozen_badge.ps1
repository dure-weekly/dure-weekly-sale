# goodsDetails.json의 보관방법이 "냉동"으로 확인된 항목 중, note가 비어있는 products.json 항목에
# note="냉동"을 채운다(이미 note가 있는 항목은 덮어쓰지 않음 - 위에서 사전 확인 완료).

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$targetIds = @("p001","p125","p124","p123","p119","p145","p147","p149","p129","p128","p151","p155","p160","p159","p162","p164","p163","p170","p173","p177","p178")

$text = Get-Content $dataPath -Raw -Encoding UTF8

$updated = 0
$notFound = @()
foreach ($id in $targetIds) {
    $idMarker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($idMarker)
    if ($idIdx -eq -1) { $notFound += $id; continue }

    # 이 id 이후 첫 "note": "" 를 찾아서 "냉동"으로 채운다
    $noteMarker = '"note": "",'
    $noteIdx = $text.IndexOf($noteMarker, $idIdx)
    if ($noteIdx -eq -1) { $notFound += "$id(note 못찾음)"; continue }
    # 너무 멀리 있으면(다른 항목 note일 수 있음) 안전장치: 500자 이내인지 확인
    if ($noteIdx - $idIdx -gt 500) { $notFound += "$id(note가 너무 멀리 있음)"; continue }

    $newNote = '"note": "냉동",'
    $text = $text.Substring(0, $noteIdx) + $newNote + $text.Substring($noteIdx + $noteMarker.Length)
    $updated++
}

Write-Output "갱신 완료: $updated / $($targetIds.Count)"
if ($notFound.Count -gt 0) { Write-Output ("실패: " + ($notFound -join ", ")) }

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
