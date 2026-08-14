# 기존 seafood_coupon(수산쿠폰) 112개 블록을 products.json에서 전부 제거하고
# seafood6_new_products.json(199개)을 배열 끝에 이어붙인다.
# 텍스트 블록 단위 처리(ConvertTo-Json 왕복 금지).

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$dir = Join-Path $root "scripts\_last_run"

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
$oldSeafoodIds = @($obj.products | Where-Object { $_.category -eq "seafood_coupon" } | ForEach-Object { $_.id })
Write-Output "제거 대상(기존 수산쿠폰): $($oldSeafoodIds.Count)"

$text = Get-Content $dataPath -Raw -Encoding UTF8

$removals = @()
foreach ($id in $oldSeafoodIds) {
    $idMarker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($idMarker)
    if ($idIdx -eq -1) { continue }
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $blockEnd = $closeBraceIdx + 1
    if ($text.Substring($blockEnd, 1) -eq ",") { $blockEnd++ }
    $lineStart = $text.LastIndexOf("`n", $openBraceIdx) + 1
    $removals += [PSCustomObject]@{ Start = $lineStart; End = $blockEnd }
}
$removals = $removals | Sort-Object Start -Descending
foreach ($r in $removals) {
    $text = $text.Remove($r.Start, $r.End - $r.Start)
}
Write-Output "제거 완료: $($removals.Count)건"

# 신규 199개 삽입
$newText = (Get-Content (Join-Path $dir "seafood6_new_products.json") -Raw -Encoding UTF8).Trim()
$inner = $newText.Substring(1, $newText.Length - 2).Trim()

$lastBracketIndex = $text.LastIndexOf("]")
$before = $text.Substring(0, $lastBracketIndex).TrimEnd()
$before = $before.TrimEnd(",")
$merged = $before + ",`n" + $inner + "`n  ]`n}`n"

[System.IO.File]::WriteAllText($dataPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
