# LITD — Bible UX/UI

Version de référence : 2026-09-10

## 1. Objectif

L'interface de LITD doit aider le joueur à décider sans recouvrir l'univers. La règle centrale est : **montrer immédiatement ce qui est nécessaire à la décision présente, rendre le détail accessible en une action, et laisser le monde communiquer tout ce qu'il peut communiquer lui-même.**

LITD utilise quatre niveaux de divulgation :

1. **Monde** — information portée par l'environnement, l'animation, l'audio, la lumière, les traces et le comportement des personnages.
2. **HUD** — information critique, immédiatement actionnable et impossible à communiquer assez précisément par le monde.
3. **Contexte / décision** — information apparaissant au survol, focus, sélection ou ciblage.
4. **Inspection** — détail complet demandé volontairement par le joueur.

Le joueur ne doit jamais devoir mémoriser une statistique depuis un autre écran pour prendre une décision présente.

---

## 2. Règles globales

1. HUD permanent minimal ; détails à la demande.
2. Toute entité importante est inspectable avec le même geste conceptuel.
3. Pendant une action, les informations pertinentes apparaissent automatiquement.
4. Les informations secondaires ne doivent pas concurrencer une décision critique.
5. Une action fréquente doit rester accessible en au plus deux interactions depuis son contexte naturel.
6. Souris/clavier, manette et tactile partagent la même architecture d'information mais peuvent employer des contrôles différents.
7. Les positions, libellés et conventions de navigation sont stables entre écrans.
8. Les animations ne bloquent jamais l'entrée ; l'écran devient utilisable immédiatement.
9. Les changements importants sont communiqués par au moins deux canaux lorsque possible : forme + texte, icône + son, position + animation, etc.
10. La couleur seule ne porte jamais une information indispensable.
11. Le focus manette/clavier est toujours visible et son déplacement déterministe.
12. L'UI est testée avec mise à l'échelle texte/UI, safe areas, petits écrans et différents rapports d'image.
13. Un retour arrière conserve autant que possible la sélection, le personnage, le filtre et la position de défilement précédents.
14. Les confirmations ne sont utilisées que pour les actions irréversibles ou coûteuses ; elles ne doivent pas banaliser le clic de confirmation.
15. Toute impossibilité d'action doit expliquer **pourquoi** elle est impossible et, si pertinent, ce qu'il faut changer.

---

## 3. Combat

### 3.1 HUD permanent

Afficher uniquement :

- identité et position des quatre héros ;
- PV/état vital lisible ;
- tour ou disponibilité actuelle ;
- au maximum deux états critiques directement visibles, avec `+N` pour le reste ;
- ressource/action indispensable au choix en cours ;
- information de lumière/risque uniquement si elle modifie réellement la décision présente.

Ne pas conserver un tableau latéral permanent de statistiques détaillées. Les rangs sont **R1 à R4 de droite à gauche** du point de vue du joueur et cette convention doit être identique partout.

### 3.2 Placement et lisibilité

La composition doit rendre la fonction du personnage compréhensible. Un support ne doit pas masquer visuellement un combattant de mêlée placé derrière lui. Le placement à l'écran, les lignes de ciblage et la représentation R1–R4 doivent raconter la formation avant même la lecture des chiffres.

### 3.3 Survol / focus

Le survol souris ou focus manette donne une fiche courte :

- nom, niveau et camp ;
- PV ;
- statistiques essentielles ;
- 2–3 effets prioritaires ;
- 2–3 compétences pertinentes ;
- état de capture pour une créature si cette information est connue et actionnable.

Cette fiche ne doit pas couvrir la cible ou la zone de décision.

### 3.4 Clic / inspection

Un clic, bouton d'examen ou commande équivalente ouvre l'inspection complète :

- portrait / identité ;
- PV actuels/max ;
- précision, vitesse, dégâts, protection/résistances ;
- peur, folie, espoir lorsque pertinents ;
- état du corps et blessures ;
- buffs/debuffs, durée et source si connue ;
- compétences, coûts, contraintes de rang et recharge ;
- équipement pertinent pour les héros ;
- capture et connaissances acquises pour les ennemis ;
- historique court des effets récents si cela aide au diagnostic.

