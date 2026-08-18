# Combat tactique — rangs, déplacements et synergies

Le combat v3 de **Light in the Dark** conserve le moteur de rounds à quatre héros du combat v2 et ajoute une couche de positionnement tactique.

## Formation

- **Rang 1** : avant de la formation.
- **Rang 4** : arrière de la formation.
- Formation initiale : **Malvor R1 · Darius R2 · Aurélien R3 · Lysandra R4**.
- Un héros peut **AVANCER** ou **RECULER** d'un rang.
- Le déplacement échange sa place avec l'occupant adjacent et **consomme l'action du héros**.

## Portées de base

### Malvor
Briseur de première ligne.
- Frappe : depuis R1–R2 vers R1–R2 ennemis.
- Coup lourd : depuis R1 vers R1 ennemi.
- Technique **Brise-garde** : depuis R1–R2 vers R1–R2 ; dégâts réduits, rupture garantie.

### Darius
Veilleur de ligne.
- Frappe : depuis R1–R3 vers R1–R2 ennemis.
- Coup lourd : depuis R1–R2 vers R1 ennemi.
- Technique **Posture de Veille** : depuis R1–R3 ; garde renforcée et +20 % riposte jusqu'au prochain tour ennemi.

### Aurélien
Occultiste de seconde ligne.
- Frappe : depuis R2–R4 vers R2–R4 ennemis.
- Coup lourd : depuis R3–R4 vers R3–R4 ennemis.
- Technique **Marque du Voile** : depuis R3–R4 vers R2–R4 ; marque la cible et renforce les deux prochaines attaques alliées.

### Lysandra
Vestale d'arrière-garde.
- Frappe : depuis R3–R4 vers R2–R4 ennemis.
- Coup lourd : depuis R4 vers R3–R4 ennemis.
- Technique **Lueur de Concorde** : depuis R3–R4 ; soigne l'allié le plus blessé et réduit la Peur de toute la compagnie.

## Ciblage ennemi

Les ennemis ordinaires ont également une portée positionnelle :
- ennemis R1–R2 : ciblent prioritairement les héros R1–R2 ;
- ennemis R3–R4 : ciblent les héros R2–R4 ;
- les boss peuvent menacer toute la formation afin de ne pas rendre l'arrière-garde invulnérable.

Les rangs ennemis se resserrent lorsqu'un ennemi tombe.

## Synergies de formation

### Mur de la Veille
Si Malvor et Darius occupent les rangs 1 et 2, tous deux gagnent **+5 % de résistance physique**.

### Concorde du Voile
Si Aurélien et Lysandra sont adjacents, tous deux gagnent **+5 résistance à la Peur** et les soins de Lysandra gagnent **+15 %**.

### Faille préparée
Si Malvor se trouve directement devant Aurélien, Aurélien gagne **+15 % de dégâts** contre les cibles brisées ou étourdies.

## Philosophie

Le positionnement ne doit pas devenir une simple copie de Darkest Dungeon. Dans Light in the Dark, les rangs servent surtout à représenter la manière dont les personnages **se protègent, ouvrent une faille pour un allié, contrôlent leur exposition au Voile et transforment la formation en relation tactique**.

Les déplacements doivent donc créer un choix réel : utiliser une attaque immédiatement, ou sacrifier une action maintenant pour préparer une meilleure formation au round suivant.

## QA

`python -m tools.qa.tactical_combat_audit`

Le contrôle vérifie la formation initiale, les portées, les techniques positionnelles, le coût d'action des déplacements, le ciblage ennemi, le traitement des boss et les trois synergies de formation.
