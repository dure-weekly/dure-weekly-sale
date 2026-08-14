# 두레맛찬 day2탄(3만원이상 고추장멸치볶음 증정) 프로모션 note를 해당 23개 항목에 적용.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$codes = @("58030","58031","58033","58059","58064","58065","58066","58067","58068","58071",
           "58425","58634","59167","59887","59888","59889","59893","59942","60117",
           "59058","59059","59060","59061")

$promoText = "3만원이상 구매시 고추장멸치볶음 증정"

$text = Get-Content $dataPath -Raw -Encoding UTF8
$updated = 0
foreach ($code in $codes) {
    $imgMarker = "GoodsImage/${code}C."
    $imgIdx = $text.IndexOf($imgMarker)
    if ($imgIdx -eq -1) { Write-Output "$code : 이미지 위치 못찾음"; continue }

    $m = [regex]::Match($text.Substring($imgIdx), '"note":\s*"[^"]*",')
    if (-not $m.Success) { Write-Output "$code : note 필드 못찾음"; continue }
    if ($m.Index -gt 600) { Write-Output "$code : note가 너무 멀리 있음(스킵)"; continue }

    $newField = "`"note`": `"$promoText`","
    $absStart = $imgIdx + $m.Index
    $absEnd = $absStart + $m.Length
    $text = $text.Substring(0, $absStart) + $newField + $text.Substring($absEnd)
    $updated++
}
Write-Output "갱신 완료: $updated / $($codes.Count)"
[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
