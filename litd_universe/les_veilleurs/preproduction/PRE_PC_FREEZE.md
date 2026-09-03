# LITD : Les Veilleurs — Gel de préproduction avant PC

Date : 2026-09-03
Statut : contrat fonctionnel pré-prototype. Les paramètres marqués PROTOTYPE ne doivent pas être figés avant test Godot.

## Principes non négociables

- Godot, mobile-first avec adaptation PC complète.
- Groupe de 4 combattants maximum, toujours au moins 1 Veilleur.
- Les 4 Veilleurs sont les seuls protagonistes humains permanents ; les renforts viennent du Ralliement.
- Les recrues restent des individus persistants : identité, seed, blessures, relations, histoire, orientation, mort et éventuelle libération.
- Mort permanente. Pas de résurrection.
- Gore systémique : anatomie, impacts, lésions, conséquences fonctionnelles, armure et environnement. Aucun démembrement par simple proc arbitraire.
- Rémanence : individus, cadavres, ennemis mémoriels, connaissance et cicatrices du donjon persistent de façon bornée.
- Ralliement découvert par connaissance et observation ; aucun pourcentage de capture visible.
- Perception ennemie honnête : aucune IA ne connaît automatiquement la position du joueur.
- Connaissance qualitative, jamais monnaie abstraite.

## Identifiants des Veilleurs

Le contenu existant a employé deux jeux de noms pour les mêmes quatre rôles. Le code et les sauvegardes utilisent donc exclusivement des IDs stables V01, V02, V03, V04. Le nom affiché reste une donnée de localisation/contenu et pourra être canonisé sans migration de gameplay.

- V01 : avant-garde / protection / rupture physique.
- V02 : mobilité / traque / discrétion / information.
- V03 : anatomie / soin / neutralisation / Rémanence corporelle.
- V04 : autorité / ordre / politique / cohésion et dissidence.

## Compétences

Le contrat de contenu est 21 arbres x 15 compétences = 315 compétences. Les 21 ultimes sont des objets séparés, un par arbre, et ne comptent pas dans les 315.

Chaque compétence doit renseigner : type d'action, ciblage, fonctions corporelles requises, impacts autorisés, zones corporelles autorisées et privilégiées, puissance physique qualitative, précision qualitative, lésions possibles, conséquences fonctionnelles, conditions de démembrement, interaction armure, interaction environnement, bruit/vibration/signaux biologiques, risque pour l'utilisateur, tir allié, tags de synergie, tags IA et intention d'animation.

Aucune compétence physique ne peut contourner l'anatomie ou l'armure simplement parce qu'elle est de haut niveau. Les effets doivent émerger de la résolution du contact.

## Bestiaire et Ralliement

Bestiaire V1 des Marches du Sanctuaire : 25 archétypes, 5 familles, 75 orientations.

Familles : Déliés, Retournés, Silencieux, Veines, Porte-Cendres.

Recrues : progression 1-50 ; L10 choix permanent d'une des 3 orientations ; jalons fonctionnels L15/L20/L25/L30/L35/L40/L45/L50. Les recrues conservent leur kit natif et l'orientation le transforme au lieu de créer 45 nouvelles compétences par créature.

Méthodes officielles : Soumission, Reddition, Sauvetage, Pacte, Apprivoisement/acclimatation uniquement lorsque cohérent. Capture et ralliement sont deux états différents.

## Refuge

Capacité : I=4, II=6, III=8, IV=10, V=12. Le Refuge évolue de survie vers communauté politique. Les résidents ont des besoins qualitatifs, des fonctions et des droits ; ils peuvent demander à partir. Refuser physiquement un départ transforme politiquement le Refuge et est mémorisé.

Relations : Confiance, Respect, Peur, Ressentiment. Pas de jauge globale d'amitié.

## SPE — perception événementielle

Canaux : vision, son, odeur, vibration, biologique ; les perturbations de cendre sont un médium spécialisé. La perception produit des hypothèses avec certitude décroissante, jamais une position omnisciente.

Séquence IA : PERCEIVE -> UPDATE BELIEFS -> ASSESS SELF -> ASSESS SITUATION -> SELECT GOAL -> SELECT ACTION -> EXECUTE -> LEARN/REMEMBER.

Vigilance : UNAWARE -> CURIOUS -> SUSPICIOUS -> SEARCHING -> CONFIRMED -> ENGAGED, avec transitions descendantes possibles.

## Rémanence

Mémoire bornée en trois couches : fondatrice, significative, récente. Les souvenirs anciens peuvent être compressés. Certains profils peuvent perdre des détails ou déformer un souvenir via certainty/accuracy.

Ennemi : NORMAL -> MEMORIEL -> VETERAN -> ELITE -> NEMESIS uniquement par événements vécus, jamais par simple rareté.

Persistance de zone par cicatrices ancrées, pas par snapshot complet : corps laissé, porte détruite, pont effondré, croissance Veine, saturation de cendre, objet retiré, événement mémoriel, etc.

## Économie

Ressources persistantes principales : Or, Provisions, Matériaux, Remèdes. La Connaissance est un état qualitatif. Pas d'Essence générique sans fonction indispensable.

Le chargement d'expédition doit créer un arbitrage entre équipement, provisions, stabilisation/entraves et capacité de récupération. Les valeurs exactes restent PROTOTYPE.

## Génération hybride

Pipeline : seed campagne -> macrographe auteur -> contraintes de zone -> sélection de modules -> validation connectivité -> injection cicatrices persistantes -> état faction/écologie -> directeur de rencontres -> ressources -> ancres narratives -> validation extraction -> passe de cohérence.

RNG séparés par flux : monde, rencontre, individu, loot, narration. Recharger ne doit jamais reroll les propriétés persistantes.

## Boss

Boss et mini-boss non ralliables. Ils respectent l'anatomie systémique sauf définition anatomique explicitement spéciale. Pas de sac à PV : les changements de phase doivent privilégier rupture de fonction, terrain, doctrine, réseau ou organe de support plutôt qu'un seuil de PV arbitraire.

## Interface

Mobile : information fonctionnelle d'abord, détail au long press. Ciblage anatomique par grandes zones compatibles avec le pouce. SPE affiché qualitativement. Ralliement via action contextuelle INTERAGIR et uniquement les options réellement comprises.

PC : même logique, densité d'information supérieure ; pas une simple interface mobile agrandie.

## Ce qui reste volontairement PROTOTYPE

Dégâts, PV, probabilités, cooldowns, durée exacte des animations, tailles tactiles exactes, haptique, densité d'ennemis, fréquence d'événements du Refuge, vitesse de progression, coûts économiques exacts, limite numérique de mémoire IA et difficulté. Ces paramètres exigent un build Godot jouable.
