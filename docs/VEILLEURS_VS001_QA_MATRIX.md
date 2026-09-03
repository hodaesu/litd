# LITD : Les Veilleurs — VS001 QA Matrix

Mission de référence : **Les Voix sous le Sanctuaire**  
Seed de référence : `WATCHERS_VERTICAL_001`

## But

Ce document définit les tests fonctionnels qui doivent être validés avant de considérer le vertical slice jouable comme stable. Les règles de gameplay sont identiques sur téléphone, tablette, PC et manette ; seuls la présentation et les périphériques changent.

## A. Démarrage, seed et sérialisation

| ID | Scénario | Attendu |
|---|---|---|
| A01 | Lancer VS001 avec `WATCHERS_VERTICAL_001` | Graphe S1–S8 identique, S7 objectif, S6/S8 facultatives |
| A02 | Sauvegarder en S3 puis recharger | Salle, lumière, bruit, blessures, inventaire et seed restaurés |
| A03 | Sauvegarder après désamorçage S2 puis recharger | Piège reste neutralisé |
| A04 | Sauvegarder après recrutement S6 puis recharger | Identité, blessures et historique de la Goule persistent |
| A05 | Sauvegarder après étude/destruction/désactivation S7 | État exact du dispositif restauré |
| A06 | Recharger plusieurs fois avant un jet déterministe | Aucun reroll exploitable |
| A07 | Retour au hub puis nouvelle expédition | Les cicatrices/flags persistants restent ; aucun snapshot complet de scène n’est requis |

## B. Structure du donjon

| ID | Scénario | Attendu |
|---|---|---|
| B01 | Suivre uniquement le chemin critique | S1→S2→S3→S5→S7 accessible |
| B02 | Ignorer S4 | Objectif reste réalisable |
| B03 | Ignorer S6 | Objectif reste réalisable |
| B04 | Détruire le dispositif S7 | Objectif validable, S8 inaccessible |
| B05 | Désactiver le dispositif S7 | Objectif validable, S8 inaccessible |
| B06 | Étudier le dispositif avec succès | S8 devient accessible |
| B07 | Ne jamais découvrir S8 | Aucun blocage de progression |
| B08 | Faire demi-tour avant S7 | Retour physique à l’entrée possible |

## C. S1 — Vestibule

| ID | Scénario | Attendu |
|---|---|---|
| C01 | Entrer pour la première fois | Dialogue d’entrée contextuel |
| C02 | Inspecter brièvement la fresque | Information visuelle sans coût de Pulse |
| C03 | Inspection approfondie réussie | `KNOWLEDGE_PRE_SANCTUARY_STRUCTURE`, certitude faible |
| C04 | Inspection approfondie échouée | Aucune fausse certitude ; progression non bloquée |
| C05 | Revenir plus tard | État de connaissance cohérent avec ce qui a réellement été découvert |

## D. S2 — Piège et bruit

| ID | Scénario | Attendu |
|---|---|---|
| D01 | Tarek mène la détection en lumière claire | Bonus de profil et de lumière correctement pris en compte |
| D02 | Piège non détecté | Aucun indicateur omniscient |
| D03 | Désamorcer avec succès | Piège neutralisé, récupération possible, 1 Pulse |
| D04 | Contourner avec succès | Piège reste physiquement présent mais n’est pas déclenché |
| D05 | Échec désamorçage | Piège déclenché, conséquences corporelles + bruit |
| D06 | Déclenchement | +30 bruit et groupe S3 passe en alerte |
| D07 | Déclenchement à distance | Bruit produit mais risque corporel direct évité |
| D08 | Rechargement après piège déclenché | État déclenché conservé, aucun reroll |

## E. Lumière

| ID | Scénario | Attendu |
|---|---|---|
| E01 | Début expédition | Lumière = 82 |
| E02 | Marche normale | -2 par Pulse |
| E03 | Marche prudente | -3 par Pulse et bonus de détection |
| E04 | Recherche approfondie | -4 |
| E05 | Huile standard | +30, plafonné à 100 |
| E06 | Passer 76→75 | État Claire→Stable, modificateurs mis à jour |
| E07 | Passer 51→50 | Stable→Faible |
| E08 | Passer 26→25 | Faible→Critique |
| E09 | Atteindre 0 | Obscurité, aucune valeur négative |
| E10 | Même action en faible lumière | Les mécaniques changent sans modifier la topologie du donjon |