Retour/Annuler ferme l'inspection et rend exactement le focus précédent.

### 3.5 Prévision d'action

Quand une compétence est sélectionnée, l'interface affiche automatiquement sur la cible :

- cible valide/invalide ;
- chance de toucher ;
- dégâts ou intervalle de dégâts prévisionnels lorsque connaissables ;
- chance d'appliquer l'effet ;
- résistance concernée si elle est connue ;
- coût et ressource consommée ;
- déplacement de rang provoqué ;
- conséquence importante : rupture, étourdissement, garde, riposte, exposition, etc.

Les données doivent provenir de la même logique de résolution que le combat afin d'éviter qu'une prévision UI diverge du résultat réel.

### 3.6 Information ennemie et connaissance

L'inspection d'un ennemi ne doit pas nécessairement révéler tout dès la première rencontre. Prévoir des niveaux de connaissance :

- **Inconnu** : silhouette comportementale et informations observables.
- **Observé** : statistiques ou résistances approximatives.
- **Étudié** : résistances, compétences et comportements déjà vus.
- **Documenté** : données fiables obtenues par répétition, textes, capture ou recherche au hub.

L'UI devient ainsi une récompense d'exploration et de compréhension du monde.

---

## 4. Menu principal en jeu

Architecture recommandée :

`Inventaire | Équipement | Compétences | Journal | Options`

Règles :

- onglets toujours dans le même ordre ;
- titre, retour et commandes globales aux mêmes emplacements ;
- dernier onglet et dernier héros conservés à la réouverture ;
- pas de transition empêchant une action ;
- raccourcis directs autorisés sans créer une seconde logique de navigation.

---

## 5. Inventaire

### Vue normale

Deux zones maximum :

- gauche : objets et filtres ;
- droite : sélection et information immédiatement utile.

Filtres : Tout / Équipement / Consommables / Quête. Les filtres doivent mémoriser la dernière sélection pendant la session.

### Détail

N'afficher d'abord que : nom, rareté, emplacement, 3 bonus les plus importants et action principale. `Détails` développe le descriptif complet.

En expédition, rappeler la capacité, les emplacements utilisés et le caractère sécurisé/non sécurisé du butin sans transformer cette ligne en second HUD.

---

## 6. Équipement

Structure :

- sélecteur compact du héros ;
- silhouette ou représentation centrale ;
- arme, armure, deux anneaux, collier ;
- panneau de comparaison.

Au choix d'une pièce, comparer directement **équipé vs sélectionné** et mettre en évidence les valeurs qui changent. Le joueur ne doit pas faire le calcul mental en alternant deux fiches.

Une action équipe/déséquipe ; confirmation uniquement si l'objet est lié, détruit ou engage une conséquence permanente.

---

## 7. Arbres de compétences

Chaque personnage possède trois arbres de 15 compétences. Avant le choix définitif :

- montrer les trois arbres simultanément ou avec navigation instantanée ;
- expliquer clairement leur identité tactique ;
- montrer la compétence ultime dès le début, même verrouillée ;
- prévisualiser le coût et la progression future.

Après verrouillage d'un arbre :

- l'arbre choisi devient principal ;
- les deux autres restent visibles comme choix fermés, sans donner l'impression d'un bug ;
- l'UI explique que le verrouillage est définitif ;
- les jalons de l'ultime aux niveaux 16/32/48 sont visibles sur son propre composant.

---

## 8. Exploration

### Principe

Le monde est prioritaire sur le HUD. Les indices de direction et d'intérêt utilisent d'abord :

- cendre ;
- vent ;
- lanternes ;
- architecture ;
- sons ;
- traces ;
- lumière.

Les marqueurs HUD génériques sont le dernier recours.

### Interactions

Une interaction contextuelle emploie une grammaire stable :

`[commande] + verbe + cible`

Exemples conceptuels : Examiner · Stèle ; Fouiller · Cadavre ; Parler · Survivant ; Ouvrir · Porte scellée.

Pas de contour jaune universel. Les objets importants doivent être distinguables par composition, lumière, animation subtile, matériau, son, regard/posture des personnages ou conséquence environnementale.

### Perception par personnage

