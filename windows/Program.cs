// Vell for Windows.
// Copyright (c) 2026 Boumediene B. (@bovmii). All rights reserved.
// Free and open source under PolyForm Noncommercial 1.0.0.
// Selling this software, or any derivative based on it, is strictly prohibited.
// Contact: instagram.com/bovmii, github.com/bovmii

using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Win32;

namespace Vell;

internal static class Program
{
    public const string Copyright =
        "Vell © 2026 @bovmii. Free and noncommercial. Selling prohibited. instagram.com/bovmii";

    [STAThread]
    static void Main()
    {
        // Single instance guard.
        using var mutex = new Mutex(true, "Vell.SingleInstance", out bool isOnlyInstance);
        if (!isOnlyInstance) return;

        ApplicationConfiguration.Initialize();
        Trace.WriteLine(Copyright);
        Application.Run(new TrayContext());
    }
}

// =====================================================================
//  Tray context: lifecycle, menu, gamma, hotkey, settings
// =====================================================================

public sealed class TrayContext : ApplicationContext
{
    private readonly NotifyIcon _tray;
    private readonly ContextMenuStrip _menu;
    private readonly ToolStripMenuItem _enabledItem;
    private readonly ToolStripMenuItem _intensityHeader;
    private readonly ToolStripMenuItem _presetSubmenu;
    private readonly ToolStripMenuItem _loginItem;
    private readonly HotKeyWindow _hotKeyWindow;
    private PreferencesForm? _prefsForm;
    private MainWindow? _mainWindow;

    public AppSettings Settings { get; private set; }

