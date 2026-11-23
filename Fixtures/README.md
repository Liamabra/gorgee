# Clips de test du détecteur

Les clips vidéo vivent dans `Fixtures/clips/`, **ignoré par git** : ils te filment et ne quittent jamais ton Mac.

## Enregistrer

QuickTime Player → Fichier → Nouvel enregistrement vidéo, caméra FaceTime, 8 à 15 secondes par clip, cadrage habituel devant ton Mac.

Chaque clip suit le geste complet : montrer le verre à la caméra, boire 2 secondes tête inclinée, reposer, remontrer le verre.

## Nommer

Le nom annonce le verdict attendu :

| Nom | Situation |
|---|---|
| `ok-verre-plein.mov` | une vraie gorgée d'eau dans un verre transparent |
| `ok-bouteille.mov` | une vraie gorgée dans une bouteille transparente |
| `ok-gorgee-rapide.mov` | une gorgée courte mais réelle |
| `refus-noContainer-mime.mov` | le geste sans rien dans la main |
| `refus-emptyContainer-verre-vide.mov` | un verre vide |
| `refus-coloredLiquid-cola.mov` | du cola, du jus, du café… |
| `refus-opaqueLiquid-lait.mov` | du lait |
| `refus-opaqueContainer-mug.mov` | un mug ou une gourde opaque |
| `refus-noDrinkSeen-montre-seulement.mov` | montrer le verre sans boire |

Une vingtaine de clips suffit : variés en lumière, en verre et en position.

## Rejouer

```sh
swift test --package-path Packages/GorgeeKit --filter "Clips rejoués"
```

Chaque clip affiche son verdict ; un écart avec le nom fait échouer le test.
