# Recover-OffscreenWindows

A lightweight PowerShell utility to recover application windows that are stuck outside the boundaries of currently connected monitors on Windows 10 and Windows 11.

## Why?

Some applications remember their last window position even after a monitor is disconnected. Instead of using Alt+Space, M and the arrow keys for each lost window, run this script to recover them automatically.

## Features

- Detects all monitors currently recognized by Windows.
- Leaves windows with sufficient overlap on any connected monitor unchanged.
- Centers inaccessible windows on the primary monitor.
- Resizes oversized windows to fit the primary monitor's working area.
- Preserves window stacking order and avoids intentionally stealing focus.
- Requires no third-party dependencies.

## Usage

Clone or download this repository, then run from PowerShell:

```powershell
.\Recover-OffscreenWindows.ps1
```

For a one-time execution using Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Recover-OffscreenWindows.ps1"
```

Adjust the path to match the location of your script. ExecutionPolicy Bypass applies to this invocation; review scripts before running them.

## Keyboard shortcut

1. Save the script in a permanent location, such as `C:\Scripts`.
2. Create a Windows desktop shortcut with the following target:

   ```text
   powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Scripts\Recover-OffscreenWindows.ps1"
   ```

3. Open the shortcut properties and assign a shortcut key, such as Ctrl+Alt+R.
4. Use the shortcut whenever an application window becomes inaccessible.

## How it works

The script uses Windows Forms to obtain monitor bounds and working areas, and the Win32 API (user32.dll) to enumerate, inspect and reposition top-level windows. A window is considered accessible if its rectangle overlaps any connected monitor by at least 50 pixels horizontally and 30 pixels vertically. Otherwise, the script centers it within the primary monitor's working area using SetWindowPos with SWP_NOZORDER and SWP_NOACTIVATE.

## Limitations

- Hidden, minimized and untitled windows are ignored.
- The primary monitor is the Windows-designated primary display, not necessarily display number 1.
- The overlap threshold does not guarantee that a window's title bar is reachable.
- Mixed-DPI monitor configurations, virtual desktops, unusual window styles and application-imposed positioning or size constraints may affect results.
- Elevated applications may require an elevated PowerShell session.
- Tested by the project owner on Windows 11. Windows 10 has not been independently validated.

## Built-in help

```powershell
Get-Help .\Recover-OffscreenWindows.ps1 -Full
```

## License

MIT. See [LICENSE](LICENSE).
