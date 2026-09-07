# LITD : Les Veilleurs — Bible de chorégraphie des 12 ultimes

Statut : direction canonique de présentation et de mise en scène.

Source mécanique : référentiel combat maître des Veilleurs. Les chorégraphies ne remplacent jamais la résolution gameplay : elles présentent un résultat calculé par les resolvers.

## Règles communes

- Déblocage : niveau 16.
- Charges par expédition : N16–31 = 1 ; N32–47 = 2 ; N48–50 = 3.
- Limite : une activation maximum du même ultime par rencontre.
- Pas d’invulnérabilité gratuite, pas de résurrection, pas d’effacement des blessures réelles.
- La charge n’est consommée qu’au moment de `ULTIMATE_RESOLVE`, jamais au simple appui sur le bouton.
- Les contraintes corporelles restent autoritaires : une fonction perdue peut empêcher ou modifier l’ultime.
- Version complète : environ 2,8 à 4,2 s selon l’ultime.
- Version courte après première visualisation : environ 1,3 à 2,0 s, sans modification mécanique.
- Haptique, screen shake, flash et mouvements de caméra sont désactivables ou réductibles.
- La caméra ne doit jamais rendre l’espace tactique incompréhensible.
- Toute variante fatale, de démembrement, de chute, de fracture ou de déplacement est produite par les systèmes corporels réels.
- La Rémanence ne retient un ultime que s’il crée une conséquence réellement mémorable.

## NAYRA ORUN

### 1. Bastion — LA LIGNE NE ROMPT PAS

**Mécanique canonique :** interceptions multiples pendant une fenêtre ; tous les impacts sont réellement résolus.

**Intention :** montrer que Nayra ne devient pas invulnérable : elle choisit de devenir le point par lequel les coups doivent passer.

**Durée d’activation :** ~2,2 s, puis micro-réactions de 0,15–0,30 s pendant la fenêtre d’interception. Version courte : ~1,2 s d’activation.

**Séquence :**
1. `ULTIMATE_FOCUS` — Nayra regarde successivement les alliés protégés.
2. `ULTIMATE_SET_LINE` — elle avance d’un demi-pas et pose l’angle du grand bouclier.
3. `ULTIMATE_BRACE` — pieds ancrés, respiration bloquée, centre de gravité bas.
4. `ULTIMATE_WINDOW` — la fenêtre d’interceptions est ouverte.
5. Chaque attaque entrante produit `ULTIMATE_INTERCEPT_RESOLVE` : l’impact réel est calculé, les dégâts, fractures, recul et perte fonctionnelle restent possibles.
6. `ULTIMATE_AFTERMATH` — la posture de Nayra reflète ce qu’elle vient réellement d’encaisser.

**Caméra :** basse et légèrement derrière l’épaule de Nayra ; aucun zoom sur chaque impact. Les interceptions latérales provoquent seulement un petit recentrage.

**Audio :** respiration, bottes, cuir, bois/métal du bouclier. La signature est une série d’impacts distincts dont le timbre dépend de l’arme reçue.

**Haptique :** une impulsion différente par impact réel ; amplitude liée à la force calculée, jamais à une animation fixe.

**Variantes :**
- impact absorbé : Nayra conserve ses appuis ;
- recul : déplacement réel et caméra qui accompagne brièvement ;
- fracture/blessure : animation de compensation immédiate ;
- perte de fonction nécessaire : la fenêtre peut prendre fin ;
- attaque de zone non interceptable : elle passe normalement.

**Rémanence :** peut retenir une série exceptionnelle d’interceptions, une blessure reçue en protégeant un Veilleur ou un sauvetage d’un allié critique.

### 2. Brisure — LE POIDS DU MUR

**Mécanique canonique :** charge exceptionnelle convertissant masse, déplacement et armure en collision.

**Intention :** toute la puissance vient de la masse de Nayra, de son équipement, de sa vitesse et de ce qui se trouve derrière la cible.

**Durée :** ~3,1 s. Version courte : ~1,5 s.

