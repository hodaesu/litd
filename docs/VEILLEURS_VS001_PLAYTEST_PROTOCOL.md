# LITD : Les Veilleurs — VS001 Playtest Protocol

Mission : **Les Voix sous le Sanctuaire**  
Baseline : `WATCHERS_VERTICAL_001`  
Statut : **équilibrage provisoire avant playtest humain**

## Principe

Les simulations synthétiques servent à détecter les contradictions, les valeurs impossibles et les régressions. Elles ne valident ni le rythme, ni la tension, ni la lisibilité, ni le plaisir de jeu. La première passe d’équilibrage humain commence à **12 runs complets ou interrompus documentés**.

Aucun testeur ne doit être informé de l’existence de S8 lors de sa première partie. Une découverte secrète mesurée après divulgation n’a plus de valeur.

## Avant chaque run

Enregistrer :

- `build_id` ;
- seed ;
- profil appareil : téléphone / tablette / desktop / handheld PC ;
- profil d’entrée : tactile / souris-clavier / manette ;
- expérience du testeur avec les roguelikes : novice / intermédiaire / habitué ;
- première partie VS001 : oui/non.

Ne pas enregistrer de nom, adresse, compte, texte libre ou modèle matériel exact dans la télémétrie automatique.

## Première vague — 12 runs

| Run | Style demandé | S6 | S7 | Secret | But principal |
|---|---|---|---|---|---|
| 01 | Aveugle / naturel | libre | libre | ne rien révéler | première compréhension globale |
| 02 | Aveugle / naturel | libre | libre | ne rien révéler | seconde lecture indépendante |
| 03 | Équilibré | tenter approche prudente | libre | ne rien révéler | lumière/bruit + recrutement doux |
| 04 | Équilibré | tenter approche prudente | libre | ne rien révéler | reproductibilité recrutement doux |
| 05 | Équilibré | laisser la Goule | désactiver | facultatif | valeur d’une non-capture |
| 06 | Équilibré | tuer après état non hostile | détruire | inaccessible | vérifier absence de prime morale |
| 07 | Méthodique | tenter approche prudente | étudier | ne pas révéler S8 | pression du temps et curiosité |
| 08 | Méthodique | libre | étudier | ne pas révéler S8 | valeur des salles facultatives |
| 09 | Méthodique | tenter approche prudente | libre | ne rien révéler | consommation maximale raisonnable |
| 10 | Ruée | maîtrise immédiate | détruire | inaccessible | borne basse temps / borne haute risque |
| 11 | Bruyant volontaire | maîtrise immédiate | libre | ne rien révéler | propagation sonore et réactions IA |
| 12 | Ruée | libre | libre | ne rien révéler | lisibilité quand le joueur néglige l’enquête |

Le « style demandé » ne doit jamais dicter les actions combat tour par tour. Le joueur conserve ses décisions tactiques.

## Répartition appareils visée

Pour la première vague, si le matériel est disponible :

- 4 runs desktop souris-clavier ;
- 2 runs manette ou handheld PC ;
- 4 runs téléphone ;
- 2 runs tablette.

Si tous les appareils ne sont pas encore disponibles, **ne pas retarder le test gameplay** : noter simplement les profils non couverts. Les mêmes runs pourront être rejoués ensuite pour QA d’interface, mais pas comptés comme nouveaux « premiers runs » pour le taux de découverte S8.

## Mesures automatiques obligatoires

Le contrat détaillé est dans `data/veilleurs/vs001_telemetry_contract.json`.

À comparer aux garde-fous :

| Mesure | Baseline cible |
|---|---:|
| Durée médiane | 25–35 min |
| Lumière à première entrée S7 | 30–65 |
| Pic de bruit typique | 20–55 |
| Blessures critiques nouvelles typiques | 0–2 |
| Recrutement prudent réussi | 70–90 % à terme |
| Maîtrise immédiate réussie | 20–45 % à terme |
| Découverte S8 en première partie | 20–40 % à terme |
| Événements majeurs perçus | 1–4 par run |

Avec seulement 12 runs, les pourcentages sont des **signaux**, pas des preuves statistiques. Ne pas corriger un système uniquement parce qu’un taux brut sur 2 ou 3 tentatives semble hors plage.

## Questions qualitatives après le run

