# Vell — Contexte pour Claude

Ce fichier sert de mémoire pour reprendre le projet dans une nouvelle session, peu importe où le dossier a été déplacé.

---

## 1. Vue d'ensemble

**Vell** est une app multiplateforme (macOS + Windows) qui **réduit l'intensité du point blanc** de l'écran, à la manière de l'option *Accessibilité → Affichage → Réduire le point blanc* sur iPhone.

- **Auteur** : Boumediene B. (`@bovmii` sur GitHub et Instagram, email `boumi311@yahoo.com`)
- **Repo GitHub** : https://github.com/bovmii/vell
- **Release stable** : v1.0 (`Vell.dmg` 2.9 Mo + `Vell.exe` 74 Mo)
- **Licence** : **PolyForm Noncommercial 1.0.0** — gratuit, revente interdite

### Principe technique

L'app cape la valeur maximale RGB envoyée à l'écran via la table de gamma système :

- **macOS** : `CGSetDisplayTransferByFormula(display, 0, cap, 1, …)` sur chaque écran branché. `cap = 1 - intensité`.
- **Windows** : `SetDeviceGammaRamp(hdc, &ramp)` sur chaque `DISPLAY_DEVICE` actif. Ramp linéaire de 0 à `cap*65535`.

Au quit, la gamma est restaurée (`CGDisplayRestoreColorSyncSettings` / `Apply(1.0)`).

---

## 2. Structure du dossier

```
.
├── CLAUDE.md                       ← ce fichier
├── README.md                       Doc principale FR (mac + windows)
├── LICENSE                         PolyForm Noncommercial 1.0.0 + notice anti-revente
├── .gitignore
├── icone.png                       Icône source 2048×2048 (utilisée par les deux ports)
│
├── Package.swift                   Manifeste SwiftPM
├── Sources/Vell/
│   ├── main.swift                  Entry point macOS (7 lignes)
│   └── AppDelegate.swift           639 lignes — toute la logique macOS
├── build.sh                        Compile Swift + génère .icns + crée bundle .app + DMG
├── make_dmg_background.swift       Génère l'image de fond du DMG (Swift + CoreGraphics)
├── uninstall.sh                    Désinstalle complètement (Mac)
│
├── windows/
│   ├── Vell.csproj                 Projet .NET 8 WinForms
│   ├── app.manifest                Manifest Windows (DPI awareness)
│   ├── Program.cs                  647 lignes — entry + TrayContext + gamma GDI + hotkey + settings
│   ├── MainWindow.cs               216 lignes — fenêtre GUI principale
│   ├── PreferencesForm.cs          204 lignes — fenêtre Préférences (presets + recorder de raccourci)
│   ├── README.md                   Doc spécifique Windows
│   └── icone.png                   Copie de l'icône source
│
└── .github/workflows/
    └── build-windows.yml           CI : compile sur Windows runner, upload artifact, attache à release
```

Dossiers ignorés par git : `.build/`, `build/`, `.swiftpm/`, `windows/bin/`, `windows/obj/`, `windows/publish/`.

---

## 3. Résumé fichier par fichier

### Racine — partagé / commun

#### `README.md`
Doc principale du repo, en français. Table à 2 lignes en haut listant macOS + Windows avec lien vers `windows/README.md`. Reste du fichier dédié à macOS (installation Terminal, déblocage Gatekeeper en 7 étapes, désinstallation, comment ça marche, licence). Inclut un screenshot mentionné (`docs/screenshot.png` — pas encore créé, à faire un jour).

#### `LICENSE`
Texte intégral de **PolyForm Noncommercial 1.0.0** + une notice en bas :
> *Vell est Copyright (c) 2026 Boumediene B. (@bovmii). Free, noncommercial only. Selling strictly prohibited.*

#### `icone.png`
2048×2048 RGBA. Source unique de toutes les déclinaisons d'icône. Le carré arrondi avec un demi-cercle blanc dessus.

### macOS — Swift / Cocoa

#### `Package.swift`
Manifeste SwiftPM minimal. Target executable `Vell`, macOS 13+.

#### `Sources/Vell/main.swift`
7 lignes. Crée l'app, set policy `.accessory` (pas d'icône Dock), lance.

#### `Sources/Vell/AppDelegate.swift`  ⭐ fichier principal Mac
639 lignes. Tout est dedans :

