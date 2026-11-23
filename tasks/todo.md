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
- [ ] Persistance JSON + journal des gorgées (TDD)
- [ ] Réseau de craquelures déterministe (TDD)
- [ ] Moniteur d'activité (inactivité + session verrouillée)
- [ ] Overlay : une fenêtre par écran, au-dessus du plein écran, clics traversants
- [ ] Prototype flou (`CGSSetWindowBackgroundBlurRadius`)
- [ ] Barre de menus : jauge, total, jokers, bouton provisoire « j'ai bu »
- [ ] Réglages : profil, plage, seuils
- [ ] Relance automatique (LaunchAgent) + « Quitter » protégé
- [ ] Textes FR/EN
- [ ] Debug : accélérateur de temps, raccourci de secours
- [ ] Vérification bout en bout M1

## M2 — Preuve par caméra
- [ ] (à détailler au début du jalon)

## M3 — Quantité · M4 — Historique · M5 — Widget
- [ ] (à détailler au début de chaque jalon)

## Journal des décisions

- Ruling: le suivi vit dans `tasks/todo.md` (exigé par le CLAUDE.md du projet) plutôt que dans l'espace `.superpowers/sdd` — le plan est découpé en jalons et non en tâches au format des scripts — coût si faux : aucun, le suivi reste en un seul endroit.
- Ruling: travail direct sur `main` — dépôt neuf, aucune branche à protéger — coût si faux : nul tant que personne d'autre ne contribue.
- Ruling: signature ad hoc par défaut, équipe Apple via `Config/Local.xcconfig` ignoré par git — aucune identité installée et l'identifiant d'équipe n'a pas sa place dans un dépôt public — coût si faux : la caméra redemandera sa permission à chaque build tant que l'identité manque.
- Ruling: la cible `GorgeeDetection` sera créée en M2 — une cible vide ne compile pas — coût si faux : aucun.
