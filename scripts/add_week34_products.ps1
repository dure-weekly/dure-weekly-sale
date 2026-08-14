# 34주 주간할인 신규 34개 항목을 products.json에 추가한다(53332 백미는 사전예약 중복이라 제외).
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"
$dataPath = Join-Path $root "data\products.json"

$meta = Get-Content (Join-Path $dir "week34_add_meta.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$rows = Import-Csv (Join-Path $dir "week34_products_rows.csv")

function Parse-Won($text) {
    if ($text.Trim() -eq "") { return $null }
    return [int]($text -replace '[^\d]', '')
}
function Strip-Prefix($name) { return ([regex]::Replace($name.Trim(), '^\([^)]*\)\s*', '')).Trim() }

$nextId = 700
$blocks = @()
$skipped = 0
foreach ($row in $rows) {
    $code = $row.코드
    $metaProp = $meta.PSObject.Properties[$code]
    if (-not $metaProp) { $skipped++; continue }
    $m = $metaProp.Value

    $orig = Parse-Won $row.상시가격
    $sale = Parse-Won $row.기획가격
    if ($orig -eq $null) { $orig = $sale }
    $discountRate = if ($orig -gt 0) { [math]::Round((($orig - $sale) / $orig) * 100) } else { 0 }

    $name = Strip-Prefix $row.생활재명
    $descParts = @($row.특징1, $row.특징2) | Where-Object { $_.Trim() -ne "" }
    $desc = if ($descParts.Count -gt 0) { ($descParts -join " ").Trim() } else { "$name 입니다." }
    $noteText = if ($m.note) { $m.note } else { "" }
    $id = "p$nextId"
    $nextId++

    $block = @"
    {
      "id": "$id",
      "name": "$name",
      "icon": "$($m.icon)",
      "image": "https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/${code}C.jpg",
      "originalPrice": $orig,
      "salePrice": $sale,
      "discountRate": $discountRate,
      "category": "$($m.category)",
      "itemType": "소비촉진",
      "note": "$noteText",
      "description": "$desc"
    }
"@
    $blocks += $block
}

Write-Output "생성된 항목 수: $($blocks.Count) (스킵: $skipped)"

$text = Get-Content $dataPath -Raw -Encoding UTF8
$joined = ($blocks -join ",`n")
$lastBracketIndex = $text.LastIndexOf("]")
$before = $text.Substring(0, $lastBracketIndex).TrimEnd()
$before = $before.TrimEnd(",")
$merged = $before + ",`n" + $joined + "`n  ]`n}`n"

[System.IO.File]::WriteAllText($dataPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