**Séquence :**
1. `ULTIMATE_MEASURE` — Nayra évalue ligne, distance et obstacle derrière la cible.
2. `ULTIMATE_LOAD` — bouclier près du corps, première poussée de jambe.
3. `ULTIMATE_DRIVE` — deux à trois pas lourds maximum ; pas de sprint irréaliste.
4. `ULTIMATE_COLLISION` — résolution masse/vitesse/armure/stabilité.
5. `ULTIMATE_TRANSFER` — le système calcule recul, chute, fracture, armure et collision environnementale.
6. `ULTIMATE_RECOVER` — Nayra doit elle-même récupérer son appui.

**Caméra :** très basse sur les deux derniers pas ; coupe interdite au moment de la collision afin que le joueur perçoive la distance réellement parcourue.

**Audio :** armure et souffle montent progressivement ; l’impact est grave, court et matériel, sans explosion sonore.

**Haptique :** vibration montante sur les pas, puis une impulsion très forte à la collision.

**Variantes :**
- cible légère : projection plus importante, dommage corporel relatif moindre ;
- cible lourde : très peu de recul mais traumatisme élevé ;
- cible contre mur/obstacle : collision secondaire réelle ;
- boss/masse immobile : Nayra peut être stoppée et subir un contre-traumatisme ;
- jambe/appui déjà critique chez Nayra : puissance réduite ou activation interdite.

**Rémanence :** mur détruit, armure historiquement brisée, ennemi mémoriel projeté ou blessure durable de Nayra liée à la charge.

### 3. Serment — PAS UN DE PLUS

**Mécanique canonique :** protège temporairement les alliés critiques récupérables et priorise sauvetage/extraction.

**Intention :** ce n’est pas « tout le monde devient immortel » ; Nayra décide que chaque seconde suivante sera consacrée à ramener les vivants.

**Durée d’activation :** ~2,8 s, puis la fenêtre de sauvetage s’exécute dans le combat normal. Version courte : ~1,4 s.

**Séquence :**
1. `ULTIMATE_TRIAGE_VIEW` — très brefs regards vers les alliés critiques récupérables.
2. `ULTIMATE_VOW` — Nayra serre le bouclier et dit une phrase très courte, sans cri héroïque.
3. `ULTIMATE_REPOSITION` — elle se place entre la menace prioritaire et le blessé le plus vulnérable si la formation l’autorise.
4. `ULTIMATE_RESCUE_WINDOW` — priorité aux interceptions, relèves et actions d’extraction valides.
5. `ULTIMATE_END` — la fenêtre se ferme quand les conditions ou les fonctions corporelles de Nayra ne permettent plus de continuer.

**Caméra :** plan d’ensemble centré sur la formation, car l’ultime parle du groupe et non de Nayra seule.

**Audio :** la musique se tasse légèrement ; respirations des blessés et frottement du bouclier deviennent plus présents.

**Haptique :** impulsion ferme au serment, puis petites impulsions lors de chaque sauvetage réel.

**Variantes :** aucun allié récupérable = activation impossible ; allié au sol = priorité de relève ; extraction ouverte = chemin de retrait mis en évidence ; allié mort = aucune résurrection, aucune cible de protection fictive.

**Rémanence :** sauvetage d’un Veilleur critique, extraction sous pression ou échec du serment laissant une conséquence relationnelle.

## TAREK SENN

### 4. Traque — LA PROIE N’A PLUS D’OMBRE

**Mécanique canonique :** révèle au maximum les informations confirmées d’une cible étudiée et maximise leur exploitation.

**Intention :** Tarek ne reçoit aucune omniscience. Il assemble instantanément tout ce qui a déjà été réellement observé.

**Durée :** ~3,0 s. Version courte : ~1,4 s.