## F. Bruit et propagation

| ID | Scénario | Attendu |
|---|---|---|
| F01 | Pulse calme | bruit -5, minimum 0 |
| F02 | Marche normale | +2 |
| F03 | Porte forcée | +20 |
| F04 | Combat violent | +25 |
| F05 | Bruit traverse corridor ouvert | Atténuation 0,70 puis absorption de salle |
| F06 | Bruit traverse porte lourde | Atténuation nettement supérieure au corridor |
| F07 | Réseau acoustique S7 intact | Transmission renforcée via conduit acoustique |
| F08 | Bruit entendu ≥20 | Patrouille peut enquêter |
| F09 | Bruit entendu ≥40 | État d’alerte possible |
| F10 | Bruit entendu ≥60 | Préparation d’embuscade possible |
| F11 | Bruit entendu ≥80 | Localisation approximative du groupe possible, jamais connaissance totale |

## G. S3 — Premier combat et cadavres

| ID | Scénario | Attendu |
|---|---|---|
| G01 | Entrée calme | 2 Affamées + 1 profil Éclaireuse |
| G02 | S2 a fait du bruit | Rencontre démarre en état d’alerte différent |
| G03 | Affamée <65 % PV + cadavre accessible | `corpse_feast` devient une option IA |
| G04 | Festin utilisé | soin + buff, créature tactiquement vulnérable pendant son choix |
| G05 | Éclaireuse identifie le groupe | Peut pousser un cri d’alerte puis chercher à fuir |
| G06 | Éclaireuse fuit | Peut devenir individu mémoriel si événement significatif |
| G07 | Fin du combat | Cadavres nouveaux restent dans la salle |
| G08 | Quitter puis revenir | Les cadavres ne disparaissent pas par reset de salle |
| G09 | Conditions EVT_10 réunies | Un cadavre peut être déplacé/consommé et la cicatrice est stockée par anchor/flag |

## H. Blessures anatomiques

| ID | Scénario | Attendu |
|---|---|---|
| H01 | Coup anatomique échoue | Dégâts HP normaux, trauma ×0,35 |
| H02 | Résultat partiel | Dégâts HP normaux, trauma ×0,65 |
| H03 | Succès | trauma ×1 |
| H04 | Succès fort | trauma ×1,15 |
| H05 | Bras atteint 35 % seuil | `fragile` |
| H06 | Bras atteint 65 % | `wounded` |
| H07 | Bras atteint 85 % | `critical` et forte perte fonctionnelle |
| H08 | Bras atteint 100 % avec condition de section | `lost`, fonction indisponible |
| H09 | Tête atteint seuil critique | Jamais sectionnée par action joueur normale |
| H10 | Jambe critique | mobilité/dodge diminués + boiterie |
| H11 | Saignement 100 | exsanguination létale |
| H12 | Mode gore réduit/off | Même calcul de trauma, blessure et fonction que mode complet |

## I. Soins

| ID | Scénario | Attendu |
|---|---|---|
| I01 | Bandage | -2 niveaux de saignement, 1 Pulse |
| I02 | Suture avec médecine <70 | Action non disponible ou échec contractuel explicite |
| I03 | Suture Aïsha | Affinité appliquée, coût minimum 1 Pulse |
| I04 | Attelle fracture | pénalité de fracture réduite de moitié |
| I05 | Stabilisation critique Aïsha | empêche un contrôle d’aggravation |
| I06 | Extraction avec blessure `wounded+` | blessure persistante au hub |
| I07 | Perte de membre | état corporel permanent et événement historique |

## J. S4 — Vasque noire et loot

| ID | Scénario | Attendu |
|---|---|---|
| J01 | Ignorer S4 | Aucune pénalité de mission |
| J02 | Fouiller | huile standard + bandage + seed toolkit + 8 or |
| J03 | Eau sur vasque | `BLACK_BASIN_WATER_REACTION` mémorisée |
| J04 | Recharger après découverte | Connaissance persiste |
| J05 | Toucher sans savoir | Risque de contamination, aucune encyclopédie automatique |
| J06 | Sang/lumière | Résultats restent verrouillés tant que leur design n’est pas activé |

## K. S5 — Investigation

