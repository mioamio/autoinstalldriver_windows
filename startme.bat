@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

set "defaultScriptName=aid_script.ps1"
set "scriptPath="

if "%~1"=="" (
    set "scriptName=%defaultScriptName%"
    echo Используется имя скрипта по умолчанию: %scriptName%
) else (
    set "scriptName=%~1"
    echo Ищем скрипт по имени, переданному как аргумент: %scriptName%
)

echo.

echo Проверка наличия powershell.exe в системном PATH...
where powershell.exe >nul 2>nul
if %errorlevel% neq 0 (
    echo ОШИБКА: powershell.exe не найден в системном PATH. Установите PowerShell или настройте переменные среды.
    goto EndBatchError
)
echo powershell.exe найден.

echo.

echo Начинаем поиск "%scriptName%"...

echo Идет поиск в текущей директории: %cd%
for /f "delims=" %%F in ('dir /s /b "%scriptName%" 2^>nul') do (
    set "scriptPath=%%F"
    goto FoundScript
)

echo.
echo В текущей директории не найден.

for %%D in (C D E F G H I J K) do (
    if exist "%%D:\" (
        echo Идет поиск на диске %%D:\...
        for /f "delims=" %%F in ('dir /s /b "%%D:\%scriptName%" 2^>nul') do (
            set "scriptPath=%%F"
            goto FoundScript
        )
    )
)

goto ScriptNotFound

:FoundScript
if defined scriptPath (
    echo.
    echo Найден скрипт: "%scriptPath%"
    start "" powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%scriptPath%"
    goto EndBatchSuccess
)

:ScriptNotFound
echo.
echo Ошибка: Скрипт "%scriptName%" не найден в текущей директории или на дисках C-K.
goto EndBatchError

:EndBatchSuccess
echo.
echo PowerShell скрипт "%scriptName%" запущен. Пакетный скрипт завершается.
endlocal
exit /b 0

:EndBatchError
echo.
pause
endlocal
exit /b 1
