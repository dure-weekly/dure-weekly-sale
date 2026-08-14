# 지난주에도 제외됐던 "자연산" 계열 14개 품목을 이번 6차 수산쿠폰에서도 제외한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$targetNames = @(
    "자연산대하(300g)",
    "자연산 광어회(280g)",
    "자연산참소라(1.5kg)",
    "자연산 붕장어(300g/샤브샤브용)",
    "자연산전복(200g/2~3미)",
    "자연산해삼(500g)",
    "자연산 붕장어회(150g)",
    "자연산 참돔(700g/1미)",
    "자연산해삼(250g)",
    "자연산 순살광어(200g/3~4조각)",
    "자연산 가자미회(300g)",
    "자연산 물미역(500g)",
    "자연산참바지락(350g)",
    "자연산 민어회(280g)"
)

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

$removals = @()
$notFound = @()
foreach ($name in $targetNames) {
    $nameMarker = '"name": "' + $name + '",'
    $nameIdx = $text.IndexOf($nameMarker)
    if ($nameIdx -eq -1) { $notFound += $name; continue }
    $openBraceIdx = $text.LastIndexOf("{", $nameIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $blockEnd = $closeBraceIdx + 1
    if ($text.Substring($blockEnd, 1) -eq ",") { $blockEnd++ }
    $lineStart = $text.LastIndexOf("`n", $openBraceIdx) + 1
    $removals += [PSCustomObject]@{ Start = $lineStart; End = $blockEnd }
}
Write-Output "제거 대상 찾음: $($removals.Count) / $($targetNames.Count)"
if ($notFound.Count -gt 0) { Write-Output ("못찾음: " + ($notFound -join ", ")) }

$removals = $removals | Sort-Object Start -Descending
foreach ($r in $removals) {
    $text = $text.Remove($r.Start, $r.End - $r.Start)
}

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
