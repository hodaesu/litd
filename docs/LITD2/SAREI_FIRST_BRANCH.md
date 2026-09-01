# LITD 2 — Première branche de Rémanence : Les Derniers Médecins de Sarei

> Branche d'introduction des Archives de Rémanence. Canon LITD 2 uniquement.

## Objectifs de design

Cette branche enseigne sans tutoriel massif :

- la découverte d'Échos et de Fragments ;
- la connexion de connaissances ;
- la reconstruction ;
- la distinction PV / blessures / traumatismes ;
- la valeur des potions ;
- la lecture critique des sources ;
- le passage d'un sujet médical à une question politique.

## Opération d'entrée — Les Faubourgs de Sarei

Le joueur traverse un quartier partiellement détruit et découvre un ancien poste médical. Dans une salle demeurent une table, des instruments, des traces de sang et une caisse ouverte.

Une anomalie sonore se déclenche :

> « Il en reste combien ? »  
> « Deux. »

À proximité de la table, une Rémanence de quelques secondes montre deux silhouettes de médecins rationnant les dernières préparations.

### Écho : Le Dernier Flacon

**ID :** `SAREI_ECHO_LAST_FLASK`

Deux médecins semblent avoir rationné les préparations médicales pendant l'évacuation de Sarei.

Déblocages d'Archive :

- `SAREI_FIELD_POTIONS`
- `SAREI_HOSPITAL`
- `THIRD_ARMY`
- un lien encore inconnu.

Aucun bonus de gameplay n'est donné à ce stade.

## Fragment — Rapport du chirurgien Vel

**ID :** `SAREI_SOURCE_VEL_REPORT`

Le rapport indique que les préparations doivent rester isolées de l'air, de l'humidité et des variations de température. Il mentionne que les nouveaux coffrets militaires ont réduit les pertes.

Connexions révélées :

`POTIONS_DE_CAMPAGNE → CONDITIONNEMENT → COFFRETS_MILITAIRES`

## Fragment — Coffret de la IIIe Armée

**ID :** `SAREI_THIRD_ARMY_CASE`

Un ancien coffret incomplet peut être examiné. La Rémanence permet de comprendre l'organisation des compartiments hermétiques même si l'objet physique est endommagé.

Cette découverte rend disponible la première reconstruction de la branche.

## Reconstruction 01 — Conservation médicale de campagne

**ID :** `SAREI_RECON_FIELD_MEDICAL_STORAGE`

### Connaissances requises

Obligatoires :

- `SAREI_FIELD_POTIONS`
- `SAREI_MEDICAL_STORAGE`

Plus **une preuve technique parmi plusieurs sources équivalentes** :

- `SAREI_SOURCE_VEL_REPORT`
- `SAREI_THIRD_ARMY_CASE`
- une future source équivalente autorisée par le système.

### Résultat

**Capacité maximale de potions : 3 → 4.**

Texte UX :

> **CONNAISSANCE RECONSTRUITE — Conservation médicale de campagne**  
> Les coffrets à compartiments hermétiques de la IIIe Armée permettent désormais de conserver une préparation supplémentaire.

La récompense est justifiée par une connaissance logistique, jamais par une monnaie abstraite.

## Suite — Protocole Ashara

**ID :** `SAREI_ASHARA_PROTOCOL`

Le Protocole Ashara est d'abord présenté comme une méthode de triage médical permettant de distinguer rapidement les patients qui nécessitent un traitement immédiat, ceux qui peuvent attendre et ceux dont le pronostic est désespéré.

### Premier effet de gameplay

Le protocole améliore l'information affichée sur les traumatismes :

- zone atteinte ;
- part des PV condamnée ;
- gravité ;
- recommandation de traitement avant un affrontement majeur.

Il ne soigne aucun traumatisme et n'ajoute pas de puissance brute.

## Bascule politique

Une source ultérieure révèle que le protocole a été étendu à l'évacuation civile de Sarei : les autorités ont appliqué une logique de triage à la population entière.

La branche change alors de nature :

`MEDECINE → TECHNOLOGIE → GUERRE → POLITIQUE → PERSONNES`

### Contradiction majeure

Archive officielle :

> « Le protocole permit de sauver 11 000 citoyens. »

Témoignage :

> « Ils nous ont simplement abandonnés. »

Le nœud devient :

`PROTOCOLE ASHARA — CONTESTE`

Le jeu ne tranche pas immédiatement. Le joueur doit trouver d'autres sources et peut ne jamais obtenir une réponse parfaitement confortable.

## Cadence d'apprentissage cible

- **Run 1** : Écho du Dernier Flacon.
- **Run 2** : rapport médical ou source équivalente.
- **Run 3** : coffret militaire / preuve technique et première reconstruction, potions 3 → 4.
- **Runs suivantes** : Protocole Ashara, lecture des traumatismes, puis contradiction politique.

La distribution procédurale peut déplacer les sources secondaires, mais les occasions de découvrir les éléments fondamentaux doivent revenir régulièrement. Aucune progression structurante ne dépend d'un drop rarissime.

## Critères de validation

La branche est réussie si le joueur comprend naturellement que :

1. une Rémanence est une trace et non une vérité absolue ;
2. plusieurs traces peuvent être reliées ;
3. comprendre peut débloquer une possibilité de jeu ;
4. les Archives ne sont pas un arbre de statistiques ;
5. une question technique peut révéler une décision humaine ou politique beaucoup plus grave.
