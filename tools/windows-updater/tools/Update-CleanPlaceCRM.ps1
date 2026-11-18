param(
  [Parameter(Mandatory = $true)]
  [string]$InstallDir,
  [Parameter(Mandatory = $true)]
  [string]$Repository,
  [Parameter(Mandatory = $true)]
  [string]$AssetPrefix
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Stop-Crm {
  Get-Process -Name 'CleanPlaceCRM' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

function Resolve-InstallPath {
  param([string]$SuggestedPath)

  $candidate = [System.IO.Path]::GetFullPath($SuggestedPath)
  if (Test-Path -LiteralPath (Join-Path $candidate 'CleanPlaceCRM.exe') -PathType Leaf) {
    return $candidate
  }

  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = 'Выберите папку, где находится CleanPlaceCRM.exe'
  $dialog.ShowNewFolderButton = $false
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    throw 'Папка CRM не выбрана.'
  }

  $selected = $dialog.SelectedPath
  if (-not (Test-Path -LiteralPath (Join-Path $selected 'CleanPlaceCRM.exe') -PathType Leaf)) {
    throw 'В выбранной папке не найден CleanPlaceCRM.exe.'
  }
  return $selected
}

try {
  $installPath = Resolve-InstallPath -SuggestedPath $InstallDir

  Write-Host 'Проверяю последнюю версию CRM…'
  $headers = @{ 'User-Agent' = 'CleanPlaceCRM-Updater' }
  $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repository/releases/latest"
  $asset = @($release.assets | Where-Object {
    $_.name -like "$AssetPrefix*.zip"
  }) | Select-Object -First 1
  if ($null -eq $asset) {
    throw "В последнем выпуске $($release.tag_name) нет Windows-архива CRM."
  }

  $workPath = Join-Path ([System.IO.Path]::GetTempPath()) ("CleanPlaceCRM-" + [guid]::NewGuid())
  $zipPath = Join-Path $workPath $asset.name
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
