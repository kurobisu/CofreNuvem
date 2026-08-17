param(
  [int]$Port = 8766,
  [string]$Root = "build/web"
)

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root on http://localhost:$Port/"

$mime = @{
  ".html" = "text/html"; ".js" = "application/javascript"; ".json" = "application/json";
  ".css" = "text/css"; ".png" = "image/png"; ".jpg" = "image/jpeg"; ".svg" = "image/svg+xml";
  ".wasm" = "application/wasm"; ".ico" = "image/x-icon"; ".woff2" = "font/woff2";
}

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $req = $context.Request
  $res = $context.Response
  $path = $req.Url.AbsolutePath.TrimStart('/')
  if ([string]::IsNullOrEmpty($path)) { $path = "index.html" }
  $filePath = Join-Path $Root $path
  if (-not (Test-Path $filePath) -or (Get-Item $filePath).PSIsContainer) {
    $filePath = Join-Path $Root "index.html"
  }
  try {
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $ext = [System.IO.Path]::GetExtension($filePath)
    $contentType = $mime[$ext]
    if (-not $contentType) { $contentType = "application/octet-stream" }
    $res.ContentType = $contentType
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
  } catch {
    $res.StatusCode = 404
  }
  $res.OutputStream.Close()
}
