# Copies trayres.exe (next to this script) to %LOCALAPPDATA%\Programs\trayres and starts it through Explorer,
# the same as a double-click. Run in the signed-in session.
$dir = "$env:LOCALAPPDATA\Programs\trayres"
New-Item -ItemType Directory -Force $dir | Out-Null
Get-Process trayres -EA 0 | Stop-Process
Copy-Item "$PSScriptRoot\trayres.exe" $dir -Force
Start-Process explorer.exe "`"$dir\trayres.exe`""
Start-Sleep 3
Get-Process trayres | Select Id, Path, StartTime | Format-List
Get-Content "$dir\trayres.ini"
"run key: " + (Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run -Name trayres -EA 0).trayres
