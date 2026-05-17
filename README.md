![](https://raw.githubusercontent.com/mioamio/autoinstalldriver_windows/main/image.jpg)

[![Windows](https://badgen.net/badge/icon/windows?icon=windows&label)](https://microsoft.com/windows/)
[![Go](https://img.shields.io/badge/Made%20with-Go-1f425f.svg)](https://go.dev/)
![Terminal](https://badgen.net/badge/icon/terminal?icon=terminal&label)
[![Github All Releases](https://img.shields.io/github/downloads/mioamio/autoinstalldriver_windows/total.svg)](https://github.com/mioamio/autoinstalldriver_windows/releases)
[![Views](https://views.igorkowalczyk.dev/api/badge/mioamio?repo=autoinstalldriver_windows&label=Views&style=classic)](https://github.com/mioamio/autoinstalldriver_windows/graphs/traffic)
[![License: MIT](https://img.shields.io/github/license/mioamio/autoinstalldriver_windows?style=flat-square)](https://github.com/mioamio/autoinstalldriver_windows/blob/main/LICENSE)
[![Telegram](https://badgen.net/badge/Telegram/me/2CA5E0)](https://t.me/topvselennaya)
[![Telegram](https://badgen.net/badge/Telegram/channel/2CA5E0)](https://t.me/scriptsautomation)

# AID: Умный автоматический установщик драйверов из подготовленной папки с драйверами

**AID (Auto Install Drivers)** — это молниеносная и умная утилита, написанная на **Go**, предназначенная для автоматического поиска и установки отсутствующих драйверов оборудования в среде Windows. 

Сделано для того, чтобы забыть про ручной поиск драйверов через Диспетчер устройств.

## Основные возможности

* **Написано на Go:** Работает значительно быстрее и стабильнее аналогов на PowerShell/CMD. Анализ сотен INF-файлов происходит за миллисекунды.
* **Умная многопроходность (Multipass PnP):** Утилита умеет распознавать «родительские» устройства. Если после установки драйвера (например, хаба или USB-контроллера) в системе появляются новые дочерние устройства (например, *COM-порты*), скрипт автоматически выполнит повторный проход и установит драйверы для них.
* **Современный CLI-интерфейс:** Красивый, минималистичный и плавный консольный UI с прогресс-барами, таблицами предпросмотра и стилизацией под ваш терминал.
* **Мгновенный маппинг:** Сравнивает `HardwareID` и `CompatibleID` проблемных устройств, считывая поддерживаемые архитектуры (x86, amd64, arm64) и версии прямо из `.inf` файлов в оперативной памяти.
* **Горячие клавиши ("На лету"):** Нажмите `S` в активном окне, чтобы прямо во время работы сменить целевую директорию драйверов (переключение между `ADrivers` и `asSERVER`) и моментально перезапустить сканирование.
* **Авто-запрос привилегий (UAC):** При запуске без прав администратора, программа сама запросит повышение прав и перезапустится.

## 📂 Как подготовить драйверы?

Это самый важный шаг. Скрипт не качает драйверы из интернета (это будет в одном из будущих обновлений), он использует вашу локальную базу с драйверами.

1. Создайте в корне любого диска (`C:\`, `D:\`, `E:\` и т.д.) папку с названием **`ADrivers`**.
2. Скачайте нужные драйверы из интернетра.
3. Обязательно **распакуйте архивы**. Внутри папки должны лежать файлы с расширением `.inf`, `.sys`, `.cat` и т.д.
