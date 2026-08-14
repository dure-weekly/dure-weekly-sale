# reservations.json의 모든 항목이 goodsDetails.json에 상세카드를 가지고 있는지 확인한다.
$root = Split-Path -Parent $PSScriptRoot
$r = Get-Content (Join-Path $root "data\reservations.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$g = Get-Content (Join-Path $root "data\goodsDetails.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$gKeys = New-Object System.Collections.Generic.HashSet[string]
foreach ($p in $g.PSObject.Properties.Name) { [void]$gKeys.Add($p) }

Write-Output ("전체 사전예약: " + $r.reservations.Count)
$missing = @()
foreach ($item in $r.reservations) {
    $key = if ($item.code -and $item.code -ne "") { $item.code } else { $item.id }
    if (-not $gKeys.Contains($key)) {
        $missing += $item
    }
}
Write-Output ("상세카드 없음: " + $missing.Count)
foreach ($m in $missing) {
    Write-Output ("$($m.id)|$($m.code)|$($m.name)|$($m.category)")
}
