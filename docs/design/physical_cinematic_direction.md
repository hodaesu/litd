# PASS 32 — Direction corporelle et cinématographique

## Intention

La mise en scène de Light in the Dark doit pouvoir raconter une scène même sans dialogue. Le corps, l'espace, la caméra et le son prolongent la direction dramatique existante au lieu d'ajouter des gestes décoratifs.

Ordre de travail : **objectif dramatique → rapport de pouvoir → blocking → écoute/réaction → action physique → beats → caméra → lumière/son → retour gameplay**.

## Physical Bible

`data/physical_bible.json` définit pour Darius, Aurélien, Malvor, Lysandra, la Goule affamée et le Témoin des Cendres une signature physique : centre corporel, posture neutre, poids, amplitude gestuelle, tempo, axes Laban, budget d'immobilité, regard, toucher, marche, arrêt, gestes de mains, équipement et modifications par peur, colère, fatigue, blessure ou perception altérée.

La règle centrale est qu'un personnage **fait quelque chose à quelqu'un ou au monde** avant de « montrer une émotion ». Une colère peut donc réduire le mouvement au lieu de l'augmenter ; une peur peut resserrer les choix spatiaux avant de provoquer une fuite.

## Langage non verbal et proxémie

`data/nonverbal_language_contract.json` décrit posture, poids, distance, orientation, regard, mains, toucher, immobilité, respiration, usage d'objet et trajectoire d'entrée/sortie.

`data/relationship_proxemics.json` définit les distances et changements d'axe entre les six paires du groupe principal. Les relations ne sont pas réduites à une distance fixe : confiance, tension, soin et rupture modifient la façon de partager un axe, un objet, une sortie ou un silence.

## Grammaire caméra

`data/cinematic_grammar.json` impose qu'un mouvement ou une coupe ait une raison narrative lisible. Le blocking est construit avant la shot-list. La caméra ne doit pas tourner autour de personnages parce qu'une conversation paraît statique ; elle change lorsqu'une information, une attention, un rapport de pouvoir ou une géométrie relationnelle change.

La continuité suit au minimum : regard, direction écran, côté de l'arme, main sur un objet, orientation du corps et trajectoire. Toute cinématique doit rendre le contrôle au joueur sur un axe lisible, dans un espace navigable et sans changement caché de ressources ou dégâts.

## Démo bloquée

`data/demo_cinematic_blocking.json` prépare six moments correspondant aux six sections de la démo : départ du Sanctuaire, entrée dans les Cendres, choix des survivants, fenêtre de capture de la Goule, reconnaissance du motif du Témoin et retour au Sanctuaire.

Chaque scène possède : objectif, statut avant/après, blocking, beats, corps, caméra, raison de caméra, lumière, son et handoff gameplay. Les répliques existantes sont liées à leur action dramatique et à la signature physique de leur personnage via `tools/cinematics/build_staging_plan.py`.

## Étude continue

`data/staging_study_protocol.json` permet de continuer à apprendre de cours de théâtre, réalisation cinéma et cinematic design. On n'archive ni clips, ni transcriptions, ni copie d'une performance identifiable : seulement des observations abstraites (action physique, statut, regard, immobilité, logique de caméra, réaction, handoff), ensuite reformulées dans un contexte original LITD.

## Validation PC

Le dépôt peut valider la cohérence des contrats et du plan, mais pas la vérité d'une animation ou d'un cadrage vu en mouvement. `tools/cinematics/staging_take_review.py` prépare donc une revue humaine des prises sur dix critères : objectif physique, identité corporelle, écoute, économie gestuelle, proxémie, blocking, motivation caméra, continuité, cohérence corps/voix/caméra et clarté du retour gameplay.

Une prise n'est jamais déclarée artistiquement validée par la CI.
