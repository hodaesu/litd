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
