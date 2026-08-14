# 34주 파일에 없는 이전 주 "일반 주간할인"(비쿠폰) 항목 80개를 id 기준으로 삭제한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"

$idsToDelete = @(
    "p001","p030","p040","p039","p012","p020","p017","p016","p023","p044",
    "p034","p045","p041","p031","p067","p026","p042","p065","p033","p037",
    "p035","p036","p066","p043","p062","p068","p069","p004","p019","p018",
    "p027","p064","p005","p007","p011","p013","p010","p009","p008","p014",
    "p015","p022","p021","p024","p025","p028","p063","p056","p057","p070",
    "p079","p083","p085","p090","p089","p082","p101","p100","p102","p107",
    "p094","p093","p095","p096","p097","p099","p098","p103","p104","p106",
    "p105","p111","p109","p113","p112","p114","p110","p108","p115","p116"
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
$deleted = 0
foreach ($id in $idsToDelete) {
    $marker = '"id": "' + $id + '",'
    $idIdx = $text.IndexOf($marker)
    if ($idIdx -eq -1) { Write-Output "경고: $id 못찾음"; continue }
    $openBraceIdx = $text.LastIndexOf("{", $idIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    # 블록 뒤 콤마까지 포함해서 제거(콤마가 있으면), 없으면(마지막 항목) 앞의 콤마를 제거
    $afterIdx = $closeBraceIdx + 1
    $removeEnd = $afterIdx
    if ($text.Substring($afterIdx, 1) -eq ",") { $removeEnd = $afterIdx + 1 }
    $before = $text.Substring(0, $openBraceIdx)
    $after = $text.Substring($removeEnd)
    $text = $before + $after
    $deleted++
}
Write-Output "삭제 완료: $deleted 개"

[System.IO.File]::WriteAllText($dataPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
