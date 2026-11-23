# Gorgée — suivi

Plan validé : `~/.claude/plans/j-ai-envie-de-cr-er-snug-bee-of-c17f7770-8f82-4bdc-88b5-9bdd8c608dca.md`

## M0 — Squelette
- [x] Ancienne app déplacée dans `legacy/`, `git init`
- [x] `.gitignore`, licence MIT, README avec coupe-circuit
- [x] `project.yml`, paquet `GorgeeKit`, app minimale
- [x] Build `xcodebuild` + `swift test` verts
- [x] Dépôt GitHub public `gorgee` créé et poussé (https://github.com/Liamabra/gorgee)
- [ ] Identité de signature (action de l'utilisateur : identifiant Apple dans Xcode)

## M1 — Sécheresse
- [x] Objectif journalier (TDD)
- [x] Moteur de dette : accumulation, plage, gel, plafond, sévérité (TDD)
- [x] Gorgées : remboursement, « bu ailleurs », changement de jour (TDD)
- [x] Jokers : pause 15 min (TDD)
- [x] Persistance JSON + journal des gorgées (TDD)
- [x] Sol craquelé déterministe : plaques de Voronoï qui sèchent depuis les bords (TDD)
- [x] Moniteur d'activité (inactivité + session verrouillée)
- [x] Overlay : une fenêtre par écran, niveau 24, clics traversants
- [x] Prototype flou (`CGSSetWindowBackgroundBlurRadius`) : l'appel réussit
- [x] Barre de menus : jauge, total, jokers, bouton provisoire « j'ai bu »
- [x] Réglages : profil, plage, seuils
- [x] Relance automatique (LaunchAgent) + « Quitter » protégé par une phrase
- [x] Textes FR/EN (40 chaînes, `fr.lproj` + `en.lproj`)
- [x] Debug : accélérateur, raccourci de secours ⌃⌥⇧D, rendu PNG hors écran
- [ ] Vérification visuelle par l'utilisateur (voir ci-dessous)

### Vérifié automatiquement (M1)
- 39 tests verts (`swift test --package-path Packages/GorgeeKit`), build sans avertissement.
- Rendus PNG à 5 / 25 / 50 / 75 / 100 % : liseré discret, gênant mais lisible, puis inutilisable.
- Dette gelée pendant l'inactivité réelle (1327 s sans saisie → 0 mL).
- Accumulation ×60 : 27,5 mL en 12 s (attendu 2,38 mL/s), plafond à 750 mL.
- `kill -9` → launchd relance (`runs = 2`), dette conservée (28,6 → 45,9 mL).
- Flou : rayon 0 → 20 suivant la sévérité, appel accepté par WindowServer.

### À vérifier par l'utilisateur (M1)
- [ ] Le flou est visible à l'écran au-delà de 35 % de sécheresse
- [ ] Une app en plein écran (Safari) reste cliquable sous la sécheresse
- [ ] Le menu de Gorgée et les réglages restent au-dessus de la sécheresse
- [ ] « Quitter » protégé : refusé sans la phrase, accepté avec

## M2 — Preuve par caméra
- [ ] (à détailler au début du jalon)

## M3 — Quantité · M4 — Historique · M5 — Widget
- [ ] (à détailler au début de chaque jalon)

## Journal des décisions

- Ruling: le suivi vit dans `tasks/todo.md` (exigé par le CLAUDE.md du projet) plutôt que dans l'espace `.superpowers/sdd` — le plan est découpé en jalons et non en tâches au format des scripts — coût si faux : aucun, le suivi reste en un seul endroit.
- Ruling: travail direct sur `main` — dépôt neuf, aucune branche à protéger — coût si faux : nul tant que personne d'autre ne contribue.
- Ruling: signature ad hoc par défaut, équipe Apple via `Config/Local.xcconfig` ignoré par git — aucune identité installée et l'identifiant d'équipe n'a pas sa place dans un dépôt public — coût si faux : la caméra redemandera sa permission à chaque build tant que l'identité manque.
- Ruling: la cible `GorgeeDetection` sera créée en M2 — une cible vide ne compile pas — coût si faux : aucun.
- Ruling: craquelures remplacées par un sol de plaques d'argile (Voronoï) qui couvre tout l'écran à 100 % — les marches aléatoires ressemblaient à des racines et ne rendaient pas l'écran inutilisable — coût si faux : retour à un style plus discret, la logique de sévérité ne change pas.
- Ruling: LaunchAgent classique écrit dans `~/Library/LaunchAgents` plutôt que `SMAppService` — fonctionne sans identité de signature, testé avec `kill -9` — coût si faux : l'app apparaît comme « développeur non identifié » dans les éléments d'ouverture.
- Ruling: protection désactivée par défaut en Debug, activée en Release — sinon chaque build relancerait l'ancienne version — coût si faux : aucun en usage réel.
- Ruling: overlay au niveau 24 (barre de menus) et non « économiseur d'écran » — garde le menu de Gorgée et ses fenêtres au-dessus — coût si faux : les menus et panneaux système passent au-dessus de la sécheresse.
- Ruling: le temps où l'app est morte compte comme actif (plafonné à 60 s par tick) — tuer l'app ne doit pas effacer la dette — coût si faux : quelques mL de trop après un plantage.