// Preferences window: edit presets and customize the global hotkey.

using System.Globalization;

namespace Vell;

public sealed class PreferencesForm : Form
{
    private readonly TrayContext _tray;
    private readonly NumericUpDown[] _presetFields = new NumericUpDown[3];
    private Button _recorderButton = null!;
    private CheckBox _hotKeyEnabledBox = null!;
    private bool _recording;
    private int _capturedMods;
    private int _capturedVk;

    public PreferencesForm(TrayContext tray)
    {
        _tray = tray;
        Text = "Préférences";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = false;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(400, 320);
        KeyPreview = true;
        BuildUI();
        Refresh();
    }

    private void BuildUI()
    {
        var lblPresets = new Label
        {
            Text = "Préréglages (%)",
            Font = new Font(Font, FontStyle.Bold),
            Left = 20, Top = 20, Width = 360
        };
        Controls.Add(lblPresets);

        string[] labels = { "Léger", "Moyen", "Fort" };
        for (int i = 0; i < 3; i++)
        {
            int y = 50 + i * 32;
            var lbl = new Label { Text = labels[i], Left = 20, Top = y + 3, Width = 70 };
            var num = new NumericUpDown
            {
                Left = 100, Top = y, Width = 70,
                Minimum = 0, Maximum = 90, Value = 50, DecimalPlaces = 0
            };
            var pct = new Label { Text = "%", Left = 175, Top = y + 3, Width = 20 };
            Controls.Add(lbl); Controls.Add(num); Controls.Add(pct);
            _presetFields[i] = num;
        }

        var sep1 = new Label { Left = 20, Top = 155, Width = 360, Height = 1, BorderStyle = BorderStyle.Fixed3D };
        Controls.Add(sep1);

        var lblHk = new Label
        {
            Text = "Raccourci global",
            Font = new Font(Font, FontStyle.Bold),
            Left = 20, Top = 170, Width = 360
        };
        Controls.Add(lblHk);

        _recorderButton = new Button
        {
            Left = 20, Top = 195, Width = 160, Height = 28,
            Text = "Ctrl+Alt+B"
        };
        _recorderButton.Click += (_, _) => StartRecording();
        Controls.Add(_recorderButton);

        _hotKeyEnabledBox = new CheckBox
        {
            Text = "Activer", Left = 200, Top = 198, Width = 100,
            Checked = true
        };
        _hotKeyEnabledBox.CheckedChanged += (_, _) => HotKeyEnabledChanged();
        Controls.Add(_hotKeyEnabledBox);

        var help = new Label
        {
            Text = "Cliquez puis appuyez sur la combinaison souhaitée.",
            Left = 20, Top = 230, Width = 360, ForeColor = SystemColors.GrayText
        };
        Controls.Add(help);

        var sep2 = new Label { Left = 20, Top = 260, Width = 360, Height = 1, BorderStyle = BorderStyle.Fixed3D };
        Controls.Add(sep2);

        var resetBtn = new Button { Left = 20, Top = 275, Width = 160, Height = 30, Text = "Tout réinitialiser" };
        resetBtn.Click += (_, _) => ResetAllPressed();
        Controls.Add(resetBtn);

        var applyBtn = new Button { Left = 290, Top = 275, Width = 90, Height = 30, Text = "Appliquer" };
        applyBtn.Click += (_, _) => ApplyPressed();
        AcceptButton = applyBtn;
        Controls.Add(applyBtn);
    }

    private new void Refresh()
    {
        var s = _tray.Settings;
        for (int i = 0; i < 3; i++)
        {
            _presetFields[i].Value = (decimal)(s.Presets[i] * 100);
        }
        _hotKeyEnabledBox.Checked = s.HotKeyEnabled;
        _recorderButton.Text = _tray.HotKeyDisplay();
        _recorderButton.Enabled = s.HotKeyEnabled;
        _capturedMods = s.HotKeyMods;
        _capturedVk = s.HotKeyVk;
    }

    // ------------------------------------------------------------------
    //  Recording
    // ------------------------------------------------------------------

    private void StartRecording()
    {
        _recording = true;
        _recorderButton.Text = "Tapez la combinaison…";
        _recorderButton.Enabled = false;
        Focus();
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (_recording)
        {
            var key = keyData & Keys.KeyCode;
            // Ignore modifier-only presses
            if (key == Keys.ShiftKey || key == Keys.ControlKey || key == Keys.Menu ||
                key == Keys.LWin || key == Keys.RWin || key == Keys.None)
                return base.ProcessCmdKey(ref msg, keyData);

            int mods = 0;
            if ((keyData & Keys.Control) != 0) mods |= HotKeyWindow.MOD_CONTROL;
            if ((keyData & Keys.Alt) != 0)     mods |= HotKeyWindow.MOD_ALT;
            if ((keyData & Keys.Shift) != 0)   mods |= HotKeyWindow.MOD_SHIFT;
            if (mods == 0)
            {
                // require at least one modifier
                return true;
            }
            _capturedMods = mods;
            _capturedVk = (int)key;
            _recording = false;
            _recorderButton.Enabled = true;
            _recorderButton.Text = FormatCombo(mods, key);
            return true;
        }
        return base.ProcessCmdKey(ref msg, keyData);
    }

    private static string FormatCombo(int mods, Keys key)
    {
        var s = "";
        if ((mods & HotKeyWindow.MOD_CONTROL) != 0) s += "Ctrl+";
        if ((mods & HotKeyWindow.MOD_ALT) != 0)     s += "Alt+";
        if ((mods & HotKeyWindow.MOD_SHIFT) != 0)   s += "Shift+";
        s += key.ToString().ToUpperInvariant();
        return s;
    }

    private void HotKeyEnabledChanged()
    {
        _recorderButton.Enabled = _hotKeyEnabledBox.Checked;
    }

    // ------------------------------------------------------------------
    //  Apply / Reset
    // ------------------------------------------------------------------

    private void ApplyPressed()
    {
        var s = _tray.Settings;
        for (int i = 0; i < 3; i++)
        {
            s.Presets[i] = (double)_presetFields[i].Value / 100.0;
        }
        s.HotKeyMods = _capturedMods;
        s.HotKeyVk = _capturedVk;
        s.HotKeyEnabled = _hotKeyEnabledBox.Checked;
        s.Save();
        _tray.OnPreferencesChanged();
    }

    private void ResetAllPressed()
    {
        var r = MessageBox.Show(
            "Réinitialiser tous les réglages ?\n\nLes préréglages, le raccourci et l'intensité seront remis aux valeurs par défaut.",
            "Réinitialiser",
            MessageBoxButtons.OKCancel,
            MessageBoxIcon.Question);
        if (r == DialogResult.OK)
        {
            _tray.ResetAll();
            Refresh();
        }
    }
}
