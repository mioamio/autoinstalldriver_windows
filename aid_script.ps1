# --- самоповышение до администратора ---
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = [System.Security.Principal.WindowsPrincipal]::new($currentUser)
if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Попытка перезапуска от имени администратора..."
    try {
        $scriptPath = $MyInvocation.MyCommand.Path
        $arguments = $MyInvocation.BoundParameters.Keys | ForEach-Object {
            $paramName = $_
            $paramValue = $MyInvocation.BoundParameters[$_]
            if ($paramValue -is [System.Management.Automation.SwitchParameter]) {
                if ($paramValue.IsPresent) { "-$paramName" }
            } else {
                "-$paramName `"$($paramValue -replace '"', '`"')`""
            }
        }
        $argumentString = $arguments -join " "
        $processArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $argumentString"
        Start-Process powershell.exe -ArgumentList $processArgs -Verb RunAs -ErrorAction Stop
        Exit 0
    } catch {
        Write-Error "Не удалось перезапустить скрипт от имени администратора. Ошибка: $($_.Exception.Message)"
        Write-Error "Пожалуйста, вручную запустите этот скрипт, щелкнув правой кнопкой мыши и выбрав 'Запуск от имени администратора'."
        Read-Host "Нажмите Enter для выхода..."
        Exit 1
    }
}

Write-Host "Запущен с правами администратора" -ForegroundColor Green
Write-Host ""

$devicesToProcessList = [System.Collections.Generic.List[PSObject]]::new()
$processedInstanceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

Write-Host "1. Поиск устройств с кодом ошибки 28"
try {
    $errorCode28Devices = Get-PnpDevice | Where-Object { $_.ConfigManagerErrorCode -eq 28 } |
                          Select-Object Name, InstanceId, HardwareID, CompatibleID, Class, Status, ConfigManagerErrorCode -ErrorAction Stop
    if ($errorCode28Devices) {
        Write-Host "  Найдено $($errorCode28Devices.Count) устройств с ошибкой 28:" -ForegroundColor Cyan
        foreach ($device in $errorCode28Devices) {
            $deviceNameForOutput = if ([string]::IsNullOrWhiteSpace($device.Name)) { '(Нет имени)' } else { $device.Name }
            Write-Host "    - $deviceNameForOutput ($($device.InstanceId))"
            if ($processedInstanceIds.Add($device.InstanceId)) { $devicesToProcessList.Add($device) }
        }
    } else { Write-Host "  Устройства с ошибкой 28 не найдены." -ForegroundColor Green }
} catch { Write-Warning "  Ошибка при поиске устройств с кодом 28: $($_.Exception.Message)" }
Write-Host ""

Write-Host "2. Поиск видеоадаптеров с базовым драйвером Microsoft"
$genericVideoDevicesFound = @()
try {
    $displayAdapters = Get-PnpDevice -Class Display -ErrorAction Stop |
                       Select-Object Name, InstanceId, HardwareID, CompatibleID, Class, Status, ConfigManagerErrorCode
    foreach ($adapter in $displayAdapters) {
        if (($adapter.Status -eq 'OK' -or $adapter.ConfigManagerErrorCode -eq 0) -and
            ($adapter.Name -like "*Базовый видеоадаптер*" -or $adapter.Name -like "*Microsoft Basic Display Adapter*")) {
            if ($processedInstanceIds.Add($adapter.InstanceId)) {
                $genericVideoDevicesFound += $adapter
                $devicesToProcessList.Add($adapter)
            }
        }
    }
    if ($genericVideoDevicesFound) {
         Write-Host "  Найдено $($genericVideoDevicesFound.Count) видеоадаптеров с базовым драйвером:" -ForegroundColor Magenta
         foreach($dev in $genericVideoDevicesFound){ Write-Host "    - $($dev.Name) ($($dev.InstanceId))" }
    } else { Write-Host "  Видеоадаптеры с базовым драйвером не найдены." -ForegroundColor Green }
} catch { Write-Warning "  Ошибка при поиске видеоадаптеров: $($_.Exception.Message)" }
Write-Host ""

if ($devicesToProcessList.Count -eq 0) {
    Write-Host "Устройства, требующие установки/обновления драйверов, не найдены. Все в порядке." -ForegroundColor Green
    Read-Host "Нажмите Enter для закрытия окна..."
    Exit 0
}
Write-Host "Всего найдено $($devicesToProcessList.Count) устройств для обработки."
Write-Host ""

Write-Host "--- Поиск указанной директории и INF файлов ---" -ForegroundColor Yellow
$driverSearchPaths = @()
$driveLetters = 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'
foreach ($driveLetter in $driveLetters) {
    $path = "$($driveLetter):\ВСТАВИТЬНАЗВАНИЕДИРЕКТОРИИСДРАЙВЕРАМИ"
    if (Test-Path -LiteralPath $path -PathType Container -ErrorAction SilentlyContinue) {
        Write-Host "Найдена директория с драйверами: $path" -ForegroundColor Cyan
        $driverSearchPaths += $path
    }
}
if ($driverSearchPaths.Count -eq 0) {
    Write-Warning "Директория с драйверами не найдена."
    Read-Host "Нажмите Enter для закрытия окна..."
    Exit 1
}

# Собираем все INF файлы
$allInfFiles = @()
foreach ($searchPath in $driverSearchPaths) {
    Write-Host "Поиск *.inf файлов в '$searchPath' (включая подпапки)..."
    try {
        $infFiles = Get-ChildItem -LiteralPath $searchPath -Filter *.inf -Recurse -File -ErrorAction Stop
        if ($infFiles) {
            $allInfFiles += $infFiles
            Write-Host "  Найдено $($infFiles.Count) *.inf файлов в '$searchPath'." -ForegroundColor Gray
        } else { Write-Host "  *.inf файлы не найдены в '$searchPath'." -ForegroundColor Gray }
    } catch { Write-Warning "Ошибка при поиске файлов в '$searchPath': $($_.Exception.Message)" }
}
if ($allInfFiles.Count -eq 0) {
    Write-Warning "В укзанной директории не обнаружено *.inf файлов."
    Read-Host "Нажмите Enter для закрытия окна..."
    Exit 1
}
Write-Host "Всего найдено $($allInfFiles.Count) *.inf файлов для анализа."
Write-Host ""

Write-Host "--- Поиск подходящих драйверов ---" -ForegroundColor Yellow
$installAttempts = [ordered]@{} # [InstanceId] = InfPath

foreach ($device in $devicesToProcessList) {
    $deviceNameForOutput = if ([string]::IsNullOrWhiteSpace($device.Name)) { '(Нет имени)' } else { $device.Name }
    $deviceInstanceId = $device.InstanceId
    Write-Host "--------------------------------------------------"
    Write-Host "Обработка устройства: $deviceNameForOutput ($deviceInstanceId)"
    Write-Host "  Текущий статус: $($device.Status), Код ошибки: $($device.ConfigManagerErrorCode)"

    $deviceHardwareIds = $device.HardwareID | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $deviceCompatibleIds = $device.CompatibleID | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    Write-Host "  Hardware IDs: $($deviceHardwareIds -join ', ')" -ForegroundColor Gray
    if ($deviceCompatibleIds) { Write-Host "  Compatible IDs: $($deviceCompatibleIds -join ', ')" -ForegroundColor DarkGray }

    $foundInfForDevice = $null
    $foundMatchId = $null
    $foundMatchType = $null

    foreach ($hwId in $deviceHardwareIds) {
        Write-Verbose "  Поиск по HardwareID: $hwId"
        foreach ($infFile in $allInfFiles) {
            Write-Verbose "    Проверка файла: $($infFile.FullName)"
            try {
                $infContent = Get-Content -LiteralPath $infFile.FullName -Raw -Encoding Default -ErrorAction Stop
                $escapedId = [regex]::Escape($hwId)
                if ($infContent -match "(?i)$escapedId") {
                    $foundInfForDevice = $infFile.FullName
                    $foundMatchId = $hwId
                    $foundMatchType = "HardwareID"
                    Write-Host "    Найден кандидат по HardwareID!" -ForegroundColor Green
                    Write-Host "    -> INF: $foundInfForDevice"
                    Write-Host "    -> Совпадение по ${foundMatchType}: $foundMatchId"
                    break # Нашли совпадение по этому HWID, прекращаем проверку других INF
                }
            } catch { Write-Warning "    Не удалось прочитать/обработать $($infFile.FullName): $($_.Exception.Message)" }
        }
        if ($foundInfForDevice) { break }
    }

    if (-not $foundInfForDevice -and $deviceCompatibleIds) {
        Write-Host "  По HardwareID совпадений не найдено. Поиск по CompatibleID..." -ForegroundColor Yellow
        foreach ($compId in $deviceCompatibleIds) {
            Write-Verbose "  Поиск по CompatibleID: $compId"
            foreach ($infFile in $allInfFiles) {
                Write-Verbose "    Проверка файла: $($infFile.FullName)"
                try {
                    $infContent = Get-Content -LiteralPath $infFile.FullName -Raw -Encoding Default -ErrorAction Stop
                    $escapedId = [regex]::Escape($compId)
                    if ($infContent -match "(?i)$escapedId") {
                        $foundInfForDevice = $infFile.FullName
                        $foundMatchId = $compId
                        $foundMatchType = "CompatibleID"
                        Write-Host "    Найден кандидат по CompatibleID!" -ForegroundColor DarkCyan
                        Write-Host "    -> INF: $foundInfForDevice"
                        Write-Host "    -> Совпадение по ${foundMatchType}: $foundMatchId"
                        break
                    }
                } catch { Write-Warning "    Не удалось прочитать/обработать $($infFile.FullName): $($_.Exception.Message)" }
            }
            if ($foundInfForDevice) { break }
        }
    }

    if ($foundInfForDevice) {
        $installAttempts[$deviceInstanceId] = $foundInfForDevice
    } else {
        $searchIdsList = ($deviceHardwareIds + $deviceCompatibleIds) -join ', '
        Write-Warning "  Наиболее подходящий драйвер для $deviceNameForOutput (искали по IDs: $searchIdsList) не найден."
    }

}

Write-Host "--------------------------------------------------"
Write-Host ""
if ($installAttempts.Count -gt 0) {
    Write-Host "--- Попытка установки найденных драйверов ($($installAttempts.Count) шт.) ---" -ForegroundColor Yellow
    foreach ($instanceId in $installAttempts.Keys) {
        $infPath = $installAttempts[$instanceId]
        $deviceInfo = Get-PnpDevice -InstanceId $instanceId -ErrorAction SilentlyContinue | Select-Object Name, Class
        $deviceNameForOutput = if ($deviceInfo -and (-not [string]::IsNullOrWhiteSpace($deviceInfo.Name))) { $deviceInfo.Name } else { '(Нет имени)' }

        Write-Host "--------------------------------------------------"
        Write-Host "Установка драйвера для: '$deviceNameForOutput' ($instanceId)"
        Write-Host "Используемый INF файл: $infPath"

        $commandArgs = "/add-driver `"$infPath`" /install"
        Write-Host "Выполнение команды: pnputil.exe $commandArgs"

        try {
            $process = Start-Process pnputil.exe -ArgumentList $commandArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop

            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                Write-Host "  Команда PnPUtil для '$infPath' успешно выполнена (Код возврата: $($process.ExitCode))." -ForegroundColor Green
                if ($process.ExitCode -eq 3010) {
                }

                Write-Host "Ожидание обновления статуса устройства (5 секунд)"
                Start-Sleep -Seconds 5

                $updatedDevice = Get-PnpDevice -InstanceId $instanceId -ErrorAction SilentlyContinue
                if ($updatedDevice) {
                    $updatedDeviceName = if ([string]::IsNullOrWhiteSpace($updatedDevice.Name)) { '(Нет имени)' } else { $updatedDevice.Name }
                    $statusColor = 'Yellow' # По умолчанию
                    $message = "-> Проблема не решена (Код: $($updatedDevice.ConfigManagerErrorCode)). Проверьте Диспетчер Устройств/лог setupapi.dev.log."

                    if ($updatedDevice.ConfigManagerErrorCode -eq 0) {
                        # Если код 0, проверяем, не остался ли базовый видеоадаптер
                        if ($updatedDevice.Class -eq 'Display' -and ($updatedDevice.Name -like "*Базовый видеоадаптер*" -or $updatedDevice.Name -like "*Microsoft Basic Display Adapter*")) {
                            $statusColor = 'Magenta'
                            $message = "-> Драйвер применен (код 0), но имя '$updatedDeviceName' все еще базовое. Лучший драйвер не подошел или требуется перезагрузка."
                        } else {
                            $statusColor = 'Green'
                            $message = "-> Установка/обновление драйвера прошла успешно! Устройство '$updatedDeviceName' готово."
                        }
                    } elseif ($updatedDevice.ConfigManagerErrorCode -eq 28) {
                         $message = "-> Устройство '$updatedDeviceName' все еще сообщает об отсутствии драйвера (Ошибка 28). PnPUtil не смог применить выбранный INF '$infPath'. Возможно, он несовместим."
                    }

                    Write-Host "  Проверка статуса '$updatedDeviceName': Статус=`"$($updatedDevice.Status)`", Код ошибки=`"$($updatedDevice.ConfigManagerErrorCode)`"" -ForegroundColor $statusColor
                    Write-Host "  $message" -ForegroundColor $statusColor

                } else { Write-Warning "  Не удалось получить обновленный статус устройства '$deviceNameForOutput'. Проверьте вручную." }

            } else {
                Write-Warning "  Команда PnPUtil для '$infPath' завершилась с ОШИБКОЙ (Код возврата: $($process.ExitCode)). Установка драйвера не удалась."
                Write-Warning "  Возможные причины: INF поврежден, не подписан/несовместим, конфликт и т.д."
                Write-Warning "  Рекомендуется проверить лог: C:\Windows\INF\setupapi.dev.log"
            }
        } catch {
            Write-Error "  Критическая ошибка при запуске PnPUtil для '$infPath': $($_.Exception.Message)"
            Write-Error "  Установка для этого устройства прервана."
        }
        Write-Host "--------------------------------------------------"

    }
} else {
    Write-Host "--- Результат ---" -ForegroundColor Yellow
    Write-Host "Не было найдено подходящих INF файлов для установки на проблемные устройства (поиск с приоритетом HardwareID)."
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          Работа скрипта завершена" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Read-Host "Нажмите Enter для закрытия окна..."