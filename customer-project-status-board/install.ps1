$BASE = "https://raw.githubusercontent.com/i555758/claude-skills/main/customer-project-status-board"
$CLAUDE_DIR = "$env:USERPROFILE\.claude"
$COMMANDS   = "$CLAUDE_DIR\commands"
$SKILLS     = "$CLAUDE_DIR\skills"
$SETTINGS_LOCAL = "$CLAUDE_DIR\settings.local.json"
$README     = "$env:USERPROFILE\Desktop\LEIA-ME-CSB-Configuracao.txt"

Write-Host ""
Write-Host "============================================"
Write-Host " Customer Project Status Board - Installer"
Write-Host "============================================"
Write-Host ""

# --- [1/3] Baixar arquivos de skill ---
Write-Host "[1/3] Instalando arquivos de skill..."
New-Item -ItemType Directory -Force -Path $COMMANDS | Out-Null
New-Item -ItemType Directory -Force -Path $SKILLS   | Out-Null

$files = @{
    "$COMMANDS\Customer-Project-Status-Board.md" = "$BASE/Customer-Project-Status-Board.md"
}
foreach ($name in @("csb-00-init","csb-01-portal","csb-02-itsm","csb-03-comms","csb-04-crossref","csb-05-html","csb-06-finalize")) {
    $files["$SKILLS\$name.md"] = "$BASE/$name.md"
}

foreach ($dest in $files.Keys) {
    try {
        Invoke-WebRequest -Uri $files[$dest] -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host "  OK  $(Split-Path $dest -Leaf)"
    } catch {
        Write-Host "  ERRO $(Split-Path $dest -Leaf): $_"
    }
}

Write-Host ""

# --- [2/3] Configurar permissoes Teams MCP em settings.local.json ---
Write-Host "[2/3] Configurando permissoes Teams MCP..."

$mcpTools = @(
    "mcp__sap-msteams__teams_web_calendar",
    "mcp__sap-msteams__teams_web_conversations",
    "mcp__sap-msteams__teams_web_messages",
    "mcp__sap-msteams__teams_web_my_profile",
    "mcp__sap-msteams__teams_web_search_people",
    "mcp__sap-msteams__teams_web_find_private_chat"
)

$alreadySet = $false
if (Test-Path $SETTINGS_LOCAL) {
    $content = Get-Content $SETTINGS_LOCAL -Raw
    if ($content -match "mcp__sap-msteams__teams_web_calendar") {
        Write-Host "  OK  Permissoes Teams MCP ja configuradas em settings.local.json"
        $alreadySet = $true
    }
}

if (-not $alreadySet) {
    if (Test-Path $SETTINGS_LOCAL) {
        # Arquivo existe mas sem as permissoes — tentar fazer merge via JSON
        try {
            $json = Get-Content $SETTINGS_LOCAL -Raw | ConvertFrom-Json
            if (-not $json.permissions) {
                $json | Add-Member -NotePropertyName "permissions" -NotePropertyValue ([PSCustomObject]@{ allow = @() })
            }
            if (-not $json.permissions.allow) {
                $json.permissions | Add-Member -NotePropertyName "allow" -NotePropertyValue @()
            }
            $existing = @($json.permissions.allow)
            $merged = ($existing + $mcpTools) | Select-Object -Unique
            $json.permissions.allow = $merged
            $json | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS_LOCAL -Encoding UTF8
            Write-Host "  OK  Permissoes Teams MCP adicionadas em settings.local.json"
        } catch {
            Write-Host "  AVISO: Nao foi possivel fazer merge automatico de settings.local.json."
            Write-Host "         Adicione manualmente as entradas mcp__sap-msteams__* em permissions.allow"
        }
    } else {
        # Criar do zero
        $newSettings = [PSCustomObject]@{
            permissions = [PSCustomObject]@{
                allow = $mcpTools
            }
        }
        $newSettings | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS_LOCAL -Encoding UTF8
        Write-Host "  OK  settings.local.json criado com permissoes Teams MCP"
    }
}

Write-Host ""

# --- [3/3] Criar LEIA-ME no Desktop ---
Write-Host "[3/3] Criando instrucoes de configuracao no Desktop..."

$readmeContent = @"
================================================
 Customer Project Status Board - Configuracao
================================================

A instalacao foi concluida. Resta 1 passo manual:
configurar o cookie SSO para acessar o Portal HPI.

-----------------------------------------------
 COOKIE SSO - Portal HPI Cloud Reporting
-----------------------------------------------

1. Abra o Chrome e acesse:
   https://reporting.ondemand.com

2. Faca login com sua conta SAP (I-number + senha)

3. Pressione F12 para abrir o DevTools
   Va em: Application > Storage > Cookies > https://reporting.ondemand.com
   Localize o cookie chamado: mysapsso2
   Copie o valor (campo "Value") -- e uma string longa

4. Abra o arquivo:
   $CLAUDE_DIR\settings.json

   Se nao existir, crie-o com este conteudo:

   {
     "env": {
       "HPI_COOKIE": "mysapsso2=COLE_O_VALOR_AQUI"
     }
   }

   Se ja existir, adicione dentro do bloco "env":
     "HPI_COOKIE": "mysapsso2=COLE_O_VALOR_AQUI"

   Substitua COLE_O_VALOR_AQUI pelo valor copiado no passo 3.

NOTA: O cookie expira a cada ~8h. Quando o portal retornar erro
      de autenticacao, repita os passos 2-4 com o novo valor.

-----------------------------------------------
 Depois de configurar o cookie:
-----------------------------------------------

1. Reinicie o Claude Code
2. Execute o comando: /Customer-Project-Status-Board

================================================
"@

$readmeContent | Set-Content $README -Encoding UTF8
Write-Host "  OK  Instrucoes salvas em: $README"

Write-Host ""
Write-Host "============================================"
Write-Host " Instalacao concluida!"
Write-Host "============================================"
Write-Host ""
Write-Host " Proximos passos:"
Write-Host "   1. Leia o arquivo no seu Desktop:"
Write-Host "      LEIA-ME-CSB-Configuracao.txt"
Write-Host "   2. Configure o cookie HPI conforme as instrucoes"
Write-Host "   3. Reinicie o Claude Code"
Write-Host "   4. Execute: /Customer-Project-Status-Board"
Write-Host ""