Les réponses restent dans une fiche de test séparée de la télémétrie automatique.

1. À quel moment as-tu senti que le donjon devenait dangereux ?
2. As-tu compris que la lumière avait un coût avant qu’elle devienne faible ?
3. As-tu relié au moins une réaction ennemie au bruit que tu avais produit ?
4. Le premier combat t’a-t-il appris quelque chose sur les cadavres ?
5. Quand une blessure corporelle est apparue, as-tu compris sa conséquence fonctionnelle ?
6. En S6, qu’as-tu cru possible avant de voir les choix proposés ?
7. Si tu as recruté la Goule, qu’est-ce qui t’a convaincu que ta méthode avait aidé ?
8. Si tu l’as tuée ou laissée, as-tu eu l’impression de perdre une récompense « obligatoire » ?
9. En S7, quelle différence pensais-tu qu’il y avait entre détruire, désactiver et étudier ?
10. As-tu fait demi-tour ou envisagé l’extraction ? Pourquoi ?
11. Quelle information t’a manqué à l’écran ?
12. Quelle information affichée t’a paru inutile ou trop insistante ?

Ne pas demander « As-tu aimé ? » comme question principale : demander **où**, **quand** et **pourquoi** une décision ou une information a posé problème.

## Échelle de problèmes

### P0 — Bloquant

- crash ;
- softlock ;
- sauvegarde corrompue ;
- objectif impossible ;
- extraction impossible ;
- divergence de règles entre plateformes.

Action : corriger avant tout nouveau playtest comparable.

### P1 — Rupture systémique

- recrutement prudent moins fiable que la force sans raison ;
- le bruit semble sans conséquence ou omniscient ;
- la lumière ne crée aucun arbitrage ;
- une blessure grave n’a pas de conséquence lisible ;
- tuer S6 devient objectivement la meilleure récompense ;
- S8 devient nécessaire à la progression.

Action : corriger avant la seconde vague.

### P2 — Équilibrage

- combat trop long/court ;
- lumière légèrement trop généreuse/sévère ;
- fréquence événementielle ;
- valeur de loot ;
- probabilité recrutement ;
- puissance fine d’une Goule.

Action : regrouper plusieurs observations avant modification.

### P3 — Présentation

- texte trop long ;
- feedback tardif ;
- icône ambiguë ;
- animation ou vibration mal calibrée ;
- placement UI inconfortable.

Action : corriger indépendamment si cela ne change pas la règle.

## Règles de rééquilibrage

1. Corriger P0 avant tout calcul d’équilibrage.
2. Modifier **une famille de paramètres à la fois** : lumière, bruit, Goules, recrutement, événements ou loot.
3. Conserver les métriques et la version avant/après.
4. Une modification normale reste dans les limites définies par `vs001_playtest_guardrails.json`.
5. Ne jamais augmenter la récompense de la mise à mort S6 pour « compenser » le recrutement.
6. Ne jamais faciliter la capture par mutilation au point qu’elle devienne la stratégie dominante ; le contrat global impose aussi une dégradation du lien et une convalescence.
7. Ne pas équilibrer S8 pour forcer son taux de découverte : le secret doit rester une conséquence de curiosité et de lecture du dispositif.
8. Après une modification importante, rejouer au minimum un profil équilibré, un méthodique et un run de ruée avant d’accumuler de nouvelles statistiques.

## Après 12 runs

Produire un rapport avec quatre colonnes pour chaque famille :

`Baseline → Mesure humaine → Diagnostic → Modification proposée`

Une valeur dans la cible peut tout de même être mauvaise si les retours montrent que le joueur ne comprend pas la cause de ce qu’il subit. Inversement, une valeur momentanément hors cible sur 12 runs ne justifie pas automatiquement une correction.

## Après 30 runs

Les changements supérieurs aux limites normales de garde-fou peuvent être envisagés si :

- la tendance reste stable ;
- au moins deux profils de joueurs ou appareils sont concernés ;
- le problème n’est pas d’abord un problème de lisibilité ;
- le changement ne casse pas les invariants narratifs et systémiques.

À ce stade seulement, les valeurs pourront commencer à passer de **baseline provisoire** à **équilibrage candidat**. Elles ne deviennent « définitives » qu’après validation du vertical slice complet sur les appareils cibles.
