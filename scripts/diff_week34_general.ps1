# 34주 파일(week34_full_list.txt: 코드\t이름)에 있는 코드 목록과
# 현재 products.json의 "일반" 항목(수산쿠폰/농할쿠폰 제외)을 비교해
# 34주 파일에 없는 항목들을 후보로 나열한다 (삭제는 하지 않고 목록만 출력).

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$listPath = Join-Path $root "scripts\_last_run\week34_full_list.txt"

$week34Codes = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in Get-Content $listPath -Encoding UTF8) {
    if ($line -match '^(\d+)\t') { [void]$week34Codes.Add($matches[1]) }
}
Write-Output "34주 파일 코드 수: $($week34Codes.Count)"

function Extract-Code($item) {
    if ($item.image -and $item.image -match '/(\d+)[A-Za-z]?\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    if ($item.image -and $item.image -match 'images/(\d+)\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    return $null
}

$obj = Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$general = $obj.products | Where-Object { $_.category -ne "seafood_coupon" -and $_.category -ne "nonghal_coupon" }
Write-Output "일반(비쿠폰) 항목 수: $($general.Count)"

$toDelete = @()
foreach ($item in $general) {
    $code = Extract-Code $item
    if ($code -and $week34Codes.Contains($code)) { continue }
    $toDelete += $item
}
Write-Output "34주 파일에 없는(삭제 후보) 항목 수: $($toDelete.Count)"
$toDelete | ForEach-Object { Write-Output "$($_.id)`t$($_.category)`t$($_.name)" }
