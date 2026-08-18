# Combat — anatomie avancée, blessures et démembrements

Le combat anatomique de **Light in the Dark** est une couche tactique complète. Son objectif n'est pas de transformer le démembrement en simple effet gore : le joueur choisit **quelle fonction de l'adversaire il veut neutraliser**, accepte un coût en précision et en tempo, puis adapte sa stratégie aux conséquences physiques et psychologiques.

Le système actif passe par la chaîne de combat `v12 → v11 → v10 → v9 → v8 → v7 → v6 → v5 → v4 → v3 → v2`.

## 1. Ciblage anatomique

Chaque cible corporelle possède des parties anatomiques sélectionnables. Le joueur peut faire défiler les parties accessibles avant d'attaquer.

Une partie définit notamment :
- un identifiant stable ;
- un nom visible ;
- une difficulté à toucher ;
- une résistance au Trauma ;
- des tags fonctionnels ;
- la possibilité ou non d'être sectionnée ;
- la conséquence tactique attendue si elle est neutralisée.

Un échec du jet anatomique **ne transforme pas l'attaque en raté complet** : les dégâts normaux sont déjà infligés, mais le Trauma appliqué à la partie n'est que partiel. Cela évite qu'un choix anatomique rende les attaques inutilement binaires.

## 2. Trauma indépendant par partie

Il n'existe plus une seule jauge décidant arbitrairement quel membre tombe. Chaque partie possède son propre Trauma :

`Bras d'attaque 62/100 · Jambe d'appui 20/105 · Tête 0/125`

Les coups lourds produisent davantage de Trauma que les frappes légères. Rupture, étourdissement, cible très affaiblie et certaines techniques peuvent accélérer la progression.

Les états intermédiaires sont :
- **Intact** ;
- **Fragilisé** à partir d'environ 35 % du seuil ;
- **Blessé** à partir d'environ 65 % ;
- **Critique** à partir d'environ 85 % ;
- **Perdu** lorsqu'une partie sectionnable atteint son seuil.

Le système historique de Trauma global reste uniquement comme compatibilité. Lorsque l'anatomie v2 est active, il ne peut plus choisir un membre au hasard.

## 3. Spécialisations anatomiques des héros

Les quatre héros ne sont pas interchangeables face à l'anatomie.

### Malvor
Spécialiste des **armures, appuis et structures porteuses**.
- bonus de précision anatomique : +10 sur ses affinités ;
- Trauma ×1,35 sur ses affinités.

### Darius
Spécialiste des **armes, membres offensifs et soutiens**.
- bonus de précision : +8 ;
- Trauma ×1,20.

### Aurélien
Spécialiste des **ancrages, noyaux et structures liées au Voile**.
- bonus de précision : +12 ;
- Trauma ×1,40.

### Lysandra
Spécialiste des **organes sensoriels, parties fines, venin et points critiques**.
- bonus de précision : +15 ;
- Trauma ×1,15.

L'objectif est de créer une décision de groupe : le meilleur personnage pour infliger des dégâts bruts n'est pas forcément celui qui neutralise le plus vite la partie importante.

## 4. Anatomies uniques des boss

Les boss importants ne reposent plus uniquement sur `offensive_limb / anchor_limb / support_limb`.

Onze boss possèdent actuellement une anatomie propre :
- Le Général de Silex ;
- La Frontière qui marche ;
- Le Consensus Brisé ;
- La Rupture Commune ;
- La Septième Voix ;
- Le Dernier Stratège ;
- La Dernière Veille ;
- Le Commandement Sans Corps ;
- La Cartographe des Mers Absentes ;
- L'Interprète Unique ;
- Le Théorème Vivant.

Exemples :
- le **Bras du commandement** du Général de Silex est lié à *Ordre de recul* ;
- l'**Ancrage de frontière** est lié à la translation de La Frontière qui marche ;
- l'**Ancrage de perspective** du Consensus Brisé gouverne sa permutation de formation ;
- le **Pilier de soutien commun** de la Rupture Commune gouverne son inversion des duos.

Neutraliser une partie modifie une phase ou une manœuvre. Cela ne remplace jamais les conditions fondamentales du boss. En particulier, fissurer le Noyau de contradiction de la Rupture Commune ne remplace pas les trois ancrages requis par sa mécanique principale.

## 5. IA adaptative après mutilation

Une créature mutilée ne continue pas son script comme si rien ne s'était produit.

Les comportements possibles incluent :
- repli sous garde ;
- rage blessée ;
- retraite boiteuse ;
- déplacement instable ;
- surcharge structurelle ;
- adaptation contrôlée des élites ;
- adaptation de phase des boss.

Une créature ordinaire très affaiblie et ayant perdu plusieurs parties peut tenter de fuir. Les mini-boss et boss ne fuient jamais.

Certaines créatures protègent également une partie encore fonctionnelle. Une partie marquée **PROTÉGÉE** impose actuellement une pénalité de 15 points à la précision anatomique du joueur.

