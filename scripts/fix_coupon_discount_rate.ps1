# 쿠폰(hasCoupon+couponPrice) 적용 항목의 discountRate를 "자체할인만"이 아니라
# "정상가 -> 쿠폰최종가" 기준 총 할인율로 재계산한다(원형 배지가 총 할인율을 보여주도록).
# products.json / reservations.json 둘 다 처리.

$root = Split-Path -Parent $PSScriptRoot

function Fix-File($path) {
    $obj = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $items = if ($obj.products) { $obj.products } else { $obj.reservations }

    $text = Get-Content $path -Raw -Encoding UTF8
    $fixedCount = 0

    foreach ($item in $items) {
        if (-not $item.hasCoupon) { continue }
        if ($null -eq $item.couponPrice) { continue }
        if ($null -eq $item.originalPrice -or $item.originalPrice -le 0) { continue }

        $newRate = [math]::Round((($item.originalPrice - $item.couponPrice) / $item.originalPrice) * 100)
        if ($newRate -eq $item.discountRate) { continue }

        # 이 항목의 이미지 URL(또는 code)로 위치를 찾아서 그 근처의 discountRate만 바꾼다.
        $anchor = if ($item.image) { $item.image } elseif ($item.code) { '"code": "' + $item.code + '"' } else { $null }
        if (-not $anchor) { continue }
        $anchorIdx = $text.IndexOf($anchor)
        if ($anchorIdx -eq -1) { continue }

        $oldPattern = '"discountRate":\s*' + [regex]::Escape("$($item.discountRate)") + ','
        $m = [regex]::Match($text.Substring($anchorIdx), $oldPattern)
        if (-not $m.Success) { continue }
        # anchor와 너무 멀면(다른 항목일 위험) 스킵
        if ($m.Index -gt 800) { continue }

        $absStart = $anchorIdx + $m.Index
        $absEnd = $absStart + $m.Length
        $newText = '"discountRate": ' + $newRate + ','
        $text = $text.Substring(0, $absStart) + $newText + $text.Substring($absEnd)
        $fixedCount++
    }

    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "$path : $fixedCount 건 수정"
}

Fix-File (Join-Path $root "data\products.json")
Fix-File (Join-Path $root "data\reservations.json")