| ID | Scénario | Attendu |
|---|---|---|
| K01 | Inspection simple par Aïsha | Mort et blessures correctement décrites |
| K02 | Inspection approfondie réussie | Corps identifié comme déplacé après mort |
| K03 | Tarek contribue à la trace | Piste vers S6 révélable |
| K04 | Ignorer l’indice S6 | Mission reste réalisable |
| K05 | Bruit mural | Présenté comme anomalie acoustique, pas comme fantôme certain |

## L. S6 — Recrutement

| ID | Scénario | Attendu |
|---|---|---|
| L01 | Première entrée | Goule ne charge pas automatiquement |
| L02 | Observer | peur -5, confiance +2, stabilité +3 |
| L03 | Nayra baisse sa garde | peur -8, confiance +10, agressivité -8 |
| L04 | Tarek bloque la sortie | contrainte augmente mais peur/agressivité montent |
| L05 | Aïsha diagnostique | révèle jambe critique/douleur/soin sûr |
| L06 | Aïsha soigne avec ressource | peur -15, confiance +18, douleur -25, stabilité +18, PV +7 % |
| L07 | Idris désamorce | peur -18, confiance +9, agressivité -12, stabilité +10 |
| L08 | Approche non préparée à peur ≥85 | attaque défensive possible |
| L09 | Capture après séquence prudente | taux cible de playtest 70–90 % |
| L10 | Maîtrise immédiate | taux cible 20–45 %, conséquences relationnelles négatives |
| L11 | Manifestation destructrice présente | recrutement impossible |
| L12 | Slots régionaux pleins | recrutement impossible |
| L13 | Sanctuaire plein | recrutement impossible |
| L14 | Capture réussie | règles globales de blessures de capture appliquées |
| L15 | Capture réussie | identité + historique `abandoned_wounded`, `fear_origin` persistants |
| L16 | Après recrutement avant soins terminés | combat indisponible conformément au contrat global |
| L17 | Tuer la Goule | pas de récompense rare exclusive ; empêche optimisation morale artificielle |
| L18 | La laisser | entité peut persister et réapparaître selon futurs systèmes |

## M. S7 — Objectif

| ID | Scénario | Attendu |
|---|---|---|
| M01 | Combat | 1 Goule vorace niveau 5 + 2 Affamées |
| M02 | Vorace sous pression | privilégie blessés/faibles et cadavres selon poids IA |
| M03 | Vorace survit à événement fort | éligible promotion mémorielle/Némésis, jamais automatique sans histoire |
| M04 | Détruire dispositif | état persistant `destroyed`, mission conclue, S8 fermée |
| M05 | Désactiver | `disabled`, mission conclue, S8 fermée |
| M06 | Étudier succès | `studied`, mission conclue, S8 ouverte |
| M07 | Étudier échec | aucun secret gratuit ; joueur peut décider du risque temporel suivant |
| M08 | Confirmation destruction | action irréversible exige validation explicite |

## N. S8 — Secret

| ID | Scénario | Attendu |
|---|---|---|
| N01 | Accès sans étude S7 | impossible |
| N02 | Accès après étude | possible |
| N03 | Lire fragment | `KNOWLEDGE_THREE_PATHS_PRE_NAMING`, certitude moyenne |
| N04 | Interprétation | Présentée comme contradiction/hypothèse, pas retcon certain |
| N05 | Quitter sans fragment | mission principale déjà valide |

## O. Extraction et retour

| ID | Scénario | Attendu |
|---|---|---|
| O01 | Extraire avant S7 | confirmation explicite |
| O02 | Extraction partielle | loot, blessures, recrutement et connaissances acquis restent ; récompense mission perdue |
| O03 | Extraire après objectif | bilan complet |
| O04 | Retour bruyant ≥50 | EVT_09/patrouille retour possible |
| O05 | Retour calme | pas de patrouille forcée |
| O06 | Route de retour | lumière continue de diminuer et monde continue d’évoluer |
| O07 | Mort du groupe | conséquences persistantes prévues par la campagne, pas de reset magique du monde |

## P. Loot et économie

