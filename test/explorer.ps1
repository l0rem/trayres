# Restarts Explorer and checks that trayres puts its icon back (TaskbarCreated), then that a second
# launch exits instead of adding a second icon. Run in the signed-in session.
. "$PSScriptRoot\disp.ps1"
[Disp]::DpiAware()
$pid0 = (Get-Process trayres).Id
"before: pid $pid0 icon " + [Disp]::IconRect()
Get-Process explorer | Stop-Process -Force
Start-Sleep 2
if (-not (Get-Process explorer -EA 0)) { Start-Process explorer.exe }   # in case AutoRestartShell is off
for ($i = 0; $i -lt 30 -and -not ([Disp]::IconRect() -like "hr=0x0*")) { Start-Sleep 1 }
"after explorer restart: pid $((Get-Process trayres).Id) icon " + [Disp]::IconRect()
Start-Process explorer.exe "`"$env:LOCALAPPDATA\Programs\trayres\trayres.exe`""
Start-Sleep 3
"second launch: trayres processes = " + @(Get-Process trayres).Count
