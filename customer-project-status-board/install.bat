@echo off
setlocal enabledelayedexpansion

set "BASE=https://raw.githubusercontent.com/i555758/claude-skills/main/customer-project-status-board"

echo ============================================
echo  Customer Project Status Board - Installer
echo ============================================
echo.

set "COMMANDS=%USERPROFILE%\.claude\commands"
set "SKILLS=%USERPROFILE%\.claude\skills"

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
echo Concluido! Reinicie o Claude Code e execute /Customer-Project-Status-Board
echo.
pause
