param(
    [string]$ProductsJsonPath = "c:\Users\USER\Documents\클로드코워크\랜딩페이지\data\products.json",
    [string]$OutDir = "$PSScriptRoot\_last_run"
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$data = Get-Content $ProductsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Test-ImageUrl($url) {
    try {
        $r = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 8
        return $r.StatusCode -eq 200
    } catch {
        return $false
    }
}

$ok = New-Object System.Collections.Generic.List[string]
$fixed = New-Object System.Collections.Generic.List[string]
$broken = New-Object System.Collections.Generic.List[string]

$extCandidates = @("jpg", "png", "jpeg")

foreach ($p in $data.products) {
    if (Test-ImageUrl $p.image) {
        $ok.Add($p.id)
        continue
    }
    # 확장자 바꿔가며 재시도
    $baseUrl = $p.image -replace '\.(jpg|jpeg|png)$', ''
    $found = $false
    foreach ($ext in $extCandidates) {
        $tryUrl = "$baseUrl.$ext"
        if ($tryUrl -eq $p.image) { continue }
        if (Test-ImageUrl $tryUrl) {
            $fixed.Add("$($p.id)|$($p.name)|$($p.image)|$tryUrl")
            $found = $true
            break
        }
    }
    if (-not $found) {
        $broken.Add("$($p.id)|$($p.name)|$($p.image)")
    }
}

Write-Output "정상: $($ok.Count) / 확장자 수정으로 복구: $($fixed.Count) / 복구 불가(사진 없음): $($broken.Count)"
$fixed | Out-File "$OutDir\image_fixed.txt" -Encoding utf8
$broken | Out-File "$OutDir\image_broken.txt" -Encoding utf8
