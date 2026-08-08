# 사전예약 63개 항목의 recipes 필드를 구형(문자열배열)에서 카드형으로 교체.
# ConvertTo-Json 왕복 금지 원칙에 따라, 텍스트에서 각 키의 "recipes": [...] 블록만
# 문자열-인식 괄호매칭으로 정확히 찾아서 새 텍스트로 치환한다(다른 필드는 건드리지 않음).

$root = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $root "data\goodsDetails.json"
$dir = Join-Path $root "scripts\_last_run"
$batchFiles = @("recipes_upgrade_batch_1.json","recipes_upgrade_batch_2.json","recipes_upgrade_batch_3.json","recipes_upgrade_batch_4.json")

# 문자열 인식 괄호매칭: $text의 $startBracketIndex(여는 괄호 위치)부터 시작해서
# 짝이 맞는 닫는 괄호의 인덱스를 찾는다. 따옴표 안의 [ ] { } 는 무시한다.
function Find-MatchingBracket($text, $startBracketIndex) {
    $openChar = $text[$startBracketIndex]
    $closeChar = if ($openChar -eq '[') { ']' } else { '}' }
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

# 카드 배열 하나를 JSON 텍스트로 수동 조립(문자열 그대로 삽입 - 이스케이프 손상 없음)
function Build-RecipesText($cards) {
    $cardTexts = @()
    foreach ($c in $cards) {
        $steps = @($c.steps) | ForEach-Object { '"' + $_ + '"' }
        $stepsText = "[" + ($steps -join ", ") + "]"
        $tagline = if ($c.tagline) { $c.tagline } else { "" }
        $cardTexts += "{`"icon`": `"$($c.icon)`", `"name`": `"$($c.name)`", `"steps`": $stepsText, `"tagline`": `"$tagline`"}"
    }
    return "[`n      " + ($cardTexts -join ",`n      ") + "`n    ]"
}

$allNew = @{}
foreach ($f in $batchFiles) {
    $obj = Get-Content (Join-Path $dir $f) -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($prop in $obj.PSObject.Properties) {
        $allNew[$prop.Name] = $prop.Value
    }
}
Write-Output "치환 대상 키 총 개수: $($allNew.Count)"

$text = Get-Content $targetPath -Raw -Encoding UTF8

$successCount = 0
$failKeys = @()
foreach ($key in $allNew.Keys) {
    # 키 시작 지점 찾기: "KEY": { 형태
    $keyPattern = '"' + [regex]::Escape($key) + '":\s*\{'
    $m = [regex]::Match($text, $keyPattern)
    if (-not $m.Success) {
        $failKeys += "$key (키를 못찾음)"
        continue
    }
    $keyStart = $m.Index

    # 그 다음 "recipes": 위치 찾기 (키 시작 이후 범위에서)
    $recipesLabelIdx = $text.IndexOf('"recipes":', $keyStart)
    if ($recipesLabelIdx -eq -1) {
        $failKeys += "$key (recipes 필드를 못찾음)"
        continue
    }
    # "recipes": 다음의 첫 '[' 위치
    $bracketStart = $text.IndexOf('[', $recipesLabelIdx)
    if ($bracketStart -eq -1) {
        $failKeys += "$key (여는 대괄호를 못찾음)"
        continue
    }
    $bracketEnd = Find-MatchingBracket $text $bracketStart
    if ($bracketEnd -eq -1) {
        $failKeys += "$key (닫는 대괄호를 못찾음)"
        continue
    }

    $newRecipesText = Build-RecipesText $allNew[$key]
    $before = $text.Substring(0, $bracketStart)
    $after = $text.Substring($bracketEnd + 1)
    $text = $before + $newRecipesText + $after
    $successCount++
}

Write-Output "치환 성공: $successCount / $($allNew.Count)"
if ($failKeys.Count -gt 0) {
    Write-Output "실패한 키:"
    $failKeys | ForEach-Object { Write-Output "  - $_" }
}

[System.IO.File]::WriteAllText($targetPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "저장 완료."
