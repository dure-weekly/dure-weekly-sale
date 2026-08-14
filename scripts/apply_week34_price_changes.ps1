# 34주 파일 기준 맛찬(즉석반찬) 23개 가격 변동을 반영한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$updates = @{
    "58030" = 3800; "58031" = 5800; "58033" = 4800; "58059" = 12500; "58064" = 5800
    "58065" = 5400; "58066" = 4600; "58067" = 5700; "58068" = 5700; "58071" = 4600
    "58425" = 13000; "58634" = 5500; "59167" = 4400; "59887" = 5400; "59888" = 5600
    "59889" = 4600; "59893" = 4300; "59942" = 6200; "60117" = 14000; "59058" = 11200
    "59059" = 9200; "59060" = 10500; "59061" = 10600
}

$text = Get-Content $dataPath -Raw -Encoding UTF8
$updated = 0
foreach ($code in $updates.Keys) {
    $newPrice = $updates[$code]
    $imgMarker = "GoodsImage/${code}C."
    $imgIdx = $text.IndexOf($imgMarker)
    if ($imgIdx -eq -1) { Write-Output "$code : 이미지 위치 못찾음"; continue }

    $m = [regex]::Match($text.Substring($imgIdx), '"originalPrice":\s*(\d+),\s*\n\s*"salePrice":\s*(\d+),\s*\n\s*"discountRate":\s*(\d+),')
    if (-not $m.Success) { Write-Output "$code : 가격블록 패턴 못찾음"; continue }

    $orig = [int]$m.Groups[1].Value
    $discountRate = [math]::Round((($orig - $newPrice) / $orig) * 100)

    $newBlock = "`"originalPrice`": $orig,`n      `"salePrice`": $newPrice,`n      `"discountRate`": $discountRate,"
    $absStart = $imgIdx + $m.Index
    $absEnd = $absStart + $m.Length
    $text = $text.Substring(0, $absStart) + $newBlock + $text.Substring($absEnd)
    $updated++
}
Write-Output "갱신 완료: $updated / $($updates.Count)"
[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
