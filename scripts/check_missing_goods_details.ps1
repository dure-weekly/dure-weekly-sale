# 배포 전에, products.json/reservations.json의 모든 생활재코드 중
# goodsDetails.json에 상세 데이터가 없는 코드를 뽑아서 보여준다.
# (주간할인 상품은 code 필드가 없어 image 파일명에서 코드를 추출한다 - js/main.js의
#  extractGoodsCode()와 동일한 규칙: 파일명 끝의 숫자+선택적 알파벳 한 글자.)

$root = Split-Path -Parent $PSScriptRoot
$productsPath = Join-Path $root "data\products.json"
$reservationsPath = Join-Path $root "data\reservations.json"
$detailsPath = Join-Path $root "data\goodsDetails.json"

$products = (Get-Content $productsPath -Raw -Encoding UTF8 | ConvertFrom-Json).products
$reservations = (Get-Content $reservationsPath -Raw -Encoding UTF8 | ConvertFrom-Json).reservations
$details = Get-Content $detailsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$detailKeys = @{}
$details.PSObject.Properties | ForEach-Object { $detailKeys[$_.Name] = $true }

function Get-GoodsCode($image) {
    if (-not $image) { return $null }
    if ($image -match '(\d+)[A-Za-z]?\.(jpg|jpeg|png|gif)$') {
        return $matches[1]
    }
    return $null
}

Write-Output "=== 주간할인(products.json) - 상세 데이터 없는 항목 ==="
$missingProducts = @()
foreach ($p in $products) {
    $code = Get-GoodsCode $p.image
    $key = if ($code -and $detailKeys.ContainsKey($code)) { $code } elseif ($detailKeys.ContainsKey($p.id)) { $p.id } else { $null }
    if (-not $key) {
        $missingProducts += [PSCustomObject]@{ id = $p.id; code = $code; name = $p.name }
    }
}
$missingProducts | Format-Table -AutoSize
Write-Output "누락: $($missingProducts.Count) / 전체: $($products.Count)"

Write-Output ""
Write-Output "=== 사전예약(reservations.json) - 상세 데이터 없는 항목 ==="
$missingReservations = @()
foreach ($r in $reservations) {
    $code = $r.code
    $key = if ($code -and $detailKeys.ContainsKey($code)) { $code } elseif ($detailKeys.ContainsKey($r.id)) { $r.id } else { $null }
    if (-not $key) {
        $missingReservations += [PSCustomObject]@{ id = $r.id; code = $code; name = $r.name }
    }
}
$missingReservations | Format-Table -AutoSize
Write-Output "누락: $($missingReservations.Count) / 전체: $($reservations.Count)"
