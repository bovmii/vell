# Vell

Une petite app menu-bar pour macOS qui **réduit l'intensité du point blanc** de votre écran, exactement comme l'option *Accessibilité → Affichage → Réduire le point blanc* sur iPhone, mais pour le Mac.

Utile pour la lecture nocturne, le confort sur écrans OLED, ou n'importe qui qui trouve les blancs purs trop agressifs même luminosité au minimum.

![menu](docs/screenshot.png)

## Fonctionnalités

- Vit dans la barre de menus (pas d'icône Dock)
- Slider d'intensité 0 → 90 %
- **Raccourci global ⌥⌘B** pour activer/désactiver
- Préréglages rapides (Léger / Moyen / Fort)
- Bouton Réinitialiser
- Lancer au démarrage en un clic
- Multi-écrans
- Préférences persistées entre les redémarrages
- ~250 lignes de Swift, zéro dépendance

## Installation via Terminal

Prérequis : macOS 13+ et les *Xcode Command Line Tools* (`xcode-select --install`).

```bash
# 1. Cloner le repo
git clone https://github.com/bovmii/vell.git
cd vell

# 2. Compiler
chmod +x build.sh
./build.sh

# 3. Installer dans /Applications
cp -R "build/Vell.app" /Applications/

# 4. Lancer
open "/Applications/Vell.app"
```

## Premier lancement : débloquer Gatekeeper

Vell n'est pas signée avec un Developer ID Apple (99 €/an), donc macOS affiche au premier lancement :

> *« Apple n'a pas pu confirmer que "Vell" ne contenait pas de logiciel malveillant. »*

Pas de panique, l'app est saine. Voici comment l'autoriser :

### Méthode 1 : Réglages Système (recommandée)

1. Sur la boîte de dialogue, cliquer **Terminé** (PAS « Placer dans la corbeille »).
2. Ouvrir **Réglages Système → Confidentialité et sécurité**.
3. **Défiler jusqu'en bas** de la page, dans la section *Sécurité*.
4. Un message indique : *« "Vell" a été bloqué car il ne provient pas d'un développeur identifié »*.
5. Cliquer **Ouvrir quand même**.
6. Authentifier avec Touch ID ou mot de passe.
7. Cliquer **Ouvrir** dans la dernière boîte de dialogue.

L'app démarre et tu ne reverras plus jamais cet avertissement.

### Méthode 2 : Terminal (la plus rapide)

```bash
xattr -dr com.apple.quarantine /Applications/Vell.app
open /Applications/Vell.app
```

Une seule commande retire le drapeau de quarantaine et Gatekeeper ne s'en mêle plus.

## Utilisation

Cliquez sur l'icône ☀️ dans la barre de menus :

- **Activé** : on/off (raccourci `⌥⌘B` global)
- **Slider** : intensité de 0 à 90 %
- **Préréglages** : valeurs prédéfinies
- **Lancer au démarrage** : pour ne plus y penser

## Désinstallation

```bash
cd vell
chmod +x uninstall.sh
./uninstall.sh
```

Le script :
- Quitte l'app
- La retire des *Login Items*
- Supprime `/Applications/Vell.app`
- Supprime les préférences (`~/Library/Preferences/com.bovmii.vell.plist`)

## Comment ça marche

L'app appelle `CGSetDisplayTransferByFormula` sur chaque écran branché pour plafonner la valeur RGB maximale. Plafonner le max à, disons, 0.7 fait qu'un pixel "blanc pur" est rendu à 70 % de sa luminance normale, c'est exactement ce que fait *Reduce White Point* sur iOS.

Quand vous quittez ou désactivez, `CGDisplayRestoreColorSyncSettings` remet l'écran dans son état normal.

## Structure du projet

```
Package.swift              Manifeste SwiftPM
Sources/Vell/
  main.swift               Point d'entrée
  AppDelegate.swift        Menu, slider, gamma, hotkey, login item
build.sh                   Compile + génère l'icône + crée le bundle .app
uninstall.sh               Désinstallation propre
icone.png                  Source de l'icône (2048×2048)
```

## Bugs, idées, contributions

Un bug, une idée, une PR ? :

- Ouvrir une [issue GitHub](https://github.com/bovmii/vell/issues)
- Me MP sur Instagram [@bovmii](https://instagram.com/bovmii)

## Licence

**PolyForm Noncommercial 1.0.0** (voir [LICENSE](LICENSE)).

Vell est **100 % gratuit**. Vous pouvez l'utiliser, le modifier, et le redistribuer **gratuitement**. Vous ne pouvez **pas** le vendre, ni vendre une version dérivée. Si vous trouvez Vell en vente quelque part, c'est du vol. Signalez-le sur [Instagram @bovmii](https://instagram.com/bovmii).

Copyright © 2026 @bovmii.

Créé par [@bovmii](https://github.com/bovmii).
