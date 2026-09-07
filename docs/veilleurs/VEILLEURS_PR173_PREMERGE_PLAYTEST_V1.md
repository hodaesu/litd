# LITD : Les Veilleurs — Protocole de playtest pré-fusion PR #173 v1

## Objet

Ce document est le **gate humain officiel** avant fusion de la PR #173 `feat(veilleurs): add content foundation v2`.

Il complète les validations automatiques déjà vertes. Il ne remplace ni les tests CI ni les futurs tests iPhone réels : il sert à vérifier ce que les smokes ne peuvent pas décider seuls — sensation de contrôle, lisibilité, cohérence des conséquences, difficulté vécue et compréhension du joueur.

Référence machine-readable : `res://data/veilleurs/qa/premerge_playtest_matrix_v1.json`.

## Périmètre

Le playtest couvre :

- la salle QA ;
- le combat tactique v0.6.1 ;
- le slice Khar-Sen `SLICE_KHAR_SEN_01` ;
- les quatre Veilleurs v0.6 canoniques : **Sahen Varo, Mira Sen, Narem Osh, Ysra Nahal** ;
- les intentions/télégraphes ;
- les blessures et conséquences corporelles ;
- la Rémanence Normal → Mémoriel → Vétéran → Élite → Némésis ;
- capture, ralliement et Refuge ;
- les cinq boss et leurs transitions ;
- sauvegarde/chargement ;
- équilibre et régressions critiques ;
- clavier/souris, manette et émulation tactile.

Les identités `Nayra Orun`, `Tarek Senn`, `Aïsha Maren` et `Idris Vael` sont des identités legacy et ne doivent pas réapparaître dans les données v0.6.

## Matériel / modes requis pour la PR #173

### Obligatoire

1. **Windows + clavier/souris**.
2. **Windows + manette**.
3. **Windows + émulation tactile / viewport mobile paysage** dans Godot.
4. Résolutions de contrôle :
   - 1280×720 ;
   - 1920×1080 ;
   - un viewport mobile paysage proche de 19.5:9 avec safe areas simulées.

### Non bloquant pour la fusion #173, mais bloquant pour l'alpha mobile

- test sur iPhone physique ;
- export iOS/Xcode ;
- profilage énergétique/thermique réel.

L'absence d'un Mac ne doit donc pas bloquer la fusion de la fondation de contenu #173. En revanche, aucune alpha mobile ne doit être déclarée prête sans test sur appareil réel.

## Règle de sévérité

- **BLOCKER** : crash, softlock, perte/corruption de sauvegarde, impossibilité de finir Khar-Sen, mauvais quatuor, boss recruté, Rémanence omnisciente, disparition d'une blessure/cicatrice qui devrait persister, action impossible à déclencher sur une interface obligatoire.
- **MAJOR** : mécanique centrale incorrecte ou incompréhensible, télégraphe après l'effet, contrôle tactile/manette inutilisable, phase de boss incohérente, capture confondue avec recrutement, stratégie dominante trivialisant une large part du slice.
- **MINOR** : défaut local non bloquant, texte/UI imparfait, animation ou transition gênante mais contournable.
- **POLISH** : cosmétique, confort ou finition sans incidence sur la compréhension/règle.

## Gate exact de fusion

La PR #173 est autorisée à fusionner uniquement si :

1. les quatre workflows GitHub de la tête testée sont verts ;
2. **0 BLOCKER ouvert** ;
3. **0 MAJOR reproductible** sur le chemin principal Khar-Sen, sauvegarde/chargement, contrôles, blessures, Rémanence, recrutement ou boss ;
4. 100 % des cas marqués `merge_blocking=true` dans la matrice ont un résultat `PASS` ;
5. les deux routes Khar-Sen ont été parcourues au moins une fois jusqu'à `KHAR_09` ;
6. une retraite a été effectuée puis un retour a confirmé la persistance attendue ;
7. un roundtrip sauvegarde → chargement a conservé état du groupe, blessures et données persistantes testées ;
8. les quatre Veilleurs ont chacun été joués activement et leur rôle reste distinct ;
9. aucun boss ne propose d'action de recrutement ;
10. aucune Némésis ne peut apparaître sans histoire partagée ;
11. la partie ne révèle pas une information canonique non observée par simple lecture omnisciente de l'IA ou des Archives ;
12. les contrôles clavier/souris, manette et tactile simulé permettent d'accomplir les actions obligatoires sans souris de secours.

Les MINOR/POLISH peuvent rester ouverts s'ils sont consignés et n'affectent pas les points ci-dessus.

---

# Session A — Préflight et salle QA

## A1. Démarrage

