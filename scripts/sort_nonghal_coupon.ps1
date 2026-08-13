# 농할쿠폰(nonghal_coupon) 카테고리 항목을 중분류(돼지/한우/닭오리양/쌀/채소 등)별로
# 묶어서 순차적으로 보이게 정렬하고, 사진이 없는(깨진) 항목은 맨 뒤로 보낸다.
# products.json의 나머지(다른 카테고리) 항목 순서는 건드리지 않는다.

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$dir = Join-Path $root "scripts\_last_run"

$csvRows = Import-Csv (Join-Path $dir "nonghal_coupon_list.csv")
$csvRows29 = Import-Csv (Join-Path $dir "nonghal29_coupon_list.csv")
$middleCategoryByCode = @{}
foreach ($r in $csvRows) { $middleCategoryByCode[$r.코드] = $r.중분류 }
foreach ($r in $csvRows29) { $middleCategoryByCode[$r.코드] = $r.중분류 }

$brokenLines = Get-Content (Join-Path $dir "nonghal_truly_broken.txt") -Encoding UTF8
$brokenIds = @{}
foreach ($line in $brokenLines) {
    if ($line.Trim() -eq "") { continue }
    $id = ($line -split '\|')[0]
    $brokenIds[$id] = $true
}

# 중분류 표시 우선순위(비슷한 것끼리 묶이는 순서)
$middleOrder = @{
    "유정란/알" = 1
    "쌀" = 2
    "잡곡류" = 3
    "잎채소" = 4
    "열매채소" = 5
    "뿌리채소" = 6
    "손질채소/특용채소" = 7
    "버섯" = 8
    "과수/과채" = 9
    "돼지(냉장)" = 10
    "한우(냉장)" = 11
    "닭/오리/양" = 12
}

function Get-GoodsCode($image) {
    if (-not $image) { return $null }
    if ($image -match '(\d+)[A-Za-z]?\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    return $null
}

$obj = Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$allProducts = @($obj.products)

$nonghalItems = @($allProducts | Where-Object { $_.category -eq "nonghal_coupon" })
$otherItems = @($allProducts | Where-Object { $_.category -ne "nonghal_coupon" })

Write-Output "농할쿠폰 항목: $($nonghalItems.Count) / 그외: $($otherItems.Count)"

$decorated = foreach ($item in $nonghalItems) {
    $code = Get-GoodsCode $item.image
    $mid = if ($code -and $middleCategoryByCode.ContainsKey($code)) { $middleCategoryByCode[$code] } else { "" }
    $midRank = if ($middleOrder.ContainsKey($mid)) { $middleOrder[$mid] } else { 99 }
    $noImageRank = if ($brokenIds.ContainsKey($item.id)) { 1 } else { 0 }
    [PSCustomObject]@{
        Item = $item
        NoImageRank = $noImageRank
        MidRank = $midRank
        Name = $item.name
    }
}

$sorted = $decorated | Sort-Object NoImageRank, MidRank, Name | ForEach-Object { $_.Item }

# 텍스트 기반 재조립: 기존 products.json에서 nonghal_coupon 블록들을 전부 제거하고
# 정렬된 블록을 배열 맨 끝에 하나로 이어붙인다(다른 카테고리 순서는 원본 텍스트 그대로 유지하기 위해
# 원본 텍스트에서 각 항목 블록을 잘라내는 대신, 새 JSON 배열 전체를 재구성한다).
Write-Output "정렬 완료. 첫 5개:"
$sorted | Select-Object -First 5 | ForEach-Object { Write-Output "  $($_.name)" }

$sortedIds = $sorted | ForEach-Object { $_.id }
$sortedIds | Out-File (Join-Path $dir "nonghal_sorted_order.txt") -Encoding utf8
Write-Output "정렬 순서를 nonghal_sorted_order.txt 에 저장했습니다."