Prévoir un système permettant à différents personnages de remarquer des informations différentes. Corps, Esprit et Politique peuvent servir d'axes de perception du monde : technique corporelle, art/culture/symboles, organisation sociale/pouvoir/histoire civique.

La composition de l'équipe modifie alors non seulement le combat mais aussi ce que le joueur peut comprendre de l'environnement.

---

## 9. Carte

La carte montre :

- position actuelle ;
- zones connues/inconnues ;
- objectifs découverts ;
- sorties/extractions connues ;
- lieux importants déjà identifiés ;
- danger seulement lorsqu'il a été appris ou observé.

Prévoir une liste textuelle des points d'intérêt et objectifs en complément de la navigation spatiale, particulièrement avec zoom/UI agrandie et manette.

Éviter le tapis d'icônes : filtres et catégories, priorisation selon l'objectif sélectionné.

---

## 10. Hub

### 10.1 Hub physique + accès rapide

La première découverte d'un bâtiment se fait dans l'espace physique. Après découverte, le joueur peut toujours y aller physiquement mais peut aussi utiliser une navigation rapide du hub.

La navigation rapide ne remplace pas le hub : elle supprime seulement les trajets répétitifs quand le joueur veut gérer son groupe efficacement.

### 10.2 Le hub doit évoluer

Après une expédition, produire quelques changements observables plutôt qu'un écran figé :

- personnages déplacés ;
- conversations nouvelles ;
- travaux, blessures ou réparations ;
- nouvelles créatures/captifs ;
- objets ramenés visibles ;
- bâtiments transformés ;
- zones ouvertes/fermées ;
- mémorial et conséquences des morts.

### 10.3 Mort permanente

Une mort importante laisse une trace : lit vide, objet, nom au mémorial, réaction d'un proche, changement de dialogue, rumeur ou conséquence systémique. Le décès ne doit pas être seulement une ligne de journal.

### 10.4 Bâtiments

Tous les bâtiments utilisent un squelette UX commun :

- identité du bâtiment ;
- fonction principale ;
- ressources/coûts ;
- action primaire ;
- détails secondaires ;
- retour clair vers le hub.

La forge, la taverne, le stockage et les sanctuaires peuvent avoir une personnalité visuelle différente sans réinventer les commandes de base.

---

## 11. Interactions entre personnages

Les relations ne doivent pas devenir une jauge sociale omniprésente. Stocker en interne, selon les besoins du système :

- confiance ;
- affinité ;
- peur ;
- dette ;
- admiration ;
- ressentiment ;
- rivalité ;
- connaissance mutuelle.

Le joueur découvre ces relations par leurs manifestations :

- lignes et silences ;
- déplacements dans le hub ;
- animations et regards ;
- réactions à une blessure ou une mort ;
- interventions lors d'événements ;
- variations tactiques rares et lisibles ;
- objets, lettres ou souvenirs.

Une relation chiffrée exacte ne doit être affichée que si une mécanique exige réellement cette précision.

---

## 12. Dialogues

- nom/origine du locuteur immédiatement identifiable ;
- historique accessible en une commande ;
- choix groupés visuellement et focus stable ;
- pas de minuterie par défaut ;
- conséquences irréversibles confirmées seulement lorsque le joueur ne pouvait raisonnablement les anticiper ;
- les options indisponibles peuvent rester visibles si leur verrouillage apprend quelque chose au joueur, avec explication ;
- la caméra, l'animation et le son ne doivent pas masquer le changement de focus.

Les dialogues dans le hub et en expédition doivent pouvoir être déclenchés par l'état du monde, la composition du groupe, les relations, les découvertes, les pertes et les décisions précédentes.

---

## 13. Mémoire / connaissance collective

Créer une couche de connaissance persistante alimentée par :

- observation répétée d'ennemis ;
- capture ;
- textes anciens ;
- sanctuaires ;
- conversations ;
- inspection d'objets ;
- événements ;
- retour d'expédition.

Elle doit nourrir directement les interfaces : meilleure inspection des ennemis, nouvelles descriptions d'objets, compréhension de symboles, options de dialogue, avertissements de carte, interactions supplémentaires.

Le codex/journal est une conséquence de cette connaissance, pas un silo isolé.

