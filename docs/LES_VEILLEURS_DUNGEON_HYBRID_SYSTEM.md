# LITD : Les Veilleurs — Système définitif de création hybride des donjons

## Statut
Spécification de référence pour la génération des donjons de **LITD : Les Veilleurs**. Le système doit rester compatible mobile (iPhone/iPad) et PC, déterministe par seed, léger en mémoire et compatible avec la Rémanence.

## Principe
Un donjon n'est jamais généré comme un assemblage aléatoire pur. Il est construit en cinq couches :

1. **Intention authored** — identité du lieu, arc narratif, salles obligatoires, boss, découvertes majeures, sorties et contraintes de mise en scène.
2. **Graphe semi-procédural** — ordre et connexions entre modules, branches, boucles, raccourcis, secrets, retraites.
3. **Modules authored** — salles, corridors, escaliers, carrefours, arènes et espaces spéciaux dessinés à la main et validés artistiquement.
4. **Variation procédurale locale** — variantes internes d'un module : obstacles, effondrements, couvertures, pièges, ressources, éclairage, accès secondaires, positions de rencontre.
5. **Rémanence** — application de cicatrices persistantes issues des runs précédents sans sauvegarder des snapshots complets de scènes.

Le résultat doit conserver la lisibilité et la direction artistique d'un level design manuel tout en offrant une forte rejouabilité.

## Pipeline de génération

### Étape 1 — Seed de run
La seed de donjon est composée de :
- `campaign_seed`
- `dungeon_id`
- `visit_index`
- `difficulty_band`
- éventuellement un `story_epoch`

La seed NE doit PAS dépendre uniquement de `zone_id.hash()`. Une même zone doit pouvoir produire plusieurs configurations tout en restant reproductible à partir de la seed sauvegardée.

### Étape 2 — Contraintes authored
Le générateur charge le profil du donjon :
- nombre min/max de salles ;
- profondeur min/max ;
- salles obligatoires ;
- salle d'entrée ;
- salle de boss ou objectif final ;
- salles facultatives ;
- quota de secrets ;
- quota de boucles ;
- quota de raccourcis ;
- points de retraite ;
- rythme de danger ;
- budget de rencontres ;
- budget de ressources ;
- tags architecturaux et narratifs autorisés.

### Étape 3 — Construction du squelette critique
Créer d'abord le chemin critique :
`entrée -> progression -> tension -> pivot -> profondeur -> pré-boss -> boss/objectif`

Le chemin critique doit :
- rester toujours solvable ;
- ne jamais exiger un secret ;
- fournir au moins une possibilité de retraite physique avant le dernier tiers ;
- respecter la durée cible ;
- contenir les salles narratives obligatoires.

### Étape 4 — Branches et boucles
Ajouter ensuite :
- branches facultatives ;
- boucles revenant vers le chemin critique ;
- salles secrètes ;
- raccourcis ouvrables depuis le côté profond ;
- chemins de contournement de rencontres lorsqu'ils sont autorisés.

Le générateur doit privilégier les **boucles lisibles** plutôt que les culs-de-sac gratuits.

### Étape 5 — Sélection de modules authored
Chaque nœud du graphe reçoit un module compatible selon :
- rôle du nœud ;
- biome ;
- taille ;
- nombre et orientation des connecteurs ;
- étage/élévation ;
- tags narratifs ;
- tags de combat ;
- contraintes de caméra/isométrie ;
- budget de performance mobile.

Un module peut posséder plusieurs variantes artistiques partageant le même contrat de gameplay.

### Étape 6 — Assemblage spatial
Assembler les modules sans collision et en respectant :
- connecteurs compatibles ;
- largeur minimale de déplacement ;
- navigation ;
- caméra ;
- visibilité ;
- distances de combat ;
- budget de géométrie ;
- séparation des espaces de streaming si nécessaire.

En cas d'échec, le générateur retente un nombre borné de fois puis utilise un fallback authored valide.

### Étape 7 — Variation locale
Une fois la structure validée, chaque module reçoit une variation locale déterministe :
- obstacles ;
- objets destructibles ;
- couvertures ;
- pièges ;
- dangers environnementaux ;
- ressources ;
- cadavres ;
- traces ;
- positions de rencontres ;
- éclairage ;
- portes condamnées ;
- accès secondaires.

