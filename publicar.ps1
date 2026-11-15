$ErrorActionPreference = "Stop"
$in = "protocol=https`nhost=github.com`n`n"
$out = $in | git credential fill 2>$null
$user = (($out | Select-String '^username=').ToString() -replace '^username=','')
$token = (($out | Select-String '^password=').ToString() -replace '^password=','')
$headers = @{ Authorization = "token $token"; Accept = "application/vnd.github+json"; "User-Agent" = "setup-9router" }

$repoName = "setup-9router"
$apiBase = "https://api.github.com"

# ja existe?
$existe = $false
try { $null = Invoke-RestMethod -Uri "$apiBase/repos/$user/$repoName" -Headers $headers -TimeoutSec 20; $existe = $true } catch { $existe = $false }

if (-not $existe) {
  $body = @{
    name = $repoName
    description = "Instalador do 9Router (fallback automatico de modelos de IA) + configuracao do OpenCode"
    private = $true
    has_issues = $true
  } | ConvertTo-Json
  $repo = Invoke-RestMethod -Uri "$apiBase/user/repos" -Method Post -Headers $headers -Body $body -TimeoutSec 30
  Write-Host "Repositorio criado: $($repo.html_url)"
} else {
  Write-Host "Repositorio ja existia."
}

# git init + push
$dir = "D:\Projetos Open Code\ferramentas\setup-9router"
Push-Location $dir
try {
  if (-not (Test-Path ".git")) { git init -b main | Out-Null }
  git config user.name "Rafael" | Out-Null
  git config user.email "$user@users.noreply.github.com" | Out-Null
  git add -A | Out-Null
  git -c user.name="Rafael" -c user.email="$user@users.noreply.github.com" commit -m "Instalador do 9Router para Windows + OpenCode" | Out-Null
  $remote = "https://x-access-token:$token@github.com/$user/$repoName.git"
  $temRemote = git remote
  if ($temRemote -contains "origin") { git remote set-url origin $remote } else { git remote add origin $remote }
  git push -u origin main 2>&1 | ForEach-Object { if ($_ -match "error|fatal") { Write-Host $_ -ForegroundColor Red } }
  # limpa o token da URL salva
  git remote set-url origin "https://github.com/$user/$repoName.git"
  Write-Host "Push concluido."
} finally { Pop-Location }

Write-Host "URL: https://github.com/$user/$repoName"