---

## 14. Manette, clavier/souris, tactile

### Manette

- focus initial explicite ;
- voisins haut/bas/gauche/droite explicitement définis sur les interfaces complexes ;
- Focus toujours très visible ;
- commandes conceptuelles stables : Valider / Retour / Inspecter / Changer d'onglet / Personnage précédent-suivant ;
- radial uniquement lorsque le nombre d'actions rend une barre linéaire inefficace.

### Souris/clavier

- survol = aperçu, clic/sélection = action, inspection volontaire = détail ;
- raccourcis documentés ;
- aucune fonction critique exclusivement cachée dans le clic droit.

### Tactile/mobile

- safe area ;
- taille de cible suffisante ;
- pas de dépendance au hover ;
- appui simple pour sélection, commande distincte pour inspection si nécessaire ;
- aucune information essentielle placée sous une zone système/notch.

---

## 15. Accessibilité obligatoire

- échelle UI réglable ;
- échelle de texte réglable ;
- contraste suffisant et option de contraste renforcé ;
- aucun état communiqué uniquement par couleur ;
- remappage des commandes ;
- prompts mis à jour avec le remappage ;
- navigation complète au clavier/manette ;
- indicateur de focus visible ;
- réduction des animations/clignotements ;
- sous-titres et informations audio importantes transmises visuellement ;
- reflow correct quand le texte est agrandi ;
- une seule direction de scroll par zone autant que possible ;
- retour toujours accessible depuis les sous-menus.

---

## 16. Audit du dépôt au 2026-09-10

### Déjà solide

#### `scripts/ui/hud_director.gd`

Très bonne base architecturale. Déjà présents :

- niveaux Monde / Danger / Contexte / Décision / Inspection ;
- priorités CRITICAL/ACTIONABLE/CONTEXT/INFORMATION/DECORATIVE ;
- limitation du nombre d'informations simultanées ;
- report silencieux des informations secondaires vers le journal ;
- limitation des icônes de statut ;
- demandes de confirmation ;
- profil de mouvement réduit ;
- canaux de guidage environnemental ;
- HUD d'exploration transitoire.

**Décision : conserver et en faire la source de vérité de la politique de divulgation.**

#### `scripts/ui/context_hud.gd`

Déjà présents :

- HUD masqué en exploration normale ;
- overlays temporaires statut / interaction / sélection / quête / danger ;
- feedback psychologique contextuel ;
- apparition courte ;
- interaction avec le profil de mouvement.

**À améliorer :** supprimer progressivement les tailles/positions absolues au profit d'ancres, conteneurs et contraintes adaptatives ; appliquer la mise à l'échelle/accessibilité à ces overlays comme à l'inspection.

#### `scripts/ui/combatant_inspection_ui.gd`

Déjà présents :

- aperçu au survol ;
- aperçu au focus ;
- détail au clic/bouton ;
- héros et ennemis ;
- PV/statistiques/états/compétences ;
- information de capture ;
- UI scale, text scale et safe areas mobile ;
- fermeture par commandes globales.

**À améliorer :**

- restituer explicitement le focus à la cible précédente après fermeture ;
- filtrer les données ennemies selon connaissance acquise ;
- ajouter durée/source des effets ;
- intégrer la prévision tactique dans le contexte de compétence plutôt que surcharger l'inspection ;
- ne pas employer `confirm` comme fermeture si cela peut provoquer une double intention selon le contexte.

#### `scripts/ui/context_menu_ui_v2.gd`

Déjà présents :

- onglets compacts ;
- inventaire filtré ;
- deux panneaux ;
- détails progressifs des objets ;
- sélection compacte des héros ;
- équipement ;
- compétences/journal/options dans la même architecture ;
- option de contraste renforcé et échelle du texte.

**À améliorer :**

- remplacer les dimensions de frame/panneaux trop absolues par une mise en page réellement responsive ;
- expliciter le focus initial et les voisins de focus ;
- mémoriser focus/scroll lors des retours et changements d'onglet ;
- comparaison d'équipement plus directe ;
- harmoniser les raccourcis affichés avec le périphérique actif ;
- vérifier le reflow à 140 % UI + texte agrandi.

