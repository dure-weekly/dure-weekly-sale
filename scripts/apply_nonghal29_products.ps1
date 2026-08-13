# 29차 농할쿠폰 기준으로 가격이 바뀐 주간할인 8개 항목을 갱신한다(황도/백도 6종, 근대, 치커리).
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

# code -> orig, self(salePrice), coupon
$updates = @{
    "57364" = @{ orig=20500; self=18400; coupon=14720 }
    "57669" = @{ orig=20500; self=18400; coupon=14720 }
    "57670" = @{ orig=22000; self=19800; coupon=15840 }
    "57362" = @{ orig=18900; self=16900; coupon=13520 }
    "23580" = @{ orig=22000; self=19800; coupon=15840 }
    "25723" = @{ orig=18900; self=16900; coupon=13520 }
    "20991" = @{ orig=2700;  self=2700;  coupon=2160 }
    "48976" = @{ orig=2400;  self=2400;  coupon=1920 }
}

$text = Get-Content $dataPath -Raw -Encoding UTF8

$updated = 0
foreach ($code in $updates.Keys) {
    $u = $updates[$code]
    $discountRate = if ($u.orig -gt 0) { [math]::Round((($u.orig - $u.self) / $u.orig) * 100) } else { 0 }

    $imgMarker = "GoodsImage/${code}C."
    $imgIdx = $text.IndexOf($imgMarker)
    if ($imgIdx -eq -1) { Write-Output "$code : 이미지로 위치를 못찾음"; continue }

    $blockPattern = '"originalPrice":\s*[^,]+,\s*\n\s*"salePrice":\s*[^,]+,\s*\n\s*"couponPrice":\s*[^,]+,\s*\n\s*"discountRate":\s*[^,]+,'
    $m = [regex]::Match($text.Substring($imgIdx), $blockPattern)
    if (-not $m.Success) { Write-Output "$code : 가격블록 패턴을 못찾음"; continue }

    $newBlock = "`"originalPrice`": $($u.orig),`n      `"salePrice`": $($u.self),`n      `"couponPrice`": $($u.coupon),`n      `"discountRate`": $discountRate,"

    $absStart = $imgIdx + $m.Index
    $absEnd = $absStart + $m.Length
    $text = $text.Substring(0, $absStart) + $newBlock + $text.Substring($absEnd)
    $updated++
}

Write-Output "갱신 완료: $updated / $($updates.Count)"
[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
