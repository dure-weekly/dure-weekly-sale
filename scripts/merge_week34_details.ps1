# 34주 신규 사전예약 20개 항목의 상세 콘텐츠(그룹A+B)를 goodsDetails.json에 병합.
# 코드 키 유지, 각 항목에 id 필드 추가. 기존 항목은 절대 덮어쓰지 않음(사전에 겹침 0건 확인됨).

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"
$targetPath = Join-Path $root "data\goodsDetails.json"

$idMap = @{
    "52942"="r072"; "58803"="r073"; "56011"="r074"; "56606"="r075"; "57183"="r076"
    "7253"="r077"; "7254"="r078"; "7255"="r079"; "7256"="r080"; "7257"="r081"
    "7527"="r082"; "11004"="r083"; "11005"="r084"; "12932"="r085"; "14663"="r086"
    "35253"="r087"; "35254"="r088"; "53332"="r089"; "24697"="r090"; "57857"="r091"
}

$a = Get-Content (Join-Path $dir "week34_details_A.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$b = Get-Content (Join-Path $dir "week34_details_B.json") -Raw -Encoding UTF8 | ConvertFrom-Json

$all = @{}
foreach ($p in $a.PSObject.Properties) { $all[$p.Name] = $p.Value }
foreach ($p in $b.PSObject.Properties) { $all[$p.Name] = $p.Value }

Write-Output "병합 대상 총 개수: $($all.Count)"

function Json-Escape($s) {
    if ($null -eq $s) { return "" }
    return $s -replace '\\','\\\\' -replace '"','\"'
}

$blocks = @()
foreach ($code in $all.Keys) {
    $entry = $all[$code]
    $id = $idMap[$code]

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

    $block = @"
  "$code": {
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
    $blocks += $block
}

$text = Get-Content $targetPath -Raw -Encoding UTF8
$joined = ($blocks -join ",`n")
$lastBraceIndex = $text.LastIndexOf("}")
$before = $text.Substring(0, $lastBraceIndex).TrimEnd()
$merged = $before + ",`n" + $joined + "`n}`n"

[System.IO.File]::WriteAllText($targetPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
