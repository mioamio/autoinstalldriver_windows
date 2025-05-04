# --- ������������� �� �������������� ---
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = [System.Security.Principal.WindowsPrincipal]::new($currentUser)
if (-not $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "������� ����������� �� ����� ��������������..."
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
        Write-Error "�� ������� ������������� ������ �� ����� ��������������. ������: $($_.Exception.Message)"
        Write-Error "����������, ������� ��������� ���� ������, ������� ������ ������� ���� � ������ '������ �� ����� ��������������'."
        Read-Host "������� Enter ��� ������..."
        Exit 1
    }
}

Write-Host "������� � ������� ��������������" -ForegroundColor Green
Write-Host ""

$devicesToProcessList = [System.Collections.Generic.List[PSObject]]::new()
$processedInstanceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

Write-Host "1. ����� ��������� � ����� ������ 28"
try {
    $errorCode28Devices = Get-PnpDevice | Where-Object { $_.ConfigManagerErrorCode -eq 28 } |
                          Select-Object Name, InstanceId, HardwareID, CompatibleID, Class, Status, ConfigManagerErrorCode -ErrorAction Stop
    if ($errorCode28Devices) {
        Write-Host "  ������� $($errorCode28Devices.Count) ��������� � ������� 28:" -ForegroundColor Cyan
        foreach ($device in $errorCode28Devices) {
            $deviceNameForOutput = if ([string]::IsNullOrWhiteSpace($device.Name)) { '(��� �����)' } else { $device.Name }
            Write-Host "    - $deviceNameForOutput ($($device.InstanceId))"
            if ($processedInstanceIds.Add($device.InstanceId)) { $devicesToProcessList.Add($device) }
        }
    } else { Write-Host "  ���������� � ������� 28 �� �������." -ForegroundColor Green }
} catch { Write-Warning "  ������ ��� ������ ��������� � ����� 28: $($_.Exception.Message)" }
Write-Host ""

Write-Host "2. ����� �������������� � ������� ��������� Microsoft"
$genericVideoDevicesFound = @()
try {
    $displayAdapters = Get-PnpDevice -Class Display -ErrorAction Stop |
                       Select-Object Name, InstanceId, HardwareID, CompatibleID, Class, Status, ConfigManagerErrorCode
    foreach ($adapter in $displayAdapters) {
        if (($adapter.Status -eq 'OK' -or $adapter.ConfigManagerErrorCode -eq 0) -and
            ($adapter.Name -like "*������� ������������*" -or $adapter.Name -like "*Microsoft Basic Display Adapter*")) {
            if ($processedInstanceIds.Add($adapter.InstanceId)) {
                $genericVideoDevicesFound += $adapter
                $devicesToProcessList.Add($adapter)
            }
        }
    }
    if ($genericVideoDevicesFound) {
         Write-Host "  ������� $($genericVideoDevicesFound.Count) �������������� � ������� ���������:" -ForegroundColor Magenta
         foreach($dev in $genericVideoDevicesFound){ Write-Host "    - $($dev.Name) ($($dev.InstanceId))" }
    } else { Write-Host "  ������������� � ������� ��������� �� �������." -ForegroundColor Green }
} catch { Write-Warning "  ������ ��� ������ ��������������: $($_.Exception.Message)" }
Write-Host ""

if ($devicesToProcessList.Count -eq 0) {
    Write-Host "����������, ��������� ���������/���������� ���������, �� �������. ��� � �������." -ForegroundColor Green
    Read-Host "������� Enter ��� �������� ����..."
    Exit 0
}
Write-Host "����� ������� $($devicesToProcessList.Count) ��������� ��� ���������."
Write-Host ""

Write-Host "--- ����� ��������� ���������� � INF ������ ---" -ForegroundColor Yellow
$driverSearchPaths = @()
$driveLetters = 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'
foreach ($driveLetter in $driveLetters) {
    $path = "$($driveLetter):\�������������������������������������"
    if (Test-Path -LiteralPath $path -PathType Container -ErrorAction SilentlyContinue) {
        Write-Host "������� ���������� � ����������: $path" -ForegroundColor Cyan
        $driverSearchPaths += $path
    }
}
if ($driverSearchPaths.Count -eq 0) {
    Write-Warning "���������� � ���������� �� �������."
    Read-Host "������� Enter ��� �������� ����..."
    Exit 1
}

