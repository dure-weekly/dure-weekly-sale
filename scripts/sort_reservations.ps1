# 사전예약 물리적 배열 순서를 카테고리->공급일->할인율(desc) 기준으로 재정렬한다.
# (전체 클릭 시 별도 정렬(날짜->부류->할인율)은 js/main.js에서 런타임에 처리되므로 여기선 안 건드림)

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\reservations.json"

# js/main.js의 RESERVATION_CATEGORY_LABELS 배열 순서와 동일하게 유지
$categoryOrder = @{
    "seafood" = 1
    "meat" = 2
    "jeju_pork" = 3
    "processed" = 4
    "health" = 5
    "grain" = 6
    "lacquerware" = 7
    "living" = 8
}

function Get-DateSortKey($item) {
    if ($item.directShip -eq $true) { return 0 }
    if ($item.supplyDate -match '(\d+)/(\d+)') {
        return [int]$matches[1] * 100 + [int]$matches[2]
    }
    return 9999
}

function Find-MatchingBracket($text, $startBracketIndex) {
    $depth = 0
    $inString = $false
    $escaped = $false
    for ($i = $startBracketIndex; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($inString) {
            if ($escaped) { $escaped = $false }
            elseif ($ch -eq '\') { $escaped = $true }
            elseif ($ch -eq '"') { $inString = $false }
            continue
        }
        if ($ch -eq '"') { $inString = $true; continue }
        if ($ch -eq '{') { $depth++ }
        elseif ($ch -eq '}') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }
    return -1
}

$obj = Get-Content $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$items = @($obj.reservations)
Write-Output "전체 항목 수: $($items.Count)"

$decorated = foreach ($item in $items) {
    $catIdx = if ($categoryOrder.ContainsKey($item.category)) { $categoryOrder[$item.category] } else { 99 }
    $featuredRank = if ($item.featured -eq $true) { 0 } else { 1 }
    [PSCustomObject]@{
        Item = $item
        FeaturedRank = $featuredRank
        CatIdx = $catIdx
        DateKey = Get-DateSortKey $item
        Discount = if ($item.discountRate) { $item.discountRate } else { 0 }
    }
}
$sorted = $decorated | Sort-Object FeaturedRank, CatIdx, DateKey, @{Expression="Discount"; Descending=$true}
$sortedIds = $sorted | ForEach-Object { $_.Item.id }

$text = Get-Content $dataPath -Raw -Encoding UTF8
$blocksById = @{}
foreach ($id in $sortedIds) {
    $idMarker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($idMarker)
    if ($idIdx -eq -1) { Write-Output "경고: $id 못찾음"; continue }
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $blockText = $text.Substring($openBraceIdx, $closeBraceIdx - $openBraceIdx + 1)
    $blocksById[$id] = $blockText.TrimEnd()
}
Write-Output "블록 추출: $($blocksById.Count)"

$orderedBlocks = foreach ($id in $sortedIds) { $blocksById[$id] }
$joined = ($orderedBlocks -join ",`n    ")
$merged = "{`n  ""updatedAt"": ""$($obj.updatedAt)"",`n  ""sourceWeek"": ""$($obj.sourceWeek)"",`n  ""reservations"": [`n    " + $joined + "`n  ]`n}`n"

[System.IO.File]::WriteAllText($dataPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
