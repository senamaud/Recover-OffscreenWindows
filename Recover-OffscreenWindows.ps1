<#
.SYNOPSIS
    Recovers application windows located outside currently connected monitors.
.DESCRIPTION
    Enumerates visible top-level windows and checks their overlap with
    connected monitors. Windows with insufficient overlap are centered on
    the primary monitor, resizing them if necessary.
.NOTES
    Windows 10 / 11; requires Windows Forms and the Win32 API.
    Minimized, hidden and untitled windows are ignored.
    Elevated applications may require elevated PowerShell.
.EXAMPLE
    .\Recover-OffscreenWindows.ps1
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Recover-OffscreenWindows.ps1"
#>

# 1. Load .NET assemblies for monitor information and rectangle calculations.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 2. Define the Win32 API interface only once per PowerShell session.
if (-not ("WindowRecovery" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class WindowRecovery
{
    // Returning true continues enumeration of top-level windows.
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    // A visible window may still be outside all connected monitors.
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    // Determines whether the window is minimized.
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    // Retrieves the window rectangle in desktop screen coordinates.
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    // Changes window position and dimensions without necessarily activating it.
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy, uint uFlags);

    // Window titles are used to filter and identify windows.
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd,
        System.Text.StringBuilder text, int count);

    // Coordinates may be negative for monitors above or left of the primary.
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@
}

# 3. Retrieve connected monitors and the primary monitor's usable area.
# WorkingArea excludes reserved areas such as the Windows taskbar.
$screens = [System.Windows.Forms.Screen]::AllScreens
$primary = [System.Windows.Forms.Screen]::PrimaryScreen
$area = $primary.WorkingArea

# 4. Enumerate all top-level windows on the current desktop.
[WindowRecovery]::EnumWindows({
    param($hWnd, $lParam)

    # 4.1. Ignore hidden, minimized and untitled windows.
    if (
        -not [WindowRecovery]::IsWindowVisible($hWnd) -or
        [WindowRecovery]::IsIconic($hWnd) -or
        [WindowRecovery]::GetWindowTextLength($hWnd) -eq 0
    ) {
        return $true
    }

    # 4.2. Retrieve the current window position; skip on failure.
    $rect = New-Object WindowRecovery+RECT
    if (-not [WindowRecovery]::GetWindowRect($hWnd, [ref]$rect)) {
        return $true
    }

    # 4.3. Calculate dimensions and ignore invalid rectangles.
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) {
        return $true
    }

    $window = [System.Drawing.Rectangle]::new(
        $rect.Left, $rect.Top, $width, $height
    )

    # 4.4. Check whether enough of the window overlaps any connected monitor.
    # Require at least 50 horizontal and 30 vertical pixels of overlap.
    # This is a heuristic, not a guarantee that the title bar is accessible.
    $accessible = $false
    foreach ($screen in $screens) {
        $intersection = [System.Drawing.Rectangle]::Intersect(
            $window, $screen.Bounds
        )
        if ($intersection.Width -ge 50 -and $intersection.Height -ge 30) {
            $accessible = $true
            break
        }
    }

    # 5. Recover only inaccessible windows.
    if (-not $accessible) {
        # 5.1. Preserve dimensions where possible; shrink oversized windows.
        $width = [Math]::Min($width, $area.Width)
        $height = [Math]::Min($height, $area.Height)

        # 5.2. Calculate the centered position within the primary working area.
        $x = $area.Left + [int](($area.Width - $width) / 2)
        $y = $area.Top + [int](($area.Height - $height) / 2)

        # 5.3. Retrieve the window title for console logging.
        $title = New-Object System.Text.StringBuilder 512
        [WindowRecovery]::GetWindowText(
            $hWnd, $title, $title.Capacity
        ) | Out-Null

        # 5.4. Move and resize without changing Z-order or activating the window.
        # 0x0004 = SWP_NOZORDER; 0x0010 = SWP_NOACTIVATE.
        $success = [WindowRecovery]::SetWindowPos(
            $hWnd, [IntPtr]::Zero, $x, $y, $width, $height, 0x0014
        )

        # 5.5. Report the result of the Windows API call.
        if ($success) {
            Write-Host "Window recovered: $title" -ForegroundColor Green
        } else {
            Write-Warning "Unable to move window: $title"
        }
    }

    # 6. Continue enumeration regardless of the current window's outcome.
    return $true
}, [IntPtr]::Zero) | Out-Null
