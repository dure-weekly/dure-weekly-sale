# 농할쿠폰(30차) 전체 재작성: 기존 nonghal_coupon을 모두 삭제하고
# 30차 파일(nonghal30_full_list.txt, 돼지/한우 제외 138개)을 기준으로 새로 생성한다.
# 정렬 순서(지혜님 지정): 쌀(백미) -> 과일 -> 잡곡 -> 채소/버섯 -> 정육/유정란(닭.오리.양/유정란)
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$listPath = Join-Path $root "scripts\_last_run\nonghal30_full_list.txt"
$couponPeriod = "8/20(목)~26(수)"

$iconMap = @{
    "쌀" = "🌾"
    "잡곡류" = "🌾"
    "닭/오리/양" = "🍗"
    "유정란/알" = "🥚"
    "버섯" = "🍄"
    "뿌리채소" = "🥕"
    "손질채소/특용채소" = "🥬"
    "열매채소" = "🫑"
    "잎채소" = "🥬"
    "과수/과채" = "🍎"
}

function Get-SortPriority($daebun, $jungbun) {
    if ($jungbun -eq "쌀") { return 1 }
    if ($daebun -eq "과일/견과") { return 2 }
    if ($jungbun -eq "잡곡류") { return 3 }
    if ($daebun -eq "채소/버섯") { return 4 }
    return 5
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

# 0) 소스 라인 파싱 확인 (필드 인덱스 검증용 미리보기)
$lines = Get-Content $listPath -Encoding UTF8
Write-Output "원본 라인 수: $($lines.Count)"
$sample = ($lines[0] -split "`t")
Write-Output "샘플 파싱: code=$($sample[0]) name=$($sample[1]) daebun=$($sample[2]) jungbun=$($sample[3]) normal=$($sample[4]) selfDisc=$($sample[5]) couponPrice=$($sample[6]) totalRate=$($sample[8])"

# 1) 기존 nonghal_coupon 블록 전부 제거
$text = Get-Content $dataPath -Raw -Encoding UTF8
$removed = 0
while ($true) {
    $catIdx = $text.IndexOf('"category": "nonghal_coupon"')
    if ($catIdx -eq -1) { break }
    $openBraceIdx = $text.LastIndexOf("{", $catIdx)
    $closeBraceIdx = Find-MatchingBracket $text $openBraceIdx
    $afterIdx = $closeBraceIdx + 1
    $removeEnd = $afterIdx
    if ($afterIdx -lt $text.Length -and $text.Substring($afterIdx, 1) -eq ",") { $removeEnd = $afterIdx + 1 }
    $before = $text.Substring(0, $openBraceIdx)
    $after = $text.Substring($removeEnd)
    $text = $before + $after
    $removed++
}
Write-Output "기존 nonghal_coupon 삭제: $removed 개"

# 2) 우선순위별로 정렬해서 새 블록 생성
$parsed = foreach ($line in $lines) {
    $f = $line -split "`t"
    if ($f.Count -lt 10) { continue }
    $normal = [int]$f[4]; $couponPrice = [int]$f[6]
    # 총할인율 컬럼 텍스트는 신뢰하지 않는다(30차 파일 백미 2건에서 %가 아니라 원 단위 금액이 들어있는
    # 데이터 오류 발견됨) - 항상 정상가->쿠폰최종가 실제 가격차로 직접 계산한다.
    $computedRate = if ($normal -gt 0) { [int][math]::Round((($normal - $couponPrice) / $normal) * 100) } else { 0 }
    [PSCustomObject]@{
        Code = $f[0]; Name = $f[1]; Daebun = $f[2]; Jungbun = $f[3]
        Normal = $normal; SelfDisc = [int]$f[5]; CouponPrice = $couponPrice
        TotalRate = $computedRate
        Priority = Get-SortPriority $f[2] $f[3]
    }
}
$sorted = $parsed | Sort-Object Priority

$blocks = @()
$idNum = 2000
foreach ($item in $sorted) {
    $icon = if ($iconMap.ContainsKey($item.Jungbun)) { $iconMap[$item.Jungbun] } else { "🥦" }
    $idNum++
    $id = "n$idNum"
    $nameEsc = $item.Name -replace '"','\"'
    $block = @"
    {
      "id": "$id",
      "name": "$nameEsc",
      "icon": "$icon",
      "image": "https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/$($item.Code)C.jpg",
      "originalPrice": $($item.Normal),
      "salePrice": $($item.SelfDisc),
      "couponPrice": $($item.CouponPrice),
      "discountRate": $($item.TotalRate),
      "hasCoupon": true,
      "couponLabel": "🌾 농할 쿠폰",
      "couponPeriod": "$couponPeriod",
      "theme": "$($item.Daebun)",
      "category": "nonghal_coupon",
      "itemType": "소비촉진",
      "note": "",
      "hideFromAll": false,
      "code": "$($item.Code)",
      "description": "$nameEsc, 이번 주 농할쿠폰 특가로 만나보세요."
    }
"@
    $blocks += $block
}
Write-Output "신규 생성: $($blocks.Count) 개"

# 3) products.json 끝에 삽입 (마지막 "]" 앞)
$joined = ($blocks -join ",`n")
$lastBracketIdx = $text.LastIndexOf("]")
$before2 = $text.Substring(0, $lastBracketIdx).TrimEnd()
if ($before2.EndsWith(",")) { $before2 = $before2.Substring(0, $before2.Length - 1) }
$after2 = $text.Substring($lastBracketIdx)
$merged = $before2 + ",`n" + $joined + "`n  " + $after2

[System.IO.File]::WriteAllText($dataPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
