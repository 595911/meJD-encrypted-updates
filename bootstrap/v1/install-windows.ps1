param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) { throw '请在 Windows PowerShell 中运行。' }
if (-not $env:MEJD_UPDATE_KEY_BASE64) { throw '命令缺少首次安装码。' }
$architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
switch ($architecture) {
  'X64' { $target = 'windows-amd64' }
  'Arm64' { $target = 'windows-arm64' }
  default { throw "不支持此 Windows CPU 架构：$architecture" }
}
$base = 'https://raw.githubusercontent.com/595911/meJD-encrypted-updates/main/bootstrap/v1'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('mejd-public-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
  $updater = Join-Path $stage 'mejd-updater.exe'
  $checksum = Join-Path $stage 'mejd-updater.sha256'
  Invoke-WebRequest -UseBasicParsing -Uri "$base/$target/mejd-updater.exe" -OutFile $updater
  Invoke-WebRequest -UseBasicParsing -Uri "$base/$target/mejd-updater.sha256" -OutFile $checksum
  $expected = ([System.IO.File]::ReadAllText($checksum)).Trim()
  if ($expected -notmatch '^[0-9a-f]{64}$') { throw '安装程序摘要格式错误。' }
  $actual = (Get-FileHash -LiteralPath $updater -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected) { throw '安装程序摘要不匹配。' }
  & $updater --install-latest
  if ($LASTEXITCODE -ne 0) { throw '首次安装失败，原安装保持不变。' }
  & $updater --verify
  if ($LASTEXITCODE -ne 0) { throw '安装后验证失败。' }
} finally {
  Remove-Item Env:MEJD_UPDATE_KEY_BASE64 -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
if ($env:MEJD_INSTALL_HEADLESS -eq '1') { return }
$loadDir = Join-Path $env:LOCALAPPDATA 'mejd-package-update\extension'
Set-Clipboard -Value $loadDir
$chromeCandidates = @()
foreach ($directory in @($env:LOCALAPPDATA, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
  if ($directory) { $chromeCandidates += Join-Path $directory 'Google\Chrome\Application\chrome.exe' }
}
$chrome = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ($chrome) { Start-Process -FilePath $chrome -ArgumentList 'chrome://extensions' }
Write-Host "Chrome 加载目录已复制到剪贴板：$loadDir"
Write-Host '请开启开发者模式，点击“加载已解压的扩展程序”，选该目录。已有同 ID 扩展时先核对其数据，不要直接卸载。'
