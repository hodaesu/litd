# LITD 2 — Bibliothèque de mouvements de combat et de magie

Cette bibliothèque sert de **réservoir de mouvements** pour le prototype Unreal de LITD 2. Elle ne rajoute aucune commande au joueur : toutes les variantes restent compatibles avec les cinq entrées retenues :

- `Light` — attaque légère
- `Heavy` — attaque lourde
- `Parry` — parade / parade parfaite
- `Dodge` — esquive / esquive parfaite
- `SkillAttack` — attaque de compétence, technique spéciale ou sort

## Contenu V1

- **40 mouvements mains nues**
- **72 mouvements armes blanches**
- **48 sortilèges / mouvements de magie**
- **60 animations / mouvements du build Politique**
- **220 entrées au total**

## Principe

Les entrées ne sont pas des copies d'animations existantes. Elles extraient des principes de chorégraphie — rythme, trajectoire, transfert de poids, distance, lisibilité, création d'une ouverture ou fin de séquence — puis les recomposent pour LITD 2.

Une animation finale doit toujours être lisible, compatible avec le timing gameplay autoritaire, courte hors finisher/compétence engagée, cohérente avec le poids de l'arme, compatible avec le transfert de cible et avec gore/démembrement lorsque c'est pertinent.

## Mains nues

La bibliothèque privilégie les frappes compactes, coudes et genoux, low kicks, déviations, esquives du buste et pas latéraux, projections courtes et utilisation contextuelle de l'environnement. Les enchaînements spéciaux restent généralement limités à 2–3 temps afin de préserver le contrôle.

Références de direction : `The Raid`, `The Raid 2`, films de Jackie Chan et Sammo Hung, `John Wick`, `Ong-Bak`, `Tom-Yum-Goong`, `Oldboy`, `Sifu` et principes Pak Mei comme référence de compacité.

## Armes blanches

Familles V1 : Sabre, Longsword, Lance, Naginata, Axe, Masse, DoubleLames, Batons, Daggers.

Le joueur garde les mêmes cinq commandes, mais le profil d'arme change distance, trajectoire, tempo, engagement, pression sur l'Équilibre, nature de dégâts, locomotion et potentiel de démembrement.

Références de direction : films de samouraïs dont `13 Assassins`, wuxia (`Hero`, `Crouching Tiger, Hidden Dragon`), `Ghost of Tsushima`, `Sekiro`, `Nioh`, `For Honor`, `Ninja Gaiden`, `Devil May Cry`, `God of War`, plus principes HEMA pour certaines armes européennes.

## Magie

Les sorts passent par `SkillAttack` au niveau du vocabulaire de base. Le build et l'équipement déterminent la compétence montée dans le slot ou les variantes disponibles.

Écoles V1 :
- **Lumière** — projectiles, rayons, sceaux, barrières, explosions, mobilité lumineuse ;
- **Cendres** — contamination, nuages, marques, propagation, désagrégation ;
- **Perception** — télékinésie, interruption, mirages, distorsion mentale, contrôle ;
- **Porte** — failles, déplacement spatial, redirection, compression et rupture de l'espace.

Chaque sort possède un geste de lancement identifiable : le geste doit annoncer sa nature avant même l'effet visuel.

Références de direction : `Doctor Strange` pour la géométrie gestuelle et spatiale, `Dragon's Dogma` pour la préparation et l'échelle, `Final Fantasy XVI` pour l'intégration des capacités magiques au combat d'action, `Hogwarts Legacy` pour le langage visuel distinct et les réactions ennemies, `Control` pour la télékinésie directionnelle, `Elden Ring` pour les incantations à engagement élevé.

## Politique

Politique possède son propre langage d'animation afin de rester **un build offensif complet**, et non un build support.

Familles V1 :
- **Autorité** — posture verticale, gestes minimaux, pression physique et interruption ;
- **Condamnation** — désignation, marques, accumulation et mise en état `Condamné` ;
- **Commandements** — gestes vectoriels immédiats : pousser, attirer, faire tomber, interrompre ;
- **Lois** — gestes géométriques plus larges qui imposent une règle temporaire à l'arène ;
- **Sentences** — gestes très courts et définitifs convertissant Condamnation/Autorité en dégâts ;
- **Tyrannie** — version dangereuse, plus brutale et plus coercitive de la même grammaire.

Politique utilise les cinq entrées : `Light`, `Heavy`, `Parry`, `Dodge` et `SkillAttack`. Une arme reste visible dans la gestuelle : elle peut servir de pointe de désignation, de ligne de sentence ou d'équivalent de marteau de magistrat sans devenir une nouvelle commande.

Références de direction : `Dune` pour la présence et l'autorité vocale, `Control` pour les forces directionnelles, cinéma de samouraïs et de cour pour la retenue gestuelle, `Sekiro`/`Sifu` pour les réponses défensives nettes, imagerie judiciaire et rituelle pour les Lois et Sentences. Les gestes sont recomposés pour LITD 2 et ne reproduisent pas une chorégraphie existante.

Voir `POLITICS_ANIMATION_BIBLE.md` pour les règles détaillées.

## Colonnes CSV

- `id` : identifiant stable.
- `domain` : `unarmed`, `weapon`, `magic` ou `politics`.
- `family_or_school` : famille corporelle/arme ou école magique.
- `name` : nom technique interne.
- `input` : une des cinq commandes autorisées.
- `role_or_form` : fonction gameplay principale.
- `range` : distance d'emploi.
- `tempo` : vitesse de lecture/exécution.
- `commitment` : niveau d'engagement et difficulté d'annulation.
- `damage_nature` : nature d'impact.
- `equilibrium_pressure` : pression prévue sur l'Équilibre.
- `locomotion_or_gesture` : mouvement corporel ou geste de cast.
- `targeting` : cible unique, arc, cône, ligne, zone, etc.
- `body_bias` : zone privilégiée pour les frappes physiques.
- `finisher_candidate` : peut servir de base à un finisher.
- `inspiration_tags` : références de ton/rythme, jamais instruction de copie.
- `animation_note` : intention destinée à l'animateur.

## Utilisation Unreal

À terme, un importeur peut convertir les CSV en Data Tables / Data Assets. La bibliothèque ne décide jamais des fenêtres gameplay. Elle alimente la création des `ULITDCombatActionData` et des profils d'armes ; `Startup`, `Active`, `Recovery`, fenêtres de hit, cancel, parade parfaite et esquive parfaite restent configurés dans le runtime de combat.

## Méthode de sélection

1. Choisir arme/domaine.
2. Choisir l'entrée (`Light`, `Heavy`, `Parry`, `Dodge`, `SkillAttack`).
3. Choisir le rôle : ouverture, pression, rupture, contrôle, zone, mobilité ou finisher.
4. Filtrer par portée et engagement.
5. Sélectionner un motif de mouvement.
6. Adapter son timing au gameplay LITD 2.
7. Seulement ensuite produire ou retoucher l'animation.

Cette méthode évite de construire le gameplay autour d'une animation spectaculaire mais inutilisable.
