# Gorgée

*A macOS menu-bar app that dries out your screen until you drink a glass of water.*

Gorgée assèche ton écran tant que tu n'as pas bu. Plus tu travailles sans boire, plus il se couvre de sable, de craquelures et de poussière, jusqu'à devenir inutilisable. Bois un verre d'eau devant la caméra et l'eau ruisselle pour tout réparer.

Inspiré de [Ghostty Blackhole](https://github.com/s0xDk/ghostty-blackhole), version hydratation.

> **État : en construction.** Sécheresse et preuve par caméra fonctionnent ; quantité mesurée, historique et widget arrivent.

## Comment ça marche

- **Objectif du jour** : `max(2,5 L homme / 2 L femme, poids × 35 mL homme / 31 mL femme)`.
- **Dette** : elle monte pendant que tu utilises activement le Mac dans ta plage horaire (8 h – 22 h par défaut), au rythme de ton objectif. Elle est gelée quand tu t'absentes et remise à zéro chaque matin.
- **Sécheresse** : premiers signes à 250 mL de dette, écran inutilisable à 750 mL. Rien n'est vraiment ralenti, et tes clics passent toujours au travers.
- **Preuve** : ⌃⌥G (ou le menu) ouvre la caméra ; elle s'ouvre aussi seule quand la sécheresse s'aggrave. Montre ton verre d'eau, bois tête inclinée, repose-le, remontre-le. Vision et le modèle embarqué d'Apple jugent le geste et la couleur du liquide : tout se passe sur ton Mac, aucune image n'est envoyée ni enregistrée.
- **Visio** : quand une autre app utilise la caméra, la sécheresse attend (la dette, elle, continue).
- **Jokers** : 2 par jour, pour suspendre la sécheresse 15 minutes.

## Compiler

Prérequis : macOS 27, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Gorgee.xcodeproj -scheme Gorgee -derivedDataPath build build
open build/Build/Products/Debug/Gorgee.app
```

Tests de la logique :

```sh
swift test --package-path Packages/GorgeeKit
```

Par défaut l'app est signée localement (ad hoc). Pour signer avec ton équipe Apple, crée `Config/Local.xcconfig` (ignoré par git) :

```
DEVELOPMENT_TEAM = TON_TEAM_ID
CODE_SIGN_IDENTITY = Apple Development
```

## Coupe-circuit

Gorgée se relance toute seule si on la tue. Pour l'arrêter pour de bon depuis un terminal :

```sh
launchctl bootout gui/$(id -u)/app.gorgee.Gorgee.agent
rm -f ~/Library/LaunchAgents/app.gorgee.Gorgee.agent.plist
killall Gorgee
```

## Licence

MIT
