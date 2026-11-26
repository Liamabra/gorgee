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
- [x] Prototype Foundation Models : disponible, vision active, ~0,9 s par image ; couleur juste (eau / cola / jus), niveau non fiable sur photos web
- [x] Prototype caméras : seule la FaceTime intégrée (`bltn`) ; pas de caméra virtuelle installée pour tester
- [x] Machine à états de la gorgée : montrer, boire, reposer, remontrer (TDD)
- [x] Refus consécutifs, déclaration manuelle payée par un joker, ancien état toujours lisible (TDD)
- [x] Politique caméra : intégrée, USB, Continuity ; le reste refusé (TDD)
- [x] Géométrie « main à la bouche + tête inclinée » (TDD)
- [x] Cible `GorgeeDetection` : analyse Vision d'une image, juge Foundation Models, relecture de clips
- [x] App : session caméra à la demande, panneau de preuve, raccourci ⌃⌥G, ouverture automatique
- [x] Suspension de la sécheresse pendant une visio
- [x] Permission caméra FR/EN + droit `device.camera` (runtime durci)
- [x] Fumée : vidéo fixe de cola → refus « liquide coloré » ; verre d'eau → accepté, attend la gorgée
- [ ] Vérification avec les clips de l'utilisateur (voir `Fixtures/README.md`)
- [ ] Vérification en direct par l'utilisateur : eau validée, verre vide et café refusés, FaceTime suspend la sécheresse

## M3 — Quantité
- [x] Contenance réglable (lecture tolérante des anciens réglages) (TDD)
- [x] Volume crédité = contenance × baisse du niveau, au moins un quart de verre (TDD)
- [x] A : après une preuve validée, l'utilisateur choisit la quantité bue (100 / 150 / 250 / 330 / 500 mL, plafonnée à la contenance) — remplace le quart de verre par défaut (« 63 mL » faux)
- [ ] **B : mesurer la quantité avec un modèle entraîné sur le verre de l'utilisateur** (~3–4 h de code + ~1 h de photos)
  1. Mode « photos du verre » : l'app range les photos par niveau (vide, ¼, ½, ¾, plein) — ~45 min
  2. Recadrage automatique du verre autour de la main (Vision) — ~1 h, étape risquée (+1–2 h si besoin)
  3. Classifieur d'images Create ML à 5 niveaux — ~15 min
  4. Branchement dans la preuve, en remplaçant le niveau lu par Foundation Models (garder `SipCredit.milliliters`) — ~1 h
  5. Mesure de la précision sur les photos de l'utilisateur et réglages — ~1 h
  Pistes lues : LCDTC (5 niveaux, verres du quotidien), LabLiquidVolume, YOLOv8 fioles ; éviter Ultralytics (AGPL).

## M4 — Historique
- [x] Totaux par jour, série de jours réussis (TDD)
- [x] Export CSV (heure locale) et JSON (TDD)
- [x] Fenêtre Historique : aujourd'hui, série, courbes 7 / 30 jours avec ligne d'objectif, export
- [x] « Bu ailleurs… » dans le menu (compte dans le total, pas dans la dette)
- [x] Textes FR/EN (84 chaînes, pluriel pour la série)

## M5 — Widget
- [ ] Bloqué : il faut une identité de signature (App Group). À faire après l'ajout de l'identifiant Apple dans Xcode.

## Journal des décisions

