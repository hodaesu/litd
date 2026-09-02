# LITD : Les Veilleurs — Premier Accord hybride — relais PC

## État avant PC
Le design, les contrats de données, les ancres de Rémanence, les tables de rencontres, le planificateur hybride, le résolveur de modules et les tests multi-seeds sont préparés dans le dépôt.

Le fallback authored historique reste intact : `res://data/dungeons/first_map_hall_of_first_accord_map.json`.

## Commandes à exécuter sur PC

### 1. Tests Python statiques
```bash
python -m pytest tests/test_first_accord_hybrid_data.py -q
```
Puis la suite existante :
```bash
python -m pytest tests -q
```

### 2. Test Godot multi-seeds
Depuis la racine du projet :
```bash
godot --headless --path . -s res://scripts/tests/first_accord_hybrid_seed_test.gd
```
Résultat attendu :
`FIRST_ACCORD_HYBRID_SEEDS_OK tested=80 unique>=4`

### 3. Vérification parse/compile Godot
Ouvrir le projet sous la version Godot retenue par le projet et vérifier l'absence d'erreur de parsing dans :
- `hybrid_dungeon_generator.gd`
- `first_accord_hybrid_planner.gd`
- `first_accord_hybrid_runtime_plan.gd`
- `first_accord_hybrid_seed_test.gd`

## Points à vérifier visuellement dans Godot
1. Générer au moins 20 seeds et inspecter le graphe obtenu.
2. Confirmer que l'ordre narratif reste : Vestibule → Galerie des Noms → Chambre du Débat → Passage effondré → Salle des Trois Piliers → Sanctuaire du Gardien.
3. Confirmer que les branches facultatives changent réellement entre plusieurs seeds.
4. Confirmer qu'au moins deux possibilités de retraite existent.
5. Vérifier qu'aucun secret n'est nécessaire pour atteindre le boss.
6. Vérifier que le module du boss ne change jamais.
7. Vérifier que le même état de run reproduit exactement le même plan.
8. Vérifier que `visit_index` différent peut produire une configuration différente.
9. Vérifier que les modules de fallback temporaires ne créent pas de connecteurs impossibles.

## Travail 3D obligatoire après validation logique
Créer progressivement de vraies scènes authored pour chaque module du catalogue, avec mêmes identifiants et contrats de connecteurs. Le résolveur temporaire peut alors être remplacé par une bibliothèque suffisamment profonde pour éliminer les fallbacks de rôle.

Pour chaque module :
- scène Godot/asset Blender ;
- origine stable ;
- connecteurs nommés ;
- volumes de collision ;
- navigation ;
- caméra isométrique testée ;
- ancres de variation ;
- ancres de Rémanence ;
- ancres de rencontre ;
- version mobile ;
- détails PC sans modification de collision.

## Tests de Rémanence sur PC
Créer des états artificiels et vérifier au minimum :
- porte détruite ;
- raccourci ouvert ;
- cadavre persistant ;
- trace de Némésis ;
- zone brûlée ;
- objet majeur déjà récupéré ;
- barricade ennemie.

Aucun de ces états ne doit supprimer la seule progression ou la seule retraite disponible.

## Critères avant remplacement du donjon authored actuel
Le nouveau système ne remplace `FirstAccordDungeonMapBuilder` dans le vertical slice que lorsque :
- tests Python verts ;
- test multi-seeds Godot vert ;
- 1000 seeds automatisées sans seed insoluble ;
- navigation validée ;
- caméra validée ;
- budget mobile validé sur appareil ;
- au moins une vraie variante authored par rôle critique ;
- fallback authored toujours fonctionnel.

## Limite atteinte sans PC
À ce stade, les tâches restantes exigent l'exécution de Godot, le bake/navigation, l'inspection visuelle des scènes ou des mesures de performances réelles. Elles ne doivent pas être déclarées validées depuis le chat seul.
