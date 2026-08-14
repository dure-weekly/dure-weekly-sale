# 신규 사전예약 12개(미앤미/시흥로컬 3개=id키, 싹스텐 9개=code키) 상세 콘텐츠를 goodsDetails.json에 병합.
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"
$targetPath = Join-Path $root "data\goodsDetails.json"

$a = Get-Content (Join-Path $dir "new_reservation_details_A.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$b = Get-Content (Join-Path $dir "new_reservation_details_B.json") -Raw -Encoding UTF8 | ConvertFrom-Json

# A그룹(58371/58374/50454)은 코드가 실제로는 다른 상품 것이므로, id(r092/r093/r094)로 키를 바꾼다.
$codeToId = @{ "58371" = "r092"; "58374" = "r093"; "50454" = "r094" }

function Json-Escape($s) {
    if ($null -eq $s) { return "" }
    return $s -replace '\\','\\\\' -replace '"','\"'
}

function Build-Block($key, $id, $code, $entry) {
    $featuresJson = ($entry.features | ForEach-Object { '"' + (Json-Escape $_) + '"' }) -join ", "
    $recipesJson = ($entry.recipes | ForEach-Object {
        $steps = ($_.steps | ForEach-Object { '"' + (Json-Escape $_) + '"' }) -join ", "
        '{"icon": "' + $_.icon + '", "name": "' + (Json-Escape $_.name) + '", "steps": [' + $steps + '], "tagline": "' + (Json-Escape $_.tagline) + '"}'
    }) -join ",`n      "
    $specsJson = ($entry.specs.PSObject.Properties | ForEach-Object { '"' + (Json-Escape $_.Name) + '": "' + (Json-Escape $_.Value) + '"' }) -join ", "
    $reviewsJson = if ($entry.reviews -and $entry.reviews.Count -gt 0) {
        ($entry.reviews | ForEach-Object {
            $yearsField = if ($_.years -ne $null) { ', "years": ' + $_.years } else { "" }
            '{"text": "' + (Json-Escape $_.text) + '", "rating": ' + $_.rating + ', "author": "' + (Json-Escape $_.author) + '"' + $yearsField + '}'
        }) -join ", "
    } else { "" }

    return @"
  "$key": {
    "id": "$id",
    "code": "$code",
    "lookupStatus": "ok",
    "features": [$featuresJson],
    "differentiation": "$(Json-Escape $entry.differentiation)",
    "tip": "$(Json-Escape $entry.tip)",
    "recipes": [
      $recipesJson
    ],
    "specs": {$specsJson},
    "reviews": [$reviewsJson]
  }
"@
}

$blocks = @()
foreach ($p in $a.PSObject.Properties) {
    $origCode = $p.Name
    $id = $codeToId[$origCode]
    $blocks += Build-Block $id $id "" $p.Value
}
foreach ($p in $b.PSObject.Properties) {
    $code = $p.Name
    $blocks += Build-Block $code "" $code $p.Value
}

Write-Output "병합 대상 총 개수: $($blocks.Count)"

$text = Get-Content $targetPath -Raw -Encoding UTF8
$joined = ($blocks -join ",`n")
$lastBraceIndex = $text.LastIndexOf("}")
$before = $text.Substring(0, $lastBraceIndex).TrimEnd()
$merged = $before + ",`n" + $joined + "`n}`n"

[System.IO.File]::WriteAllText($targetPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