**Séquence :**
1. `ULTIMATE_RECALL` — indices confirmés réapparaissent brièvement : déplacement, blessure, appui, intention, couverture.
2. `ULTIMATE_CONNECT` — les informations se regroupent autour de la cible sans scanner magique.
3. `ULTIMATE_LOCK` — Tarek choisit la meilleure faiblesse réellement connue.
4. `ULTIMATE_SHARE` — le groupe reçoit les informations exploitables.
5. `ULTIMATE_RESOLVE` — précision/initiative/exploitation sont calculées depuis ces connaissances.

**Caméra :** focale plus serrée sur la cible avec de très courts inserts sur traces corporelles ou environnementales déjà observées.

**Audio :** environnement atténué ; petits sons matériels des indices : pas, respiration, métal d’armure, corde d’arc. Aucun son de radar.

**Haptique :** trois petits taps espacés, puis une impulsion courte au verrouillage.

**Variantes :** cible très étudiée = lecture dense ; cible partiellement étudiée = uniquement les faits disponibles ; cible presque inconnue = ultime peu rentable ou non activable selon les prérequis.

**Rémanence :** peut consolider une connaissance d’espèce seulement si elle a été réellement confirmée par le combat.

### 5. Entaille — LES SEPT OUVERTURES

**Mécanique canonique :** enchaîne les frappes sur fonctions déjà fragilisées ; faible valeur contre cible intacte.

**Intention :** le nombre « sept » représente le sommet de la lecture opportuniste de Tarek, pas sept dégâts gratuits garantis.

**Durée :** ~3,4 s lorsque plusieurs ouvertures existent ; version courte ~1,7 s.

**Séquence :**
1. `ULTIMATE_COUNT_OPENINGS` — le resolver liste les fonctions réellement fragilisées.
2. `ULTIMATE_STEP_IN` — Tarek ferme la distance.
3. `ULTIMATE_CHAIN` — jusqu’à sept frappes très courtes, chacune sur une ouverture valide ; chaque frappe est résolue séparément.
4. `ULTIMATE_BREAK_CHAIN` — la chaîne s’arrête si la cible tombe, devient hors portée ou si aucune ouverture valide ne reste.
5. `ULTIMATE_EXIT` — Tarek ressort de l’axe d’attaque.

**Caméra :** caméra proche mais continue, sans sept cuts. Les changements de zones se lisent dans le déplacement du corps de Tarek.

**Audio :** suite sèche de lame, textile et respiration ; pas de crescendo orchestral artificiel.

**Haptique :** impulsions courtes, une par impact effectivement résolu.

**Variantes corporelles :** tendon atteint → appui cède ; main/avant-bras → arme lâchée si le système le permet ; ancienne plaie → saignement aggravé ; fonction intacte → frappe faible ou non sélectionnée ; démembrement uniquement si seuil réel atteint.

**Rémanence :** peut inscrire la neutralisation fonctionnelle majeure d’un ennemi mémoriel, jamais « sept coups » comme événement abstrait.

### 6. Disparition — LÀ OÙ NUL NE REGARDE

**Mécanique canonique :** exploite couvertures, ombres et ruptures d’attention pour devenir très difficile à fixer.

**Intention :** Tarek ne devient pas invisible. L’ennemi perd la certitude de sa position parce que Tarek exploite réellement l’espace.

**Durée :** ~2,7 s. Version courte : ~1,3 s.

**Séquence :**
1. `ULTIMATE_BREAK_ATTENTION` — Tarek attend ou provoque une vraie rupture d’attention exploitable.
2. `ULTIMATE_MOVE` — déplacement rapide vers une couverture/ombre valide.
3. `ULTIMATE_OLD_POSITION` — la caméra reste une fraction de seconde sur l’endroit où l’ennemi pense encore qu’il se trouve.
4. `ULTIMATE_NEW_POSITION` — révélation de sa position réelle au joueur, pas nécessairement aux ennemis.
5. `ULTIMATE_CERTAINTY_RESOLVE` — baisse de certitude, priorité de ciblage et options de réaction calculées par l’IA.

**Caméra :** très important : pas de fondu magique. Le décor masque naturellement Tarek pendant son déplacement.