1. Lancer le projet avec Godot 4.3.
2. Ouvrir `res://scenes/qa/qa_validation_room.tscn`.
3. Vérifier absence de SCRIPT ERROR / crash.
4. Déplacer le groupe.
5. Tester dialogue.
6. Ouvrir le coffre et confirmer ajout du butin.
7. Déclencher le combat QA.
8. Utiliser un soin et une grenade.
9. Injecter Peur/Espoir/Folie.
10. Injecter `BLESSURE PERSISTANTE`.
11. Sauver un snapshot QA puis le recharger.

### PASS

La checklist intégrée doit valider déplacement, dialogue, coffre, butin, entrée/sortie de combat, consommables, psychologie, blessure, guidage par les cendres et sauvegarde/chargement.

### FAIL bloquant

Crash, softlock, snapshot invalide, blessure supprimée au chargement, combat impossible à quitter, interaction obligatoire inaccessible.

---

# Session B — Contrôles et UI

## B1. Clavier/souris

Tester : déplacement, sélection d'un Veilleur, sélection d'une compétence, cible, validation, annulation, inspection, pause, retour.

**PASS** : aucune action obligatoire ne demande plus de deux changements de contexte UI inutiles ; annuler revient toujours au contexte précédent sans perdre le tour.

## B2. Manette

Refaire le même parcours sans toucher à la souris.

**PASS** : focus toujours visible ; aucune boucle de focus ; aucune action obligatoire inaccessible ; le bouton retour annule avant de quitter un écran.

## B3. Tactile simulé

Tester en viewport mobile paysage avec safe areas.

**PASS** :

- aucune cible interactive essentielle sous une safe area ;
- aucun texte critique tronqué ;
- aucune action obligatoire nécessitant hover ;
- toucher une unité/compétence donne un retour visuel immédiat ;
- inspection et confirmation restent distinctes pour éviter les actions accidentelles ;
- l'UI reste jouable sans clavier.

## B4. Responsive

Passer 1280×720 → 1920×1080 → viewport mobile sans recharger la logique de partie.

**PASS** : aucun panneau obligatoire hors écran, aucun chevauchement empêchant une action, aucune information tactique importante perdue.

---

# Session C — Khar-Sen

Seed de référence : `606101`.

## C1. Route Archives

Parcours : `KHAR_01 → KHAR_02 → KHAR_03 → KHAR_05 → KHAR_06 → KHAR_07 ou KHAR_08 → KHAR_09`.

Vérifier :

- entrée/extraction à KHAR_01 ;
- combat narrow_lane KHAR_02 ;
- Archive `CODEX_REMANENCE_FIRST_TRACE` à KHAR_03 ;
- nœud Mémoriel KHAR_05 ;
- choix KHAR_06 ;
- objectif `recover_messenger_trace` KHAR_09.

## C2. Route Cour du sang sec

Parcours : `KHAR_01 → KHAR_02 → KHAR_04 → KHAR_05 → KHAR_06 → autre branche → KHAR_09`.

Vérifier le `corpse_field` de KHAR_04 et son impact réel sur la lecture/positionnement.

## C3. Embranchement KHAR_06

Prendre la gauche puis, sur un second run, la droite.

**PASS** : les deux routes sont valides et convergent vers KHAR_09 ; aucune route n'est un faux choix ou un cul-de-sac sans information.

## C4. Retraite

Retraiter depuis un nœud où l'extraction est autorisée, puis revenir.

**PASS** : les conséquences déjà ancrées restent présentes ; aucune restauration magique de blessures/cicatrices/objets persistants ; la progression ne devient pas incohérente.

## C5. Nœud Mémoriel KHAR_05

Rencontrer une entité déjà persistante quand disponible.

**PASS** : identité/histoire/blessures/relations restent cohérentes et le jeu ne remplace pas l'individu par un clone générique silencieusement.

---

# Session D — Les quatre Veilleurs

## Sahen Varo — briseur de lignes / gardien martial

Tester au moins : maintien de ligne, rupture/repositionnement ennemi, protection d'un allié.

**PASS** : son intérêt ne se réduit pas à infliger plus de dégâts qu'un autre Veilleur.

## Mira Sen — précision / mobilité / observation

Tester : ciblage précis, mobilité, observation d'une intention ou faiblesse.

**PASS** : la précision et l'information créent un avantage compréhensible sans omniscience.

## Narem Osh — bastion / protection / souffrance

Tester : garde, absorption/protection, maintien malgré blessure.

**PASS** : il protège réellement sans devenir invulnérable ni annuler les conséquences corporelles.

## Ysra Nahal — connaissance / Rémanence / psychologie

Tester : lecture d'intention, interaction avec Rémanence/psychologie, information partielle.