La variation locale ne doit jamais casser une sortie obligatoire ni rendre le graphe insoluble.

### Étape 8 — Rémanence
Appliquer ensuite les cicatrices persistantes correspondantes aux `anchor_id` présents dans la configuration générée.

Une cicatrice est une donnée compacte, par exemple :
- porte détruite ;
- pont effondré ;
- cadavre persistant ;
- sang ancien ;
- autel profané ;
- passage découvert ;
- raccourci ouvert ;
- barricade construite ;
- zone brûlée ;
- objet majeur récupéré ;
- marque d'une Némésis ;
- changement d'occupation ennemie.

Ne jamais stocker de scène complète. Sauvegarder seulement `anchor_id + scar_type + state + payload`.

### Étape 9 — Population dynamique
Les ennemis ne sont placés qu'après la géométrie et la Rémanence.

Le directeur de rencontres prend en compte :
- profondeur ;
- ressources restantes ;
- blessures du groupe ;
- historique des Veilleurs ;
- ennemis mémoriels présents ;
- faction dominante ;
- bruit/alerte ;
- salles déjà sécurisées ;
- budget de danger du profil.

### Étape 10 — Validation finale
Avant de rendre le donjon jouable, valider :
- entrée accessible ;
- objectif accessible ;
- chemin critique continu ;
- toutes les salles obligatoires présentes ;
- retraites fonctionnelles ;
- aucune porte obligatoire verrouillée par une ressource impossible ;
- nombre de branches dans les bornes ;
- aucun chevauchement spatial majeur ;
- navigation valide ;
- budget performance respecté ;
- Rémanence applicable sans casser la progression.

Si un test échoue, régénérer avec un `attempt_index` déterministe. Après N échecs, utiliser un fallback authored.

---

# Grammaire des salles

## Rôles principaux

### ENTRY
Zone d'entrée et d'observation. Toujours lisible, danger limité, possibilité de ressortir.

### TRANSIT
Couloir, galerie, escalier, pont, passage ou espace de respiration reliant les salles majeures.

### COMBAT
Salle conçue autour d'une rencontre tactique. Plusieurs configurations de couvertures et d'accès sont permises.

### CHOICE
Carrefour présentant au moins deux routes significatives.

### RESOURCE
Espace favorisant récupération, fouille ou préparation. Peut être risqué mais ne doit pas devenir automatiquement sûr.

### NARRATIVE
Salle de découverte, archive, vestige, scène environnementale ou événement philosophique.

### HAZARD
Salle dominée par un danger environnemental ou un piège systémique.

### PUZZLE
Obstacle basé sur observation, connaissance ou interaction avec le monde. Ne doit jamais bloquer définitivement le chemin critique sans solution garantie.

### REST
Point rare permettant un choix de récupération, préparation ou extraction partielle selon les règles du donjon.

### LOOP_GATE
Raccourci ou porte ouvrable depuis le côté profond créant une boucle permanente ou semi-permanente.

### SECRET
Contenu volontairement facultatif, jamais requis pour finir le donjon.

### ELITE
Salle pour Vétéran/Élite/Némésis ou rencontre à forte identité.

### BOSS
Arène authored et stable. Ses accès, zones de sécurité, sorties et volumes critiques ne sont jamais procéduraux au point de modifier la lisibilité du combat.

### EXIT
Sortie finale ou extraction physique.

---

# Contrat d'un module authored

Chaque module doit déclarer :
- `module_id`
- `role`
- `biome_tags`
- `theme_tags`
- `size_class`
- `connectors[]`
- `elevation_profile`
- `camera_profile`
- `combat_profile`
- `variation_slots[]`
- `scar_anchors[]`
- `encounter_anchors[]`
- `resource_anchors[]`
- `lore_anchors[]`
- `streaming_cost`
- `mobile_cost`
- `pc_detail_tier`

