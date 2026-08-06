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
set "SETTINGS=%CLAUDE_DIR%\settings.json"
set "SETTINGS_LOCAL=%CLAUDE_DIR%\settings.local.json"
set "README=%USERPROFILE%\Desktop\LEIA-ME-CSB-Configuracao.txt"

if not exist "%COMMANDS%" mkdir "%COMMANDS%"
if not exist "%SKILLS%" mkdir "%SKILLS%"

echo [1/3] Instalando arquivos de skill...
echo.

curl -fsSL -o "%COMMANDS%\Customer-Project-Status-Board.md" "%BASE%/Customer-Project-Status-Board.md"
if %errorlevel%==0 (echo   OK  Customer-Project-Status-Board.md) else (echo   ERRO Customer-Project-Status-Board.md)

for %%f in (csb-00-init csb-01-portal csb-02-itsm csb-03-comms csb-04-crossref csb-05-html csb-06-finalize) do (
  curl -fsSL -o "%SKILLS%\%%f.md" "%BASE%/%%f.md"
  if !errorlevel!==0 (echo   OK  %%f.md) else (echo   ERRO %%f.md)
)

echo.

rem ---------------------------------------------------------------
rem [2/3] Configurar permissoes Teams MCP em settings.local.json
rem ---------------------------------------------------------------
echo [2/3] Configurando permissoes Teams MCP...

set "MCP_PERMS=0"
if exist "%SETTINGS_LOCAL%" (
  findstr /C:"mcp__sap-msteams__teams_web_calendar" "%SETTINGS_LOCAL%" >nul 2>&1
  if !errorlevel!==0 (
    echo   OK  Permissoes Teams MCP ja configuradas
    set "MCP_PERMS=1"
  )
)

if !MCP_PERMS!==0 (
  if not exist "%SETTINGS_LOCAL%" (
    rem Criar settings.local.json do zero
    (
      echo {
      echo   "permissions": {
      echo     "allow": [
      echo       "mcp__sap-msteams__teams_web_calendar",
      echo       "mcp__sap-msteams__teams_web_conversations",
      echo       "mcp__sap-msteams__teams_web_messages",
      echo       "mcp__sap-msteams__teams_web_my_profile",
      echo       "mcp__sap-msteams__teams_web_search_people",
      echo       "mcp__sap-msteams__teams_web_find_private_chat"
      echo     ]
      echo   }
      echo }
    ) > "%SETTINGS_LOCAL%"
    echo   OK  settings.local.json criado com permissoes Teams MCP
  ) else (
    echo   AVISO: settings.local.json ja existe mas nao tem permissoes Teams.
    echo          Adicione manualmente dentro de "permissions" ^> "allow":
    echo            "mcp__sap-msteams__teams_web_calendar",
    echo            "mcp__sap-msteams__teams_web_conversations",
    echo            "mcp__sap-msteams__teams_web_messages",
    echo            "mcp__sap-msteams__teams_web_my_profile",
    echo            "mcp__sap-msteams__teams_web_search_people",
    echo            "mcp__sap-msteams__teams_web_find_private_chat"
  )
)

echo.

rem ---------------------------------------------------------------
rem [3/3] Criar arquivo LEIA-ME no Desktop com instrucoes do cookie
rem ---------------------------------------------------------------
echo [3/3] Criando instrucoes para cookie SSO no Desktop...

(
  echo ================================================
  echo  Customer Project Status Board - Configuracao
  echo ================================================
  echo.
  echo A instalacao foi concluida. Reste apenas 1 passo manual:
  echo configurar o cookie SSO para acessar o Portal HPI.
  echo.
  echo -----------------------------------------------
  echo  COOKIE SSO - Portal HPI Cloud Reporting
  echo -----------------------------------------------
  echo.
  echo 1. Abra o Chrome e acesse:
  echo    https://reporting.ondemand.com
  echo.
  echo 2. Faca login com sua conta SAP (I-number + senha)
  echo.
  echo 3. Pressione F12 para abrir o DevTools
  echo    Va em: Application ^> Storage ^> Cookies ^> https://reporting.ondemand.com
  echo    Localize o cookie chamado: mysapsso2
  echo    Copie o valor (campo "Value") — e uma string longa
  echo.
  echo 4. Abra o arquivo:
  echo    %SETTINGS%
  echo.
  echo    Se nao existir, crie-o. Adicione (ou inclua no bloco "env" existente):
  echo.
  echo    {
  echo      "env": {
  echo        "HPI_COOKIE": "mysapsso2=COLE_O_VALOR_AQUI"
  echo      }
  echo    }
  echo.
  echo    Substitua COLE_O_VALOR_AQUI pelo valor copiado no passo 3.
  echo.
  echo NOTA: O cookie expira a cada ~8h. Quando o portal retornar erro
  echo       de autenticacao, repita os passos 2-4 com o novo valor.
  echo.
  echo -----------------------------------------------
  echo  Depois de configurar o cookie:
  echo -----------------------------------------------
  echo.
  echo 1. Reinicie o Claude Code
  echo 2. Execute o comando: /Customer-Project-Status-Board
  echo.
  echo ================================================
) > "%README%"

echo   OK  Instrucoes salvas em: %README%
echo.

echo ============================================
echo  Instalacao concluida!
echo ============================================
echo.
echo  Proximos passos:
echo    1. Leia o arquivo no seu Desktop:
echo       LEIA-ME-CSB-Configuracao.txt
echo    2. Configure o cookie HPI conforme as instrucoes
echo    3. Reinicie o Claude Code
echo    4. Execute: /Customer-Project-Status-Board
echo.
pause