# �������� ��� INF �����
$allInfFiles = @()
foreach ($searchPath in $driverSearchPaths) {
    Write-Host "����� *.inf ������ � '$searchPath' (������� ��������)..."
    try {
        $infFiles = Get-ChildItem -LiteralPath $searchPath -Filter *.inf -Recurse -File -ErrorAction Stop
        if ($infFiles) {
            $allInfFiles += $infFiles
            Write-Host "  ������� $($infFiles.Count) *.inf ������ � '$searchPath'." -ForegroundColor Gray
        } else { Write-Host "  *.inf ����� �� ������� � '$searchPath'." -ForegroundColor Gray }
    } catch { Write-Warning "������ ��� ������ ������ � '$searchPath': $($_.Exception.Message)" }
}
if ($allInfFiles.Count -eq 0) {
    Write-Warning "� �������� ���������� �� ���������� *.inf ������."
    Read-Host "������� Enter ��� �������� ����..."
    Exit 1
}
Write-Host "����� ������� $($allInfFiles.Count) *.inf ������ ��� �������."
Write-Host ""

Write-Host "--- ����� ���������� ��������� ---" -ForegroundColor Yellow
$installAttempts = [ordered]@{} # [InstanceId] = InfPath

foreach ($device in $devicesToProcessList) {
    $deviceNameForOutput = if ([string]::IsNullOrWhiteSpace($device.Name)) { '(��� �����)' } else { $device.Name }
    $deviceInstanceId = $device.InstanceId
    Write-Host "--------------------------------------------------"
    Write-Host "��������� ����������: $deviceNameForOutput ($deviceInstanceId)"
    Write-Host "  ������� ������: $($device.Status), ��� ������: $($device.ConfigManagerErrorCode)"

    $deviceHardwareIds = $device.HardwareID | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $deviceCompatibleIds = $device.CompatibleID | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    Write-Host "  Hardware IDs: $($deviceHardwareIds -join ', ')" -ForegroundColor Gray
    if ($deviceCompatibleIds) { Write-Host "  Compatible IDs: $($deviceCompatibleIds -join ', ')" -ForegroundColor DarkGray }

    $foundInfForDevice = $null
    $foundMatchId = $null
    $foundMatchType = $null

    foreach ($hwId in $deviceHardwareIds) {
        Write-Verbose "  ����� �� HardwareID: $hwId"
        foreach ($infFile in $allInfFiles) {
            Write-Verbose "    �������� �����: $($infFile.FullName)"
            try {
                $infContent = Get-Content -LiteralPath $infFile.FullName -Raw -Encoding Default -ErrorAction Stop
                $escapedId = [regex]::Escape($hwId)
                if ($infContent -match "(?i)$escapedId") {
                    $foundInfForDevice = $infFile.FullName
                    $foundMatchId = $hwId
                    $foundMatchType = "HardwareID"
                    Write-Host "    ������ �������� �� HardwareID!" -ForegroundColor Green
                    Write-Host "    -> INF: $foundInfForDevice"
                    Write-Host "    -> ���������� �� ${foundMatchType}: $foundMatchId"
                    break # ����� ���������� �� ����� HWID, ���������� �������� ������ INF
                }
            } catch { Write-Warning "    �� ������� ���������/���������� $($infFile.FullName): $($_.Exception.Message)" }
        }
        if ($foundInfForDevice) { break }
    }

    if (-not $foundInfForDevice -and $deviceCompatibleIds) {
        Write-Host "  �� HardwareID ���������� �� �������. ����� �� CompatibleID..." -ForegroundColor Yellow
        foreach ($compId in $deviceCompatibleIds) {
            Write-Verbose "  ����� �� CompatibleID: $compId"
            foreach ($infFile in $allInfFiles) {
                Write-Verbose "    �������� �����: $($infFile.FullName)"
                try {
                    $infContent = Get-Content -LiteralPath $infFile.FullName -Raw -Encoding Default -ErrorAction Stop
                    $escapedId = [regex]::Escape($compId)
                    if ($infContent -match "(?i)$escapedId") {
                        $foundInfForDevice = $infFile.FullName
                        $foundMatchId = $compId
                        $foundMatchType = "CompatibleID"
                        Write-Host "    ������ �������� �� CompatibleID!" -ForegroundColor DarkCyan
                        Write-Host "    -> INF: $foundInfForDevice"
                        Write-Host "    -> ���������� �� ${foundMatchType}: $foundMatchId"
                        break
                    }
                } catch { Write-Warning "    �� ������� ���������/���������� $($infFile.FullName): $($_.Exception.Message)" }
            }
            if ($foundInfForDevice) { break }
        }
    }

    if ($foundInfForDevice) {
        $installAttempts[$deviceInstanceId] = $foundInfForDevice
    } else {
        $searchIdsList = ($deviceHardwareIds + $deviceCompatibleIds) -join ', '
        Write-Warning "  �������� ���������� ������� ��� $deviceNameForOutput (������ �� IDs: $searchIdsList) �� ������."
    }

}

