# Chapitre VIII — Le monde extérieur

## Fonction du chapitre

Le Chapitre VIII marque la première sortie durable hors du continent de la Concorde. Il transforme l'enquête sur le Pacte de l'Horizon Fermé en confrontation avec quatre sociétés qui ont elles aussi été frappées par la catastrophe.

La règle canonique est absolue : **la responsabilité d'un dirigeant, d'une institution ou d'un commanditaire ne devient jamais une culpabilité collective de son peuple**.

Le joueur doit donc identifier des responsables précis tout en rencontrant, dans chaque puissance, des civils, dissidents, sauveteurs et témoins qui ont subi ou combattu les décisions de leurs propres autorités.

## Boucle jouable

Le chapitre comporte huit étapes et huit zones, deux par puissance étrangère.

### Varkhane

1. **Frontière des Provinces Libres**
2. **Archives du Trône Vide**

Le joueur rencontre le capitaine **Varek Sorn**, officier ayant refusé une réquisition impériale liée aux relais. Les archives prouvent qu'une partie du pouvoir central soutenait le Pacte alors que certaines unités et provinces l'ont refusé.

Le boss est **Maréchal du Trône Vide**. Sa force principale n'est pas son nombre de PV mais sa légitimité. Trois contre-autorités doivent devenir visibles : officiers dissidents, assemblée provinciale et représentants civils.

Sa résistance passe de 75 % à 50 %, 25 %, puis 0 % au fur et à mesure que ces voix sont reconnues.

Signature : **Ordre du Trône Vide**.

Après le combat : renverser le Maréchal, négocier sa reddition ou soutenir une transition locale qui n'est pas administrée par la Concorde.

### Namar

3. **Port-Refuge d'Ilyara**
4. **Voûte des Registres de Namar**

La navigatrice **Issel Pell** et les refuges flottants montrent une Namar différente des grandes Maisons : dockers, capitaines et communautés déplacées ont parfois falsifié des manifestes ou refusé des contrats pour sauver des dissidents.

Les registres permettent néanmoins d'isoler précisément les transferts financiers liés au cercle d'Yssara Pell et aux composants du Projet Seuil.

Il n'y a pas de boss artificiellement ajouté à cette partie : la difficulté repose sur la négociation, la confiance et la qualité des preuves.

### Azravel

5. **Temple-Refuge de Damar Az**
6. **Cour du Dernier Dogme**

Le joueur rencontre **Frère Oren Val**, religieux qui considère que protéger les faibles est plus fidèle à sa foi que suivre les autorités responsables de purges.

Le boss est **Le Saint de la Faille**. Il maintient son autorité en cachant trois contradictions : le registre des refuges, un texte hétérodoxe et l'ordre de purge.

Sa résistance passe de 80 % à 55 %, 30 %, puis 0 % lorsque ces preuves deviennent publiques.

Signature : **Une seule vérité**.

Les issues sont : révéler publiquement ses mensonges, l'arrêter, ou soutenir le schisme des courants religieux opposés aux purges. Le jeu ne présente jamais la foi des habitants comme la cause collective du crime.

### Kor-Em

7. **Académie Fortifiée de Kor-Em**
8. **Archive des Protocoles Conservés**

La docteure **Keira Om** aide le groupe à accéder à des copies presque complètes du Projet Seuil. Les archives montrent que certains mécènes et princes ont financé l'appropriation des recherches, alors que d'autres chercheurs réclamaient une science ouverte et une coopération avec la Concorde.

La copie technique retrouvée prépare directement le Chapitre IX en montrant quelles modifications du protocole ont été réalisées sans compréhension réelle de la nature du Voile.

## Enquête transfrontalière

Le monde contient 16 sources, quatre par puissance. Pour considérer une puissance comme suffisamment comprise, le joueur doit réunir au moins trois sources et au moins une voix civile ou dissidente.

La progression complète demande au minimum 12 sources, six familles de sources indépendantes et quatre maillons de la chaîne de commandement étrangère.

Cette structure empêche une archive officielle unique de définir tout un peuple.

## Alliés étrangers

- **Capitaine Varek Sorn** — Varkhane
- **Navigatrice Issel Pell** — Namar
- **Frère Oren Val** — Azravel
- **Docteure Keira Om** — Kor-Em

Ils ne sont pas des représentants parfaits de leur civilisation. Ils donnent au joueur des points d'entrée vers des sociétés fragmentées et contradictoires.

## Récompenses

- **Boussole des Quatre Rives** : révèle une fois par expédition l'origine institutionnelle ou civile d'un indice ambigu avant son classement.
- **Catastrophe partagée** : nouvelle connaissance permettant au journal de distinguer peuple, institution, courant et responsabilité individuelle.
- **Maison des Délégations** : nouvelle couche du Sanctuaire accueillant réfugiés, témoins et alliés étrangers.

## Conséquence au Sanctuaire

Après le chapitre, des cartes étrangères annotées par leurs propres habitants, des traductions, des témoignages et de nouveaux réfugiés apparaissent dans la **Maison des Délégations**.

Le Sanctuaire commence ainsi à devenir un lieu international plutôt qu'un refuge uniquement issu de la Concorde.

## Révélation finale

> **La catastrophe n'a pas puni un peuple : elle a traversé les frontières et les régimes qui l'avaient provoquée.**

Les mêmes sociétés qui ont produit certains commanditaires ont aussi produit des opposants, des sauveteurs et des victimes.

Cette conclusion ouvre **Chapitre IX — La nature du Voile**, où les expériences de la Concorde, des quatre puissances, des créatures et des Absents peuvent enfin être comparées.

## Implémentation

Fichiers principaux :

- `data/levels/chapter_08_outer_world.json`
- `data/levels/chapter_08_world.json`
- `scripts/world/chapter_08_runtime.gd`
- `scripts/world/chapter_08_record.gd`
- `scripts/world/chapter_08_node.gd`
- `scripts/world/chapter_08_blockout_builder.gd`
- `scripts/world/chapter_08_boss_runtime.gd`
- `scripts/ui/chapter_08_journal_ui.gd`
- `scenes/world/chapter_08/*.tscn`
- `tests/python/test_chapter_08_runtime.py`

La sauvegarde associée est la version **0.28**.
