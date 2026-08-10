# 농할쿠폰(28차) 대상 사전예약 19개 항목에 정상가/농할20%할인가를 반영.
# 텍스트 블록 치환 방식(ConvertTo-Json 왕복 금지 원칙 준수).

$root = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $root "data\reservations.json"

# code -> (originalPrice, salePrice=농할가)
$updates = [ordered]@{
    "49977" = @{ orig = 30500; sale = 24400 }
    "54947" = @{ orig = 29700; sale = 23760 }
    "48666" = @{ orig = 20500; sale = 16400 }
    "39884" = @{ orig = 20200; sale = 16160 }
    "55555" = @{ orig = 15900; sale = 12720 }
    "58575" = @{ orig = 15000; sale = 12000 }
    "54293" = @{ orig = 10300; sale = 8240 }
    "13385" = @{ orig = 9900;  sale = 7920 }
    "54201" = @{ orig = 7300;  sale = 5840 }
    "37976" = @{ orig = 22500; sale = 18000 }
    "37973" = @{ orig = 22500; sale = 18000 }
    "37975" = @{ orig = 22500; sale = 18000 }
    "37980" = @{ orig = 21500; sale = 17200 }
    "37979" = @{ orig = 14900; sale = 11920 }
    "37978" = @{ orig = 14900; sale = 11920 }
    "38635" = @{ orig = 11900; sale = 9520 }
    "37977" = @{ orig = 10900; sale = 8720 }
    "37970" = @{ orig = 7900;  sale = 6320 }
    "42508" = @{ orig = 6900;  sale = 5520 }
}

$text = Get-Content $targetPath -Raw -Encoding UTF8

$successCount = 0
$failKeys = @()
foreach ($code in $updates.Keys) {
    $codeMarker = '"code": "' + $code + '",'
    $codeIdx = $text.IndexOf($codeMarker)
    if ($codeIdx -eq -1) {
        $failKeys += "$code (코드를 못찾음)"
        continue
    }

    # 이 코드 블록 안의 originalPrice ~ hasCoupon 라인 구간을 찾아서 통째로 교체한다.
    $blockPattern = '"originalPrice":\s*[^,]+,\s*\n\s*"salePrice":\s*[^,]+,\s*\n\s*"couponPrice":\s*[^,]+,\s*\n\s*"discountRate":\s*[^,]+,\s*\n\s*"hasCoupon":\s*(true|false),?'
    $searchStart = $codeIdx
    $m = [regex]::Match($text.Substring($searchStart), $blockPattern)
    if (-not $m.Success) {
        $failKeys += "$code (가격 블록 패턴을 못찾음)"
        continue
    }

    $orig = $updates[$code].orig
    $sale = $updates[$code].sale
    $newBlock = "`"originalPrice`": $orig,`n      `"salePrice`": $sale,`n      `"couponPrice`": null,`n      `"discountRate`": 20,`n      `"hasCoupon`": true,`n      `"couponLabel`": `"🌾 농할 쿠폰`","

    $absStart = $searchStart + $m.Index
    $absEnd = $absStart + $m.Length
    $text = $text.Substring(0, $absStart) + $newBlock + $text.Substring($absEnd)
    $successCount++
}

Write-Output "치환 성공: $successCount / $($updates.Count)"
if ($failKeys.Count -gt 0) {
    Write-Output "실패:"
    $failKeys | ForEach-Object { Write-Output "  - $_" }
}

[System.IO.File]::WriteAllText($targetPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
