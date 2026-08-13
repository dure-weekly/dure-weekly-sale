# 34주 기획일람표의 "예약" 행 중 신규 20개를 reservations.json에 추가한다.
# 특이사항 컬럼에서 공급일을 파싱하고, 카테고리는 품목군에 따라 배정한다.

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\reservations.json"
$rows = Import-Csv (Join-Path $root "scripts\_last_run\week34_reservation_rows.csv")

function Strip-Prefix($name) {
    return ([regex]::Replace($name.Trim(), '^\([^)]*\)\s*', '')).Trim()
}
function Parse-Won($text) { return [int]($text -replace '[^\d]', '') }

# 코드 -> (id, category, theme, icon, supplyDate, hasCoupon 여부/농할쿠폰 필드)
$plan = @{
    "52942" = @{ id="r072"; category="processed"; icon="🦆"; supplyDate="9/4(금)" }
    "58803" = @{ id="r073"; category="processed"; icon="🐟"; supplyDate="9/4(금)" }
    "56011" = @{ id="r074"; category="processed"; icon="🥬"; supplyDate="9/3(목)" }
    "56606" = @{ id="r075"; category="processed"; icon="🥬"; supplyDate="9/3(목)" }
    "57183" = @{ id="r076"; category="processed"; icon="🥬"; supplyDate="9/3(목)" }
    "7253"  = @{ id="r077"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "7254"  = @{ id="r078"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "7255"  = @{ id="r079"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "7256"  = @{ id="r080"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "7257"  = @{ id="r081"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "7527"  = @{ id="r082"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "11004" = @{ id="r083"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "11005" = @{ id="r084"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "12932" = @{ id="r085"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "14663" = @{ id="r086"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "35253" = @{ id="r087"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "35254" = @{ id="r088"; category="lacquerware"; icon="🥢"; supplyDate="9/11(금)" }
    "53332" = @{ id="r089"; category="grain"; icon="🌾"; supplyDate="8/27(목)~29(토)" }
    "24697" = @{ id="r090"; category="meat"; icon="🥩"; supplyDate="9/2(수)" }
    "57857" = @{ id="r091"; category="meat"; icon="🥩"; supplyDate="9/2(수)"; nonghal=$true }
}

$blocks = @()
foreach ($row in $rows) {
    $code = $row.코드
    if (-not $plan.ContainsKey($code)) { continue }
    $p = $plan[$code]
    $name = Strip-Prefix $row.생활재명
    $orig = Parse-Won $row.상시가격
    $sale = Parse-Won $row.기획가격
    $descParts = @($row.특징1, $row.특징2, $row.특징3) | Where-Object { $_.Trim() -ne "" }
    $desc = if ($descParts.Count -gt 0) { ($descParts -join " ").Trim() } else { "$name 입니다." }

    $couponFields = ""
    if ($p.nonghal) {
        $couponFields = "`n      `"couponPrice`": 20000,`n      `"couponLabel`": `"🌾 농할 쿠폰`",`n      `"couponPeriod`": `"8/13(목)~19(수)`","
    }

    $block = @"
    {
      "id": "$($p.id)",
      "code": "$code",
      "name": "$name",
      "theme": "$($row.테마)",
      "category": "$($p.category)",
      "reservationType": "예약",
      "originalPrice": $orig,
      "salePrice": $sale,$couponFields
      "discountRate": $([math]::Round((($orig-$sale)/[math]::Max($orig,1))*100)),
      "hasCoupon": $(if ($p.nonghal) { "true" } else { "false" }),
      "supplyDate": "$($p.supplyDate)",
      "image": "https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/${code}C.jpg",
      "icon": "$($p.icon)",
      "description": "$desc"
    }
"@
    $blocks += $block
}

Write-Output "생성된 항목 수: $($blocks.Count) / 대상: $($plan.Count)"

$text = Get-Content $dataPath -Raw -Encoding UTF8
$joined = ($blocks -join ",`n")
$lastBracketIndex = $text.LastIndexOf("]")
$before = $text.Substring(0, $lastBracketIndex).TrimEnd()
$before = $before.TrimEnd(",")
$merged = $before + ",`n" + $joined + "`n  ]`n}`n"

[System.IO.File]::WriteAllText($dataPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
