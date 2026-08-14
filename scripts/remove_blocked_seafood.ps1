# ERP OrderList 조회 결과(GwRemark="예약운영생활재" 등) 기준으로 실제 주문불가인
# 수산쿠폰 19개 품목을 제거한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$targetNames = @(
    "손질민물장어(600g/2~3미)",
    "초벌장어(470g/2~3미)",
    "미더덕(500g)",
    "왕바지락(600g)",
    "생물 바지락살(200g)",
    "완도참전복700g(8~10미)",
    "완도참전복(3미/300~330g)",
    "완도왕전복(5미/600g이상)",
    "홍가리비(1.5kg)",
    "비단가리비(1kg)",
    "백합조개(1kg)",
    "개조개(800g)",
    "완도참전복(480g/6미)",
    "뿔소라(900g/7~10미)",
    "세척홍합(1.5kg)",
    "문어 슬라이스(200g)",
    "동죽조개(200g)",
    "바지락(200g)",
    "바지락(800g)",
    "돌멍게(900g/6~9미)",
    "해삼(200g)"
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
    if ($nameIdx -eq -1) {
        # seafood_coupon이 아닌 다른 항목(예: 사전예약 관련 동명이인)일 수 있으니
        # category가 seafood_coupon인 것만 매칭되도록 두 번째 시도는 생략하고 기록만.
        $notFound += $name
        continue
    }
    $openBraceIdx = $text.LastIndexOf("{", $nameIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $blockEnd = $closeBraceIdx + 1
    if ($text.Substring($blockEnd, 1) -eq ",") { $blockEnd++ }
    $lineStart = $text.LastIndexOf("`n", $openBraceIdx) + 1
    $removals += [PSCustomObject]@{ Start = $lineStart; End = $blockEnd }
}
Write-Output "제거 대상 찾음: $($removals.Count) / $($targetNames.Count)"
if ($notFound.Count -gt 0) { Write-Output ("못찾음: " + ($notFound -join " | ")) }

$removals = $removals | Sort-Object Start -Descending
foreach ($r in $removals) {
    $text = $text.Remove($r.Start, $r.End - $r.Start)
}

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