**Audio :** souffle coupé, appui discret, tissu. La signature est l’absence momentanée de ses pas.

**Haptique :** glissement très léger puis tap sec au nouvel appui.

**Variantes :** forte lumière sans couverture = effet réduit ou activation impossible ; fumée/cadavre/débris = couverture légitime ; ennemi très attentif = certitude réduite moins fortement ; boss = aucune « cécité » artificielle.

**Rémanence :** une embuscade ou fuite majeure peut laisser une mémoire ennemie de la manière dont Tarek a disparu.

## AÏSHA MAREN

### 7. Anatomie — CARTE PARFAITE DU VIVANT

**Mécanique canonique :** partage au groupe une lecture anatomique complète d’une cible suffisamment étudiée.

**Intention :** Aïsha transmet une compréhension, pas un buff magique de dégâts.

**Durée :** ~3,4 s. Version courte : ~1,6 s.

**Séquence :**
1. `ULTIMATE_OBSERVE` — Aïsha reconstitue posture, respiration, lésions et protection.
2. `ULTIMATE_MAP` — seules les structures connues/confirmées sont mises en relation.
3. `ULTIMATE_CALL_OUT` — Aïsha communique brièvement les fonctions importantes.
4. `ULTIMATE_PARTY_READ` — les trois autres Veilleurs ajustent regard, arme ou appui vers les zones révélées.
5. `ULTIMATE_RESOLVE` — la connaissance est partagée et les systèmes de ciblage utilisent cette information.

**Caméra :** plans courts sur signes corporels réels ; jamais de squelette holographique ou d’organe visible à travers l’armure.

**Audio :** respiration de la cible, friction d’articulation, armure, quelques mots d’Aïsha. Musique réduite mais non supprimée.

**Haptique :** petits taps lors des confirmations anatomiques, aucun gros impact.

**Variantes :** anatomie connue = carte riche ; créature inconnue = seulement structures probables déjà inférées ; zone couverte/non observable = reste inconnue.

**Rémanence :** enrichit le bestiaire uniquement avec les observations réellement validées.

### 8. Suture — TOUT CE QUI PEUT ÊTRE SAUVÉ

**Mécanique canonique :** triage d’urgence du groupe ; stabilise ce qui est récupérable sans résurrection ni régénération.

**Intention :** faire sentir la médecine de catastrophe : Aïsha ne « soigne pas le groupe », elle empêche les blessures récupérables de devenir irréversibles.

**Durée :** ~4,0 s si plusieurs blessés ; version courte ~1,9 s.

**Séquence :**
1. `ULTIMATE_TRIAGE` — le système classe saignements, fractures, état critique, capacité respiratoire et transportabilité.
2. `ULTIMATE_SELECT` — seulement les lésions réellement récupérables sont retenues.
3. `ULTIMATE_INTERVENTIONS` — Aïsha enchaîne compression, maintien, attelle ou stabilisation selon chaque blessure.
4. `ULTIMATE_RESOLVE` — réduction de saignement/aggravation et stabilisation réelle ; les séquelles demeurent.
5. `ULTIMATE_REASSESS` — Aïsha vérifie qui peut continuer, être porté ou doit être extrait.

**Caméra :** plan d’ensemble dynamique autour du groupe ; pas de halo de soin.

**Audio :** tissu tendu, respiration, ordre clinique très court, boucles métalliques, parfois gémissement du blessé. La musique passe en arrière-plan.

**Haptique :** un tap par intervention réussie ; une vibration plus longue si une urgence critique est stabilisée.

**Variantes :** allié mort = ignoré ; membre perdu = aucune restauration ; fracture = attelle/limitation et non guérison ; hémorragie = réduction selon accessibilité et ressources ; plusieurs blessés = priorité médicale réelle.

**Rémanence :** peut mémoriser un sauvetage majeur, une séquelle conservée ou un choix de triage difficile.

### 9. Hémocorde — LE DERNIER BATTEMENT

