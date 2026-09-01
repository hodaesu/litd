# LITD Universe

`litd_universe/` contient le canon transversal et les ressources communes à toute la franchise.

## Règle d'architecture

- **LITD Universe** est la source commune de canon, références, principes et bibliothèques réutilisables.
- **LITD 1**, **LITD 2** et les futurs jeux restent des projets de gameplay distincts.
- Une mécanique spécifique à un jeu ne devient pas automatiquement une règle de l'Universe.
- Toute bibliothèque de référence créée pour un projet LITD doit être centralisée dans `litd_universe/libraries/` lorsqu'elle peut servir à plusieurs jeux.

## Les Sept Piliers immuables

Les Sept Piliers de LITD Universe sont définis dans [`SEVEN_PILLARS.md`](SEVEN_PILLARS.md) et verrouillés par le contrat [`seven_pillars.json`](seven_pillars.json).

Ils sont exactement, dans cet ordre :

1. **Création de personnages**
2. **Gore systémique et conséquences corporelles**
3. **Philosophie et psychologie dans la narration**
4. **Profondeur humaine accessible**
5. **Narration forte**
6. **Interconnexion des différents jeux**
7. **Rémanence de la connaissance**

Cette liste est **immuable** : aucun projet LITD ne peut renommer, réordonner, fusionner, supprimer ou ajouter un pilier. La manière de les exprimer peut varier selon le jeu.

La **cohérence narrative** reste une règle transversale obligatoire ; elle n'est pas un pilier supplémentaire.

Le septième pilier conserve le chemin canonique :

**Trace → Écho → Mémoire → Concordance**

## Bibliothèques communes

Les bibliothèques centrales se trouvent dans [`libraries/`](libraries/). Les références externes servent d'inspiration et d'étude ; elles ne doivent pas être copiées. La réutilisation directe entre projets est réservée aux créations LITD originales ou aux ressources explicitement licenciées de manière compatible, conformément à `libraries/USAGE_POLICY.md`.
