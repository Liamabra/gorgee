# Gorgée

*A macOS menu-bar app that dries out your screen until you drink a glass of water.*

Gorgée assèche ton écran tant que tu n'as pas bu. Plus tu travailles sans boire, plus il se couvre de sable, de craquelures et de poussière, jusqu'à devenir inutilisable. Bois un verre d'eau devant la caméra et l'eau ruisselle pour tout réparer.

Inspiré de [Ghostty Blackhole](https://github.com/s0xDk/ghostty-blackhole), version hydratation.

> **État : en construction.** Sécheresse, preuve par caméra, quantité et historique fonctionnent ; le widget arrive.

Le build Debug sert au développement : protection anti-fermeture désactivée, accélérateur de temps et bouton pour masquer la sécheresse.

## Comment ça marche

- **Objectif du jour** : `max(2,5 L homme / 2 L femme, poids × 35 mL homme / 31 mL femme)`.
- **Dette** : elle monte pendant que tu utilises activement le Mac dans ta plage horaire (8 h – 22 h par défaut), au rythme de ton objectif. Elle est gelée quand tu t'absentes et remise à zéro chaque matin.
- **Sécheresse** : premiers signes à 250 mL de dette, écran inutilisable à 750 mL. Comme dans Ghostty Blackhole, le contenu de ton écran est réellement avalé : il ondule, se brise en éclats le long des fissures, puis disparaît sous l'argile. Rien n'est ralenti et tes clics passent toujours au travers.
- **Enregistrement de l'écran** : c'est ce qui permet de déformer le vrai contenu. La capture ne tourne que pendant la sécheresse, les images ne sont ni gardées ni envoyées. Sans cette permission, l'argile est simplement peinte par-dessus.
- **Preuve** : ⌃⌥G (ou le menu) ouvre la caméra ; elle s'ouvre aussi seule quand la sécheresse s'aggrave. Montre ton verre d'eau, bois tête inclinée, repose-le, remontre-le, puis indique combien tu as bu (jamais plus que la contenance de ton verre). Vision et le modèle embarqué d'Apple jugent le geste et la couleur du liquide : tout se passe sur ton Mac, aucune image n'est envoyée ni enregistrée.
- **Visio** : quand une autre app utilise la caméra, la sécheresse attend (la dette, elle, continue).
- **Jokers** : 2 par jour, pour suspendre la sécheresse 15 minutes ou déclarer une gorgée sans preuve (sans caméra, ou après 3 vrais refus).
- **Réglages** : après la première configuration, ils s'appliquent le lendemain, pour qu'on ne desserre pas l'étau en pleine sécheresse.
- **Historique** : total du jour, série de jours réussis, courbes 7 et 30 jours, export CSV et JSON. « Bu ailleurs » compte dans le total, pas dans la dette.

## Compiler

Prérequis : macOS 27, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Gorgee.xcodeproj -scheme Gorgee -configuration Release -derivedDataPath build build
open build/Build/Products/Release/Gorgee.app
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