- Ruling: le suivi vit dans `tasks/todo.md` (exigé par le CLAUDE.md du projet) plutôt que dans l'espace `.superpowers/sdd` — le plan est découpé en jalons et non en tâches au format des scripts — coût si faux : aucun, le suivi reste en un seul endroit.
- Ruling: travail direct sur `main` — dépôt neuf, aucune branche à protéger — coût si faux : nul tant que personne d'autre ne contribue.
- Ruling: signature ad hoc par défaut, équipe Apple via `Config/Local.xcconfig` ignoré par git — aucune identité installée et l'identifiant d'équipe n'a pas sa place dans un dépôt public — coût si faux : la caméra redemandera sa permission à chaque build tant que l'identité manque.
- Ruling: la cible `GorgeeDetection` sera créée en M2 — une cible vide ne compile pas — coût si faux : aucun.
- Ruling: craquelures remplacées par un sol de plaques d'argile (Voronoï) qui couvre tout l'écran à 100 % — les marches aléatoires ressemblaient à des racines et ne rendaient pas l'écran inutilisable — coût si faux : retour à un style plus discret, la logique de sévérité ne change pas.
- Ruling: LaunchAgent classique écrit dans `~/Library/LaunchAgents` plutôt que `SMAppService` — fonctionne sans identité de signature, testé avec `kill -9` — coût si faux : l'app apparaît comme « développeur non identifié » dans les éléments d'ouverture.
- Ruling: protection désactivée par défaut en Debug, activée en Release — sinon chaque build relancerait l'ancienne version — coût si faux : aucun en usage réel.
- Ruling: overlay au niveau 24 (barre de menus) et non « économiseur d'écran » — garde le menu de Gorgée et ses fenêtres au-dessus — coût si faux : les menus et panneaux système passent au-dessus de la sécheresse.
- Ruling: un refus « aucun récipient vu » ne compte pas dans les 3 refus — sinon mimer ou laisser expirer la caméra automatique débloquerait la déclaration manuelle — coût si faux : un utilisateur sans verre visible doit réessayer davantage.
- Ruling: en M2, chaque gorgée vérifiée crédite 250 mL fixes — la mesure du niveau arrive en M3 — coût si faux : crédit inexact jusqu'à M3.
- Ruling: sans Apple Intelligence, preuve par le geste seul (tout récipient accepté) — repli prévu au plan — coût si faux : le cola passe sur ces Mac-là.
- Ruling: sans baisse de niveau visible, une gorgée vérifiée crédite un quart de la contenance — le modèle lit mal le niveau sur photos — coût si faux : sous-crédit jusqu'à ce que les clips permettent d'affiner.
- Ruling: la série se mesure avec l'objectif actuel, pas celui de chaque jour passé — l'objectif change rarement — coût si faux : une série recalculée après un changement de poids.
- Ruling: le widget (M5) est reporté — il exige une identité de signature pour l'App Group, absente — coût si faux : aucun, la jauge de la barre de menus couvre le besoin.
- Ruling: la quantité est déclarée après une preuve validée (choix de l'utilisateur, option A) — le modèle d'Apple lit mal le niveau — coût si faux : on peut exagérer, dans la limite de la contenance.
- Ruling: fermer le panneau sans choisir de quantité n'enregistre rien — pas de valeur inventée — coût si faux : une gorgée validée perdue si on ferme trop vite.
- Ruling: le shader est compilé au lancement depuis son code source — la compilation au build exige la « Metal Toolchain », téléchargement séparé d'Xcode 27 — coût si faux : ~100 ms au premier affichage, erreurs de shader visibles seulement à l'exécution (couvertes par l'aperçu de debug).
- Ruling: la zone encore humide reste transparente (vrai écran, sans latence) ; la copie capturée n'apparaît que là où le sol sèche ou dès que le mirage commence (30 %) — coût si faux : le blocage commence un peu plus tard.
- Ruling: capture en panne ou sans image → retour automatique à l'argile peinte — la sécheresse ne disparaît jamais — coût si faux : aucun.
- Ruling: le temps où l'app est morte compte comme actif (plafonné à 60 s par tick) — tuer l'app ne doit pas effacer la dette — coût si faux : quelques mL de trop après un plantage.
## M6 — Déformation réelle de l'écran (comme Ghostty Blackhole)
Décidé le 26/11 : le contenu de l'écran est capturé, tordu puis avalé par le sol sec ; clics et clavier passent toujours ; aucune zone épargnée.
- [x] 1. Exposer la grille du sol craquelé pour le GPU (TDD : le germe le plus proche est toujours dans les 3×3 cases voisines) — ~20 min
- [x] 2. Shader Metal : éclats de plaques qui décalent le contenu, contenu aspiré dans les fissures, mirage de chaleur, argile qui recouvre — ~1 h 30
- [x] 3. Aperçu PNG hors écran sur le faux bureau (`-GorgeeRenderPreview`, fichiers `warp-*.png`) — look à valider par l'utilisateur
- [x] 4. Capture ScreenCaptureKit par écran, sans les fenêtres de Gorgée, seulement pendant la sécheresse — ~2 h
- [x] 5. Affichage Metal dans l'overlay ; repli sur le rendu peint si la permission est refusée — ~1 h
- [x] 6. Permission « Enregistrement de l'écran » (demande, bouton dans le menu), textes FR/EN — ~45 min
- [ ] 7. Vérification en direct par l'utilisateur (lisibilité, latence, charge GPU)

## Revue finale (agent indépendant, tout le dépôt)

- Final: fixed proof bloquée après un refus de caméra ou sans caméra — `show()` relance dès qu'aucune preuve ne tourne, « Réessayer » et « Ouvrir les réglages » proposés — vérifié par build (pas de cible de tests UI).
- Final: fixed caméra suspendue (capot fermé) — filtrée ; aucune image en 8 s → « pas de caméra », ce qui ouvre la déclaration manuelle — vérifié par build.
- Final: fixed panne du juge déguisée en « pas de verre » — `ProofRunnerTests` RED→GREEN ; l'app passe en « modèle indisponible » et ouvre la déclaration manuelle.
- Final: fixed seuil abaissé qui effaçait la dette — `loweringThresholdKeepsDebt` RED→GREEN.
- Final: fixed réglages qui desserraient l'étau sur-le-champ — `scheduledSettingsApplyTomorrow`, `pendingSettingsPersist` RED→GREEN ; immédiat seulement pendant la première configuration.
- Final: fixed geste seul (sans Apple Intelligence) qui créditait un quart de grand verre pour une main vide — crédit fixe de 100 mL — vérifié par build.
- Final: fixed README qui compilait la configuration Debug — passe en Release.
- Final: fixed voyage vers l'ouest qui remettait la journée à zéro — `travellingWestKeepsTheDay` RED→GREEN (jour ancré à midi) ; calendrier `autoupdatingCurrent`.
- Final: fixed fichier d'état illisible écrasé en silence — `corruptedFileIsSetAside` RED→GREEN.
- Final: fixed gorgée perdue après une ligne tronquée — `appendAfterTornLineKeepsNextEvent` RED→GREEN ; total du jour calculé depuis le journal.
- Final: fixed (regradé Important) panneau automatique qui volait la frappe — ouverture sans prise de focus.
- Final: fixed (regradé Important) poussière animée en continu — en pause pendant l'inactivité, rien quand il n'y a aucun grain.
- Suite : 92 tests verts ; builds Debug et Release sans avertissement.
- Final: minor (deferred): `CameraController.start()` configure la session sur le fil principal (bref gel) ; course possible si on ferme puis rouvre pendant la première demande d'autorisation.
- Final: minor (deferred): Debug et Release partagent identifiant, préférences et libellé du LaunchAgent.
- Final: minor (deferred): `state.json` réécrit toutes les 5 s.
- Final: Ruling: une app qui utilise la caméra (Photo Booth) suspend la sécheresse — prévu par la spec — coût si faux : une échappatoire, connue.
- Final: Ruling: sans caméra autorisée, 2 déclarations par jour restent possibles — c'est le budget de jokers — coût si faux : 2 gorgées sans preuve par jour.
