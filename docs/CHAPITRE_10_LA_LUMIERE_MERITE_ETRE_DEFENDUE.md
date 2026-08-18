# Chapitre X — La lumière mérite d'être défendue

## Fonction du dernier chapitre

Le Chapitre X ne demande pas au joueur quelle fin il préfère abstraitement. Il vérifie quelles orientations le monde est réellement capable de soutenir après toute la campagne.

La règle finale est : **une solution n'existe que si ses conditions politiques, sociales, morales et matérielles ont été construites.**

Le chapitre reprend donc directement les métriques de campagne : confiance, Trois Éveils, relations avec les créatures, contact avec les Absents, alliances étrangères, intégrité de la justice, connaissance du Voile et stabilisateurs disponibles.

## Structure

Le chapitre comporte huit étapes et sept zones.

1. **Conseil du Monde** — constituer les voix qui peuvent réellement participer.
2. **Racines du Premier Voile** — rappeler les besoins matériels des communautés présentes.
3. **Bord des Absents** — entendre les formes de vie qui ne partagent pas entièrement notre réalité.
4. **Routes Partagées** — maintenir le lien avec les peuples étrangers et les refuges.
5. **Chambre du Coût Oublié** — nommer les sacrifices cachés par chaque solution.
6. **Nœud Central** — préparer Corps, Esprit et Cité.
7. **La Rupture Commune** — stabiliser la crise finale.
8. **Ce que nous ferons du monde** — choisir uniquement parmi les orientations réellement disponibles.

## Le Conseil du Monde

Trois voix existent toujours :

- habitants du Sanctuaire ;
- Cercles civiques de la Concorde ;
- survivants des expéditions.

Quatre autres voix ne peuvent participer que si la campagne a créé les relations nécessaires :

- créatures conscientes ;
- Absents ;
- délégations étrangères ;
- Cercle d'Audience.

Le jeu ne transforme pas leur absence en simple malus numérique. Une voix absente réduit aussi la capacité du groupe à reconnaître certaines conséquences de la décision finale.

## Treize enjeux documentés

Le joueur peut documenter treize enjeux issus d'au moins dix familles de sources différentes : réserves, droit au désaccord, infirmes et personnes dépendantes, travail de maintenance, enfants, consentement des Absents, foyer des créatures conscientes, souveraineté étrangère, routes de réfugiés, générations futures, deuil, maintenance permanente et contrôle politique des dispositifs.

Avant d'entrer dans la crise finale, au moins huit enjeux et cinq familles différentes doivent avoir été examinés.

## Mini-boss — Le Coût Oublié

**PV : 188**

Signature : **Quelqu'un paiera**.

La manifestation représente les conséquences que les institutions cessent de compter lorsqu'elles veulent présenter une décision comme sans perte.

Trois témoins environnementaux doivent être activés :

- coût pour les vivants présents ;
- coût pour les Absents et les créatures ;
- coût pour les générations futures.

Sa résistance passe de **85 % → 55 % → 25 % → 0 %**.

## Boss final — La Rupture Commune

**PV : 320**

Phases :

1. **Le monde se sépare**
2. **Une solution pour tous**
3. **Ce que nous refusons de sacrifier**

Signature : **Ce que nous refusons de sacrifier**.

La Rupture Commune n'est ni un dieu maléfique ni l'esprit secret du Voile. C'est une crise du réseau de réalité alimentée par les contradictions réelles du monde.

Elle tente successivement de faire d'une nécessité particulière l'unique réalité légitime : survivre matériellement, préserver les consciences ou maintenir un ordre commun.

Dans son arène, trois ancrages doivent être réactivés :

- **Corps** — aucune idée ne remplace la survie des vivants ;
- **Esprit** — aucune stabilité ne justifie d'effacer les consciences ;
- **Cité** — aucune nécessité ne parle seule au nom de tous.

Sa résistance passe de **95 % → 70 % → 40 % → 0 %**.

Vaincre le boss ne choisit pas la politique du monde. Cela rend seulement une décision encore possible.

## Les orientations finales

Les six orientations existantes restent celles de la bible de campagne :

- **La Grande Fermeture nouvelle** ;
- **La Concorde des deux rives** ;
- **Les Portes gardées** ;
- **Ramener les Absents** ;
- **La Concorde restaurée** ;
- **La Quatrième Veille**.

Le journal final n'affiche comme sélectionnables que les fins retournées par `CampaignState.available_endings()`.

Les autres apparaissent comme **non réalisables par cette partie**, avec les conditions manquantes. Le joueur voit donc aussi ce que ses choix antérieurs n'ont pas permis de construire.

Si aucune orientation globale n'est viable, le monde n'obtient pas une bonne fin gratuite. Un état cohérent est appliqué : archipel de refuges, ordre autoritaire ou fragmentation croissante du réseau.

## Le Sanctuaire après la campagne

Chaque orientation modifie le Sanctuaire en postgame : architecture, circulation, habitants, sons et activité politique.

La Grande Fermeture produit un lieu marqué par les évacuations et les dispositifs scellés. La coexistence fait du Sanctuaire une interface durable entre formes de vie. Les Portes gardées créent un système de passages contrôlés. La recherche des Absents agrandit la Chambre d'Écoute. La Concorde restaurée remet au premier plan les Cercles civiques. La Quatrième Veille crée un nouveau cercle où humains, créatures, étrangers et Absents peuvent être représentés.

Les états d'échec ont eux aussi leur propre Sanctuaire : refuges fragmentés, ordre d'exception ou réseau instable.

## Conclusion canonique

> **La lumière ne supprime pas l'obscurité ; elle rend possible un monde commun malgré elle. Défendre la lumière signifie aussi refuser de cacher qui paie le prix de nos solutions.**

Le jeu ne désigne donc pas une fin parfaite. Il juge la cohérence entre les valeurs revendiquées, les moyens employés et les personnes auxquelles le joueur a réellement permis de participer.

## Implémentation

Fichiers principaux :

- `data/levels/chapter_10_final_choice.json`
- `data/levels/chapter_10_world.json`
- `scripts/world/chapter_10_runtime.gd`
- `scripts/world/chapter_10_stake.gd`
- `scripts/world/chapter_10_node.gd`
- `scripts/world/chapter_10_blockout_builder.gd`
- `scripts/world/chapter_10_boss_runtime.gd`
- `scripts/ui/chapter_10_journal_ui.gd`
- `scenes/world/chapter_10/*.tscn`
- `tests/python/test_chapter_10_runtime.py`

La sauvegarde associée est la version **0.30**.