- **Constante `kVellCopyright`** au top — embedée dans le binaire, loggée au démarrage, dissuasion anti-revente.
- **Modificateurs helpers** (`carbonMods`, `nsMods`, `displayString`) pour convertir entre flags AppKit et flags Carbon.
- **`AppDelegate`** :
  - Refs persistantes vers items du menu (`enabledItem`, `intensityLabel`, `slider`, `loginItem`, `presetSubmenu`) — **important : on mute les items en place, on ne reconstruit JAMAIS le menu pendant son ouverture** (sinon le slider freeze).
  - 4 refresh helpers : `refreshEnabledItem`, `refreshIntensityLabel`, `refreshLoginItem`, `refreshPresetSubmenu`.
  - Storage des prefs dans `UserDefaults` avec clés `"intensity"`, `"enabled"`, `"preset0/1/2"`, `"hotKeyCode/Mods/Char/Enabled"`.
  - Gamma : itère sur `CGGetOnlineDisplayList`, appelle `CGSetDisplayTransferByFormula` avec `cap = isEnabled ? 1-intensity : 1`.
  - Login item : `SMAppService.mainApp` (macOS 13+).
  - Hotkey : Carbon `RegisterEventHotKey` + handler dans une `InstallEventHandler`. ID signature `'VELL'`.
  - About : NSAlert avec 3 boutons (OK / Ouvrir GitHub / Ouvrir Instagram).
- **`PreferencesWindow`** (NSWindow custom) :
  - 3 champs `NSTextField` pour les presets (avec `field.cell?.sendsActionOnEndEditing = true` — mais on a aussi un bouton Appliquer explicite).
  - Bouton recorder de raccourci : utilise `NSEvent.addLocalMonitorForEvents(.keyDown)`, force `makeFirstResponder(nil)` et `NSApp.activate` avant pour fiabilité.
  - Checkbox "Activer le raccourci".
  - Bouton "Tout réinitialiser" en bas à gauche (confirme via NSAlert), "Appliquer" en bas à droite (Entrée).
  - `windowWillClose` nettoie le monitor et force end-editing.

#### `build.sh`
139 lignes. Pipeline :
1. `swift build -c release --arch arm64 --arch x86_64` (universal binary, sortie dans `.build/apple/Products/Release/Vell`).
2. **Icône** : génère 12 PNG (16/32/64/128/256/512 + @2x) en faisant un sips zoom à 115% puis crop centré → bordures blanches éliminées. Puis `iconutil -c icns`.
3. Bundle `.app` : `Contents/MacOS/Vell`, `Contents/Resources/AppIcon.icns`, `Info.plist` (LSUIElement=true, version 1.0, copyright noncommercial).
4. `codesign --sign -` (ad-hoc).
5. **DMG** :
   - Mode UDRW d'abord, mounted.
   - Génère le fond avec `swift make_dmg_background.swift`.
   - Copie le PNG dans `.background/bg.png` du DMG.
   - **AppleScript Finder** : taille fenêtre `{200,200,720,540}` (520×340), icon size 112, set background picture via HFS path `.background:bg.png`, positions `Vell.app {140,150}` et `Applications {380,150}`.
   - Convert UDZO compressé.

⚠️ Si le `codesign` ou l'AppleScript échoue intermittently, lancer `killall Finder` puis relancer. Le bg.png chemin sensible : utiliser `file ".background:bg.png"`, pas `POSIX file`.

#### `make_dmg_background.swift`
108 lignes. Script Swift qui dessine le fond du DMG en CoreGraphics :
- 520×340 PNG.
- Dégradé lavande → bleu pâle (top-left vers bottom-right).
- Titre haut centré : *"Glissez Vell dans Applications"* (Segoe-ish, semibold, couleur violet sombre).
- Flèche violette horizontale entre l'icône Vell (x=210) et Applications (x=320), à la hauteur des icônes (y=H-150). Trait épaisseur 5 (`.butt` cap pour éviter le débord), triangle de tête 18×11 dessiné séparément. Le trait s'arrête à la base du triangle.
- Texte de licence en bas centré : *"Vell est 100 % gratuit. Licence PolyForm Noncommercial 1.0.0. Revente interdite. Copyright © 2026 @bovmii · github.com/bovmii · instagram.com/bovmii"*.

Lancé par `build.sh` : `swift make_dmg_background.swift "${DMG_STAGE}/.background/bg.png"`.

#### `uninstall.sh`
Quitte Vell, retire du login item (`osascript -e "tell System Events to delete login item"`), supprime `/Applications/Vell.app`, `defaults delete com.bovmii.vell`, supprime le `.plist`.

