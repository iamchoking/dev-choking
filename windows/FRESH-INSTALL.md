# Fresh Install Directions for Windows 10 and Windows 11

## Written for
`Windows 10` (version 1809 or later) and `Windows 11`, amd64/x64.
The same commands work on both; `settings.cmd` detects the Windows version.

### Before getting started

1. Install the network driver (Ethernet or Wi-Fi) from your PC or motherboard
   manufacturer's website, then connect to the internet.

   To find your motherboard manufacturer and model, run this in CMD:

   ```cmd
   powershell -NoProfile -Command "Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product"
   ```

   The `Product` column is the motherboard model.

2. Run a round of Windows Update and restart if prompted before continuing below.

Run the commands below in Command Prompt (`cmd.exe`).

### 0. Open Command Prompt with administrator privileges

Press `Win + R`, type `cmd`, then press `Ctrl + Shift + Enter`.
Select **Yes** in the User Account Control prompt.

### 1. Install Git

Install [Git for Windows](https://git-scm.com/install/windows) using `winget`:

```cmd
winget install --id Git.Git --exact --source winget
```

Accept any installation prompts. If `winget` is not recognized, install or update
[App Installer](https://learn.microsoft.com/en-us/windows/package-manager/winget/#install-winget)
from the Microsoft Store, then reopen Command Prompt and retry.

After Git finishes installing, close all Command Prompt and Windows Terminal
windows, then open a new administrator Command Prompt as in step 0. This loads
the updated `PATH` so that `git` is available.

### 2. Clone `dev-choking` (this repo) to your home

```cmd
cd /d "%USERPROFILE%" && git clone https://github.com/iamchoking/dev-choking.git && cd /d "%USERPROFILE%\dev-choking\windows"
```

We will operate in this directory (`%USERPROFILE%\dev-choking\windows`) henceforth.

### 3. Install essential apps (amd64/x64)

From the administrator Command Prompt, run:

```cmd
apps-essential_amd64.cmd
```

The script installs the x64 versions of VS Code, Google Chrome, and **Google Drive
for desktop** (`Google.GoogleDrive`) using `winget`. It reruns the VS Code installer
to apply its context-menu options, and skips Chrome and Google Drive when already
installed. Open Google Drive afterward and sign in to configure synchronization.

It also sets Git's global commit identity to `iamchoking`
(`iamchoking247@gmail.com`), matching `ubuntu/ubuntu-basic.sh`.

Keep `apps-essential_amd64.cmd`, `apps-essential_amd64.ps1`, and
`vscode-context-menu.ps1` together. Before
downloading Chrome or Google Drive, the helper checks Windows installation records,
registered and standard executable paths, and finally WinGet. This covers standard
installations made through Chocolatey or downloaded installers, including current-user apps.
An existing Chrome or Google Drive installation is skipped without upgrading it.
WinGet lookup errors stop setup instead of being mistaken for a missing app.

Save your work, close all VS Code windows, and let any pending VS Code update
finish before running the script. It stops with instructions if VS Code or its
installer is still running. For VS Code, it uses this command even when already
installed:

```cmd
winget install --force Microsoft.VisualStudioCode --exact --source winget --architecture x64 --accept-package-agreements --accept-source-agreements --disable-interactivity --override "/verysilent /suppressmsgboxes /norestart /log /mergetasks=!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"
```

The `addcontextmenufolders` task enables **Open with Code** when right-clicking a
folder or the background inside a folder; `addcontextmenufiles` enables it for files.
The helper also directly registers **Open with Code** in the current user's classic
file, folder, folder-background, and drive menus, and notifies Explorer immediately.
Windows 11's installer can register only its modern menu; direct registration also
covers the classic menu shown by **Show more options**. `settings.cmd` repairs
these entries for an existing VS Code installation without reinstalling VS Code.
The task list has no literal single quotes. `/norestart` leaves restarting to you,
and `/log` writes `Setup Log*.txt` to `%TEMP%` for troubleshooting. Installer exit
code 1 means setup failed to initialize; an already-running VS Code updater can
cause this. Close VS Code, allow the update to finish, then retry.

After installation, it opens **Settings > Apps > Default apps**:

* **Windows 11:** select **Google Chrome**, then click **Set default**.
* **Windows 10:** click the current **Web browser**, then choose **Google Chrome**.

See [Chrome's default-browser instructions](https://support.google.com/chrome/answer/95417?hl=en).

### 4. Apply personal Windows settings

Run this from an administrator CMD under **your own Windows account**:

```cmd
settings.cmd
```

`settings.cmd` launches `settings.ps1`, with version-specific implementations in
`settings_win10.ps1` and `settings_win11.ps1`, plus `vscode-context-menu.ps1`.
Keep these files together.
Stay online while it downloads the language resources and O&O ShutUp10.
Immediately after checking prerequisites, it sets the plugged-in sleep and screen
timeouts to **Never**, before removing OneDrive or installing language resources.
It also disables Windows Fast Startup on both Windows 10 and Windows 11.

On **Windows 10**, if the English (United States) display-language pack is missing,
the script opens **Settings > Time & Language > Language**. Add **English (United
States)** and install its **Language pack** (or select **Options > Download** if
English is already listed). Wait for installation to finish, then return to the
console and press Enter. The script checks that the display pack is installed
before proceeding; basic typing resources alone are insufficient. Windows 11
downloads the pack automatically.

Language downloads and Windows servicing can take several minutes. The Windows
11 display-pack installation prints an elapsed-time message every 15 seconds
while waiting, and reruns skip an existing English display pack. Wait for the
current run to finish before starting another setup process.
The display download excludes optional speech, handwriting, and OCR resources;
required English/Korean typing and Korean fonts are installed and checked
separately. If Windows reports a partial installation, restart Windows and rerun
`settings.cmd`; it reuses installed resources and checks the remaining components.

Alternatively, supply an official English display-language CAB matching your
Windows 10 release and architecture:

```cmd
settings.cmd -EnglishLanguagePack "D:\LanguagePacks\Microsoft-Windows-Client-Language-Pack_x64_en-us.cab"
```

This is optional; the Settings download is sufficient. If package installation
requires a restart, restart and rerun `settings.cmd`. See Microsoft's
[language-pack instructions](https://support.microsoft.com/en-us/windows/hardware/input-devices/language-packs-for-windows).

The script configures:

* **Microsoft OneDrive removal** through WinGet. An absent OneDrive is skipped;
  detection or uninstall failures stop setup with instructions to retry.
* Dark mode for Windows and apps, a left-aligned taskbar on Windows 11 (already
  the default on Windows 10), and visible hidden files and filename extensions.
* **Best performance** when plugged in and **Best power efficiency** on battery
  on Windows 11. Windows 10 laptops use **Best performance / Better battery**;
  Windows 10 desktops without a battery use the **High performance** power plan.
  Hardware that rejects a power setting is reported for manual adjustment.
* **Never automatically sleep when plugged in**, using
  `powercfg /change standby-timeout-ac 0` on the selected power plan.
* **Never turn off the screen when plugged in**, using
  `powercfg /change monitor-timeout-ac 0` on the selected power plan.
* **Fast Startup disabled** (`HiberbootEnabled=0`) on Windows 10 and Windows 11,
  so shutdown does not preserve the Windows kernel through a hybrid boot.
* **Open with Code** in the classic context menus for files, folders, folder
  backgrounds, and drives when VS Code is installed.
* **English (United States)** for Windows display language, app language preference,
  and system locale, including the welcome screen and new users. Regional formats
  use an **English (United Kingdom)** base for metric/A4 defaults, customized below.
* **Korean Microsoft IME as the only keyboard**, with Korean as the default input
  method at sign-in. The separate US keyboard and Alt+Shift/Ctrl+Shift layout
  switching shortcuts are removed. **Right Alt** switches between English and
  Hangul inside the Korean IME; **Right Ctrl** handles Hanja.
* Dates such as **2026-10-08** (`yyyy-MM-dd`), 24-hour times such as **23:15**
  (`HH:mm`; time displays with seconds use `HH:mm:ss`), **metric measurements**,
  and **A4** as the regional paper size.
  The script applies custom formats through Windows' locale API, reapplies them
  after copying international defaults, and notifies Explorer to refresh the
  taskbar date immediately.
* **UTC hardware-clock handling** (`RealTimeIsUniversal=1`) to match Ubuntu and
  prevent the time-zone offset when switching operating systems. This covers the
  [Windows side of dual-boot clock handling](../dual-boot/WINDOWS.md).
* **A4** in your printing preferences for installed local and connected shared
  printers whose drivers support it. Driver failures are reported for adjustment
  in the printer's **Printing preferences**.
* **A4** for new Word documents based on `Normal.dotm`, and **centimeters** in Word,
  if Word is installed and closed. An existing Normal template is backed up beside
  it with a `.before-dev-choking` suffix before editing.

English display language and Korean input are independent. The
[Windows input-profile API](https://learn.microsoft.com/en-us/windows/win32/tsf/installlayoutortip)
replaces the enabled keyboards with Korean IME after the language preferences are
saved. Merely clearing English's keyboard list can cause Windows to restore the
US keyboard. The script verifies Korean-only input before copying defaults to the
welcome screen and new users, and checks it again afterward.

The [Korean IME supports both English and Hangul](https://learn.microsoft.com/en-us/globalization/input/korean-ime),
so an `A` indicator means its English typing mode, not a separate US keyboard.
Korean Unicode text and fonts remain supported; the script installs Korean typing
and supplemental fonts. It does not enable the system-wide **Beta: UTF-8** locale
option. Legacy applications that require the Korean non-Unicode code page may
still need separate compatibility settings.

Windows' built-in folder labels follow the display language after restarting.
The script also refreshes the current session's Windows Search process so it
reloads the selected display language for Settings result labels.
Existing physical paths such as `C:\Users\<name>`, user-created filenames, and
third-party programs with their own language settings are not renamed or translated.
For English profile paths from the start, choose an English account name during
Windows setup. A non-English **Home Single Language** installation requires an
English installation or an edition supporting multiple display languages.

Install printer drivers and Word before this step when possible, or rerun it
after installing them. Existing documents and other document templates retain
their own page settings; choose A4 in those templates separately.

Finally, the script installs and opens **O&O ShutUp10** (formerly **ShutUp10++**).
It creates an **O&O ShutUp10** Start menu shortcut that requests administrator
privileges, and opens O&O as administrator. After restarting, search Start for
**O&O ShutUp10**, open it, and accept the administrator prompt to adjust settings
again. The executable stays in its WinGet-managed location.
Choose its privacy settings manually, close it, save your work, then **restart
Windows**. The script waits for O&O to close and leaves the restart to you.
After restarting, check that Windows is English, the only input method is Korean
IME, Right Alt switches English/Hangul, and the date/time and paper settings match
your preferences.

#### How version differences are handled

| Setting | Windows 10 | Windows 11 |
| --- | --- | --- |
| English display pack | Uses an installed pack, an optional CAB, or pauses for the Settings download | Downloads with `Install-Language` |
| Welcome screen and new-user defaults | Copies current settings through `intl.cpl` | Uses `Copy-UserInternationalSettingsToSystem` |
| AC/battery power modes | Legacy power slider preferences; High performance plan on desktops | Separate AC/DC power-mode APIs |
| Taskbar alignment | Already left-aligned | Sets left alignment |

Windows 10's [power slider](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/customize-power-slider)
uses **Better battery** for its efficiency mode; Battery Saver is a separate
feature. The helper uses the legacy overlay API and stored AC/DC preferences,
whose behavior can depend on the Windows build and device. Check the battery
slider while plugged in and unplugged after restarting. Failed power changes
are reported instead of being treated as successful.

For defaults on Windows 10, the helper uses the existing Control Panel
[settings-copy mechanism](https://learn.microsoft.com/en-us/troubleshoot/windows-client/setup-upgrade-and-drivers/automate-regional-language-settings)
after applying the current user's English UI, Korean input, and regional formats.
If Windows 10 rejects the copy-only import, the script retries with explicit
English UI, Korean IME, and regional-format values. If the Control Panel applet
still refuses to copy settings to the welcome screen and new users, setup keeps
the current user's settings and reports the manual **intl.cpl > Administrative >
Copy settings** step.
The scripts use Windows PowerShell 5.1, which is included in both Windows versions.