| ID | Scénario | Attendu |
|---|---|---|
| P01 | Seed fixe parcours complet | 67 or de base |
| P02 | S3 | bandage seedé + 21 or + tissu commun |
| P03 | S4 | huile + bandage + toolkit + 8 or |
| P04 | S5 | jeton éclaireur + enveloppe médicale usée |
| P05 | S7 | composant acoustique + outil de résonance rare + 38 or |
| P06 | S8 | fragment d’archive, pas de jackpot matériel |
| P07 | Tuer S6 | ne génère pas un objet de valeur exclusif |
| P08 | Génération aléatoire future | poids rareté 70/22/7/1/0 dans VS001 |

## Q. Téléphone

| ID | Scénario | Attendu |
|---|---|---|
| Q01 | Tous boutons primaires | cible tactile ≥48 pt |
| Q02 | Combat | tap compétence → aperçu → tap cible ; pas d’attaque au premier tap |
| Q03 | Information | aucune action irréversible déclenchée par inspection |
| Q04 | Long press jamais utilisé | toutes les informations restent accessibles |
| Q05 | Pop-up contextuel | ne masque pas la zone sous le doigt si alternative de placement possible |
| Q06 | Safe areas | aucun contrôle sous encoche/home indicator |
| Q07 | Mode gaucher | contrôles principaux reconfigurables |
| Q08 | Inventaire | tap sélectionne, n’utilise pas directement l’objet |

## R. Tablette

| ID | Scénario | Attendu |
|---|---|---|
| R01 | Combat | même logique tactile que téléphone |
| R02 | Espace disponible | panneau contextuel latéral possible sans réduire la lisibilité du combat |
| R03 | Carte/inventaire | davantage d’informations simultanées, mêmes règles de jeu |
| R04 | Aucune mise à l’échelle 16:9 forcée | interface utilise réellement la surface disponible |

## S. PC souris/clavier

| ID | Scénario | Attendu |
|---|---|---|
| S01 | Survol | aperçu uniquement, jamais action obligatoire |
| S02 | Clic gauche | sélection/validation contextuelle |
| S03 | Clic droit | inspection/annulation selon contexte |
| S04 | WASD/ZQSD | déplacement |
| S05 | E | interaction |
| S06 | 1–6 | sélection compétences après ajout des actions runtime |
| S07 | F1–F4 | sélection Veilleurs après ajout des actions runtime |
| S08 | I/M | inventaire/carte après ajout des actions runtime |
| S09 | H | statut utilise l’action déjà existante `status_hud` |
| S10 | Informations latérales | plus riches que mobile mais sans avantage mécanique caché |

## T. Manette / Steam Deck

| ID | Scénario | Attendu |
|---|---|---|
| T01 | Navigation | tout écran utilisable sans pointeur |
| T02 | Focus | anneau/état de focus toujours visible |
| T03 | Bouton sud | confirmer |
| T04 | Bouton est | annuler |
| T05 | Épaules | cycle Veilleurs |
| T06 | Gâchettes | catégories/ensembles de compétences |
| T07 | Ciblage | stick droit/dpad selon contexte |
| T08 | Vibration désactivée | aucune information de gameplay perdue |

## U. Accessibilité

| ID | Scénario | Attendu |
|---|---|---|
| U01 | Texte agrandi | aucun bouton critique masqué |
| U02 | UI scale | interface reste utilisable dans les profils supportés |
| U03 | Reduced motion | aucune information dépend d’une animation |
| U04 | Reduce flashes | aucune information dépend d’un flash |
| U05 | Gore réduit/off | aucune mécanique anatomique supprimée |
| U06 | Haptique off | feedback visuel/sonore suffisant |
| U07 | Daltonisme | aucune information critique communiquée uniquement par couleur |

## V. Objectifs de playtest

- Durée médiane : **25–35 min**.
- Lumière à l’entrée de S7 sur parcours typique : **30–65**.
- Bruit typique : **20–55**.
- Blessures critiques typiques du groupe : **0–2**.
- Recrutement S6 après approche prudente : **70–90 %** de réussite cible.
- Recrutement S6 par force immédiate : **20–45 %** cible.
- Découverte S8 en première partie : **20–40 %** cible.

Ces plages sont des objectifs de télémétrie/playtest, pas des garanties truquées par le générateur.

## Critère de sortie VS001

Le vertical slice est considéré **fonctionnellement complet** lorsque A–U passent sur PC et que les sections Q/R/T ont au minimum un appareil/profil réel validé chacune, sans divergence de sauvegarde ou de règles entre plateformes.
