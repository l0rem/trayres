# Display and tray helpers for testing trayres on a real machine (run in the signed-in session).
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text; using System.Collections.Generic; using System.Threading;
public static class Disp {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName;
    public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields;
    public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
    public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName;
    public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
    public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight; }
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] struct NII { public int cbSize; public IntPtr hWnd; public uint uID; public Guid guid; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettingsW(string dev, int mode, ref DEVMODE dm);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int ChangeDisplaySettingsExW(string dev, ref DEVMODE dm, IntPtr h, int flags, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindowW(string cls, string name);
  [DllImport("user32.dll")] static extern IntPtr SendMessageW(IntPtr h, int msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, int msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetMenuStringW(IntPtr m, int id, StringBuilder s, int n, int flags);
  [DllImport("user32.dll")] static extern int GetMenuState(IntPtr m, int id, int flags);
  [DllImport("user32.dll")] static extern int GetMenuItemCount(IntPtr m);
  [DllImport("user32.dll")] static extern bool GetMenuItemRect(IntPtr h, IntPtr m, int pos, out RECT r);
  [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] static extern void mouse_event(int f, int x, int y, int d, IntPtr e);
  [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  [DllImport("shell32.dll")] static extern int Shell_NotifyIconGetRect(ref NII id, out RECT r);
  [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(int f, out int np, out int nm);
  [DllImport("user32.dll")] static extern int QueryDisplayConfig(int f, ref int np, [Out] byte[] paths, ref int nm, [Out] byte[] modes, IntPtr topo);
  public static void DpiAware() { SetProcessDpiAwarenessContext(new IntPtr(-4)); }
  static DEVMODE Cur() { var d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(d); EnumDisplaySettingsW(null, -1, ref d); return d; }
  public static string Current() { var d = Cur(); return d.dmPelsWidth + "x" + d.dmPelsHeight + "@" + d.dmDisplayFrequency; }
  public static int Set(int w, int h, int hz) { var d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(d);
    d.dmFields = 0x80000 | 0x100000 | 0x40000 | 0x400000; d.dmPelsWidth = w; d.dmPelsHeight = h; d.dmBitsPerPel = 32; d.dmDisplayFrequency = hz;
    return ChangeDisplaySettingsExW(null, ref d, IntPtr.Zero, 1, IntPtr.Zero); }
  public static string Modes(int w, int h) { var d = new DEVMODE(); d.dmSize = (short)Marshal.SizeOf(d); var hz = new SortedSet<int>();
    for (int i = 0; EnumDisplaySettingsW(null, i, ref d); i++) if (d.dmPelsWidth == w && d.dmPelsHeight == h && d.dmBitsPerPel == 32) hz.Add(d.dmDisplayFrequency);
    return w + "x" + h + ": " + string.Join(",", hz); }
  // CCD scaling of the active path: DISPLAYCONFIG_PATH_INFO is 72 bytes, targetInfo.scaling at offset 44.
  // 1 identity, 2 centered, 3 stretched, 4 aspect ratio, 5 custom, 128 preferred
  public static int Scaling() { int np, nm; GetDisplayConfigBufferSizes(2, out np, out nm);
    var p = new byte[np * 72]; var m = new byte[nm * 64]; QueryDisplayConfig(2, ref np, p, ref nm, m, IntPtr.Zero);
    return np > 0 ? BitConverter.ToInt32(p, 44) : -1; }
  public static IntPtr Tray() { return FindWindowW("trayres", null); }
  public static string IconRect() { var id = new NII(); id.cbSize = Marshal.SizeOf(id); id.hWnd = Tray(); id.uID = 1; RECT r;
    int hr = Shell_NotifyIconGetRect(ref id, out r); return "hr=0x" + hr.ToString("x") + " rect=" + r.L + "," + r.T + "," + r.R + "," + r.B; }
  public static IntPtr OpenMenu() { // what the shell sends on a left click (NOTIFYICON_VERSION_4: NIN_SELECT, anchor in wParam)
    int x = GetSystemMetrics(0) / 2, y = GetSystemMetrics(1) - 60;
    PostMessageW(Tray(), 0x8001, new IntPtr((y << 16) | (x & 0xffff)), new IntPtr(0x400 | (1 << 16)));
    for (int i = 0; i < 60; i++) { var w = FindWindowW("#32768", null); if (w != IntPtr.Zero && IsWindowVisible(w)) { Thread.Sleep(300); return w; } Thread.Sleep(50); }
    return IntPtr.Zero; }
  public static IntPtr MenuOf(IntPtr w) { return SendMessageW(w, 0x01E1, IntPtr.Zero, IntPtr.Zero); }
  public static RECT WinRect(IntPtr w) { RECT r; GetWindowRect(w, out r); return r; }
  public static void CloseMenu() { PostMessageW(Tray(), 0x001F, IntPtr.Zero, IntPtr.Zero); Thread.Sleep(300); }
  public static string Items(IntPtr m) { var sb = new StringBuilder(); int n = GetMenuItemCount(m);
    for (int i = 0; i < n; i++) { var s = new StringBuilder(128); GetMenuStringW(m, i, s, 128, 0x400); int st = GetMenuState(m, i, 0x400);
      if ((st & 0x800) != 0) { sb.Append("    ----\n"); continue; }
      sb.Append((st & 8) != 0 ? "  [x] " : "  [ ] ").Append(s).Append((st & 3) != 0 ? " (grey)" : "").Append("\n"); }
    return sb.ToString(); }
  public static int Find(IntPtr m, string prefix) { int n = GetMenuItemCount(m);
    for (int i = 0; i < n; i++) { var s = new StringBuilder(128); GetMenuStringW(m, i, s, 128, 0x400); if (s.ToString().StartsWith(prefix)) return i; } return -1; }
  public static void Click(IntPtr m, int pos) { // a real mouse click on the menu item, then put the cursor back
    RECT r; GetMenuItemRect(IntPtr.Zero, m, pos, out r); POINT old; GetCursorPos(out old);
    SetCursorPos((r.L + r.R) / 2, (r.T + r.B) / 2); Thread.Sleep(150);
    mouse_event(2, 0, 0, 0, IntPtr.Zero); mouse_event(4, 0, 0, 0, IntPtr.Zero); Thread.Sleep(200); SetCursorPos(old.X, old.Y); }
}
'@
