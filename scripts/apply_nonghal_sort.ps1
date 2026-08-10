# nonghal_sorted_order.txt 의 순서대로 products.json 안의 nonghal_coupon 항목들을
# 원래 위치에서 제거하고, 배열 맨 끝에 정렬된 순서로 다시 이어붙인다.
# 텍스트 블록 단위 추출/재조립(ConvertTo-Json 왕복 금지 원칙 준수) - 한글 손상 없음.

$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$dir = Join-Path $root "scripts\_last_run"

$sortedIds = Get-Content (Join-Path $dir "nonghal_sorted_order.txt") -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }

function Find-MatchingBracket($text, $startBracketIndex) {
    $openChar = $text[$startBracketIndex]
    $closeChar = if ($openChar -eq '{') { '}' } else { ']' }
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
        if ($ch -eq $openChar) { $depth++ }
        elseif ($ch -eq $closeChar) {
            $depth--
            if ($depth -eq 0) { return $i }
        }
    }
    return -1
}

$text = Get-Content $dataPath -Raw -Encoding UTF8

$blocksById = @{}
foreach ($id in $sortedIds) {
    $idMarker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($idMarker)
    if ($idIdx -eq -1) {
        Write-Output "경고: $id 를 찾을 수 없음"
        continue
    }
    # id 앞쪽에서 가장 가까운 여는 중괄호 찾기
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    if ($closeBraceIdx -eq -1) {
        Write-Output "경고: $id 의 닫는 중괄호를 못찾음"
        continue
    }
    # 블록 앞의 공백/줄바꿈과 뒤의 콤마까지 포함해서 온전히 제거되도록 범위를 잡는다.
    $blockStart = $openBraceIdx
    $blockEnd = $closeBraceIdx + 1
    # 블록 뒤에 콤마가 있으면 콤마까지 포함
    if ($text.Substring($blockEnd, 1) -eq ",") { $blockEnd++ }

    $blockText = $text.Substring($blockStart, $blockEnd - $blockStart)
    $blocksById[$id] = $blockText.TrimEnd(",").Trim()
}

Write-Output "추출된 블록 수: $($blocksById.Count) / 대상: $($sortedIds.Count)"

# 원본 텍스트에서 모든 nonghal_coupon 블록을 제거한다(뒤에서부터 지워야 인덱스가 안 틀어짐).
$removals = @()
foreach ($id in $sortedIds) {
    $idMarker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($idMarker)
    if ($idIdx -eq -1) { continue }
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $blockStart = $openBraceIdx
    $blockEnd = $closeBraceIdx + 1
    if ($text.Substring($blockEnd, 1) -eq ",") { $blockEnd++ }
    # 블록 앞의 들여쓰기/줄바꿈까지 같이 제거(빈 줄이 안 남게)
    $lineStart = $text.LastIndexOf("`n", $blockStart) + 1
    $removals += [PSCustomObject]@{ Start = $lineStart; End = $blockEnd }
}
$removals = $removals | Sort-Object Start -Descending
foreach ($r in $removals) {
    $text = $text.Remove($r.Start, $r.End - $r.Start)
}

# 정렬된 순서로 블록을 이어붙여서 배열 맨 끝에 삽입
$orderedBlocks = @()
foreach ($id in $sortedIds) {
    if ($blocksById.ContainsKey($id)) { $orderedBlocks += $blocksById[$id] }
}
$joined = ($orderedBlocks -join ",`n    ")

$lastBracketIndex = $text.LastIndexOf("]")
$before = $text.Substring(0, $lastBracketIndex).TrimEnd()
$before = $before.TrimEnd(",")
$merged = $before + ",`n    " + $joined + "`n  ]`n}`n"

[System.IO.File]::WriteAllText($dataPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
