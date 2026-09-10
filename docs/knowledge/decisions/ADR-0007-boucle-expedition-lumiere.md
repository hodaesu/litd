# ADR-0007 — Boucle d’expédition et Lumière

- Statut : revalidate
- Confiance : medium_high
- Domaine : gameplay / exploration / roguelike
- Date : 2026-09-10
- Niveau de recherche : R1 (preuve historique forte dans Git, état runtime actuel à reconfirmer)

## Qui ?
Le système d’expédition LITD, les Veilleurs, le joueur et les systèmes de risque/récompense liés à la Lumière.

## Quoi ?
Le dépôt a intégré une boucle d’expédition roguelike déterministe par seed avec carte procédurale, salles de types variés, extraction volontaire, inventaire d’expédition, loot potentiel, mort permanente, bestiaire et persistance de certaines découvertes. La Lumière agit comme variable de risque/récompense : l’obscurité augmente le danger et certaines récompenses/pressions, avec possibilité d’éteindre volontairement une source de lumière.

## Où ?
Preuve historique principale : PR #70 fusionnée le 2026-08-22, qui documente l’intégration du noyau roguelike et sa sérialisation via l’ExpeditionManager existant.

## Pourquoi ?
La boucle d’expédition et la Lumière structurent directement le rythme, la prise de risque, l’extraction et la progression joueur. Elles doivent être représentées dans la bibliothèque afin que les évolutions futures ne détruisent pas silencieusement cette boucle.

## Comment ?
Le système doit rester relié à l’ExpeditionManager existant et éviter un second moteur parallèle. Les décisions de durée, volumes de salles, fenêtres d’extraction ou seuils de Lumière doivent être traitées séparément comme calibrages et non confondues avec l’existence du système lui-même.

## Éléments de preuve
La PR #70 est fusionnée et décrit : génération procédurale déterministe par seed ; Lumière comme mécanique risque/récompense ; inventaire d’expédition limité ; extraction/push-your-luck ; sérialisation des nouveaux états dans ExpeditionManager ; parcours UI complet jusqu’au retour au Sanctuaire ; tests Python, import Godot et smoke tactiles verts au moment de la validation.

## Contre-preuves / tentative de réfutation
Cette preuve atteste une intégration valide à la date de fusion de la PR #70, pas automatiquement l’état exact du runtime actuel. Depuis, le jeu a beaucoup évolué et plusieurs couches UI/runtime ont été remplacées ou étendues. Les calibrages plus récents de Vertical Slice 01 (durée cible, nombre de salles, actes, fenêtres d’extraction et seuils de Lumière) ne doivent donc pas être promus ici comme « implémentés » tant qu’une donnée, un test ou une PR intégrée actuelle ne les confirme.

## Décision
La présence d’une boucle d’expédition roguelike et de la Lumière comme mécanique de risque/récompense est une connaissance techniquement validée historiquement. Son état courant est `revalidate` jusqu’à confirmation par les données/tests du runtime actuel. Les calibrages récents restent distincts de cette ADR et devront recevoir leur propre preuve avant promotion.

## Tests et métriques à relier
- génération reproductible à seed identique ;
- transition Sanctuaire → expédition → salle → extraction → Sanctuaire ;
- sérialisation/rechargement des états d’expédition ;
- variation mesurable du risque/récompense selon la Lumière ;
- absence de second système d’expédition concurrent.

## Relations Knowledge Graph
- depends_on: architecture runtime / ExpeditionManager
- influences: exploration, combat, loot, extraction, peur/folie, persistance
- historical_evidence: PR #70
- status_reason: preuve fusionnée mais runtime actuel à reconfirmer

## Conditions de réexamen
Réexaminer dès qu’un test joueur/E2E actuel couvre la boucle complète, qu’un nouveau système d’expédition remplace ExpeditionManager, ou qu’un calibrage Vertical Slice est relié à des données/tests actuels.