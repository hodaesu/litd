# LITD Universe

`litd_universe/` contient le canon transversal et les ressources communes à toute la franchise.

## Règle d'architecture

- **LITD Universe** est la source commune de canon, références, principes et bibliothèques réutilisables.
- **LITD 1**, **LITD 2** et les futurs jeux restent des projets de gameplay distincts.
- Une mécanique spécifique à un jeu ne devient pas automatiquement une règle de l'Universe.
- Toute bibliothèque de référence créée pour un projet LITD doit être centralisée dans `litd_universe/libraries/` lorsqu'elle peut servir à plusieurs jeux.

## Identité obligatoire

Les Sept Piliers de LITD Universe sont définis dans [`SEVEN_PILLARS.md`](SEVEN_PILLARS.md) et dans leur contrat machine-readable [`seven_pillars.json`](seven_pillars.json).

Ils sont :

1. **Corps**
2. **Esprit**
3. **Politique**
4. **Peur**
5. **Espoir**
6. **Folie**
7. **Lumière**

Tout projet LITD doit faire vivre les sept, même si leur traduction mécanique, narrative ou visuelle change selon le jeu.

## Bibliothèques communes

Les bibliothèques centrales se trouvent dans [`libraries/`](libraries/). Les références externes servent d'inspiration et d'étude ; elles ne doivent pas être copiées. La réutilisation directe entre projets est réservée aux créations LITD originales ou aux ressources explicitement licenciées de manière compatible, conformément à `libraries/USAGE_POLICY.md`.