## Connecteurs
Un connecteur possède :
- type : door / corridor / stairs / ladder / breach / bridge / vertical_drop / secret ;
- orientation ;
- largeur ;
- hauteur ;
- niveau ;
- tags de compatibilité ;
- possibilité de verrouillage ;
- possibilité de devenir raccourci.

---

# Règles de branchement

Le graphe utilise quatre valeurs principales :
- `critical_length`
- `branching_target`
- `loop_target`
- `secret_target`

## Règles
1. Le chemin critique reste compréhensible sans minimap obligatoire.
2. Une branche facultative doit apporter au moins une valeur : ressource, lore, raccourci, secret, récompense, position tactique ou information.
3. Éviter plus de deux culs-de-sac non secrets dans un même étage.
4. Au moins une boucle significative par donjon moyen ou long.
5. Les raccourcis se déverrouillent préférentiellement depuis le côté profond.
6. Les secrets peuvent contourner une menace mais ne doivent jamais être nécessaires.
7. Une Némésis peut temporairement modifier une branche, mais pas rendre la seed insoluble.
8. Les salles de boss restent authored et leur topologie essentielle ne varie pas.

---

# Rémanence

## Modèle de données
Une cicatrice persistante est liée à un `scar_anchor_id` stable appartenant à un module logique, pas à une instance de scène complète.

Exemple :
```json
{
  "anchor_id": "accord.gallery_north_door",
  "scar_type": "destroyed_door",
  "state": "open_ruin",
  "created_on_run": 12,
  "source_entity_id": "nemesis_ghoul_0042",
  "payload": {
    "debris_level": 2
  }
}
```

## Priorité d'application
1. contraintes de campagne ;
2. modifications permanentes majeures ;
3. raccourcis découverts ;
4. traces de Némésis ;
5. cadavres persistants ;
6. dommages mineurs ;
7. décoration procédurale.

En conflit, une règle de priorité décide et le générateur journalise le conflit en debug.

---

# Catégories de modules à produire

Pour un biome complet, viser au minimum :
- 3 entrées ;
- 8 transits droits/coudés ;
- 4 carrefours ;
- 8 salles de combat ;
- 4 salles de ressources ;
- 4 salles narratives ;
- 4 salles de dangers ;
- 3 salles de puzzle ;
- 3 salles d'élite ;
- 4 modules secrets ;
- 4 modules de raccourci ;
- 2 points de repos/retraite ;
- 1 à 3 arènes de boss authored selon le biome.

Ces nombres sont une bibliothèque cible, pas le nombre de salles d'un seul run.

---

# Cible mobile / PC

La topologie et les règles de gameplay sont identiques sur mobile et PC. En revanche :
- mobile charge une variante d'asset allégée ;
- PC peut charger davantage de props, particules, decals et géométrie secondaire ;
- aucune différence de collision ou de route critique entre plateformes ;
- les seeds doivent produire la même logique de donjon sur les deux plateformes.

---

# Migration depuis le système Ashlands actuel

Le système existant doit évoluer ainsi :

- `AshlandsLayoutGenerator` reste utile pour les zones extérieures et blockouts, mais ne devient pas le générateur final de donjons.
- `branching` et `cover_density` doivent devenir de vrais paramètres consommés par le nouveau système.
- `FirstAccordDungeonMapBuilder` devient le prototype d'un **template authored** : ses salles et ses moments critiques sont conservés, mais certaines connexions, branches facultatives et variations locales peuvent être générées à partir de contrats de modules.
- `first_map_hall_of_first_accord_map.json` reste un fallback authored et une référence de validation.

---

# Invariants verrouillés

1. Pas de procédural pur.
2. Pas de donjon entièrement identique à chaque run sauf lieu narratif explicitement fixe.
3. Salles importantes conçues à la main.
4. Graphe rejouable et déterministe par seed.
5. Rémanence stockée en cicatrices/flags, jamais en snapshots de scènes.
6. Boss et moments narratifs majeurs protégés du hasard destructeur.
7. Toujours au moins une solution de progression et une retraite prévue selon le profil.
8. Même logique de jeu mobile et PC, détails visuels adaptés à la plateforme.
9. Validation systématique avant activation de la seed.
10. Fallback authored obligatoire en cas d'échec de génération.
