# 29차 농할쿠폰 파일 기준으로 사전예약 19개 항목의 가격을 갱신한다.
# couponPrice를 항상 채우고(null 금지), originalPrice==salePrice면 화면에서 자동으로 2단 축약된다
# (js/main.js의 isSelfDiscountSame 로직) - 그래서 여기서는 항상 couponPrice를 설정하면 된다.

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\reservations.json"
$dir = Join-Path $root "scripts\_last_run"

$rows = Import-Csv (Join-Path $dir "nonghal29_coupon_list.csv")
# 8/13 이전 공급일 정리 후 실제로 남아있는 코드만 대상으로 한다(7개는 이미 삭제됨).
$targetCodes = @("58575","54201","37976","37973","37975","37980","37979","37978","38635","37977","37970","42508")

function Parse-Won($text) { return [int]($text -replace '[^\d]', '') }

$byCode = @{}
foreach ($r in $rows) { if ($targetCodes -contains $r.코드) { $byCode[$r.코드] = $r } }

Write-Output "대상 19개 중 29차 파일에서 찾은 개수: $($byCode.Count)"

$text = Get-Content $dataPath -Raw -Encoding UTF8
$newPeriod = "8/13(목)~19(수)"

$updated = 0
foreach ($code in $targetCodes) {
    if (-not $byCode.ContainsKey($code)) { continue }
    $row = $byCode[$code]
    $orig = Parse-Won $row.정상가
    $self = Parse-Won $row.자체할인
    $coupon = Parse-Won $row.농할가
    $discountRate = if ($orig -gt 0) { [math]::Round((($orig - $self) / $orig) * 100) } else { 0 }

    $codeMarker = '"code": "' + $code + '",'
    $codeIdx = $text.IndexOf($codeMarker)
    if ($codeIdx -eq -1) { continue }

    $blockPattern = '"originalPrice":\s*[^,]+,\s*\n\s*"salePrice":\s*[^,]+,\s*\n\s*"couponPrice":\s*[^,]+,\s*\n\s*"discountRate":\s*[^,]+,\s*\n\s*"hasCoupon":\s*(true|false),\s*\n\s*"couponLabel":\s*"[^"]*",'
    $m = [regex]::Match($text.Substring($codeIdx), $blockPattern)
    if (-not $m.Success) { continue }

    $newBlock = "`"originalPrice`": $orig,`n      `"salePrice`": $self,`n      `"couponPrice`": $coupon,`n      `"discountRate`": $discountRate,`n      `"hasCoupon`": true,`n      `"couponLabel`": `"🌾 농할 쿠폰`",`n      `"couponPeriod`": `"$newPeriod`","

    $absStart = $codeIdx + $m.Index
    $absEnd = $absStart + $m.Length
    $text = $text.Substring(0, $absStart) + $newBlock + $text.Substring($absEnd)
    $updated++
}

Write-Output "갱신 완료: $updated / $($targetCodes.Count)"
[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
