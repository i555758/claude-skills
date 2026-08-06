@echo off
setlocal enabledelayedexpansion

set "BASE=https://raw.githubusercontent.com/i555758/claude-skills/main/customer-project-status-board"

echo ============================================
echo  Customer Project Status Board - Installer
echo ============================================
echo.

set "COMMANDS=%USERPROFILE%\.claude\commands"
set "SKILLS=%USERPROFILE%\.claude\skills"
set "CLAUDE_DIR=%USERPROFILE%\.claude"

if not exist "%COMMANDS%" mkdir "%COMMANDS%"
if not exist "%SKILLS%" mkdir "%SKILLS%"

echo Instalando arquivos...
echo.

curl -fsSL -o "%COMMANDS%\Customer-Project-Status-Board.md" "%BASE%/Customer-Project-Status-Board.md"
if %errorlevel%==0 (echo   OK  Customer-Project-Status-Board.md) else (echo   ERRO Customer-Project-Status-Board.md)

for %%f in (csb-00-init csb-01-portal csb-02-itsm csb-03-comms csb-04-crossref csb-05-html csb-06-finalize) do (
  curl -fsSL -o "%SKILLS%\%%f.md" "%BASE%/%%f.md"
  if !errorlevel!==0 (echo   OK  %%f.md) else (echo   ERRO %%f.md)
)

echo.
echo ============================================
echo  Configuracao de Pre-requisitos
echo ============================================
echo.
echo Para o comando funcionar sao necessarios 2 passos adicionais:
echo.

rem ---------------------------------------------------------------
rem PASSO 1 — Cookie SSO do Portal HPI
rem ---------------------------------------------------------------
echo [1/2] COOKIE SSO — Portal HPI Cloud Reporting
echo.
echo  O portal HPI requer autenticacao SAP SSO (cookie mysapsso2).
echo.
echo  Como obter:
echo    a) Abra o Chrome e acesse: https://reporting.ondemand.com
echo    b) Faca login com sua conta SAP (I-number + senha)
echo    c) Abra o DevTools (F12) ^> Application ^> Cookies
echo    d) Copie o valor do cookie chamado "mysapsso2"
echo.
echo  Onde salvar:
echo    Adicione a linha abaixo no arquivo:
echo    %CLAUDE_DIR%\settings.json
echo.
echo    Dentro do bloco "env": {
echo      "HPI_COOKIE": "mysapsso2=VALOR_COPIADO_AQUI"
echo    }
echo.
echo  Exemplo de settings.json minimo:
echo    {
echo      "env": {
echo        "HPI_COOKIE": "mysapsso2=AAAAABBBBCCCCC..."
echo      }
echo    }
echo.
echo  NOTA: O cookie expira a cada ~8h. Atualize quando o portal
echo        retornar erro de autenticacao.
echo.
pause

rem ---------------------------------------------------------------
rem PASSO 2 — Permissoes do Teams MCP
rem ---------------------------------------------------------------
echo.
echo [2/2] PERMISSOES MCP — Teams / Graph API (calendario + email)
echo.
echo  As ferramentas do Teams MCP precisam de permissao explicita.
echo  Adicione o bloco abaixo no arquivo:
echo  %CLAUDE_DIR%\settings.local.json
echo.
echo  Dentro de "permissions" ^> "allow":
echo    "mcp__sap-msteams__teams_web_calendar",
echo    "mcp__sap-msteams__teams_web_conversations",
echo    "mcp__sap-msteams__teams_web_messages",
echo    "mcp__sap-msteams__teams_web_my_profile",
echo    "mcp__sap-msteams__teams_web_search_people",
echo    "mcp__sap-msteams__teams_web_find_private_chat"
echo.
echo  Se o arquivo nao existir, crie-o com este conteudo:
echo.
echo    {
echo      "permissions": {
echo        "allow": [
echo          "mcp__sap-msteams__teams_web_calendar",
echo          "mcp__sap-msteams__teams_web_conversations",
echo          "mcp__sap-msteams__teams_web_messages",
echo          "mcp__sap-msteams__teams_web_my_profile",
echo          "mcp__sap-msteams__teams_web_search_people",
echo          "mcp__sap-msteams__teams_web_find_private_chat"
echo        ]
echo      }
echo    }
echo.
echo  DICA: O arquivo settings.local.json fica em:
echo    %CLAUDE_DIR%\settings.local.json
echo.
pause

echo.
echo ============================================
echo  Instalacao concluida!
echo ============================================
echo.
echo  Proximos passos:
echo    1. Configure HPI_COOKIE em settings.json (veja acima)
echo    2. Configure permissoes MCP em settings.local.json (veja acima)
echo    3. Reinicie o Claude Code
echo    4. Execute: /Customer-Project-Status-Board
echo.
pause
