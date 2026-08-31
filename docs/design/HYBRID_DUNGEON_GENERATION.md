# Génération hybride des donjons

LITD ne génère jamais intégralement la géométrie de ses niveaux. Chaque salle, porte tactique, arène, repère visuel et emplacement d'interaction est conçu puis validé à la main. Le procédural assemble ces salles selon un graphe contrôlé et ne modifie que des emplacements explicitement autorisés.

## Répartition

| Contenu | Politique |
|---|---|
| Première carte, didacticiel et Sanctuaire | Entièrement manuel |
| Première visite d'un donjon de campagne | Parcours et mise en scène manuels |
| Revisite d'un donjon de campagne | Salles manuelles, branches variables |
| Donjon facultatif, prime et farm | Assemblage procédural de salles manuelles |
| Boss, quête majeure, héros unique, cinématique | Toujours manuel |

## Contrat d'une salle

Une salle livrée par Blender/Godot possède une géométrie immuable, des portes compatibles et des emplacements nommés pour les formations ennemies, patrouilles, pièges, coffres, curiosités, éclairages et événements. Le générateur choisit uniquement parmi ces emplacements.

Chaque variante doit changer au moins une décision : combattre ou contourner, sécuriser ou risquer, consommer une ressource, prendre un raccourci, enquêter, se reposer ou repartir.

## Validation obligatoire

Avant de rendre un plan jouable, le générateur vérifie :

- un chemin physique entre l'entrée et l'objectif ;
- un trajet de retraite vers une sortie ;
- la compatibilité du routage des cendres ;
- l'absence de connexion vers une salle inconnue ;
- l'accessibilité des objectifs de quête ;
- l'unicité des salles obligatoires ;
- la dissimulation des salles secrètes avant leur découverte.

Si une validation échoue, le plan est rejeté et le runtime utilise le générateur historique de secours. La graine est sauvegardée afin qu'un rechargement ne puisse pas modifier le donjon.

## Premier Voile

Les Cryptes du Premier Voile utilisent le catalogue de plus de trente salles déjà dessinées. La première descente conserve le parcours mis en scène. Les revisites, primes et expéditions de farm utilisent le graphe hybride : entrée, approche, bifurcation, convergence, repos ou risque, récompense, antichambre et boss. Un raccourci de retour et une salle secrète facultative peuvent modifier le parcours sans compromettre la narration.
