# 34주 파일 67개 코드 중 현재 products.json 일반 항목에 없는 코드를 찾는다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$listPath = Join-Path $root "scripts\_last_run\week34_full_list.txt"

function Extract-Code($item) {
    if ($item.image -and $item.image -match '/(\d+)[A-Za-z]?\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    if ($item.image -and $item.image -match 'images/(\d+)\.(jpg|jpeg|png|gif)$') { return $matches[1] }
    return $null
}

$obj = Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$existingCodes = New-Object System.Collections.Generic.HashSet[string]
foreach ($item in $obj.products) {
    $c = Extract-Code $item
    if ($c) { [void]$existingCodes.Add($c) }
}

foreach ($line in Get-Content $listPath -Encoding UTF8) {
    if ($line -match '^(\d+)\t(.+)$') {
        $code = $matches[1]
        $name = $matches[2]
        if (-not $existingCodes.Contains($code)) {
            Write-Output "누락: $code`t$name"
        }
    }
}