### Manquant ou à généraliser

1. **ActionPreviewService / modèle de prévision** partagé entre logique de combat et UI.
2. **Knowledge/Discovery UI contract** reliant observations, textes, captures, sanctuaires et inspection.
3. **InteractionContext contract** générique pour objets, PNJ, portes, cadavres, sanctuaires et curiosités.
4. **HubDirector UX** : changements post-expédition, événements visibles, navigation rapide et restauration du contexte.
5. **Relationship feedback layer** : relations internes traduites en manifestations, sans jauges omniprésentes.
6. **Focus graph explicite + validation automatisée** sur tous les grands menus.
7. **Système de prompts par périphérique/remappage** commun à tous les écrans.
8. **Tests UX de responsive/reflow** avec plusieurs résolutions, échelles et safe areas.
9. **Restauration de contexte** : focus, filtre, héros, sélection et scroll après fermeture d'une inspection ou retour d'écran.
10. **Instrumentation UX** de développement : nombre d'actions pour atteindre une fonction, erreurs de focus, éléments hors safe area, panneaux dépassant l'écran.

---

## 17. Ordre d'implémentation

### P0 — avant prochain test jouable

1. Corriger définitivement le HUD de combat et retirer les informations latérales non décisionnelles.
2. Garantir R1 → R4 de droite à gauche et cohérence de placement héros.
3. Stabiliser inspection au clic/focus + retour exact au focus précédent.
4. Ajouter prévision de compétence/cible à partir de la logique réelle de combat.
5. Rendre les menus principaux navigables intégralement au clavier/manette avec focus explicite.
6. Tester 1080p + petite fenêtre + UI/text scale maximales.

### P1 — vertical slice

7. Contrat d'interaction environnementale commun.
8. Couche de connaissance ennemie/monde.
9. Hub physique + accès rapide aux bâtiments découverts.
10. Retour d'expédition faisant évoluer visuellement le hub.
11. Comparaison d'équipement et arbres de compétences finalisés.
12. Dialogues avec historique et états contextuels.

### P2 — profondeur systémique

13. Relations entre personnages et conséquences persistantes.
14. Traces des morts dans le hub et les dialogues.
15. Perception Corps / Esprit / Politique selon composition du groupe.
16. Codex/journal alimenté automatiquement par la connaissance collective.
17. Accessibilité avancée et narration d'interface si retenue pour les plateformes cibles.

---

## 18. Checklist de validation d'un écran

Avant de valider tout nouvel écran :

- Quel est l'unique but principal de cet écran ?
- Quelles informations sont nécessaires maintenant ?
- Quelles informations peuvent attendre une inspection ?
- Le joueur sait-il immédiatement où est le focus ?
- Peut-il revenir en une action ?
- Les commandes restent-elles cohérentes avec les autres écrans ?
- L'écran fonctionne-t-il sans souris ?
- Fonctionne-t-il avec texte/UI agrandis ?
- Une couleur est-elle utilisée seule pour transmettre une information ?
- Une animation retarde-t-elle l'entrée ?
- Une erreur explique-t-elle sa cause ?
- Le joueur doit-il se souvenir d'une information provenant d'un autre écran ?
- L'environnement pourrait-il communiquer une partie de l'information à la place du HUD ?
- L'état/focus précédent est-il restauré après retour ?

Si une réponse est mauvaise, l'écran n'est pas considéré terminé.

---

## 19. Références de conception

Cette bible synthétise notamment les pratiques issues de :

- documentation Godot — navigation clavier/manette, focus et `Control` ;
- Xbox Accessibility Guidelines — navigation, focus, texte, contraste et cohérence UI ;
- GDC — usability, progressive disclosure, UI intégrée à l'univers et guidage environnemental ;
- Larian / Baldur's Gate 3 — adaptation réelle de l'architecture UI à la manette et radiales personnalisables ;
- Supergiant / Hades — hub évolutif et dialogues persistants entre les runs ;
- principes HCI de reconnaissance plutôt que rappel, visibilité de l'état, cohérence et divulgation progressive.

Les références externes servent de contraintes et d'inspiration ; la décision finale doit toujours être validée par des playtests LITD sans explication préalable au testeur.