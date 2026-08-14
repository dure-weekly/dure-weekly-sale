# 농할쿠폰(29차) 전체 재작성: 기존 nonghal_coupon 195개를 모두 삭제하고
# 29차 파일(nonghal29_full_list.txt, 214개)을 기준으로 새로 생성한다.
$root = Split-Path -Parent $PSScriptRoot
$dataPath = Join-Path $root "data\products.json"
$listPath = Join-Path $root "scripts\_last_run\nonghal29_full_list.txt"
$couponPeriod = "8/20(목)~26(수)"

$iconMap = @{
    "버섯" = "🍄"
    "뿌리채소" = "🥕"
    "손질채소/특용채소" = "🥬"
    "열매채소" = "🫑"
    "잎채소" = "🥬"
    "과수/과채" = "🍎"
    "쌀" = "🌾"
    "잡곡류" = "🌾"
    "닭/오리/양" = "🍗"
    "돼지(냉장)" = "🥩"
    "유정란/알" = "🥚"
    "한우(냉장)" = "🥩"
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

# 2) 새 블록 생성
$lines = Get-Content $listPath -Encoding UTF8
$blocks = @()
$idNum = 900
foreach ($line in $lines) {
    $f = $line -split "`t"
    if ($f.Count -lt 10) { continue }
    $code = $f[0]; $name = $f[1]; $daebun = $f[2]; $jungbun = $f[3]
    $normal = [int]$f[4]; $selfDisc = [int]$f[5]; $couponPrice = [int]$f[6]
    $totalRateStr = $f[9] -replace '%',''
    $totalRate = [int][math]::Round([double]$totalRateStr)
    $icon = if ($iconMap.ContainsKey($jungbun)) { $iconMap[$jungbun] } else { "🥦" }
    $idNum++
    $id = "n$idNum"
    $nameEsc = $name -replace '"','\"'
    $block = @"
    {
      "id": "$id",
      "name": "$nameEsc",
      "icon": "$icon",
      "image": "https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/${code}C.jpg",
      "originalPrice": $normal,
      "salePrice": $selfDisc,
      "couponPrice": $couponPrice,
      "discountRate": $totalRate,
      "hasCoupon": true,
      "couponLabel": "🌾 농할 쿠폰",
      "couponPeriod": "$couponPeriod",
      "theme": "$daebun",
      "category": "nonghal_coupon",
      "itemType": "소비촉진",
      "note": "",
      "hideFromAll": false,
      "code": "$code",
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
