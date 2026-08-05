<#
매장 ERP 주간할인 데이터 검증 스크립트
=====================================
목적: 매장_주간할인_erp데이타/ 폴더의 엑셀 발주 목록을 기준으로,
      현재 data/products.json(쇼핑몰 크롤링 데이터)과 비교해
      1) 쇼핑몰은 할인인데 매장은 할인이 아닌 항목(제외 후보)
      2) 매장은 할인인데 쇼핑몰 목록엔 없는 항목(추가 후보)
      을 뽑아낸다. 실행에는 Microsoft Excel이 설치되어 있어야 한다(COM 자동화).

사용법 (PowerShell에서):
  1. 매장_주간할인_erp데이타/ 폴더를 그 주의 최신 엑셀 파일들로 교체
  2. .\scripts\verify-store-discounts.ps1 실행
  3. 콘솔에 출력되는 "제외 후보" / "추가 후보" 목록을 바탕으로
     Claude에게 "이번주 매장 ERP 대조해서 랜딩페이지 갱신해줘"라고 요청
     (신규 항목은 이미지/설명을 두레생협 몰 goodsView.do?returnNo={코드}에서
     조회해야 하므로 이 단계는 Claude가 웹 조회로 처리한다 — 이 스크립트는
     "어떤 코드가 새로 필요한지"까지만 알려준다)

주의사항 / 알아둘 것 (2026-08-05 세션에서 겪은 시행착오):
  - 생활재 항목명이 "(한정) [코드]상품명"처럼 코드 앞에 접두어가 붙는 경우가 있다.
    코드 추출 정규식은 반드시 문자열 어디서든 "[숫자]"를 찾도록 해야 한다
    (문자열 시작(^)에만 매칭시키면 "(한정)" 붙은 항목을 통째로 놓친다).
  - 단가란은 "정가 할인가"(예: "56000 55,000") 형식이면 할인 중, 숫자 하나뿐이면
    할인 아님 → 반드시 제외해야 한다(정가로만 판매 중인 상품).
  - 쇼핑몰 products.json의 image 필드 URL(.../GoodsImage/{코드}C.jpg)에서
    코드를 추출하면 이게 ERP의 생활재번호와 동일하다 — 이 코드로 매칭한다.
  - 두레생협 몰 상품 상세 페이지는 검색 없이 코드만으로 바로 접근 가능:
    https://www.ecoop.or.kr/DureShop/prod/goodsView.do?returnNo={생활재번호}
    이미지 CDN도 코드만으로 바로 유효:
    https://dureimg.ecoop.or.kr:9091/Delsys/DLOG/Goods/GoodsMaster/GoodsImage/{코드}C.jpg
  - 매장 ERP 12개 파일이 매장 취급 품목 "전체"라는 보장은 없다(발주 관리용 발췌일 수 있음).
    ERP에 전혀 없는 코드는 "매장 미확인"으로 보수적으로 제외 처리하는 것을 권장.
#>

