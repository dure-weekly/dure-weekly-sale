# 카테고리 상관없이 products.json 전체와 사전예약 코드가 겹치는지 광범위하게 확인한다(1회성 점검).
$root = Split-Path -Parent $PSScriptRoot
$productsPath = Join-Path $root "data\products.json"
$reservationsPath = Join-Path $root "data\reservations.json"

$robj = Get-Content $reservationsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$reservationCodes = New-Object System.Collections.Generic.HashSet[string]
foreach ($item in $robj.reservations) {
    if ($item.code -and $item.code -ne "") { [void]$reservationCodes.Add($item.code) }
}

function Extract-Code($item) {
    if ($item.code -and $item.code -ne "") { return $item.code }
    if ($item.image -and $item.image -match '/(\d+)[A-Za-z]?\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    if ($item.image -and $item.image -match 'images/(\d+)\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    return $null
}

$pobj = Get-Content $productsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$toRemove = @()
foreach ($item in $pobj.products) {
    $code = Extract-Code $item
    if ($code -and $reservationCodes.Contains($code)) {
        $toRemove += [PSCustomObject]@{ Id = $item.id; Code = $code; Name = $item.name; Category = $item.category }
    }
}
Write-Output "전체 카테고리 기준 겹치는 항목 수: $($toRemove.Count)"
$toRemove | ForEach-Object { Write-Output "$($_.Id)`t$($_.Category)`t$($_.Code)`t$($_.Name)" }
