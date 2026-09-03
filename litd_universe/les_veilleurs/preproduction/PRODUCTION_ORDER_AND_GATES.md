# LITD : Les Veilleurs — Ordre de production et portes de validation

## Règle

Ne jamais étendre massivement le contenu tant que la verticale représentative ne prouve pas les systèmes fondamentaux. Les chiffres précis sont ajustés uniquement après instrumentation Godot.

## Ordre de production PC

0. Valider IDs stables et chargeur de données ; créer validateur automatique du contenu.
1. Fondation déterministe : seeds séparées, EventBus, SaveGame versionné, sérialisation minimale.
2. Sandbox combat : tours, ciblage, déplacement, ActionIntent et ActionResolution.
3. Anatomie humanoïde V1 : BodyState, impacts, lésions, conséquences fonctionnelles, mort/incapacité.
4. Armure et armes V1 : couverture de zones, modes d'impact, bruit et exigences corporelles.
5. V01 + V02 : kits réduits représentatifs ; aucun besoin d'implémenter 45 compétences immédiatement.
6. SPE + IA : perception événementielle, croyances, recherche, vigilance, volonté.
7. Cadavre persistant + sauvegarde/chargement exact du corps.
8. Ralliement : une créature réellement recrutable avec blessures conservées et identité persistante.
9. Rémanence individuelle : mémoire, relation, ennemi mémoriel survivant.
10. Persistance du monde : une cicatrice de salle rechargée correctement.
11. Génération hybride : petit macrographe auteur + modules procéduraux + validation extraction.
12. Refuge I : 4 places, affectation, un besoin, un événement relationnel, départ volontaire.
13. V03 + V04 : kits réduits pour tester anatomie/soin et autorité/relations.
14. Vertical slice : une courte expédition complète, cinq familles représentées, boss technique non ralliable, extraction, retour au Refuge.
15. Profilage sur iPhone/iPad cible et PC : CPU, mémoire, save, chargements, lisibilité tactile.
16. Seulement après validation : montée progressive vers 315 compétences, 75 orientations, Refuge I-V et contenu narratif complet.

## Vertical slice minimal représentatif

- 4 Veilleurs avec kits réduits.
- 5 ennemis : un Délié, un Retourné, un Silencieux, une Veine, un Porte-Cendres.
- Au moins 3 situations de ralliement différentes.
- 1 ennemi mémoriel qui survit et réagit plus tard.
- 1 blessure permanente.
- 1 démembrement possible via causalité systémique.
- 1 cadavre retrouvé lors d'un retour.
- 1 cicatrice environnementale persistante.
- 1 événement du Refuge basé sur une mémoire réelle.
- 1 boss technique non ralliable dont la résolution dépend d'une fonction/du terrain plutôt que d'un simple sac à PV.

## Gates obligatoires

### G0 — Données
PASS si : IDs uniques ; 21 arbres peuvent être chargés ; 15 slots par arbre ; références résolues ; ultimes séparés ; erreur bloquante sur contenu invalide.

### G1 — Déterminisme
PASS si : recharger conserve seed individuelle, traits, orientation, équipement et RNG persistant sans reroll.

### G2 — Anatomie
PASS si : une partie détruite ou perdue modifie immédiatement les fonctions ; une compétence incompatible devient indisponible ; l'état persiste après save/load.

### G3 — Armure
PASS si : une armure protège uniquement sa couverture déclarée, se dégrade selon son modèle et modifie correctement le son/mobilité lorsque prévu.

### G4 — IA honnête
PASS si : un ennemi qui entend sans voir enquête vers une hypothèse de position mais ne connaît pas la position réelle ; la certitude décroît ; une diversion peut fonctionner.

### G5 — Ralliement
PASS si : conditions connues et états corporels modifient réellement l'issue ; aucune blessure n'est effacée lors du passage ennemi -> recrue.

### G6 — Mort et cadavre
PASS si : mort permanente ; même CorpseState retrouvé ; cause, identité et lésions conservées ; colonisation/déplacement n'efface pas l'identité du corps.

### G7 — Mémoire/relations
PASS si : deux observateurs du même événement peuvent l'interpréter différemment selon leurs traits/histoire ; la fiche explique qualitativement les causes de relation.

### G8 — Ennemi mémoriel
PASS si : seule une information réellement vécue peut influencer une adaptation future ; mort avant survie empêche toute progression mémorielle.

### G9 — Monde
PASS si : seed de base + ZoneScar reconstruit le lieu modifié sans sauvegarder un snapshot complet.

### G10 — Refuge
PASS si : résident peut avoir besoin/crise/demande de départ ; résolution crée mémoire et conséquence politique ; capacité maximale respectée.

### G11 — Mobile
PASS si : combat, cible anatomique, inspection, ralliement et composition d'équipe sont utilisables à une main sans éléments minuscules ni surcharge d'informations.

### G12 — Robustesse save
PASS si : fermeture/interruption lors d'un autosave récupère toujours A ou B valide et ne duplique ni ne ressuscite une entité.

### G13 — Run complet
PASS si : exploration -> combat -> blessure/ralliement -> extraction -> Refuge -> nouvelle expédition fonctionne sans correction manuelle d'état.

## Paramètres interdits au gel pré-PC

Ne pas figer avant mesure : dégâts exacts, PV exacts, probabilités exactes, cooldowns, nombre final d'usages d'ultime, durées d'animation, tailles tactiles exactes, haptique, densité d'ennemis, fréquence d'événements Refuge, vitesse XP, prix/coûts précis, limite numérique de souvenirs IA, difficulté finale.

## Condition de passage à l'expansion de contenu

Le contenu complet ne commence qu'après PASS de G0 à G13 ou décision explicite documentée acceptant une dette technique précise. Toute dette doit avoir propriétaire, risque, test de sortie et étape de remboursement.
