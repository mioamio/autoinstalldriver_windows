@echo off
chcp 65001 > nul
setlocal

set "scriptName=aid_script.ps1"
set "scriptPath="

echo Поиск %scriptName%...

for %%D in (C D E F G H I J K) do (
    if exist "%%D:\" (
        for /f "delims=" %%F in ('dir /s /b "%%D:\%scriptName%" 2^>nul') do (
            set "scriptPath=%%F"
            goto FoundScript
        )
    )
)

goto ScriptNotFound

:FoundScript
if defined scriptPath (
    echo Найден скрипт: "%scriptPath%"
    powershell.exe -NoLogo -ExecutionPolicy Bypass -NoExit -File "%scriptPath%"
) else (
    echo ОШИБКА: Не удалось определить путь к скрипту после поиска.
)
goto EndBatch

:ScriptNotFound
echo Ошибка: Скрипт %scriptName% не найден на дисках C-K.
goto EndBatch

:EndBatch
echo.
pause
endlocal