    public TrayContext()
    {
        Settings = AppSettings.Load();

        _menu = new ContextMenuStrip();

        var header = new ToolStripMenuItem("Vell  @bovmii") { Enabled = false };
        _menu.Items.Add(header);
        _menu.Items.Add(new ToolStripSeparator());

        var showWindow = new ToolStripMenuItem("Afficher la fenêtre", null, (_, _) => OpenMainWindow())
        {
            Font = new Font(SystemFonts.MenuFont!, FontStyle.Bold)
        };
        _menu.Items.Add(showWindow);
        _menu.Items.Add(new ToolStripSeparator());

        _enabledItem = new ToolStripMenuItem("Activé", null, (_, _) => ToggleEnabled());
        _menu.Items.Add(_enabledItem);
        _menu.Items.Add(new ToolStripSeparator());

        _intensityHeader = new ToolStripMenuItem { Enabled = false };
        _menu.Items.Add(_intensityHeader);

        _presetSubmenu = new ToolStripMenuItem("Préréglages");
        _menu.Items.Add(_presetSubmenu);

        var custom = new ToolStripMenuItem("Intensité personnalisée…", null, (_, _) => PromptCustomIntensity());
        _menu.Items.Add(custom);

        var reset = new ToolStripMenuItem("Réinitialiser", null, (_, _) => ResetIntensity());
        _menu.Items.Add(reset);

        _menu.Items.Add(new ToolStripSeparator());

        _loginItem = new ToolStripMenuItem("Lancer au démarrage", null, (_, _) => ToggleLoginItem());
        _menu.Items.Add(_loginItem);

        var prefs = new ToolStripMenuItem("Préférences…", null, (_, _) => OpenPreferences());
        _menu.Items.Add(prefs);

        var shortcut = new ToolStripMenuItem("Créer un raccourci sur le bureau", null, (_, _) => CreateDesktopShortcut());
        _menu.Items.Add(shortcut);

        _menu.Items.Add(new ToolStripSeparator());

        var about = new ToolStripMenuItem("À propos…", null, (_, _) => ShowAbout());
        _menu.Items.Add(about);

        var quit = new ToolStripMenuItem("Quitter", null, (_, _) => Quit());
        _menu.Items.Add(quit);

        _tray = new NotifyIcon
        {
            Icon = LoadEmbeddedIcon(),
            Text = "Vell",
            Visible = true,
            ContextMenuStrip = _menu
        };

        // Clic gauche → ouvre le menu (comme sur Mac).
        _tray.MouseUp += (_, e) =>
        {
            if (e.Button == MouseButtons.Left)
            {
                var m = typeof(NotifyIcon).GetMethod("ShowContextMenu",
                    System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
                m?.Invoke(_tray, null);
            }
        };

        // Double-clic → ouvre la fenêtre principale.
        _tray.DoubleClick += (_, _) => OpenMainWindow();

        _hotKeyWindow = new HotKeyWindow(ToggleEnabled);
        InstallHotKey();

        RefreshMenu();
        ApplyGamma();
    }

    // ------------------------------------------------------------------
    //  Main window
    // ------------------------------------------------------------------

    public void OpenMainWindow()
    {
        if (_mainWindow == null || _mainWindow.IsDisposed)
            _mainWindow = new MainWindow(this);
        if (!_mainWindow.Visible) _mainWindow.Show();
        if (_mainWindow.WindowState == FormWindowState.Minimized)
            _mainWindow.WindowState = FormWindowState.Normal;
        _mainWindow.Activate();
    }

    private void RefreshMainWindow()
    {
        if (_mainWindow != null && !_mainWindow.IsDisposed && _mainWindow.Visible)
            _mainWindow.Refresh();
    }

    // External callbacks (used by MainWindow and PreferencesForm).
    public void ApplyPresetExternal(int index) => ApplyPreset(index);
    public void ResetIntensityExternal() => ResetIntensity();
    public void OpenPreferencesExternal() => OpenPreferences();
    public void ShowAboutExternal() => ShowAbout();

    public void SetIntensity(double value)
    {
        if (value < 0) value = 0;
        if (value > 0.9) value = 0.9;
        Settings.Intensity = value;
        if (!Settings.Enabled) Settings.Enabled = true;
        Settings.Save();
        ApplyGamma();
        RefreshMenu();
        RefreshMainWindow();
    }

    // ------------------------------------------------------------------
    //  Desktop shortcut
    // ------------------------------------------------------------------

    private void CreateDesktopShortcut()
    {
        try
        {
            var desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
            var shortcutPath = Path.Combine(desktop, "Vell.lnk");
            var exePath = Process.GetCurrentProcess().MainModule?.FileName;
            if (string.IsNullOrEmpty(exePath)) return;

            Type? wshType = Type.GetTypeFromProgID("WScript.Shell");
            if (wshType == null)
            {
                MessageBox.Show("Impossible de créer le raccourci.", "Vell",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            dynamic shell = Activator.CreateInstance(wshType)!;
            dynamic sc = shell.CreateShortcut(shortcutPath);
            sc.TargetPath = exePath;
            sc.WorkingDirectory = Path.GetDirectoryName(exePath);
            sc.IconLocation = exePath + ",0";
            sc.Description = "Vell – réduction du point blanc";
            sc.Save();

            MessageBox.Show("Raccourci créé sur le bureau.", "Vell",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show("Échec de la création du raccourci :\n" + ex.Message, "Vell",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    // ------------------------------------------------------------------
    //  Menu refresh (mutate in place)
    // ------------------------------------------------------------------

    private void RefreshMenu()
    {
        _enabledItem.Text = (Settings.Enabled ? "✓ Activé   " : "Activé   ")
            + (Settings.HotKeyEnabled ? HotKeyDisplay() : "");
        _intensityHeader.Text = $"Intensité : {(int)(Settings.Intensity * 100)} %";
        RefreshPresetSubmenu();
        _loginItem.Text = IsLoginItemEnabled() ? "✓ Lancer au démarrage" : "Lancer au démarrage";
    }

    private void RefreshPresetSubmenu()
    {
        _presetSubmenu.DropDownItems.Clear();
        string[] labels = { "Léger", "Moyen", "Fort" };
        for (int i = 0; i < 3; i++)
        {
            int idx = i;
            double val = Settings.Presets[i];
            var item = new ToolStripMenuItem(
                $"{labels[i]} ({(int)(val * 100)} %)",
                null,
                (_, _) => ApplyPreset(idx));
            _presetSubmenu.DropDownItems.Add(item);
        }
    }

    // ------------------------------------------------------------------
    //  Actions
    // ------------------------------------------------------------------

    public void ToggleEnabled()
    {
        Settings.Enabled = !Settings.Enabled;
        Settings.Save();
        ApplyGamma();
        RefreshMenu();
        RefreshMainWindow();
    }

    private void ApplyPreset(int index)
    {
        Settings.Intensity = Settings.Presets[index];
        if (!Settings.Enabled) Settings.Enabled = true;
        Settings.Save();
        ApplyGamma();
        RefreshMenu();
        RefreshMainWindow();
    }

    private void ResetIntensity()
    {
        Settings.Intensity = AppSettings.DefaultIntensity;
        Settings.Save();
        ApplyGamma();
        RefreshMenu();
        RefreshMainWindow();
    }

    private void PromptCustomIntensity()
    {
        using var f = new Form
        {
            Text = "Intensité",
            FormBorderStyle = FormBorderStyle.FixedDialog,
            MinimizeBox = false,
            MaximizeBox = false,
            StartPosition = FormStartPosition.CenterScreen,
            ClientSize = new Size(300, 110)
        };
        var label = new Label { Left = 12, Top = 12, Width = 270, Text = "Intensité (0 à 90 %) :" };
        var num = new NumericUpDown { Left = 12, Top = 36, Width = 80, Minimum = 0, Maximum = 90, Value = (decimal)(Settings.Intensity * 100) };
        var ok = new Button { Text = "OK", Left = 124, Top = 72, DialogResult = DialogResult.OK };
        var cancel = new Button { Text = "Annuler", Left = 208, Top = 72, DialogResult = DialogResult.Cancel };
        f.Controls.AddRange(new Control[] { label, num, ok, cancel });
        f.AcceptButton = ok;
        f.CancelButton = cancel;
        if (f.ShowDialog() == DialogResult.OK)
        {
            Settings.Intensity = (double)num.Value / 100.0;
            if (!Settings.Enabled) Settings.Enabled = true;
            Settings.Save();
            ApplyGamma();
            RefreshMenu();
            RefreshMainWindow();
        }
    }

    private void ToggleLoginItem()
    {
        if (IsLoginItemEnabled()) DisableLoginItem();
        else EnableLoginItem();
        RefreshMenu();
    }

    private void OpenPreferences()
    {
        if (_prefsForm == null || _prefsForm.IsDisposed)
            _prefsForm = new PreferencesForm(this);
        _prefsForm.Show();
        _prefsForm.Activate();
    }

    public void OnPreferencesChanged()
    {
        InstallHotKey();
        ApplyGamma();
        RefreshMenu();
        RefreshMainWindow();
    }

    private void ShowAbout()
    {
        string text =
            "Vell pour Windows\n\n" +
            "Réduit l'intensité du point blanc de l'écran, à la manière de l'option d'accessibilité d'iOS.\n\n" +
            "Créé par @bovmii\n" +
            "GitHub : github.com/bovmii\n" +
            "Instagram : @bovmii\n\n" +
            "Vell est 100 % gratuit. Si vous payez pour cette app, vous vous êtes fait avoir.\n\n" +
            "Un bug, une idée ? Écrivez-moi sur Instagram ou ouvrez une issue sur GitHub.\n\n" +
            "Copyright © 2026 @bovmii.\nLicence PolyForm Noncommercial 1.0.0. Revente interdite.";

        var result = MessageBox.Show(text, "À propos de Vell",
            MessageBoxButtons.YesNoCancel, MessageBoxIcon.Information,
            MessageBoxDefaultButton.Button3);
        // YesNoCancel : Yes = GitHub, No = Instagram, Cancel = close
        if (result == DialogResult.Yes) OpenUrl("https://github.com/bovmii");
        else if (result == DialogResult.No) OpenUrl("https://instagram.com/bovmii");
    }

    private static void OpenUrl(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch { }
    }

    private void Quit()
    {
        GammaController.Restore();
        _tray.Visible = false;
        _hotKeyWindow.Dispose();
        Application.Exit();
    }

    // ------------------------------------------------------------------
    //  Gamma
    // ------------------------------------------------------------------

    private void ApplyGamma()
    {
        double cap = Settings.Enabled ? (1.0 - Settings.Intensity) : 1.0;
        GammaController.Apply(cap);
    }

    // ------------------------------------------------------------------
    //  Hotkey
    // ------------------------------------------------------------------

    public string HotKeyDisplay()
    {
        if (!Settings.HotKeyEnabled) return "(désactivé)";
        var s = "";
        if ((Settings.HotKeyMods & HotKeyWindow.MOD_CONTROL) != 0) s += "Ctrl+";
        if ((Settings.HotKeyMods & HotKeyWindow.MOD_ALT) != 0)     s += "Alt+";
        if ((Settings.HotKeyMods & HotKeyWindow.MOD_SHIFT) != 0)   s += "Shift+";
        if ((Settings.HotKeyMods & HotKeyWindow.MOD_WIN) != 0)     s += "Win+";
        s += ((Keys)Settings.HotKeyVk).ToString().ToUpperInvariant();
        return s;
    }

    public void InstallHotKey()
    {
        _hotKeyWindow.Unregister();
        if (Settings.HotKeyEnabled)
            _hotKeyWindow.Register(Settings.HotKeyMods, Settings.HotKeyVk);
    }

    // ------------------------------------------------------------------
    //  Login item (registry Run key)
    // ------------------------------------------------------------------

    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string RunValueName = "Vell";

    public static bool IsLoginItemEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(RunValueName) != null;
    }

    public static void EnableLoginItem()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
        if (key == null) return;
        var exe = Process.GetCurrentProcess().MainModule?.FileName ?? "";
        if (!string.IsNullOrEmpty(exe))
            key.SetValue(RunValueName, $"\"{exe}\"");
    }

    public static void DisableLoginItem()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
        key?.DeleteValue(RunValueName, throwOnMissingValue: false);
    }

    // ------------------------------------------------------------------
    //  Embedded icon
    // ------------------------------------------------------------------

    private static Icon LoadEmbeddedIcon()
    {
        var asm = Assembly.GetExecutingAssembly();
        var resName = asm.GetManifestResourceNames().FirstOrDefault(n => n.EndsWith("icone.png"));
        if (resName == null) return SystemIcons.Application;
        using var stream = asm.GetManifestResourceStream(resName)!;
        using var bitmap = new Bitmap(stream);
        return Icon.FromHandle(bitmap.GetHicon());
    }

    public void ResetAll()
    {
        Settings = AppSettings.Defaults();
        Settings.Save();
        InstallHotKey();
        ApplyGamma();
        RefreshMenu();
        RefreshMainWindow();
    }
}

// =====================================================================
//  Gamma controller (GDI SetDeviceGammaRamp on every monitor)
// =====================================================================

internal static class GammaController
{
    [DllImport("user32.dll")] private static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern int    ReleaseDC(IntPtr hwnd, IntPtr hdc);
    [DllImport("gdi32.dll")]  private static extern IntPtr CreateDC(string lpszDriver, string lpszDevice, string? lpszOutput, IntPtr lpInitData);
    [DllImport("gdi32.dll")]  private static extern bool   DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll")]  private static extern bool   SetDeviceGammaRamp(IntPtr hdc, ref Ramp ramp);

    [DllImport("user32.dll")]
    private static extern bool EnumDisplayDevices(string? lpDevice, uint iDevNum, ref DISPLAY_DEVICE displayDevice, uint flags);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DISPLAY_DEVICE
    {
        public uint cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public uint StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Ramp
    {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public ushort[] Red;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public ushort[] Green;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public ushort[] Blue;
    }

    private const uint DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x1;

    public static void Apply(double cap)
    {
        if (cap < 0.05) cap = 0.05;  // safety: never let screen go fully black
        if (cap > 1.0) cap = 1.0;

        var ramp = BuildRamp(cap);

        // Primary screen
        IntPtr hdc = GetDC(IntPtr.Zero);
        if (hdc != IntPtr.Zero)
        {
            SetDeviceGammaRamp(hdc, ref ramp);
            ReleaseDC(IntPtr.Zero, hdc);
        }

        // All attached displays (multi-monitor)
        uint i = 0;
        var dev = new DISPLAY_DEVICE();
        dev.cb = (uint)Marshal.SizeOf(typeof(DISPLAY_DEVICE));
        while (EnumDisplayDevices(null, i, ref dev, 0))
        {
            if ((dev.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0)
            {
                IntPtr mhdc = CreateDC(dev.DeviceName, dev.DeviceName, null, IntPtr.Zero);
                if (mhdc != IntPtr.Zero)
                {
                    SetDeviceGammaRamp(mhdc, ref ramp);
                    DeleteDC(mhdc);
                }
            }
            dev = new DISPLAY_DEVICE { cb = (uint)Marshal.SizeOf(typeof(DISPLAY_DEVICE)) };
            i++;
        }
    }

    public static void Restore() => Apply(1.0);

    private static Ramp BuildRamp(double cap)
    {
        var ramp = new Ramp
        {
            Red = new ushort[256],
            Green = new ushort[256],
            Blue = new ushort[256]
        };
        for (int i = 0; i < 256; i++)
        {
            int v = (int)(i * cap * 257.0);   // 0..255 * cap, then scale to 0..65535
            if (v > 65535) v = 65535;
            ramp.Red[i] = ramp.Green[i] = ramp.Blue[i] = (ushort)v;
        }
        return ramp;
    }
}

// =====================================================================
//  HotKey window (message-only)
// =====================================================================

public sealed class HotKeyWindow : NativeWindow, IDisposable
{
    public const int MOD_ALT = 0x1;
    public const int MOD_CONTROL = 0x2;
    public const int MOD_SHIFT = 0x4;
    public const int MOD_WIN = 0x8;

    private const int WM_HOTKEY = 0x0312;
    private const int HOTKEY_ID = 0x42;

    [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private readonly Action _callback;
    private bool _registered;

    public HotKeyWindow(Action callback)
    {
        _callback = callback;
        CreateHandle(new CreateParams { Caption = "VellHotKey", Parent = (IntPtr)(-3) /* HWND_MESSAGE */ });
    }

    public bool Register(int mods, int vk)
    {
        _registered = RegisterHotKey(Handle, HOTKEY_ID, mods, vk);
        return _registered;
    }

    public void Unregister()
    {
        if (_registered)
        {
            UnregisterHotKey(Handle, HOTKEY_ID);
            _registered = false;
        }
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY && m.WParam.ToInt32() == HOTKEY_ID)
            _callback();
        base.WndProc(ref m);
    }

    public void Dispose()
    {
        Unregister();
        if (Handle != IntPtr.Zero) DestroyHandle();
    }
}

// =====================================================================
//  Settings (JSON in %APPDATA%\Vell\settings.json)
// =====================================================================

public sealed class AppSettings
{
    public const double DefaultIntensity = 0.4;

    public bool Enabled { get; set; } = true;
    public double Intensity { get; set; } = DefaultIntensity;
    public double[] Presets { get; set; } = { 0.30, 0.55, 0.80 };

    public int HotKeyVk { get; set; } = (int)Keys.B;
    public int HotKeyMods { get; set; } = HotKeyWindow.MOD_CONTROL | HotKeyWindow.MOD_ALT;
    public bool HotKeyEnabled { get; set; } = true;

    private static string SettingsPath
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "Vell");
            Directory.CreateDirectory(dir);
            return Path.Combine(dir, "settings.json");
        }
    }

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(SettingsPath))
            {
                var json = File.ReadAllText(SettingsPath);
                var s = JsonSerializer.Deserialize<AppSettings>(json);
                if (s != null)
                {
                    // Backfill if file is from older version
                    if (s.Presets == null || s.Presets.Length != 3)
                        s.Presets = new double[] { 0.30, 0.55, 0.80 };
                    return s;
                }
            }
        }
        catch { /* fall through to defaults */ }
        return Defaults();
    }

    public static AppSettings Defaults() => new AppSettings();

    public void Save()
    {
        try
        {
            var json = JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsPath, json);
        }
        catch { /* best effort */ }
    }
}