Conserver la spécification détaillée dédiée. Signature : disparition presque totale du son après le contact, premier battement fort, second plus faible, puis résolution selon état physiologique réel. Neutralisation circulatoire uniquement sur physiologie connue et cible déjà très compromise ; boss non exécuté automatiquement ; charge consommée uniquement à `ULTIMATE_RESOLVE`.

## IDRIS VAEL

### 10. Sentence — LE VERDICT TOMBE

**Mécanique canonique :** réorganise le tempo en retardant, interrompant et désignant plusieurs intentions révélées.

**Intention :** Idris ne contrôle pas le temps. Il lit les préparations visibles et impose une priorité tactique au bon moment.

**Durée :** ~3,0 s. Version courte : ~1,4 s.

**Séquence :**
1. `ULTIMATE_READ_INTENTS` — seules les intentions réellement révélées sont sélectionnées.
2. `ULTIMATE_JUDGMENT` — Idris pointe successivement les menaces avec bâton/chaîne et une formule très brève.
3. `ULTIMATE_REORDER` — la timeline se réorganise visuellement au même moment où le moteur applique retard/interruption/désignation.
4. `ULTIMATE_CONFIRM` — Idris reprend une posture neutre, sans pose de victoire.

**Caméra :** angle latéral permettant de voir Idris et les ennemis concernés en même temps. La timeline reste visible, jamais remplacée par une cinématique plein écran.

**Audio :** un coup de bâton au sol ou contre une protection marque l’instant de décision ; chaque intention déplacée reçoit un son UI très discret et matériel.

**Haptique :** impulsion nette au « verdict », puis petits ticks lors des modifications de timeline.

**Variantes :** intention non révélée = intouchable ; action déjà irréversible = non annulée ; ennemi animal/incompréhensible = effets limités aux interruptions physiques possibles ; boss = retard/interruption selon résistances, jamais tour supprimé arbitrairement.

**Rémanence :** peut retenir l’interruption d’un événement majeur ou le comportement d’un ennemi qui apprend à masquer sa préparation.

### 11. Concorde — UN SEUL MOUVEMENT

**Mécanique canonique :** les quatre Veilleurs agissent dans un ordre choisi, avec synergies dépendant de la séquence.

**Intention :** c’est l’ultime du quatuor, pas celui d’Idris seul. La puissance provient de l’ordre des actions et de leurs relations systémiques.

**Durée :** ~4,2 s en présentation complète ; version courte ~2,0 s.

**Avant activation :** l’interface demande l’ordre des quatre Veilleurs parmi ceux capables d’agir. Si le canon exige les quatre et qu’un Veilleur est incapable d’agir, l’activation est indisponible plutôt que de fabriquer une copie de son action.

**Séquence :**
1. `ULTIMATE_SEQUENCE_SELECT` — le joueur choisit l’ordre.
2. `ULTIMATE_IDRIS_CUE` — Idris donne un signal minimal.
3. `ULTIMATE_ACTOR_1_RESOLVE` — vraie action et conséquences.
4. `ULTIMATE_ACTOR_2_RESOLVE` — tient compte du résultat 1.
5. `ULTIMATE_ACTOR_3_RESOLVE` — tient compte des résultats précédents.
6. `ULTIMATE_ACTOR_4_RESOLVE` — produit éventuellement une synergie finale liée à l’ordre réel.
7. `ULTIMATE_RETURN` — la formation résultante reste celle produite par les déplacements réels.

**Caméra :** travelling continu autant que possible, comme une seule phrase de combat ; éviter quatre mini-cinématiques collées.

**Audio :** un rythme commun très discret apparaît sous les sons individuels des quatre personnages ; il n’écrase jamais les impacts réels.

**Haptique :** signature différente pour chaque Veilleur, mais un motif commun relie les quatre actions.

**Variantes :** l’ordre change les effets ; blessure/position peut modifier une action ; si une première action tue/déplace une cible, la suivante doit recalculer sa cible valide ; aucune action fantôme.

**Rémanence :** une séquence exceptionnelle peut renforcer une relation ou devenir un souvenir tactique partagé, jamais un simple bonus permanent gratuit.

