$ErrorActionPreference = "Stop"
$in = "protocol=https`nhost=github.com`n`n"
$out = $in | git credential fill 2>$null
$token = (($out | Select-String '^password=').ToString() -replace '^password=','')
$h = @{ Authorization = "token $token"; Accept = "application/vnd.github+json"; "User-Agent" = "setup-9router" }

# 1. repo publico (nao contem chaves)
$body = @{ private = $false } | ConvertTo-Json
$null = Invoke-RestMethod -Uri "https://api.github.com/repos/rafadjek/setup-9router" -Method Patch -Headers $h -Body $body -TimeoutSec 30
Write-Host "Repositorio agora e publico."

# 2. remove script auxiliar do repo
$dir = "D:\Projetos Open Code\ferramentas\setup-9router"
Push-Location $dir
try {
  "publicar.ps1" | Set-Content ".gitignore" -Encoding ASCII
  git rm --cached publicar.ps1 2>$null | Out-Null
  git add -A | Out-Null
  git commit -m "Remove script auxiliar e adiciona gitignore" | Out-Null
  $remote = "https://x-access-token:$token@github.com/rafadjek/setup-9router.git"
  git remote set-url origin $remote
  git push origin main 2>&1 | Out-Null
  git remote set-url origin "https://github.com/rafadjek/setup-9router.git"
  Write-Host "Repo atualizado."
} finally { Pop-Location }
