# End-to-end check in the signed-in session: opens trayres's menu, clicks each mode, reads the mode back,
# checks the check mark and the startup toggle, then restores the mode that was active before.
param([string]$Shot = "")
. "$PSScriptRoot\disp.ps1"
[Disp]::DpiAware()
$orig = [Disp]::Current(); $w, $rest = $orig -split 'x'; $h, $hz = $rest -split '@'
"before: $orig scaling=$([Disp]::Scaling())"
if ([Disp]::Tray() -eq [IntPtr]::Zero) { "trayres window not found"; exit 1 }
"icon: " + [Disp]::IconRect()
$run = { (Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -Name trayres -EA 0).trayres }
try {
  $x = [char]0xD7
  foreach ($t in "1440 $x 1080", "1920 $x 1080", "2560 $x 1440") {
    $mw = [Disp]::OpenMenu(); if ($mw -eq [IntPtr]::Zero) { "menu did not open"; exit 1 }
    $m = [Disp]::MenuOf($mw)
    if ($Shot -and $t -like "1440*") {
      Add-Type -AssemblyName System.Drawing; $r = [Disp]::WinRect($mw); $pad = 12
      $bmp = New-Object Drawing.Bitmap ($r.R - $r.L + 2 * $pad), ($r.B - $r.T + 2 * $pad)
      $g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L - $pad, $r.T - $pad, 0, 0, $bmp.Size); $bmp.Save($Shot); "screenshot: $Shot"
    }
    "menu:"; [Disp]::Items($m)
    [Disp]::Click($m, [Disp]::Find($m, $t)); Start-Sleep -Milliseconds 2500
    "clicked '$t' -> now $([Disp]::Current()) scaling=$([Disp]::Scaling())"
  }
  $mw = [Disp]::OpenMenu(); "menu after:"; [Disp]::Items([Disp]::MenuOf($mw))
  "run key: $(& $run)"
  [Disp]::Click([Disp]::MenuOf($mw), [Disp]::Find([Disp]::MenuOf($mw), "Start with")); Start-Sleep -Milliseconds 500
  "after untick: run key = '$(& $run)'"
  $mw = [Disp]::OpenMenu(); "menu:"; [Disp]::Items([Disp]::MenuOf($mw))
  [Disp]::Click([Disp]::MenuOf($mw), [Disp]::Find([Disp]::MenuOf($mw), "Start with")); Start-Sleep -Milliseconds 500
  "after tick: run key = '$(& $run)'"
} finally {
  [Disp]::CloseMenu()
  $rc = [Disp]::Set([int]$w, [int]$h, [int]$hz); Start-Sleep -Milliseconds 1500
  "restored (rc=$rc): $([Disp]::Current()) scaling=$([Disp]::Scaling())"
}