## 6. Peur, Folie et mutilations

Une mutilation est aussi un événement psychologique.

La réaction dépend de la Folie actuelle du témoin :
- lucide ;
- ébranlé ;
- fragile ;
- dissocié.

L'auteur du coup est moins affecté que les autres témoins. Un Espoir élevé amortit la Peur. Les résistances à la Peur et à la Folie sont également appliquées.

Une mutilation de boss est plus impressionnante qu'une mutilation ordinaire et peut produire une pression de Peur supplémentaire.

## 7. Capture, confiance et convalescence

Les blessures peuvent faciliter physiquement la capture, mais la mutilation ne doit jamais être une stratégie de recrutement sans coût.

Actuellement :
- chaque partie perdue apporte +7 points au bonus anatomique de capture ;
- chaque blessure critique apporte +3 ;
- le bonus est plafonné à +20 ;
- la confiance de départ diminue avec les parties perdues et blessures critiques ;
- la créature arrive avec un nombre de points de soins nécessaires ;
- elle reste **inapte au combat** jusqu'à la fin de sa convalescence.

Le runtime du Sanctuaire expose `provide_sanctuary_care(instance_id)` pour faire progresser ces soins. Les informations de blessures, confiance et convalescence sont stockées directement dans la créature capturée et suivent donc sa sauvegarde normale.

Cela préserve la logique du monde : capturer n'est pas posséder, et mutiler une créature consciente a une conséquence relationnelle.

## 8. Blessures sans démembrement obligatoire

Toutes les neutralisations ne demandent pas une séparation physique.

Le système gère notamment :
- armure fendue ;
- tendon ou articulation lésé(e) ;
- organe sensoriel blessé ;
- glande ou canal rompu ;
- fracture offensive ;
- membre armé fracturé ;
- ancrage fissuré ;
- cohérence du Voile fissurée ;
- noyau fissuré ;
- structure de soutien lésée.

Une blessure critique peut rendre une partie **fonctionnellement indisponible**. Les mécanismes de boss et de familles vérifient cette disponibilité de la même façon qu'ils vérifient une partie perdue.

Ainsi, un joueur utilisant un niveau de gore réduit ou désactivé conserve toute la profondeur tactique.

## 9. Interface anatomique

L'interface de combat affiche maintenant :
- la partie sélectionnée ;
- le Trauma actuel et son seuil ;
- la précision anatomique estimée ;
- le statut PROTÉGÉE éventuel ;
- un schéma anatomique simplifié ;
- l'état de chaque partie ;
- la conséquence de sa neutralisation ;
- l'affinité anatomique du héros actif.

Cette UI textuelle sert de référence fonctionnelle en attendant les assets définitifs. Elle pourra ensuite être remplacée par une silhouette cel-shading sans changer les données ou le gameplay.

## 10. Contrat Blender, VFX et animations

`data/blender/dismemberment_contract.json` définit l'interface entre gameplay et production 3D.

Conventions principales :
- bones : `BONE_<part_id>` ;
- sockets de séparation : `SEVER_<part_id>` ;
- mesh détachable : `DETACHED_<part_id>` ;
- cap de plaie : `CAP_<part_id>` ;
- socket VFX : `FX_<part_id>` ;
- variante de blessure : `INJ_<part_id>_<state>`.

Collections requises :
`BODY`, `ARMATURE`, `DISMEMBERMENT`, `WOUND_CAPS`, `SOCKETS`, `VFX_GUIDES`.

Animations de référence :
- `hit_anatomy` ;
- `injury_react` ;
- `critical_injury_react` ;
- `dismember_react` ;
- `guard_remaining_part` ;
- `wounded_rage` ;
- `wounded_retreat` ;
- `panic_flee` ;
- `phase_altered` ;
- variantes `hit_<part_id>`, `injury_<part_id>`, `critical_<part_id>`, `dismember_<part_id>`.

Trois présentations sont prévues :
- **full** : mesh détaché, cap, sang et VFX complets ;
- **reduced** : aucune partie projetée, pas de projection de sang, mais réaction et plaie stylisée lisibles ;
- **off** : aucune représentation gore ; la réaction d'impact et l'interface anatomique portent l'information tactique.

`tools/blender/generate_dismemberment_jobs.py` transforme ce contrat et les anatomies de gameplay en jobs de production déterministes. Il peut être utilisé sans Blender pour préparer et vérifier le pipeline.

## QA

La commande :

```bash
python -m tools.qa.anatomy_system_audit
```

contrôle les dix étapes ci-dessus, les onze anatomies de boss, les autoloads, la capture, l'IA, la psychologie, les blessures fonctionnelles, l'interface et le contrat Blender.

Les tests `test_anatomy_system_v2.py` et `test_blender_dismemberment_contract.py` verrouillent également ces contrats dans `pytest`.

Le principe de design reste : **un démembrement intéressant ne retire pas seulement des PV ; il retire, transforme ou révèle une manière de combattre.**
