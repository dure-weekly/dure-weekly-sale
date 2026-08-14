# 수산쿠폰 6차(8/17~23) 파일 기준으로 신규 주간할인 카드를 생성한다.
# 사전예약과 겹치는 코드는 제외(사전예약 우선). 이미지는 코드로 CDN에서 실제 조회해서 확장자를 확정한다.

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"

$meta = Get-Content (Join-Path $dir "seafood6_meta.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$rows = Import-Csv (Join-Path $dir "seafood6_coupon_list.csv")

$reservationsObj = Get-Content (Join-Path $root "data\reservations.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$excludeCodes = [System.Collections.Generic.HashSet[string]]::new([string[]]($reservationsObj.reservations | Where-Object { $_.code -ne "" } | ForEach-Object { $_.code }))

function Parse-Won($text) { return [int]($text -replace '[^\d]', '') }
function Strip-Prefix($name) { return ([regex]::Replace($name.Trim(), '^\([^)]*\)\s*', '')).Trim() }

$iconMapObj = $meta.iconMap
function Get-Icon($itemType) {
    $prop = $iconMapObj.PSObject.Properties[$itemType]
    if ($prop) { return $prop.Value }
    return $meta.defaultIcon
}

function Test-ImageUrl($url) {
    try { $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 6; return $r.StatusCode -eq 200 } catch { return $false }
}
function Find-ImageUrl($code) {
    foreach ($ext in @("jpg","png","jpeg")) {
        $url = "https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/${code}C.$ext"
        if (Test-ImageUrl $url) { return $url }
    }
    return $null
}

$nextId = 600
$blocks = @()
$skipped = 0
$noImage = @()
$i = 0
foreach ($row in $rows) {
    $i++
    $code = $row.코드
    if ($excludeCodes.Contains($code)) { $skipped++; continue }

    $orig = Parse-Won $row.정상가
    $weekly = if ($row.주간할인.Trim() -ne "") { Parse-Won $row.주간할인 } else { $null }
    $final = Parse-Won $row.최종가
    $rate = [int]($row.할인율 -replace '[^\d]', '')
    $name = Strip-Prefix $row.상품명
    $icon = Get-Icon $row.품목
    $desc = $meta.descTemplate -replace '\{ITEMTYPE\}', $row.품목
    $id = "p$nextId"
    $nextId++

    $imageUrl = Find-ImageUrl $code
    if (-not $imageUrl) { $noImage += "$code $name" }
    $imageLine = if ($imageUrl) { "`"$imageUrl`"" } else { "null" }

    if ($weekly -ne $null) {
        # 3단: 정상가 -> 주간할인 -> 최종가(쿠폰가), 전체 노출
        $block = @"
    {
      "id": "$id",
      "name": "$name",
      "icon": "$icon",
      "image": $imageLine,
      "originalPrice": $orig,
      "salePrice": $weekly,
      "couponPrice": $final,
      "discountRate": $rate,
      "hasCoupon": true,
      "category": "seafood_coupon",
      "itemType": "소비촉진",
      "note": "",
      "hideFromAll": false,
      "description": "$desc"
    }
"@
    } else {
        # 2단: 정상가 -> 최종가만, 전체에선 숨김(수산쿠폰 칩에서만 노출)
        $block = @"
    {
      "id": "$id",
      "name": "$name",
      "icon": "$icon",
      "image": $imageLine,
      "originalPrice": $orig,
      "salePrice": $final,
      "couponPrice": null,
      "discountRate": $rate,
      "hasCoupon": false,
      "category": "seafood_coupon",
      "itemType": "소비촉진",
      "note": "",
      "hideFromAll": true,
      "description": "$desc"
    }
"@
    }
    $blocks += $block

    if ($i % 20 -eq 0) { Write-Output "진행: $i / $($rows.Count)" }
}

Write-Output "제외(사전예약 중복): $skipped"
Write-Output "신규 생성: $($blocks.Count)"
Write-Output "이미지 없음: $($noImage.Count)"
$noImage | Out-File (Join-Path $dir "seafood6_no_image.txt") -Encoding utf8

$joined = ($blocks -join ",`n")
[System.IO.File]::WriteAllText((Join-Path $dir "seafood6_new_products.json"), "[`n$joined`n]", (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료: seafood6_new_products.json"
