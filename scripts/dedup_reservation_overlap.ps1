# 수산쿠폰/농할쿠폰 중 사전예약(reservations.json)에 이미 들어있는 생활재 코드는
# 주간할인(products.json)에서 제외한다 (사전예약 우선).
$root = Split-Path -Parent $PSScriptRoot
$productsPath = Join-Path $root "data\products.json"
$reservationsPath = Join-Path $root "data\reservations.json"

$robj = Get-Content $reservationsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$reservationCodes = New-Object System.Collections.Generic.HashSet[string]
foreach ($item in $robj.reservations) {
    if ($item.code -and $item.code -ne "") { [void]$reservationCodes.Add($item.code) }
}
Write-Output "사전예약 코드 수: $($reservationCodes.Count)"

function Extract-Code($item) {
    if ($item.code -and $item.code -ne "") { return $item.code }
    if ($item.image -and $item.image -match '/(\d+)[A-Za-z]?\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    if ($item.image -and $item.image -match 'images/(\d+)\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    return $null
}

$pobj = Get-Content $productsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$toRemove = @()
foreach ($item in $pobj.products) {
    if ($item.category -ne "seafood_coupon" -and $item.category -ne "nonghal_coupon") { continue }
    $code = Extract-Code $item
    if ($code -and $reservationCodes.Contains($code)) {
        $toRemove += [PSCustomObject]@{ Id = $item.id; Code = $code; Name = $item.name; Category = $item.category }
    }
}
Write-Output "겹치는 항목 수: $($toRemove.Count)"
$toRemove | ForEach-Object { Write-Output "$($_.Id)`t$($_.Category)`t$($_.Code)`t$($_.Name)" }
