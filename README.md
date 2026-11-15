# setup-9router

Instalador do **9Router** (roteador local de modelos de IA com fallback automático) para Windows, já configurado para o OpenCode.

## O que ele faz

Fica rodando em `127.0.0.1:20128` (só na sua máquina) entre o OpenCode e os provedores de IA. Quando um modelo falha ou acaba a cota, ele **troca sozinho** para o próximo da lista — sem você fazer nada.

Cria 5 listas prontas (combos):

| Combo | Ordem |
|---|---|
| `geral` | Beam -> DeepSeek Flash 1017 -> GLM-5.3-Flash -> North Mini (free) -> Dots (free) -> Lightning (free) |
| `raciocinio` | GLM-5.3 -> Qwen3.8 27B -> Flint (free) -> Dots (free) |
| `velocidade` | DeepSeek Flash -> GLM-5.3-Flash -> Lightning (free) -> North Mini (free) |
| `visao` | Nemotron Super VL (free) -> Nemotron Super VL -> Beam |
| `contexto` | Dots (free) -> Qwen3.8 27B -> GLM-5.3 |

## Pré-requisitos

1. **Node.js LTS** instalado (`node -v` deve responder). Download: https://nodejs.org
2. **Chave do OpenRouter** (`sk-or-v1-...`) — a mesma que o OpenCode usa.

## Instalação (1 comando)

Abra o **PowerShell** e rode (trocando pela sua chave):

```powershell
irm https://raw.githubusercontent.com/rafadjek/setup-9router/main/instalar-9router.ps1 -OutFile "$env:TEMP\instalar-9router.ps1"; & "$env:TEMP\instalar-9router.ps1" -OpenRouterKey "sk-or-v1-SUACHAVE"
```

Se a chave já estiver na variável de ambiente `OPENROUTER_API_KEY`, pode omitir o parâmetro:

```powershell
irm https://raw.githubusercontent.com/rafadjek/setup-9router/main/instalar-9router.ps1 -OutFile "$env:TEMP\instalar-9router.ps1"; & "$env:TEMP\instalar-9router.ps1"
```

O que o instalador faz:

- instala o 9Router em `D:\Projetos Open Code\ferramentas\9router` (dá pra mudar com `-Destino`)
- conecta seu OpenRouter
- cria os 5 combos
- cria a chave local e configura o `opencode.json` (com backup automático)
- ativa o start automático com o Windows (oculto, na bandeja) — desative com `-SemAutostart`

## Depois de instalar

- O 9Router sobe sozinho com o Windows (ícone na bandeja perto do relógio).
- No OpenCode, o modelo ativo fica `9router/geral`. No seletor aparecem também `9router/raciocinio`, `9router/velocidade`, `9router/visao`, `9router/contexto`.
- Painel: http://127.0.0.1:20128 (ver cota, uso e editar combos).

## Se o OpenCode der erro de modelo

O 9Router não está rodando. Soluções:

1. Rodar `iniciar-9router.cmd` na pasta de instalação; **ou**
2. Trocar no seletor para um modelo direto (OpenRouter etc.) e continuar.

## Desligar o start automático

Apague o arquivo:

```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\9router.vbs
```

## Atualizar o 9Router

```powershell
cd "D:\Projetos Open Code\ferramentas\9router"
npm install 9router@latest
```

Depois feche o ícone da bandeja e rode `iniciar-9router.cmd`.

## Segurança

- O servidor escuta **apenas** em `127.0.0.1` (não fica exposto na rede).
- Este repositório **não contém chaves**. A chave do OpenRouter é passada no momento da instalação e fica apenas no seu computador.
- Pacote oficial: https://www.npmjs.com/package/9router (repo: https://github.com/decolua/9router)
