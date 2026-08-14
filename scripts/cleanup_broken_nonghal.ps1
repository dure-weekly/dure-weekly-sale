# 필드 인덱스 오류로 깨진 nonghal_coupon(id: n9xx) 블록 전부 제거한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

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

$text = Get-Content $dataPath -Raw -Encoding UTF8
$removed = 0
while ($true) {
    $idx = $text.IndexOf('"id": "n9')
    if ($idx -eq -1) { break }
    $openBraceIdx = $text.LastIndexOf("{", $idx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $afterIdx = $closeBraceIdx + 1
    $removeEnd = $afterIdx
    if ($afterIdx -lt $text.Length -and $text.Substring($afterIdx, 1) -eq ",") { $removeEnd = $afterIdx + 1 }
    $before = $text.Substring(0, $openBraceIdx)
    $after = $text.Substring($removeEnd)
    $text = $before + $after
    $removed++
}
Write-Output "제거된 깨진 블록: $removed 개"
[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