param(
    [string]$ErpFolder = "c:\Users\USER\Documents\클로드코워크\랜딩페이지\매장_주간할인_erp데이타",
    [string]$ProductsJsonPath = "c:\Users\USER\Documents\클로드코워크\랜딩페이지\data\products.json",
    [string]$OutDir = "$PSScriptRoot\_last_run"
)

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---------- 1. 엑셀 전체 추출 (구분/생활재/단가 3개 컬럼) ----------
$files = Get-ChildItem $ErpFolder -Filter "*.xlsx" | Where-Object { $_.Name -notlike "~$*" }
if ($files.Count -eq 0) {
    Write-Output "엑셀 파일이 없습니다: $ErpFolder"
    return
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$rawRows = New-Object System.Collections.Generic.List[object]
foreach ($f in $files) {
    $wb = $excel.Workbooks.Open($f.FullName)
    $ws = $wb.Worksheets.Item(1)
    $rowCount = $ws.UsedRange.Rows.Count
    for ($r = 2; $r -le $rowCount; $r++) {
        $item = $ws.Cells.Item($r, 2).Text
        $price = $ws.Cells.Item($r, 3).Text
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        $rawRows.Add([PSCustomObject]@{ item = $item; price = $price; source = $f.Name })
    }
    $wb.Close($false)
}
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Output "엑셀에서 추출한 총 행 수: $($rawRows.Count)"

# ---------- 2. 생활재번호 + 할인여부 파싱 ----------
# 주의: 정규식은 문자열 시작(^)이 아니라 어디든 "[숫자]"를 찾아야 한다 ("(한정)" 접두어 대응)
$discountMap = @{}   # 코드 -> {name, orig, sale, rate}
$noDiscountMap = @{} # 코드 -> name (정가만 존재, 할인 아님)

foreach ($row in $rawRows) {
    if ($row.item -notmatch '\[(\d+)\](.+)$') { continue }
    $code = $matches[1]
    $name = $matches[2]

    $nums = [regex]::Matches($row.price.Trim(), '[\d,]+')
    if ($nums.Count -ge 2) {
        $orig = [int]($nums[0].Value -replace ',', '')
        $sale = [int]($nums[1].Value -replace ',', '')
        if ($orig -gt 0 -and $sale -gt 0 -and $sale -lt $orig) {
            $rate = [Math]::Round((($orig - $sale) / $orig) * 100)
            $discountMap[$code] = [PSCustomObject]@{ name = $name; orig = $orig; sale = $sale; rate = $rate }
        }
    } elseif ($nums.Count -eq 1) {
        $noDiscountMap[$code] = $name
    }
}
Write-Output "매장에서 이번 주 할인 중인 고유 생활재: $($discountMap.Keys.Count)건"

# ---------- 3. 현재 products.json과 대조 ----------
$current = Get-Content $ProductsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$mallCodes = @{}
foreach ($p in $current.products) {
    if ($p.image -match '/(\d+)[A-Za-z]?\.(jpg|jpeg|png)$') { $mallCodes[$matches[1]] = $p }
}

$removeCandidates = New-Object System.Collections.Generic.List[string]
$addCandidates = New-Object System.Collections.Generic.List[string]

foreach ($p in $current.products) {
    if ($p.image -notmatch '/(\d+)[A-Za-z]?\.(jpg|jpeg|png)$') { continue }
    $code = $matches[1]
    if ($discountMap.ContainsKey($code)) { continue } # 일치, 정상
    if ($noDiscountMap.ContainsKey($code)) {
        $removeCandidates.Add("$($p.id) | $code | $($p.name) | 매장: 정가만 존재(할인 아님)")
    } else {
        $removeCandidates.Add("$($p.id) | $code | $($p.name) | 매장 ERP에서 코드 미발견")
    }
}

foreach ($code in $discountMap.Keys) {
    if ($mallCodes.ContainsKey($code)) { continue }
    $d = $discountMap[$code]
    $addCandidates.Add("$code | $($d.name) | $($d.orig)->$($d.sale)원 ($($d.rate)%)")
}

$removeCandidates | Out-File "$OutDir\remove_candidates.txt" -Encoding utf8
$addCandidates | Sort-Object { [int]($_ -replace '^\d+ \| .+\((\d+)%\)$', '$1') } -Descending | Out-File "$OutDir\add_candidates.txt" -Encoding utf8

Write-Output ""
Write-Output "=== 제외 후보 (쇼핑몰은 할인, 매장은 아님): $($removeCandidates.Count)건 -> $OutDir\remove_candidates.txt ==="
Write-Output "=== 추가 후보 (매장은 할인, 쇼핑몰 목록엔 없음): $($addCandidates.Count)건 -> $OutDir\add_candidates.txt ==="
Write-Output ""
Write-Output "다음 단계: 이 결과를 Claude Code에게 보여주고 '추가 후보는 goodsView.do?returnNo={코드}로 이미지/설명 조회해서 반영해줘'라고 요청하세요."