### Windows — C# .NET 8 / WinForms

#### `windows/Vell.csproj`
Projet .NET 8 WinForms. Single-file self-contained win-x64. `ApplicationIcon` conditionnel (généré par le workflow). `EmbeddedResource icone.png` (chargé au runtime pour l'icône tray).

#### `windows/app.manifest`
Manifeste DPI per-monitor V2 + asInvoker (pas d'élévation admin).

#### `windows/Program.cs`  ⭐ fichier principal Windows
647 lignes. Tout en un :

- **`Program.Main`** : `Mutex` pour single instance, `Application.Run(new TrayContext())`.
- **`TrayContext : ApplicationContext`** :
  - Owner du `NotifyIcon` + `ContextMenuStrip`.
  - **Clic gauche** sur l'icône → ouvre le menu (via reflection sur `NotifyIcon.ShowContextMenu` private method). Important : c'est ce qui rend l'expérience similaire au menu bar Mac.
  - **Double-clic** → ouvre `MainWindow`.
  - Menu items : header "Vell @bovmii", **Afficher la fenêtre** (en gras), Activé (avec raccourci affiché à droite), Intensité (header lecture seule), Préréglages (submenu), Intensité personnalisée (popup NumericUpDown), Réinitialiser, Lancer au démarrage, Préférences, **Créer un raccourci sur le bureau**, À propos (MessageBox YesNoCancel = GitHub/Instagram/Close), Quitter.
  - Gamma sécurisée : `cap < 0.05` clampé à 0.05 (évite écran 100% noir).
  - Sync bidirectionnelle : `RefreshMainWindow()` appelé partout où le menu change, et inversement.
  - External wrappers (`ApplyPresetExternal`, `ResetIntensityExternal`, etc.) exposés pour `MainWindow` et `PreferencesForm`.
- **`GammaController`** : P/Invoke `gdi32.SetDeviceGammaRamp`, `user32.GetDC`/`ReleaseDC`/`EnumDisplayDevices`, `gdi32.CreateDC`/`DeleteDC`. Applique sur l'écran primaire ET tous les `DISPLAY_DEVICE_ATTACHED_TO_DESKTOP`.
- **`HotKeyWindow : NativeWindow`** : message-only window (parent `HWND_MESSAGE` = `-3`). P/Invoke `RegisterHotKey`/`UnregisterHotKey`. Constantes MOD_ALT/CONTROL/SHIFT/WIN.
- **`AppSettings`** : POCO JSON sérialisé dans `%APPDATA%\Vell\settings.json`. Defaults : intensity 0.4, presets `[0.30, 0.55, 0.80]`, hotkey Ctrl+Alt+B activé.

#### `windows/MainWindow.cs`
216 lignes. Form 440×340, FixedSingle, fond blanc :
- Header "Vell" + "@bovmii" en haut-gauche.
- Grand bouton toggle (392×50) qui change de couleur : violet `(115,90,190)` quand activé, gris quand désactivé.
- Texte "Raccourci : Ctrl+Alt+B" sous le bouton.
- Label intensité + `TrackBar` 0-90.
- 3 boutons préréglages multi-lignes (`"Léger\n30 %"`).
- Ligne du bas : Réinitialiser / Préférences… / À propos…
- `OnFormClosing` cancel sur `UserClosing` → la croix rouge cache la fenêtre, ne quitte pas l'app.

#### `windows/PreferencesForm.cs`
204 lignes. Form 400×320 :
- 3 `NumericUpDown` pour valeurs de presets en %.
- Bouton recorder de raccourci : override `ProcessCmdKey`, capture mods + keyCode, ignore les touches modificateurs seules.
- Checkbox "Activer".
- Boutons "Tout réinitialiser" (confirme via MessageBox OKCancel) + "Appliquer" (qui force `makeFirstResponder(null)` côté nous → en C# ça serait `ActiveControl = null`).

#### `windows/README.md`
Doc Windows-only en français : install via release, déblocage SmartScreen, utilisation menu/fenêtre, build depuis sources, désinstallation manuelle (delete exe + `%APPDATA%\Vell\` + entrée registre Run), licence.

#### `.github/workflows/build-windows.yml`
CI qui se déclenche sur push de `windows/**` ou `.github/workflows/build-windows.yml`, ou release published, ou workflow_dispatch. Sur runner `windows-latest` :
1. Checkout
2. Setup .NET 8 SDK
3. `magick icone.png -define icon:auto-resize=… icone.ico` (ImageMagick préinstallé sur runner)
4. `dotnet publish` avec single-file + self-contained + EnableCompressionInSingleFile + DebugType=embedded → ~74 Mo
5. Upload artifact `Vell-Windows`
6. Si event=release : attach à la release via `softprops/action-gh-release@v2`

---

## 4. Historique des décisions clés

1. **Nom** : "Vell" choisi (court, unique sur GitHub, sonne bien). Anciennes pistes rejetées : Voile, Lull, Pénombre, Halo.
2. **Pas d'em-dash `—`** dans le code/UI/README : l'utilisateur les trouve "trop AI". Remplacés partout par virgules ou points.
3. **Licence** : passée de MIT → **PolyForm Noncommercial 1.0.0** quand l'utilisateur a voulu interdire la revente. Marqueurs anti-vol embarqués : `kVellCopyright` dans le binaire Mac, `NSHumanReadableCopyright` dans Info.plist, About box, `<Copyright>` dans .csproj Windows.
4. **Menu Mac : mutation en place obligatoire**. Reconstruire le menu pendant qu'il est ouvert le ferme et bloque le slider. Bug corrigé en gardant des refs persistantes.
5. **DMG fancy** : fond avec dégradé + flèche + licence dessinée par `make_dmg_background.swift`, fenêtre 520×340, icônes 112px, image source zoom 115% pour combler les bords.
6. **Windows : clic gauche ouvre le menu** (via reflection sur `ShowContextMenu`) pour mimer le comportement menu bar Mac.
7. **Pas de Developer ID Apple ni de cert Authenticode** : trop cher (99 $/an + 250 $/an). Utilisateurs doivent débloquer manuellement Gatekeeper/SmartScreen au premier lancement. Instructions détaillées dans les README.
8. **Pas d'auto-updater** : pas implémenté. Mise à jour = remplacer le binaire à la main. Settings persistés (`UserDefaults` / `%APPDATA%\Vell\settings.json`) donc conservés.

---

## 5. Commandes utiles

```bash
# Build Mac complet (bundle .app + DMG)
./build.sh

# Installer Mac
killall Vell 2>/dev/null; rm -rf /Applications/Vell.app
cp -R "build/Vell.app" /Applications/ && open "/Applications/Vell.app"

# Désinstaller Mac
./uninstall.sh

# Build Windows : non, lancer le workflow CI (pas de dotnet local)
git push   # → déclenche build-windows.yml

# Watch CI
gh run watch $(gh run list --workflow="Build Vell for Windows" --limit 1 --json databaseId --jq '.[0].databaseId')

# Récupérer .exe construit
gh run download <ID> --repo bovmii/vell --name Vell-Windows -D /tmp/vell

# Push DMG/EXE dans release
gh release upload v1.0 build/Vell.dmg --clobber
gh release upload v1.0 /tmp/vell/Vell.exe --clobber
```

### Config git locale du repo

```
user.name = bovmii
user.email = boumi311@yahoo.com
```

(par-repo, pas global). **Pas de Co-Authored-By Claude dans les commits.**

---

## 6. TODO / pistes futures (si l'utilisateur demande)

- [ ] Screenshot dans `docs/screenshot.png` pour le README
- [ ] Auto-updater (Sparkle sur Mac, check GitHub Releases sur Windows)
- [ ] Code signing Developer ID Apple + notarization (99 $/an)
- [ ] Code signing Authenticode Windows (~250 $/an)
- [ ] Trimming Windows pour descendre sous 74 Mo (risqué avec WinForms reflection)
- [ ] Localisation EN/autres (actuellement tout en français)
- [ ] Plus de presets (5 au lieu de 3 ?)
- [ ] Mode "schedule" (activer auto à une heure précise type Night Shift)
- [ ] Icône custom pour le tray Windows (actuellement c'est `icone.png` converti à la volée, qualité moyenne)

---

## 7. Style et préférences de l'utilisateur

- **Langue** : français, ton informel ("mdr", "ça marche pas", "ouf"), tu peut utiliser des emojis sobres.
- **Préfère** : réponses courtes et action directe, code qui marche du premier coup.
- **Déteste** : em-dashes `—`, ton "AI-corporate", `Co-Authored-By: Claude` dans les commits, écrans trop blancs (raison d'être de l'app).
- **Veut** : autonomie max — l'utilisateur n'a pas envie de relancer 12 commandes, faire le moins de back-and-forth possible.
- **Signature** : `@bovmii` partout. Insta = Instagram. Contact = DM Instagram OU issue GitHub.
