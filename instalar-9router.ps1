#requires -Version 5.1
<#
  Instalador do 9Router para Windows + configuracao do OpenCode.

  Uso:
    .\instalar-9router.ps1 -OpenRouterKey "sk-or-v1-..."
    .\instalar-9router.ps1                 (usa $env:OPENROUTER_API_KEY)

  Opcoes:
    -Destino <pasta>    pasta de instalacao (padrao: D:\Projetos Open Code\ferramentas\9router)
    -SemAutostart       nao cria o start automatico com o Windows
#>
param(
  [string]$OpenRouterKey = $env:OPENROUTER_API_KEY,
  [string]$Destino = "D:\Projetos Open Code\ferramentas\9router",
  [switch]$SemAutostart
)

$ErrorActionPreference = "Stop"
$BASE = "http://127.0.0.1:20128"

function Info($msg) { Write-Host "[9router] $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "[ok] $msg" -ForegroundColor Green }
function Aviso($m)  { Write-Host "[aviso] $m" -ForegroundColor Yellow }
function Falha($m)  { Write-Host "[erro] $m" -ForegroundColor Red; exit 1 }

# ---------- 1. pre-requisitos ----------
try { $null = node -v } catch { Falha "Node.js nao encontrado. Instale o LTS em https://nodejs.org e rode de novo." }
try { $null = npm -v }  catch { Falha "npm nao encontrado (instale o Node.js LTS)." }

if (-not $OpenRouterKey) {
  Info "Chave do OpenRouter nao informada."
  $OpenRouterKey = Read-Host "Cole a chave (sk-or-v1-...)"
}
if (-not $OpenRouterKey) { Falha "Chave do OpenRouter e obrigatoria." }

# ---------- 2. instalacao ----------
Info "Instalando em: $Destino"
New-Item -ItemType Directory -Force -Path $Destino | Out-Null
Push-Location $Destino
try {
  if (-not (Test-Path "package.json")) { npm init -y | Out-Null }
  npm install 9router | Out-Null
  # libera o script de pos-instalacao (runtime sqlite/tray)
  npm install-scripts approve 9router 2>$null | Out-Null
  npm rebuild 9router 2>$null | Out-Null
} finally { Pop-Location }
Ok "9Router instalado."

# ---------- 3. script de inicio ----------
$cmd = @"
@echo off
rem Inicia o 9Router (fallback automatico de modelos) - rode ANTES de abrir o OpenCode
title 9Router
cd /d "%~dp0"
node node_modules\9router\cli.js --host 127.0.0.1 --no-browser --skip-update
pause
"@
Set-Content -Path (Join-Path $Destino "iniciar-9router.cmd") -Value $cmd -Encoding ASCII

# ---------- 4. subir o servidor ----------
$cli = Join-Path $Destino "node_modules\9router\cli.js"
$rodando = $false
try { $h = Invoke-RestMethod -Uri "$BASE/api/health" -TimeoutSec 3; if ($h.ok) { $rodando = $true } } catch {}
if (-not $rodando) {
  Info "Iniciando o servidor..."
  Start-Process -FilePath "node" -ArgumentList "`"$cli`" --host 127.0.0.1 --no-browser --skip-update" -WorkingDirectory $Destino -WindowStyle Hidden
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    try { $h = Invoke-RestMethod -Uri "$BASE/api/health" -TimeoutSec 2; if ($h.ok) { break } } catch {}
  }
}
try { $h = Invoke-RestMethod -Uri "$BASE/api/health" -TimeoutSec 5 } catch { Falha "Servidor nao respondeu em $BASE. Rode iniciar-9router.cmd e veja o erro." }
Ok "Servidor no ar: $BASE"

# ---------- 5. token local (CLI) ----------
$dataDir = Join-Path $env:APPDATA "9router"
for ($i = 0; $i -lt 30; $i++) {
  if ((Test-Path (Join-Path $dataDir "machine-id")) -and (Test-Path (Join-Path $dataDir "auth\cli-secret"))) { break }
  Start-Sleep -Seconds 1
}
$machineId = (Get-Content (Join-Path $dataDir "machine-id") -Raw).Trim()
$cliSecret = (Get-Content (Join-Path $dataDir "auth\cli-secret") -Raw).Trim()
$sha = [System.Security.Cryptography.SHA256]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes($machineId + "9r-cli-auth" + $cliSecret)
$hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
$TOKEN = $hash.Substring(0, 16)
$H = @{ "x-9r-cli-token" = $TOKEN; "Content-Type" = "application/json" }

# ---------- 6. conectar OpenRouter ----------
try {
  $provs = Invoke-RestMethod -Uri "$BASE/api/providers" -Headers $H
  $jaTem = $provs.connections | Where-Object { $_.provider -eq "openrouter" }
} catch { $jaTem = $null }

if ($jaTem) { Aviso "OpenRouter ja conectado, mantendo." }
else {
  try {
    $body = @{ provider = "openrouter"; name = "OpenRouter"; apiKey = $OpenRouterKey } | ConvertTo-Json
    $null = Invoke-RestMethod -Uri "$BASE/api/providers" -Method Post -Headers $H -Body $body
    Ok "OpenRouter conectado."
  } catch { Falha "Nao consegui conectar o OpenRouter: $($_.Exception.Message)" }
}

# ---------- 7. combos ----------
$combos = @(
  @{ name = "geral"; models = @(
      "openrouter/reflection/beam-1.0-501b-a23b",
      "openrouter/deepseek/deepseek-v4.1-flash-1017",
      "openrouter/z-ai/glm-5.3-flash",
      "openrouter/cohere/north-mini-code:free",
      "openrouter/dots-studio/dots-3-note-preview:free",
      "openrouter/nvidia/nemotron-3.5-lightning:free") },
  @{ name = "raciocinio"; models = @(
      "openrouter/z-ai/glm-5.3",
      "openrouter/qwen/qwen3.8-27b",
      "openrouter/recursive/flint-v1.0:free",
      "openrouter/dots-studio/dots-3-note-preview:free") },
  @{ name = "velocidade"; models = @(
      "openrouter/deepseek/deepseek-v4.1-flash",
      "openrouter/z-ai/glm-5.3-flash",
      "openrouter/nvidia/nemotron-3.5-lightning:free",
      "openrouter/cohere/north-mini-code:free") },
  @{ name = "visao"; models = @(
      "openrouter/nvidia/nemotron-3.5-super-vl:free",
      "openrouter/nvidia/nemotron-3.5-super-vl",
      "openrouter/reflection/beam-1.0-501b-a23b") },
  @{ name = "contexto"; models = @(
      "openrouter/dots-studio/dots-3-note-preview:free",
      "openrouter/qwen/qwen3.8-27b",
      "openrouter/z-ai/glm-5.3") }
)
$existentes = @()
try { $existentes = (Invoke-RestMethod -Uri "$BASE/api/combos" -Headers $H).combos | ForEach-Object { $_.name } } catch {}
foreach ($c in $combos) {
  if ($existentes -contains $c.name) { Aviso "Combo '$($c.name)' ja existe, mantendo."; continue }
  try {
    $null = Invoke-RestMethod -Uri "$BASE/api/combos" -Method Post -Headers $H -Body ($c | ConvertTo-Json -Depth 4)
    Ok "Combo '$($c.name)' criado."
  } catch { Aviso "Falha ao criar combo '$($c.name)': $($_.Exception.Message)" }
}

# ---------- 8. chave do endpoint ----------
$key = $null
try {
  $keys = (Invoke-RestMethod -Uri "$BASE/api/keys" -Headers $H).keys
  $key = ($keys | Where-Object { $_.name -eq "opencode" } | Select-Object -First 1).key
} catch {}
if (-not $key) {
  try {
    $novo = Invoke-RestMethod -Uri "$BASE/api/keys" -Method Post -Headers $H -Body (@{ name = "opencode" } | ConvertTo-Json)
    $key = $novo.key
    Ok "Chave do endpoint criada."
  } catch { Falha "Nao consegui criar a chave do endpoint: $($_.Exception.Message)" }
}

# ---------- 9. configurar OpenCode ----------
$ocDir = Join-Path $env:USERPROFILE ".config\opencode"
$ocFile = Join-Path $ocDir "opencode.json"
if (Test-Path $ocFile) {
  Copy-Item $ocFile "$ocFile.bak-9router" -Force
  Ok "Backup do opencode.json salvo em $ocFile.bak-9router"
}
$body = @{
  baseUrl = "$BASE/api/v1"; apiKey = $key
  models = @("geral", "raciocinio", "velocidade", "visao", "contexto")
  activeModel = "geral"; subagentModel = "geral"
} | ConvertTo-Json -Depth 4
try {
  $null = Invoke-RestMethod -Uri "$BASE/api/cli-tools/opencode-settings" -Method Post -Headers $H -Body $body
  Ok "OpenCode configurado (modelo ativo: 9router/geral)."
} catch { Aviso "Nao consegui configurar o OpenCode automaticamente: $($_.Exception.Message)" }

# ---------- 10. autostart ----------
if (-not $SemAutostart) {
  $startup = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
  New-Item -ItemType Directory -Force -Path $startup | Out-Null
  $nodeExe = (Get-Command node).Source
  $vbs = "Set WshShell = CreateObject(""WScript.Shell"")" + "`r`n" +
         "WshShell.Run """"""$nodeExe"""""" """"""$cli"""""" --tray --host 127.0.0.1 --skip-update"", 0, False" + "`r`n"
  Set-Content -Path (Join-Path $startup "9router.vbs") -Value $vbs -Encoding ASCII
  Ok "Start automatico com o Windows ativado (oculto, na bandeja)."
}

Write-Host ""
Ok "Instalacao concluida!"
Write-Host ""
Write-Host "  Painel:      $BASE" -ForegroundColor White
Write-Host "  Pasta:       $Destino" -ForegroundColor White
Write-Host "  OpenCode:    modelo ativo 9router/geral" -ForegroundColor White
Write-Host "  Manual:      $Destino\iniciar-9router.cmd" -ForegroundColor White
Write-Host ""
Write-Host "  Dica: se o OpenCode der erro de modelo, o 9Router nao esta rodando." -ForegroundColor Yellow
