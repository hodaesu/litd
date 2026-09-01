# LITD 2 — Archives de Rémanence

> Document de conception canonique propre à **LITD 2**. Ne pas importer ces mécaniques dans LITD 1.

## Principe

La Rémanence n'est ni une monnaie, ni une boucle temporelle. Elle représente les traces laissées par les personnes, lieux, idées, objets et événements de la Dernière Guerre.

La métaprogression de LITD 2 ne consiste pas principalement à augmenter des statistiques : elle rend le joueur plus savant, le monde plus compréhensible et les possibilités de jeu plus nombreuses.

## Interface des Archives

Les Archives prennent la forme d'une constellation documentaire : carte mentale, dossier historique et table d'enquête. Le nœud central est **LA DERNIÈRE GUERRE**. Les connaissances se relient progressivement aux batailles, personnes, cités, doctrines de Corps, Esprit et Politique, à la médecine, aux technologies, aux lieux et aux sources.

### États d'un nœud

1. `INCONNU` — existence supposée ou silhouette sans contenu.
2. `TRACE` — indice découvert mais non confirmé.
3. `DOCUMENTE` — une source solide documente l'élément.
4. `RECONSTRUIT` — plusieurs connaissances permettent une reconstruction exploitable.
5. `CONTESTE` — des sources incompatibles empêchent une vérité unique.

### Fiabilité des sources

La fiabilité est qualitative, jamais affichée comme un pourcentage :

- confirmé ;
- probable ;
- incertain ;
- contesté ;
- témoignage unique ;
- propagande probable.

### Familles visuelles

- Corps : rouge sombre / cuivre.
- Esprit : ivoire / lumière froide.
- Politique : or vieilli.
- Médecine : blanc / rouge profond.
- Technologie : argent / métal.
- Personnes : lumière chaude.
- Inconnu : presque noir.

Les contradictions sont représentées par des liens brisés. Les zones non comprises restent volontairement visibles afin de nourrir la curiosité plutôt qu'une logique de checklist.

## Langage de présentation final

L'écran ne doit jamais ressembler à un arbre de talents propre et statique. Il doit donner la sensation d'une mémoire historique qui tente de se recomposer.

La version native Unreal met donc en place les règles suivantes :

- les fils entre connaissances **se dessinent progressivement** lors de l'ouverture ;
- les fils ordinaires respirent très légèrement et ne restent jamais parfaitement rigides ;
- les contradictions utilisent des traits rompus rouges, plus nerveux que les connexions normales ;
- les nœuds sont des cartes documentaires volontairement irrégulières, avec bordures décalées, amorces de filaments et halos de catégorie ;
- un nœud nouvellement compris bénéficie d'une courte pulsation lumineuse, sans explosion d'effets ;
- de fines particules de cendre/poussière traversent lentement la constellation ; elles ne doivent jamais gêner la lecture ;
- le dossier latéral glisse et se révèle à chaque nouvelle sélection au lieu de remplacer brutalement son contenu ;
- la sélection d'une information contestée peut déclencher une signature sonore distincte ;
- toute reconstruction importante déclenche une courte révélation plein écran : **CONNAISSANCE RECONSTRUITE**, titre de la découverte, puis explication historique du déblocage.

La révélation d'une connaissance doit rester brève. Elle célèbre une compréhension, pas une récompense de loot. Le joueur doit retrouver le contrôle avant que l'animation ne casse le rythme entre deux opérations.

### Audio de Rémanence

Quatre familles de cues sont prévues dans le Widget :

1. **Ouverture** — souffle très court, poussière, métal ou résonance lointaine ;
2. **Sélection** — contact discret de papier, pierre, métal ou filament ;
3. **Contradiction** — tension sèche et instable, jamais un son d'erreur d'interface ;
4. **Reconstruction** — convergence de plusieurs couches suivie d'une résolution courte.

Ces sons sont des références `USoundBase` optionnelles et data-authored. Le système fonctionne sans asset binaire assigné ; les fichiers audio définitifs seront raccordés dans Unreal. Les sons externes restent soumis aux règles de droits de LITD Universe.

## Découverte en run

La Rémanence ne dépend pas d'un mode « vision détective » permanent. Elle se manifeste par de petites anomalies du monde : son impossible, poussière inversée, reflet incohérent, voix lointaine, ombre sans corps, mouvement fugace.

Trois intensités existent :

- **Écho** : trace très courte, surtout contextuelle ;
- **Fragment** : information exploitable ou relation importante ;
- **Rémanence majeure** : scène capitale, parfois sous forme de micro-séquence jouable.

Une Rémanence est une trace subjective, pas un enregistrement objectif. Deux témoins peuvent laisser des versions incompatibles du même événement.

## Reconstruction et progression

Il n'existe aucun compteur de « points de Rémanence ». Le joueur découvre des connaissances identifiées puis les relie.

Une reconstruction peut débloquer :

- une nouvelle possibilité de build ;
- une variante de compétence ;
- un Serment ;
- une bataille historique ;
- une option de préparation ;
- de l'équipement ;
- une information sur un ennemi ;
- de la capacité logistique, dont les potions ;
- une connaissance narrative.

Les reconstructions fondamentales doivent offrir plusieurs sources ou chemins équivalents. Aucun système essentiel ne doit dépendre d'un objet à très faible probabilité d'apparition.

## Première ouverture

La première ouverture des Archives doit rester sobre :

- `HOPITAL_DE_SAREI`
- `III_ARMEE`
- `INCONNU`

Une seule instruction : **« Certaines traces peuvent être reliées. »**

## Vues secondaires

- **Chronologie** : événements connus et zones temporelles encore inconnues.
- **Carte** : cités, routes, opérations, migrations et batailles découvertes.
- **Personnes** : dossier historique et réseau relationnel.
- **Sources** : provenance, auteur, nature et fiabilité de chaque information.

## Règle UX

Chaque déblocage doit expliquer sa cause historique. Exemple :

> **CONNAISSANCE RECONSTRUITE — Conservation médicale de campagne**  
> Les coffrets hermétiques de la IIIe Armée permettent de conserver une préparation supplémentaire.  
> **Potions transportables : 3 → 4**

Le système doit donner le sentiment que le joueur a **compris** quelque chose, pas qu'il a acheté un bonus.

## Contrat de persistance

Persistent entre les runs :

- état des nœuds des Archives ;
- sources découvertes ;
- reconstructions réalisées ;
- nouvelles possibilités de build ;
- Serments découverts ;
- opérations historiques révélées ;
- options de préparation et connaissances ennemies ;
- capacités logistiques reconstruites.

Les traumatismes d'une run ne deviennent pas des malus permanents de compte.

## Relation aux trois voies

Corps, Esprit et Politique utilisent les Archives sans en devenir propriétaires. Les Archives sont un système transversal. Les Serments restent eux aussi indépendants de ces trois voies.

## Ligne directrice

**Le Codex dit ce que le développeur veut que le joueur sache. Les Archives montrent ce que le joueur a réussi à comprendre.**
