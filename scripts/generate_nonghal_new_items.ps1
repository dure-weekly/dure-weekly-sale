# 농할쿠폰(28차) 파일의 211개 품목 중, 이미 사이트에 있는 23개(주간할인 4 + 사전예약 19)를 뺀
# 나머지를 새 주간할인 카드로 생성한다. 한글/이모지 리터럴은 스크립트에 직접 쓰지 않고
# nonghal_meta.json(UTF8)에서 읽어온다 - PowerShell -File 실행 시 BOM 없는 .ps1의 한글 리터럴이
# 깨지는 문제를 피하기 위함(이번 세션에서 실제로 겪은 버그).

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"

$meta = Get-Content (Join-Path $dir "nonghal_meta.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$rows = Import-Csv (Join-Path $dir "nonghal_coupon_list.csv")

# 이미 사이트(주간할인 4 + 사전예약 19)에 있는 코드 - 새로 만들지 않음
$excludeCodes = @(
    "29366","52927","16653","1225",
    "49977","54947","48666","39884","55555","58575","54293","13385","54201",
    "37976","37973","37975","37980","37979","37978","38635","37977","37970","42508"
)

function Parse-Won($text) {
    return [int]($text -replace '[^\d]', '')
}

function Strip-Prefix($name) {
    return [regex]::Replace($name, '^\([^)]*\)\s*', '')
}

$iconMapObj = $meta.iconMap
function Get-Icon($major, $middle) {
    $key = "$major|$middle"
    $prop = $iconMapObj.PSObject.Properties[$key]
    if ($prop) { return $prop.Value }
    return $meta.defaultIcon
}

$nextId = 322
$blocks = @()
$skipped = 0
foreach ($row in $rows) {
    $code = $row.코드
    if ($excludeCodes -contains $code) { $skipped++; continue }

    $orig = Parse-Won $row.정상가
    $self = Parse-Won $row.자체할인
    $coupon = Parse-Won $row.농할가
    $name = Strip-Prefix $row.생활재명
    $icon = Get-Icon $row.대분류 $row.중분류
    $discountRate = if ($orig -gt 0) { [math]::Round((($orig - $self) / $orig) * 100) } else { 0 }
    $desc = $meta.descTemplate -replace '\{NAME\}', $name
    $id = "p$nextId"
    $nextId++

    $imageUrl = "https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/${code}C.jpg"

    $block = @"
    {
      "id": "$id",
      "name": "$name",
      "icon": "$icon",
      "image": "$imageUrl",
      "originalPrice": $orig,
      "salePrice": $self,
      "couponPrice": $coupon,
      "discountRate": $discountRate,
      "hasCoupon": true,
      "couponLabel": "$($meta.couponLabel)",
      "couponPeriod": "$($meta.couponPeriod)",
      "theme": "$($row.대분류)",
      "category": "nonghal_coupon",
      "itemType": "소비촉진",
      "note": "",
      "hideFromAll": false,
      "description": "$desc"
    }
"@
    $blocks += $block
}

Write-Output "제외(이미 사이트에 있음): $skipped"
Write-Output "신규 생성: $($blocks.Count)"

$joined = ($blocks -join ",`n")
[System.IO.File]::WriteAllText((Join-Path $dir "nonghal_new_products.json"), "[`n$joined`n]", (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료: nonghal_new_products.json"
