param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDir,
  [Parameter(Mandatory = $true)]
  [string]$Repository,
  [Parameter(Mandatory = $true)]
  [string]$AssetName
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Stop-Crm {
  Get-Process -Name 'CleanPlaceCRM' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

try {
  $installPath = [System.IO.Path]::GetFullPath($InstallDir)
  if (-not (Test-Path -LiteralPath $installPath -PathType Container)) {
    throw "Папка приложения не найдена: $installPath"
  }

  Write-Host 'Проверяю последнюю версию CRM…'
  $headers = @{ 'User-Agent' = 'CleanPlaceCRM-Updater' }
  $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/latest"
  $asset = @($release.assets | Where-Object { $_.name -eq $AssetName }) | Select-Object -First 1
  if ($null -eq $asset) {
    throw "В последнем выпуске $($release.tag_name) нет файла $AssetName."
  }

  $workPath = Join-Path ([System.IO.Path]::GetTempPath()) ("CleanPlaceCRM-" + [guid]::NewGuid())
  $zipPath = Join-Path $workPath $AssetName
  $unpackPath = Join-Path $workPath 'unpacked'
  New-Item -ItemType Directory -Path $unpackPath -Force | Out-Null

  Write-Host "Скачиваю $($release.name)…"
  Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $zipPath
  Expand-Archive -LiteralPath $zipPath -DestinationPath $unpackPath -Force

  $packageRoot = Get-ChildItem -LiteralPath $unpackPath -Directory | Select-Object -First 1
  if ($null -eq $packageRoot) {
    throw 'В архиве не найдена папка приложения.'
  }

  Write-Host 'Закрываю CRM и устанавливаю обновление…'
  Stop-Crm
  Copy-Item -Path (Join-Path $packageRoot.FullName '*') -Destination $installPath -Recurse -Force

  $app = Join-Path $installPath 'CleanPlaceCRM.exe'
  if (-not (Test-Path -LiteralPath $app -PathType Leaf)) {
    throw 'После обновления не найден CleanPlaceCRM.exe.'
  }
  Remove-Item -LiteralPath $workPath -Recurse -Force -ErrorAction SilentlyContinue
  Start-Process -FilePath $app
  Write-Host "Готово: установлена версия $($release.tag_name)."
  Start-Sleep -Seconds 2
  exit 0
} catch {
  Write-Host "`nОбновление не выполнено: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Проверьте интернет и повторите попытку.'
  Read-Host 'Нажмите Enter, чтобы закрыть окно'
  exit 1
}
