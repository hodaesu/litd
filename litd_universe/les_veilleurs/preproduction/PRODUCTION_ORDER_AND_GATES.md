# LITD : Les Veilleurs — Ordre de production et portes de validation

## Règle

Ne jamais implémenter massivement le contenu simplement parce que le référentiel le spécifie. La verticale représentative doit d'abord prouver les systèmes fondamentaux. Les chiffres précis sont ajustés après instrumentation Godot.

Le référentiel maître actuel contient 180 compétences Veilleurs + 12 ultimes et 1 305 compétences ennemies/boss + 87 ultimes. Ces données constituent la bibliothèque de contenu, pas l'ordre d'implémentation.

## Ordre de production PC

0. Matérialiser le pack canonique 2026-09-03 ; valider provenance, IDs et schémas.
1. Importer le registre des 12 arbres Veilleurs et un sous-ensemble explicitement marqué `prototype_subset` des 180 compétences.
2. Fondation déterministe : seeds séparées, EventBus, SaveGame versionné, sérialisation minimale.
3. Sandbox combat : timeline, ciblage, déplacement, ActionIntent et ActionResolution.
4. Anatomie humanoïde V1 : BodyState, impacts, lésions, conséquences fonctionnelles, mort/incapacité.
5. Armure et armes V1 : couverture de zones, modes d'impact, bruit et exigences corporelles.
6. Nayra + Tarek : kits réduits représentatifs issus exclusivement des fiches canoniques.
7. SPE + IA : perception événementielle, croyances, recherche, vigilance, volonté.
8. Cadavre persistant + sauvegarde/chargement exact du corps.
9. Ralliement : une espèce actuelle réellement ralliable/auxiliaire avec blessures conservées et identité persistante.
10. Rémanence individuelle : mémoire, relation, ennemi mémoriel survivant.
11. Persistance du monde : une cicatrice de salle rechargée correctement.
12. Générateur de rencontres : importer un sous-ensemble des 64 templates + budget/profondeur/anti-répétition.
13. Refuge I : 4 places, affectation, un besoin, un événement relationnel, départ volontaire.
14. Aïsha + Idris : kits réduits canoniques pour anatomie/soin et contrôle/relations.
15. Boss vertical : Ishar, Gardien du Passage, avec ses 3 phases actuelles.
16. Vertical slice : courte expédition Acte I -> combat -> ralliement ou extraction -> retour Refuge -> seconde sortie avec Rémanence.
17. Exécuter les cas des `Tests_48` pertinents pour la verticale.
18. Profilage iPhone/iPad cible et PC : CPU, mémoire, save, chargement, lisibilité tactile.
19. Seulement après PASS : élargir progressivement vers les 180 compétences Veilleurs, puis le bestiaire/rencontres actuels.
20. Les 1 305 compétences ennemies/boss ne sont importées massivement qu'après stabilité des systèmes et outillage de validation.

## Vertical slice minimal représentatif — Acte I

- 4 Veilleurs avec kits réduits mais tirés du corpus canonique.
- Au moins 4 familles/identités de menaces actuelles représentées parmi : Déliés, Pèlerins Fendus, Gardiens de Pierre, Bêtes de Suie.
- 1 auxiliaire/ralliement cohérent issu du référentiel actuel.
- 1 ennemi mémoriel qui survit et réagit plus tard.
- 1 blessure permanente ou longue durée issue de `Rémanence_blessures`.
- 1 Trace psychologique réellement déclenchée.
- 1 démembrement possible via causalité systémique.
- 1 cadavre retrouvé lors d'un retour.
- 1 cicatrice environnementale persistante.
- 1 événement du Refuge basé sur mémoire réelle.
- Ishar comme boss technique non ralliable ; ses phases doivent tester contrôle du seuil, mémoire/adaptation et droit de refus, pas seulement un pool de PV.

## Gates obligatoires

