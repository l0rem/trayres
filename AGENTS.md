# trayres

Win32 tray app in one C file (`trayres.c`), no CRT: entry point `start`, own `memset`, system DLLs only
(kernel32, user32, shell32, advapi32). Keep it that way. No new features beyond modes, startup toggle and exit.

- Build: `./build.sh` (zig 0.17.1, cross-compiles from the Mac). `-Werror`; the output must stay deterministic
  (CI publishes the SHA-256). Big stack frames would need `__chkstk`, so keep large buffers static.
- Icon: `res/icon.py` → `res/trayres.ico`; manifest (PerMonitorV2, asInvoker) in `res/trayres.manifest`.
- Test on a real Windows desktop: `test/install.ps1` installs to `%LOCALAPPDATA%\Programs\trayres` and starts it
  through Explorer; `test/verify.ps1` clicks each mode in the real menu, reads the mode back, checks the check mark
  and the startup toggle, and restores the previous mode. Run them in the signed-in session (on atlas:
  `home atlas run x.ps1 --gui`), not over plain ssh (session 0 has no display). Mode switches are visible to whoever
  sits at the screen: say so first and always restore the previous mode.
- Scaling: trayres sets only size, depth and refresh (the same fields the old HRC tool used) and never
  `DM_DISPLAYFIXEDOUTPUT`, so the driver's scaling setting (NVIDIA "Full-screen" for stretched 4:3) is kept.
- Releases: push a `v*` tag; the workflow builds and attaches `trayres.exe` + `.sha256`.