### 12. Dissidence — QUE L’ORDRE SE BRISE

**Mécanique canonique :** déconnecte temporairement commandement, gardes et synergies d’une formation structurée.

**Intention :** Idris ne contrôle pas les esprits ; il fait apparaître les contradictions d’un système de commandement déjà observable.

**Durée :** ~3,3 s. Version courte : ~1,5 s.

**Séquence :**
1. `ULTIMATE_IDENTIFY_STRUCTURE` — le moteur confirme chef, gardes, synergies et relations d’ordre connues.
2. `ULTIMATE_CHALLENGE` — Idris utilise parole, déplacement et présence pour forcer une hésitation ou divergence crédible.
3. `ULTIMATE_BREAK_LINKS` — les liens tactiques sont désactivés un par un par le moteur : garde, bonus de formation, ordre collectif, préparation coordonnée.
4. `ULTIMATE_REACTION` — les ennemis réagissent selon personnalité/IA : doute, colère, action isolée, silence, maintien du plan si résistance suffisante.
5. `ULTIMATE_RESOLVE` — la formation reste temporairement désynchronisée selon les règles.

**Caméra :** plan d’ensemble sur la formation ennemie. Les liens ne sont montrés que sous forme d’indices UI tactiques discrets, jamais comme chaînes magiques lumineuses.

**Audio :** voix/ordres ennemis se chevauchent au début puis cessent d’être synchrones. La signature sonore est la rupture du rythme collectif.

**Haptique :** motif régulier de trois petites impulsions, interrompu brusquement lors de la rupture.

**Variantes :** animaux/groupe sans commandement = ultime invalide ou très faible ; chef identifié = rupture forte ; structure partiellement connue = seuls les liens confirmés sont affectés ; boss solitaire = pratiquement aucun bénéfice de formation à casser ; boss commandant un groupe = commandement peut être perturbé sans contrôle mental.

**Rémanence :** peut enregistrer la façon dont une faction ou un chef a réagi à la rupture, permettant aux futurs ennemis mémoriels d’adapter leur organisation.

## Signatures sensorielles à préserver

| Ultime | Signature principale |
|---|---|
| La Ligne ne rompt pas | série d’impacts réellement encaissés |
| Le Poids du Mur | montée de masse puis collision unique |
| Pas un de plus | respiration des blessés + bouclier qui se place |
| La Proie n’a plus d’ombre | indices matériels qui se reconnectent |
| Les Sept Ouvertures | cadence de frappes conditionnelles |
| Là où nul ne regarde | disparition des pas / ancienne position vide |
| Carte parfaite du vivant | sons corporels observables + consignes d’Aïsha |
| Tout ce qui peut être sauvé | gestes de triage et respiration stabilisée |
| Le Dernier Battement | silence puis battements cardiaques |
| Le Verdict tombe | coup de bâton + timeline qui se réordonne |
| Un seul mouvement | rythme commun reliant les quatre actions |
| Que l’ordre se brise | rythme collectif ennemi qui se désynchronise |

## Contrat technique partagé

Chaque ultime doit suivre au minimum :

`ULTIMATE_REQUEST → ULTIMATE_VALIDATE → ULTIMATE_PRESENTATION_START → ULTIMATE_RESOLVE → ULTIMATE_AFTERMATH → ULTIMATE_RETURN_TO_COMBAT`

Les ultimes à fenêtre/réactions peuvent ajouter des sous-états (`INTERCEPT_WINDOW`, `CHAIN_STEP`, `SEQUENCE_STEP`, etc.). La présentation ne décide jamais de la mécanique : elle consomme un résultat ou déclenche le point autoritaire `ULTIMATE_RESOLVE`.

Avant `ULTIMATE_RESOLVE`, aucun coût de charge irréversible ne doit être enregistré. Après résolution, la charge, la limite de rencontre, les blessures, déplacements, morts, cadavres, Rémanence, IA, timeline et relations sont mis à jour dans cet ordre causal.