Write-Host "--------------------------------------------------"
Write-Host ""
if ($installAttempts.Count -gt 0) {
    Write-Host "--- ������� ��������� ��������� ��������� ($($installAttempts.Count) ��.) ---" -ForegroundColor Yellow
    foreach ($instanceId in $installAttempts.Keys) {
        $infPath = $installAttempts[$instanceId]
        $deviceInfo = Get-PnpDevice -InstanceId $instanceId -ErrorAction SilentlyContinue | Select-Object Name, Class
        $deviceNameForOutput = if ($deviceInfo -and (-not [string]::IsNullOrWhiteSpace($deviceInfo.Name))) { $deviceInfo.Name } else { '(��� �����)' }

        Write-Host "--------------------------------------------------"
        Write-Host "��������� �������� ���: '$deviceNameForOutput' ($instanceId)"
        Write-Host "������������ INF ����: $infPath"

        $commandArgs = "/add-driver `"$infPath`" /install"
        Write-Host "���������� �������: pnputil.exe $commandArgs"

        try {
            $process = Start-Process pnputil.exe -ArgumentList $commandArgs -Wait -PassThru -NoNewWindow -ErrorAction Stop

            if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                Write-Host "  ������� PnPUtil ��� '$infPath' ������� ��������� (��� ��������: $($process.ExitCode))." -ForegroundColor Green
                if ($process.ExitCode -eq 3010) {
                }

                Write-Host "�������� ���������� ������� ���������� (5 ������)"
                Start-Sleep -Seconds 5

                $updatedDevice = Get-PnpDevice -InstanceId $instanceId -ErrorAction SilentlyContinue
                if ($updatedDevice) {
                    $updatedDeviceName = if ([string]::IsNullOrWhiteSpace($updatedDevice.Name)) { '(��� �����)' } else { $updatedDevice.Name }
                    $statusColor = 'Yellow' # �� ���������
                    $message = "-> �������� �� ������ (���: $($updatedDevice.ConfigManagerErrorCode)). ��������� ��������� ���������/��� setupapi.dev.log."

                    if ($updatedDevice.ConfigManagerErrorCode -eq 0) {
                        # ���� ��� 0, ���������, �� ������� �� ������� ������������
                        if ($updatedDevice.Class -eq 'Display' -and ($updatedDevice.Name -like "*������� ������������*" -or $updatedDevice.Name -like "*Microsoft Basic Display Adapter*")) {
                            $statusColor = 'Magenta'
                            $message = "-> ������� �������� (��� 0), �� ��� '$updatedDeviceName' ��� ��� �������. ������ ������� �� ������� ��� ��������� ������������."
                        } else {
                            $statusColor = 'Green'
                            $message = "-> ���������/���������� �������� ������ �������! ���������� '$updatedDeviceName' ������."
                        }
                    } elseif ($updatedDevice.ConfigManagerErrorCode -eq 28) {
                         $message = "-> ���������� '$updatedDeviceName' ��� ��� �������� �� ���������� �������� (������ 28). PnPUtil �� ���� ��������� ��������� INF '$infPath'. ��������, �� �����������."
                    }

                    Write-Host "  �������� ������� '$updatedDeviceName': ������=`"$($updatedDevice.Status)`", ��� ������=`"$($updatedDevice.ConfigManagerErrorCode)`"" -ForegroundColor $statusColor
                    Write-Host "  $message" -ForegroundColor $statusColor

                } else { Write-Warning "  �� ������� �������� ����������� ������ ���������� '$deviceNameForOutput'. ��������� �������." }

            } else {
                Write-Warning "  ������� PnPUtil ��� '$infPath' ����������� � ������� (��� ��������: $($process.ExitCode)). ��������� �������� �� �������."
                Write-Warning "  ��������� �������: INF ���������, �� ��������/�����������, �������� � �.�."
                Write-Warning "  ������������� ��������� ���: C:\Windows\INF\setupapi.dev.log"
            }
        } catch {
            Write-Error "  ����������� ������ ��� ������� PnPUtil ��� '$infPath': $($_.Exception.Message)"
            Write-Error "  ��������� ��� ����� ���������� ��������."
        }
        Write-Host "--------------------------------------------------"

    }
} else {
    Write-Host "--- ��������� ---" -ForegroundColor Yellow
    Write-Host "�� ���� ������� ���������� INF ������ ��� ��������� �� ���������� ���������� (����� � ����������� HardwareID)."
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          ������ ������� ���������" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Read-Host "������� Enter ��� �������� ����..."