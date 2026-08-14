# 수산쿠폰 6차 신규 조사분(그룹A+B+C, 29개)을 goodsDetails.json에 병합.
# 코드 키 유지, id 필드 없음(주간할인 상품은 코드로만 키). 기존 항목은 덮어쓰지 않음.

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"
$targetPath = Join-Path $root "data\goodsDetails.json"

$a = Get-Content (Join-Path $dir "seafood6_details_A.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$b = Get-Content (Join-Path $dir "seafood6_details_B.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$c = Get-Content (Join-Path $dir "seafood6_details_C.json") -Raw -Encoding UTF8 | ConvertFrom-Json

$all = @{}
foreach ($p in $a.PSObject.Properties) { $all[$p.Name] = $p.Value }
foreach ($p in $b.PSObject.Properties) { $all[$p.Name] = $p.Value }
foreach ($p in $c.PSObject.Properties) { $all[$p.Name] = $p.Value }

Write-Output "병합 대상 총 개수: $($all.Count)"

function Json-Escape($s) {
    if ($null -eq $s) { return "" }
    return $s -replace '\\','\\\\' -replace '"','\"'
}

$blocks = @()
foreach ($code in $all.Keys) {
    $entry = $all[$code]

    $featuresJson = ($entry.features | ForEach-Object { '"' + (Json-Escape $_) + '"' }) -join ", "
    $recipesJson = ($entry.recipes | ForEach-Object {
        $steps = ($_.steps | ForEach-Object { '"' + (Json-Escape $_) + '"' }) -join ", "
        '{"icon": "' + $_.icon + '", "name": "' + (Json-Escape $_.name) + '", "steps": [' + $steps + '], "tagline": "' + (Json-Escape $_.tagline) + '"}'
    }) -join ",`n      "
    $specsJson = ($entry.specs.PSObject.Properties | ForEach-Object { '"' + (Json-Escape $_.Name) + '": "' + (Json-Escape $_.Value) + '"' }) -join ", "

    $block = @"
  "$code": {
    "code": "$code",
    "lookupStatus": "ok",
    "features": [$featuresJson],
    "differentiation": "$(Json-Escape $entry.differentiation)",
    "tip": "$(Json-Escape $entry.tip)",
    "recipes": [
      $recipesJson
    ],
    "specs": {$specsJson},
    "reviews": []
  }
"@
    $blocks += $block
}

$text = Get-Content $targetPath -Raw -Encoding UTF8
$joined = ($blocks -join ",`n")
$lastBraceIndex = $text.LastIndexOf("}")
$before = $text.Substring(0, $lastBraceIndex).TrimEnd()
$merged = $before + ",`n" + $joined + "`n}`n"

[System.IO.File]::WriteAllText($targetPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
