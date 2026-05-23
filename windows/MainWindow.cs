// Fenêtre principale (GUI) avec les mêmes contrôles que le menu tray.

namespace Vell;

public sealed class MainWindow : Form
{
    private readonly TrayContext _tray;

    private Button _toggleButton = null!;
    private Label _intensityLabel = null!;
    private TrackBar _slider = null!;
    private Button[] _presetButtons = new Button[3];
    private Label _hotkeyHint = null!;

    private bool _suppressSlider;

    public MainWindow(TrayContext tray)
    {
        _tray = tray;
        Text = "Vell";
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        MinimizeBox = true;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(440, 340);
        Icon = TryGetTrayIcon();
        ShowInTaskbar = true;

        BuildUI();
        Refresh();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        // Au clic sur la croix, on cache la fenêtre au lieu de quitter l'app.
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            Hide();
        }
        else
        {
            base.OnFormClosing(e);
        }
    }

    private static Icon? TryGetTrayIcon()
    {
        try
        {
            var asm = System.Reflection.Assembly.GetExecutingAssembly();
            var res = asm.GetManifestResourceNames().FirstOrDefault(n => n.EndsWith("icone.png"));
            if (res == null) return null;
            using var s = asm.GetManifestResourceStream(res)!;
            using var bmp = new Bitmap(s);
            return Icon.FromHandle(bmp.GetHicon());
        }
        catch { return null; }
    }

    private void BuildUI()
    {
        BackColor = Color.White;

        // Header
        var title = new Label
        {
            Text = "Vell",
            Font = new Font("Segoe UI", 18, FontStyle.Bold),
            ForeColor = Color.FromArgb(40, 40, 60),
            Left = 24, Top = 18, AutoSize = true
        };
        var subtitle = new Label
        {
            Text = "@bovmii",
            Font = new Font("Segoe UI", 10),
            ForeColor = Color.FromArgb(120, 120, 140),
            Left = 26, Top = 52, AutoSize = true
        };
        Controls.Add(title);
        Controls.Add(subtitle);

        // Toggle button (large, prominent)
        _toggleButton = new Button
        {
            Left = 24, Top = 90, Width = 392, Height = 50,
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 12, FontStyle.Bold),
            TextAlign = ContentAlignment.MiddleCenter
        };
        _toggleButton.FlatAppearance.BorderSize = 0;
        _toggleButton.Click += (_, _) => { _tray.ToggleEnabled(); };
        Controls.Add(_toggleButton);

        _hotkeyHint = new Label
        {
            Left = 24, Top = 146, Width = 392, Height = 16,
            TextAlign = ContentAlignment.MiddleCenter,
            ForeColor = Color.FromArgb(140, 140, 160),
            Font = new Font("Segoe UI", 8)
        };
        Controls.Add(_hotkeyHint);

        // Intensity label + slider
        _intensityLabel = new Label
        {
            Left = 24, Top = 174, Width = 392, Height = 18,
            Font = new Font("Segoe UI", 10),
            ForeColor = Color.FromArgb(60, 60, 80)
        };
        Controls.Add(_intensityLabel);

        _slider = new TrackBar
        {
            Left = 22, Top = 194, Width = 396, Height = 36,
            Minimum = 0, Maximum = 90,
            TickFrequency = 10, SmallChange = 1, LargeChange = 10,
            TickStyle = TickStyle.None
        };
        _slider.ValueChanged += (_, _) =>
        {
            if (_suppressSlider) return;
            _tray.SetIntensity(_slider.Value / 100.0);
        };
        Controls.Add(_slider);

        // Preset buttons row
        var presetsLabel = new Label
        {
            Text = "Préréglages",
            Left = 24, Top = 232, Width = 200,
            Font = new Font("Segoe UI", 9, FontStyle.Bold),
            ForeColor = Color.FromArgb(60, 60, 80)
        };
        Controls.Add(presetsLabel);

        for (int i = 0; i < 3; i++)
        {
            int idx = i;
            var btn = new Button
            {
                Left = 24 + i * 132, Top = 254, Width = 124, Height = 32,
                FlatStyle = FlatStyle.Flat,
                Font = new Font("Segoe UI", 9)
            };
            btn.FlatAppearance.BorderSize = 1;
            btn.FlatAppearance.BorderColor = Color.FromArgb(220, 220, 230);
            btn.Click += (_, _) => _tray.ApplyPresetExternal(idx);
            _presetButtons[i] = btn;
            Controls.Add(btn);
        }

        // Bottom row
        var resetBtn = new Button
        {
            Left = 24, Top = 298, Width = 124, Height = 30,
            Text = "Réinitialiser",
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9)
        };
        resetBtn.FlatAppearance.BorderColor = Color.FromArgb(220, 220, 230);
        resetBtn.Click += (_, _) => _tray.ResetIntensityExternal();
        Controls.Add(resetBtn);

        var prefsBtn = new Button
        {
            Left = 156, Top = 298, Width = 124, Height = 30,
            Text = "Préférences…",
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9)
        };
        prefsBtn.FlatAppearance.BorderColor = Color.FromArgb(220, 220, 230);
        prefsBtn.Click += (_, _) => _tray.OpenPreferencesExternal();
        Controls.Add(prefsBtn);

        var aboutBtn = new Button
        {
            Left = 292, Top = 298, Width = 124, Height = 30,
            Text = "À propos…",
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 9)
        };
        aboutBtn.FlatAppearance.BorderColor = Color.FromArgb(220, 220, 230);
        aboutBtn.Click += (_, _) => _tray.ShowAboutExternal();
        Controls.Add(aboutBtn);
    }

    public new void Refresh()
    {
        var s = _tray.Settings;

        _toggleButton.Text = s.Enabled ? "✓ Activé" : "Désactivé";
        _toggleButton.BackColor = s.Enabled
            ? Color.FromArgb(115, 90, 190)
            : Color.FromArgb(220, 220, 230);
        _toggleButton.ForeColor = s.Enabled ? Color.White : Color.FromArgb(80, 80, 100);

        _hotkeyHint.Text = s.HotKeyEnabled
            ? "Raccourci : " + _tray.HotKeyDisplay()
            : "Raccourci désactivé";

        _intensityLabel.Text = $"Intensité : {(int)(s.Intensity * 100)} %";

        _suppressSlider = true;
        _slider.Value = (int)(s.Intensity * 100);
        _suppressSlider = false;

        string[] labels = { "Léger", "Moyen", "Fort" };
        for (int i = 0; i < 3; i++)
        {
            _presetButtons[i].Text = $"{labels[i]}\n{(int)(s.Presets[i] * 100)} %";
        }

        base.Refresh();
    }
}