**PASS** : elle améliore la compréhension sans révéler automatiquement les informations non observées.

### Gate quatuor

Chaque Veilleur doit avoir au moins une situation où son rôle change la décision du joueur. Si un Veilleur est toujours remplaçable par une action générique plus forte, créer un MAJOR d'équilibrage/design.

---

# Session E — Intentions et connaissance

## E1. Télégraphes

Pour au moins huit actions ennemies appartenant à plusieurs familles d'intention :

1. observer l'état avant action ;
2. identifier ce que le jeu montre ;
3. laisser l'action se résoudre ;
4. comparer télégraphe et effet.

**PASS** : le télégraphe précède l'effet et ne ment pas. Il peut être incomplet, jamais volontairement faux sauf mécanique explicitement conçue et télégraphiée comme incertaine.

## E2. Lumière/perception

Rejouer avec visibilité réduite.

**PASS** : le détail affiché peut diminuer ; la connaissance stockée précédemment ne disparaît pas.

## E3. Archives

Vérifier Identité/Connaissance, Corps, Combat, Histoire, Traces.

**PASS** : une donnée non observée reste inconnue ; une donnée confirmée ne devient pas inconnue uniquement parce que la lumière baisse.

---

# Session F — Blessures et conséquences corporelles

## F1. Blessure persistante

Injecter ou subir une blessure sérieuse de bras.

Vérifier immédiatement, après combat, après retraite et après sauvegarde/chargement.

**PASS** : la blessure reste présente jusqu'à une vraie résolution prévue par le système ; son effet fonctionnel est cohérent avec la zone ; elle ne se transforme pas en simple malus abstrait sans trace corporelle.

## F2. Corps ennemi

Créer une blessure fonctionnelle sur un ennemi persistant puis le revoir.

**PASS** : la Rémanence conserve la blessure réelle ; aucune promotion de mémoire ne soigne gratuitement l'individu.

## F3. Cadavres / cicatrices

Quand un combat laisse cadavres/brisures/portes ou autres cicatrices ancrées, revenir plus tard.

**PASS** : le monde conserve les cicatrices prévues via flags/ancrages, sans snapshot complet de scène.

---

# Session G — Rémanence

## G1. Normal → Mémoriel

Créer un événement réellement vécu : survie, mutilation, fuite, capture échouée, objet important, retraite forcée ou rencontre répétée.

**PASS** : un simple spawn ne suffit pas ; l'individu Mémoriel possède une identité persistante et une histoire vérifiable.

## G2. Mémoriel → Vétéran

Lors d'une rencontre ultérieure, vérifier qu'un enseignement issu de l'événement vécu modifie une décision tactique.

**PASS** : l'adaptation porte sur ce qui a été vécu, pas sur le build global du joueur.

## G3. Vétéran → Élite

Vérifier qu'un enseignement vécu influence un allié/une formation/une logique de rencontre en utilisant les capacités que l'entité possède réellement.

**PASS** : pas de nouveau pouvoir gratuit uniquement parce que le rang devient Élite.

## G4. Élite → Némésis

Créer une histoire partagée forte puis une confrontation ultérieure.

**PASS** :

- aucune Némésis aléatoire sans histoire ;
- identité et blessures conservées ;
- pas de simple inflation de PV comme identité principale ;
- aucune lecture omnisciente du joueur.

---

# Session H — Capture, ralliement et Refuge

## H1. Capture ≠ recrutement

Mettre un ennemi ordinaire dans une situation de capture.

**PASS** : capturer ne transforme pas automatiquement l'individu en membre du Refuge.

## H2. Information UI

**PASS** : aucun pourcentage de capture n'est affiché. Montrer plutôt volonté, blessures, posture, relation et contexte de ralliement.

## H3. Ralliement

Rallier un ennemi admissible.

**PASS** : identité, blessures, traits, relations et histoire restent conservés ; aucun reset de blessure.

## H4. Capacité Refuge

Tester la limite correspondant à l'acte et le débordement.

**PASS** : quand la capacité est pleine, le nouveau recrutement est bloqué jusqu'à libération d'une place ; aucune suppression silencieuse d'un résident.

## H5. Boss

**PASS absolu** : aucun boss n'est recruté et aucune option UI ne doit laisser croire qu'il pourrait l'être.

---

# Session I — Boss

## I1. Ishar — test profond obligatoire

Jouer ses trois phases.

Vérifier :

- changement de méthode de franchissement en phase 1 ;
- mémoire limitée des familles d'actions en phase 2 ;
- refus télégraphié d'une préparation en phase 3 ;
- blessures et routes ouvertes persistantes ;
- aucune immunité finale cachée.