### G0 — Provenance et données Veilleurs
PASS si : source canonique identifiée ; 12 arbres chargés ; 180 compétences présentes dans le registre complet ; 12 ultimes séparés ; IDs uniques ; 15 compétences par arbre ; aucune donnée du stade 315 chargée comme actuelle.

### G0B — Données ennemis/boss
PASS si : 29 entités ; 87 arbres ; 1 305 compétences ; 87 ultimes dans le registre complet de référence ; le prototype peut n'en instancier qu'un sous-ensemble explicitement déclaré.

### G1 — Déterminisme
PASS si : recharger conserve seed individuelle, traits, équipement, mémoire et RNG persistant sans reroll.

### G2 — Anatomie
PASS si : une partie détruite ou perdue modifie immédiatement les fonctions ; une compétence incompatible devient indisponible ; l'état persiste après save/load.

### G3 — Armure
PASS si : une armure protège uniquement sa couverture déclarée, se dégrade selon son modèle et modifie correctement son/mobilité lorsque prévu.

### G4 — IA honnête
PASS si : un ennemi qui entend sans voir enquête vers une hypothèse de position mais ne connaît pas la position réelle ; la certitude décroît ; une diversion peut fonctionner.

### G5 — Ralliement
PASS si : conditions connues et état corporel modifient réellement l'issue ; aucune blessure n'est effacée lors du passage ennemi -> auxiliaire/recrue.

### G6 — Mort et cadavre
PASS si : mort permanente ; même CorpseState retrouvé ; cause, identité et lésions conservées ; colonisation/déplacement n'efface pas l'identité du corps.

### G7 — Mémoire / relations / Traces
PASS si : deux observateurs peuvent interpréter différemment un événement ; relations expliquées qualitativement ; au moins une Trace du référentiel peut apparaître, évoluer et persister.

### G8 — Ennemi mémoriel
PASS si : seule une information réellement vécue influence une adaptation future ; mort avant survie empêche toute progression mémorielle.

### G9 — Monde
PASS si : seed de base + ZoneScar reconstruisent le lieu modifié sans snapshot complet.

### G10 — Refuge
PASS si : résident peut avoir besoin/crise/demande de départ ; résolution crée mémoire et conséquence politique ; capacité respectée.

### G11 — Rencontres
PASS si : un sous-ensemble des templates actuels est généré selon budget/profondeur sans répétition abusive et sans contre-composition artificielle.

### G12 — Boss
PASS si : Ishar traverse ses 3 phases selon les règles du référentiel et peut être battu par compréhension/positionnement, pas uniquement par DPS.

### G13 — Mobile
PASS si : combat, cible anatomique, inspection, ralliement et composition d'équipe sont utilisables au tactile sans éléments minuscules ni surcharge.

### G14 — Robustesse save
PASS si : interruption d'autosave récupère toujours A ou B valide et ne duplique ni ne ressuscite une entité.

### G15 — Run complet
PASS si : exploration -> combat -> blessure/ralliement -> boss/extraction -> Refuge -> nouvelle expédition fonctionne sans correction manuelle d'état.

### G16 — Tests récupérés
PASS si : tous les cas applicables de `Tests_48` sont exécutés automatiquement ; tout échec est traçable à une règle ou donnée identifiable.

## Baselines à ne pas confondre avec équilibre final

Le référentiel contient déjà des valeurs de puissance, précision, cooldown, niveaux et charges. Elles sont la baseline de conception à implémenter pour test, puis à mesurer. Ne pas les remplacer arbitrairement avant premier prototype ; ne pas non plus les considérer comme définitives avant playtest.

## Contenu supersédé

- `315 compétences / 21 ultimes` avec Barek/Ilya/Oshren : historique.
- `25 archétypes / 75 orientations` : réserve de concepts, pas roster quantitatif actuel.

Ces ensembles ne doivent pas être supprimés de l'histoire du projet, mais aucun test de build actuel ne doit les compter comme canon actif.

## Condition de passage à l'expansion de contenu

L'industrialisation du contenu commence après PASS G0 à G16, ou dette explicitement documentée avec risque, test de sortie et étape de remboursement.
