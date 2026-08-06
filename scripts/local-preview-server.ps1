<#
로컬 미리보기 서버
==================
Netlify 배포 없이 이 PC에서 바로 랜딩페이지를 확인하기 위한 간단한 정적 파일 서버.
data/*.json을 fetch()로 불러오는 구조라 file:// 로 직접 열면 CORS 때문에 안 되고,
반드시 http://localhost 로 열어야 정상 동작한다.

사용법: powershell -ExecutionPolicy Bypass -File .\scripts\local-preview-server.ps1
종료: 이 창에서 Ctrl+C
#>

$root = Split-Path -Parent $PSScriptRoot
$port = 8080
$prefix = "http://localhost:$port/"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Output "로컬 미리보기 서버 시작: $prefix"
Write-Output "브라우저에서 http://localhost:$port/index.html 접속하세요. 종료하려면 Ctrl+C."

$mimeMap = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response
    try {
        $relPath = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
        if ($relPath -eq "") { $relPath = "index.html" }
        $filePath = Join-Path $root $relPath

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $mime = if ($mimeMap.ContainsKey($ext)) { $mimeMap[$ext] } else { "application/octet-stream" }
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $res.ContentType = $mime
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $res.StatusCode = 404
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $relPath")
            $res.OutputStream.Write($msg, 0, $msg.Length)
        }
    } catch {
        $res.StatusCode = 500
    } finally {
        $res.OutputStream.Close()
    }
}