**PASS** : varier réellement les méthodes est plus efficace que répéter la même solution, sans rendre le boss omniscient.

## I2. Le Copiste — test profond obligatoire

Jouer ses quatre phases.

Vérifier : copie contextuelle, Correction, Palimpseste, synthèse finale.

**PASS** : il copie les habitudes/méthodes, pas les statistiques du joueur ; mutilations, morts et cicatrices lourdes ne sont pas réparés par Correction ; les versions de l'arène restent lisibles ; la phase 4 punit la routine sans interdire toute solution.

## I3. Trois autres boss — transitions obligatoires

Orateur Sans Voix, Mère des Veines et Porte-Cendres Blanc : franchir chaque transition de phase au moins une fois.

**PASS** : télégraphes compréhensibles, condition de transition atteignable, contre-jeu cohérent, aucune phase supplémentaire cachée et aucune option de recrutement.

---

# Session J — Sauvegarde / chargement

Créer un snapshot après :

- une blessure ;
- une modification Khar-Sen ;
- une connaissance acquise ;
- une identité Mémorielle si disponible.

Recharger.

**PASS** : mêmes identités, blessures, flags, cicatrices ancrées, connaissance et état pertinent. Aucun reroll silencieux d'une identité persistante.

---

# Session K — Équilibrage humain

Effectuer au minimum :

- 3 combats LOW ;
- 3 STANDARD ;
- 3 HIGH ;
- 2 runs Khar-Sen complets, un par branche KHAR_06 ;
- 1 run avec retraite volontaire ;
- 1 combat de boss Ishar ;
- 1 combat de boss Copiste.

Pour chaque combat relever :

- tours ;
- actions utilisées par Veilleur ;
- dégâts/blessures reçus ;
- consommables dépensés ;
- unités mises hors combat ;
- retraite oui/non ;
- action ou combo dominant ;
- moment de confusion éventuel.

### Heuristiques de MAJOR

Ouvrir un MAJOR si, de façon reproductible :

- une seule action/famille représente >60 % des actions efficaces et reste meilleure dans LOW, STANDARD et HIGH sans contrepartie ;
- un Veilleur n'a aucune décision propre utile ;
- un combat obligatoire devient pratiquement automatique sans lire les intentions ;
- une rencontre est impossible avec le groupe de départ en utilisant correctement les contre-jeux visibles ;
- la retraite est annoncée viable mais ne l'est pas réellement.

Ces seuils sont des détecteurs de problème, pas une promesse d'équilibrage final.

---

# Session L — Performance et stabilité

Sur PC de test :

- relever FPS moyen et minimum observé ;
- noter tout freeze > 100 ms perceptible en combat hors chargement ;
- répéter plusieurs transitions combat ↔ exploration ;
- faire au moins 10 sauvegardes/chargements QA au total de la campagne de test.

### Bloquant

- crash ;
- fuite de mémoire conduisant à dégradation continue visible ;
- freeze reproductible empêchant une action ;
- sauvegarde corrompue ;
- chute de performance liée à une mécanique précise au point de rendre le combat injouable.

Un objectif FPS matériel définitif sera fixé après établissement d'une machine de référence et des premiers profils sur mobile réel.

---

# Fiche de bug standard

Pour chaque défaut :

- ID : `VPR173-XXX` ;
- sévérité : BLOCKER / MAJOR / MINOR / POLISH ;
- scénario de matrice ;
- build/commit ;
- plateforme + résolution + périphérique ;
- seed ;
- étapes exactes ;
- résultat observé ;
- résultat attendu ;
- reproductibilité sur 3 essais ;
- capture vidéo/image si utile ;
- sauvegarde/snapshot si utile ;
- hypothèse facultative ;
- statut : OPEN / FIXED / RETEST / CLOSED.

## Règle de retest

Tout BLOCKER/MAJOR corrigé doit être retesté sur :

1. son scénario original ;
2. un scénario voisin ;
3. sauvegarde/chargement si l'état persiste ;
4. au moins deux modes d'entrée si l'UI/contrôle est concerné.

---

# Décision finale

### MERGE

Autorisé uniquement lorsque tous les gates bloquants ci-dessus sont PASS et que la tête testée conserve CI + Remanence + Balance + Tactical verts.

### NO MERGE

Un seul BLOCKER, ou un MAJOR reproductible sur un système central, suffit à empêcher la fusion.

### Après la fusion #173

Priorités PC suivantes :

1. corriger les MINOR les plus visibles ;
2. première passe art/audio réelle ;
3. profiling PC ;
4. export mobile de développement ;
5. playtest iPhone physique ;
6. budgets performance/thermique ;
7. itération tactile finale.
