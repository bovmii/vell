# Vell pour Windows

Version Windows de [Vell](https://github.com/bovmii/vell) — une petite app dans la **barre des tâches (system tray)** qui réduit l'intensité du point blanc de votre écran, à la manière de l'option *Accessibilité → Réduire le point blanc* sur iPhone.

## Fonctionnalités

- Icône dans le system tray (à côté de l'horloge)
- Sous-menu **Préréglages** rapides : Léger / Moyen / Fort
- **Intensité personnalisée…** : popup pour une valeur précise
- **Raccourci global** Ctrl+Alt+B par défaut (personnalisable dans Préférences)
- **Lancer au démarrage** en un clic
- Multi-écrans
- Réglages persistés dans `%APPDATA%\Vell\settings.json`
- Single-file `.exe` ~12 Mo, autonome (pas besoin d'installer .NET séparément)

## Installation rapide

1. Aller dans la dernière [release GitHub](https://github.com/bovmii/vell/releases/latest)
2. Télécharger **Vell.exe**
3. Le placer où tu veux (par ex. `C:\Program Files\Vell\Vell.exe` ou `Documents\Vell\Vell.exe`)
4. Double-cliquer pour lancer

Au premier lancement, **Windows SmartScreen** peut afficher :

> *« Windows a protégé votre PC. Microsoft Defender SmartScreen a empêché le démarrage d'une application non reconnue. »*

C'est normal (l'app n'est pas signée avec un certificat Authenticode). Pour l'autoriser :

1. Cliquer sur **Informations complémentaires**
2. Cliquer sur **Exécuter quand même**

L'app démarre, l'icône apparaît dans le system tray.

## Utilisation

**Clic droit sur l'icône** dans le system tray :

- ✓ Activé / Activé (toggle, raccourci par défaut Ctrl+Alt+B)
- Intensité : XX %  (lecture seule)
- Préréglages → Léger / Moyen / Fort
- Intensité personnalisée… (popup)
- Réinitialiser (40 %)
- Lancer au démarrage
- Préférences… (presets éditables + raccourci personnalisable)
- À propos…
- Quitter

## Compiler depuis les sources

Prérequis : [.NET 8 SDK](https://dotnet.microsoft.com/download).

```powershell
git clone https://github.com/bovmii/vell.git
cd vell/windows

# Optionnel : générer l'icône (sinon le .exe utilise l'icône par défaut)
magick icone.png -define icon:auto-resize=256,128,64,48,32,16 icone.ico

# Build
dotnet publish Vell.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true
```

Le `Vell.exe` se trouve dans `bin/Release/net8.0-windows/win-x64/publish/`.

## Désinstallation

1. Quitter l'app via le menu *Quitter*
2. Supprimer le `Vell.exe`
3. Supprimer le dossier de réglages : `%APPDATA%\Vell\`
4. Si "Lancer au démarrage" était activé, supprimer aussi l'entrée :
   - `regedit` → `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run` → supprimer la valeur **Vell**

## Comment ça marche

L'app utilise l'API GDI **`SetDeviceGammaRamp`** pour modifier la *table de gamma* de chaque écran branché. Plafonner la valeur maximale à, par exemple, 0,7, fait qu'un pixel "blanc pur" est rendu à 70 % de sa luminance normale. C'est exactement le même principe que la version macOS (`CGSetDisplayTransferByFormula`) et l'option *Reduce White Point* d'iOS.

À la fermeture, la gamma est restaurée à la normale.

## Licence

**PolyForm Noncommercial 1.0.0** (voir [LICENSE](../LICENSE)).

Vell est **100 % gratuit**. Vous pouvez l'utiliser, le modifier et le redistribuer gratuitement. La **vente est interdite**. Si vous voyez Vell en vente quelque part, signalez-le sur [Instagram @bovmii](https://instagram.com/bovmii).

Copyright © 2026 @bovmii.
