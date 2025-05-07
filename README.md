![](https://raw.githubusercontent.com/mioamio/autoinstalldriver_windows/main/image.jpg)
[![Windows](https://badgen.net/badge/icon/windows?icon=windows&label)](https://microsoft.com/windows/)
![Terminal](https://badgen.net/badge/icon/terminal?icon=terminal&label)
[![Views](https://views.igorkowalczyk.dev/api/badge/mioamio?repo=autoinstalldriver_windows&label=Views&style=classic)](https://github.com/mioamio/autoinstalldriver_windows/graphs/traffic)
[![License: MIT](https://img.shields.io/github/license/mioamio/autoinstalldriver_windows?style=flat-square)](https://github.com/mioamio/autoinstalldriver_windows/blob/main/LICENSE)
[![Telegram](https://badgen.net/badge/Telegram/me/2CA5E0)](https://t.me/topvselennaya)
[![Telegram](https://badgen.net/badge/Telegram/channel/2CA5E0)](https://t.me/scriptsautomation)


# AutoInstallDriver for Windows BETA - Руководство пользователя / User Guide

## РУС

Данное руководство описывает шаги по использованию скриптов `startme.bat` и `aid_script.ps1` для автоматической установки драйверов в среде Windows (10 home/pro, 11 home/pro)

**Инструкции по установке и запуску:**

1.  **Сохраните файлы скриптов:** Загрузите и сохраните файлы `startme.bat` и `aid_script.ps1` в удобное для вас расположение на локальном диске.

2.  **Настройка пути к драйверам:**
    * Откройте файл `aid_script.ps1` в текстовом редакторе (например, Блокнот).
    * Найдите строку:
        ```powershell
        $path = "$($driveLetter):\ВСТАВИТЬНАЗВАНИЕДИРЕКТОРИИСДРАЙВЕРАМИ"
        ```
    * Замените текст `ВСТАВИТЬНАЗВАНИЕДИРЕКТОРИИСДРАЙВЕРАМИ` на **полный путь к папке**, содержащей INF-файлы ваших драйверов.
    * **Пример:** Если ваши INF-файлы находятся в папке `D:\Drivers`, строка должна выглядеть следующим образом:
        ```powershell
        $path = "$($driveLetter):\Drivers"
        ```
    * Сохраните внесенные изменения в файле `aid_script.ps1`.

3.  **Запустите `startme.bat`:** Перейдите в папку, где вы сохранили файлы, и **двойным щелчком запустите файл `startme.bat`**.

#
## ENG

This guide outlines the steps for using the `startme.bat` and `aid_script.ps1` scripts to automate driver installation in a Windows environment (10 home/pro, 11 home/pro)

**Installation and Execution Instructions:**

1.  **Save Script Files:** Download and save the `startme.bat` and `aid_script.ps1` files to a convenient location on your local drive.

2.  **Configure Driver Path:**
    * Open the `aid_script.ps1` file in a text editor (e.g., Notepad).
    * Locate the line:
        ```powershell
        $path = "$($driveLetter):\ВСТАВИТЬНАЗВАНИЕДИРЕКТОРИИСДРАЙВЕРАМИ"
        ```
    * Replace the text `ВСТАВИТЬНАЗВАНИЕДИРЕКТОРИИСДРАЙВЕРАМИ` with the **full path to the folder** containing your driver INF files.
    * **Example:** If your INF files are located in the folder `D:\Drivers`, the line should look like this:
        ```powershell
        $path = "$($driveLetter):\Drivers"
        ```
    * Save the changes you made to the `aid_script.ps1` file.

3.  **Run `startme.bat`:** Navigate to the folder where you saved the files and **double-click the `startme.bat` file** to execute it.

---
![image](https://github.com/user-attachments/assets/d23a8257-9366-40c5-8674-c65c7dda8e64)

---
 ## Идея: Автоматизация рутинной задачи установки драйверов — особенно удобно для системных администраторов или при частой переустановке системы.
---