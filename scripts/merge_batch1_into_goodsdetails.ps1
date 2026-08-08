# 1차 배치(주간할인 상품 36개) 조사 결과(detail_batch_F~I.json)를 goodsDetails.json에 병합.
# ConvertTo-Json 왕복 대신 텍스트 블록 삽입 방식(한글 유니코드 깨짐 방지, 기존 프로젝트 관행).
# 이미 있는 코드는 절대 덮어쓰지 않는다 - 이번엔 사전에 중복 0건 확인됨(merge 전 검증 완료).

$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "scripts\_last_run"
$targetPath = Join-Path $root "data\goodsDetails.json"

$batchFiles = @("detail_batch_F.json","detail_batch_G.json","detail_batch_H.json","detail_batch_I.json")

$blocks = @()
foreach ($f in $batchFiles) {
    $text = Get-Content (Join-Path $dir $f) -Raw -Encoding UTF8
    $text = $text.Trim()
    # 맨 앞 "{"와 맨 뒤 "}" 제거, 안쪽 내용만 취함
    $inner = $text.Substring(1, $text.Length - 2).Trim()
    $blocks += $inner
}
$newContent = ($blocks -join ",`n")

$target = Get-Content $targetPath -Raw -Encoding UTF8
# 파일 맨 끝의 "}"를 찾아서 그 앞에 새 항목들을 ",`n<new>`n" 형태로 삽입
$lastBraceIndex = $target.LastIndexOf("}")
$before = $target.Substring(0, $lastBraceIndex).TrimEnd()
$merged = $before + ",`n" + $newContent + "`n}`n"

[System.IO.File]::WriteAllText($targetPath, $merged, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "병합 완료."
