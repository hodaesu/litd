# LITD 2 — Première run complète : Les Faubourgs de Sarei

> Statut : **CANON DE PRODUCTION / VERTICAL SLICE**  
> Portée : **LITD 2 uniquement**. Cette opération ne doit pas importer de mécaniques de LITD 1.

## 1. Rôle de l'opération

**Les Faubourgs de Sarei** est la première opération complète servant de vertical slice jouable de LITD 2.

Elle doit prouver dans une même boucle :

- préparation pré-run et Serment ;
- combat action-RPG rapide et lisible ;
- viabilité des voies Corps / Esprit / Politique ;
- pipeline dégâts → blessure → traumatisme → gore/démembrement ;
- 3 potions au départ ;
- soins ordinaires qui restaurent les PV sans effacer les traumatismes ;
- exploration et Rémanence ;
- mini-boss ;
- boss ;
- conclusion historique ;
- retour aux Archives.

Durée cible de production : **30 à 40 minutes** pour une première réussite, avec une route critique plus courte pour un joueur expérimenté.

## 2. Règles de départ

- Potions au départ : **3**.
- Aucun soin ordinaire ne supprime un traumatisme.
- Les potions suppriment tous les traumatismes actifs et restaurent une part importante des PV.
- Aucun drop aléatoire de potion sur les ennemis.
- Les rares potions supplémentaires viennent uniquement de lieux médicaux/logistiques cohérents.
- Le choix du Serment est effectué avant l'entrée dans l'opération et reste indépendant de Corps / Esprit / Politique.
- La run doit être terminable avec une construction centrée exclusivement sur Corps, Esprit ou Politique.

## 3. Courbe dramatique

1. **Entrer** — apprendre la lecture du combat.
2. **Encaisser** — découvrir qu'une erreur grave peut laisser un traumatisme.
3. **Comprendre** — découvrir Le Dernier Flacon et la Rémanence.
4. **Choisir** — première bifurcation de route et de ressources.
5. **Être testé** — mini-boss et montée de pression.
6. **S'user** — affrontement de grande intensité avant le boss.
7. **Décider** — entrer blessé ou consommer une potion avant le boss.
8. **Survivre** — boss de fin et découverte historique.
9. **Relier** — retour aux Archives.

Le principe de tension reste : **le build devient de plus en plus puissant pendant que le corps peut devenir de plus en plus fragile.**

---

# 4. Structure zone par zone

## Z0 — Préparation : Le seuil de l'opération

### Fonction

Préparation hors combat avant l'entrée physique dans les faubourgs.

### Le joueur

- choisit un Serment ;
- voit clairement les 3 potions disponibles ;
- confirme son équipement de départ ;
- reçoit le contexte minimal : les faubourgs de Sarei sont en cours d'effondrement et une voie d'accès doit être ouverte.

### Interdiction UX

Pas de long exposé. Le contexte historique détaillé sera découvert par le terrain et les Rémanences.

---

## Z1 — Porte Sud : L'approche

### Objectif de gameplay

Valider les fondamentaux : déplacement, caméra, attaque légère/lourde, esquive, parade et lecture des télégraphes.

### Rencontre

- 3 **Errants cendrés** espacés ;
- puis 1 paire coordonnée.

### Règles

- faible pression ;
- aucune attaque ne doit provoquer directement un traumatisme en un seul coup à pleine santé ;
- gore léger autorisé afin d'introduire immédiatement la matérialité des impacts.

### Récompense

Premier choix de puissance de run : une proposition Corps / Esprit / Politique de valeur équivalente.

---

## Z2 — Rue des Brancardiers : La première vraie erreur

### Objectif de gameplay

Introduire la différence entre dégâts ordinaires et attaque traumatique lisible.

### Rencontre

- 3 Errants cendrés ;
- 1 **Arbalétrier de Sarei** en hauteur ;
- 1 **Briseur de ligne**.

Le Briseur de ligne possède une attaque lourde très télégraphiée capable de générer un traumatisme si elle est reçue sans défense correcte.

### Après le combat

Une **fontaine de secours** restaure les PV récupérables mais ne soigne aucun traumatisme.

Si le joueur a subi son premier traumatisme, l'interface doit rendre immédiatement visible qu'une partie de ses PV max reste condamnée malgré la fontaine.

### Apprentissage attendu

> « Je peux récupérer mes PV sans être réellement remis sur pied. »

---

## Z3 — Poste médical périphérique : Le Dernier Flacon

### Objectif de gameplay

Introduire la Rémanence dans un moment calme après la pression de Z2.

### Mise en scène

Salle partiellement détruite : table, instruments, sang ancien, caisse ouverte, rideaux ou cloisons médicales déchirées.

Une anomalie sonore précède l'Écho :

> « Il en reste combien ? »  
> « Deux. »

### Rémanence obligatoire

**Écho — Le Dernier Flacon**  
ID : `SAREI_ECHO_LAST_FLASK`

L'Écho révèle l'existence des potions de campagne, de l'Hôpital de Sarei, de la IIIe Armée et d'un lien encore inconnu.

### Ressources

- 1 fontaine/point de soin PV seulement ;
- 1 cache médicale optionnelle, bien dissimulée mais non aléatoire, pouvant contenir **1 potion de remplacement** si le joueur en a déjà consommé au moins une ;
- jamais de potion gratuite automatique si le joueur est encore à sa capacité maximale.

### Récompense

Aucun bonus permanent. La récompense est la **connaissance**.

---

## Z4 — Carrefour des Cendres : La première bifurcation

Le joueur choisit une route courte. Les deux chemins se rejoignent ensuite.

### Route A — Cour des Convois

Orientation : combat rapproché / contrôle de foule.

Rencontre :

- 2 Errants cendrés ;
- 2 Briseurs de ligne ;
- éléments de décor destructibles permettant de séparer ou interrompre des ennemis.

Récompense : davantage de ressources de run et une amélioration orientée survie/contrôle.

### Route B — Rue des Verriers

Orientation : mobilité / distance / risque environnemental.

Rencontre :

- 2 Arbalétriers de Sarei ;
- 3 Errants cendrés ;
- zones de verre, structures instables et lignes de tir croisées.

Récompense : amélioration offensive ou mobilité supérieure.

### Règle d'équilibrage

Aucune route ne doit être « la bonne ». Elles proposent des difficultés différentes mais une valeur moyenne équivalente.

### Rémanence optionnelle

Une petite trace environnementale peut évoquer l'évacuation civile sans expliquer encore le Protocole Ashara.

---

## Z5 — Annexe de l'Hôpital : Le Chirurgien de garde

### Mini-boss

**Le Chirurgien de garde**

Ancien praticien de guerre devenu hostile dans le chaos de l'opération. Son design ne doit pas être celui d'un « docteur fou » caricatural : son langage de combat vient d'une connaissance précise du corps et d'outils médicaux détournés.

### Mécaniques

- attaques rapides ciblant bras/torse ;
- saignement temporaire ;
- une attaque de saisie clairement télégraphiée ;
- une attaque sévère pouvant provoquer un traumatisme si elle n'est pas interrompue/esquivée ;
- faible résistance aux interruptions, mais haute précision.

### Ce que le combat teste

- Corps : interruption, pression, parade, rupture ;
- Esprit : contrôle de fenêtre, portée, punition ;
- Politique : condamnation/autorité/loi offensive permettant de contrôler le rythme du duel.

### Récompenses

- choix de puissance significatif avant la dernière partie de la run ;
- accès à un soin PV ;
- source documentaire secondaire non indispensable à la progression de la première run.

---

## Z6 — Cour d'évacuation : Tenir malgré l'usure

### Objectif de gameplay

Premier grand combat multi-vagues du vertical slice.

### Composition

Vague 1 :
- Errants cendrés ;
- Arbalétrier.

Vague 2 :
- 2 Briseurs de ligne ;
- ennemis rapides.

Vague 3 :
- mélange de mêlée, distance et élite légère.

### Arène

- brancards renversés ;
- barricades ;
- chariots ;
- couvertures partielles ;
- éléments destructibles ;
- plusieurs axes d'approche pour éviter un simple couloir.

### Choix médical

Après le combat, le joueur voit le boss à venir depuis la sortie de la cour.

Il doit décider :

- dépenser une potion pour effacer ses traumatismes ;
- ou préserver la potion et entrer diminué.

Une dernière fontaine restaure seulement les PV non condamnés afin de rendre ce choix explicite.

### Ressource rare

Une réserve médicale verrouillée peut fournir une potion de remplacement uniquement si le joueur a exploré un détour dangereux. Elle est contextuelle et fixe, jamais un drop ennemi.

---

## Z7 — Barricade de Sarei : Capitaine Rhéon, le Dernier Verrou

> Nom de production canonique du premier boss tant qu'une révision narrative explicite ne le remplace pas.

### Identité

Rhéon était chargé de maintenir la voie militaire de la Porte Sud pendant l'évacuation. Le combat doit laisser planer un doute : gardait-il Sarei contre l'ennemi, ou empêchait-il aussi certains civils d'entrer ?

### Silhouette

- armure de campagne endommagée ;
- arme d'hast courte / lame de commandement ;
- équipement marqué par les opérations d'évacuation ;
- pas de gigantisme gratuit : sa menace vient de sa technique, de son autorité et de la violence de ses impacts.

### Phase 1 — Le verrou

- garde disciplinée ;
- coups horizontaux lisibles ;
- poussées ;
- ordre bref qui déclenche une pression d'arène ;
- punit le spam sans lecture.

### Phase 2 — La ligne cède

À environ 60 % PV : destruction d'une partie de son équipement défensif.

- rythme plus agressif ;
- charges ;
- attaques de rupture ;
- une attaque majeure capable de générer un traumatisme important si elle touche sans mitigation.

### Phase 3 — Personne ne passe

À environ 25 % PV :

- séquences plus courtes mais plus dangereuses ;
- moins de défense ;
- fenêtres de punition nettes ;
- aucune inflation artificielle de PV.

### Viabilité des trois voies

Le boss doit être battable :

- par Corps grâce à la maîtrise de proximité, rupture et contre ;
- par Esprit grâce au contrôle de distance, fenêtres et manipulation des états ;
- par Politique grâce à Condamnation, Autorité, Commandements/Lois offensives et gestion du tempo.

Aucune voie ne doit dépendre d'une autre pour infliger des dégâts de boss viables.

### Gore / démembrement

Le boss utilise le même pipeline anatomique que les autres ennemis. Les effets de démembrement doivent rester compatibles avec ses phases et ne jamais casser son IA ou ses attaques obligatoires.

---

## Z8 — Après la barricade : Ce que Rhéon gardait

### Rémanence de conclusion

La mort/défaite de Rhéon libère une trace courte :

- ordre d'évacuation fragmentaire ;
- voix militaire exigeant la fermeture d'une voie ;
- silhouettes de civils encore de l'autre côté ;
- aucune explication complète.

Cette trace crée une future connexion avec :

- évacuation de Sarei ;
- autorités de guerre ;
- Hôpital de Sarei ;
- futur Protocole Ashara.

Elle **n'établit pas encore la vérité** et ne doit pas révéler prématurément la contradiction politique complète.

### Fin de run

Le joueur franchit la barricade ouverte. L'opération se termine sur un retour aux Archives plutôt que sur un coffre de récompense spectaculaire.

---

# 5. Bestiaire minimal du vertical slice

## Errant cendré

Rôle : ennemi de base.  
Teste : rythme, positionnement, esquive/parade, gore de base.

## Arbalétrier de Sarei

Rôle : pression à distance.  
Teste : mobilité, priorisation de cible, usage du décor.

## Briseur de ligne

Rôle : lourd.  
Teste : télégraphes, trauma, rupture de garde.

## Harceleur des ruelles

Rôle : rapide/flanqueur.  
Teste : orientation, gestion de plusieurs menaces, interruption.

## Chirurgien de garde

Rôle : mini-boss anatomique.  
Teste : saignement, saisie, précision, trauma ciblé.

## Capitaine Rhéon

Rôle : boss de synthèse.  
Teste : maîtrise complète du système et viabilité des trois voies.

---

# 6. Distribution des pouvoirs de run

Le vertical slice doit offrir au minimum trois moments de construction :

1. après Z1 ;
2. après la bifurcation Z4 ;
3. après le mini-boss Z5.

À chacun de ces moments, Corps, Esprit et Politique doivent proposer une option de valeur comparable.

Le joueur peut rester sur une voie unique ou mélanger, mais **aucun mélange n'est requis** pour vaincre Rhéon.

---

# 7. Soins et traumatismes dans la run

Points de soin PV : Z2, Z3, Z5, Z6.

Potions garanties : 3 au départ.

Potions de remplacement :

- cache médicale Z3 si une potion a déjà été consommée ;
- réserve risquée Z6.

Règle : aucune potion ne tombe d'un ennemi.

Le joueur doit pouvoir atteindre le boss avec 0 à plusieurs traumatismes selon sa performance. La run ne doit pas forcer artificiellement un traumatisme : il résulte d'erreurs lisibles.

---

# 8. Rémanences de la première run

### Obligatoire

- `SAREI_ECHO_LAST_FLASK`

### Optionnelles

- trace environnementale d'évacuation au Carrefour ;
- note médicale secondaire dans l'annexe ;
- trace de Rhéon après le boss.

Le **Rapport du chirurgien Vel** et le **Coffret de la IIIe Armée** restent destinés aux runs ultérieures de la branche de Sarei conformément à `SAREI_FIRST_BRANCH.md`. Le vertical slice QA pourra les forcer via un mode de validation, mais le parcours joueur de la première run ne doit pas accélérer artificiellement la métaprogression.

---

# 9. Récompenses de fin

La fin de l'opération donne :

- progression historique : opération terminée ;
- nouvelles entrées/connexions dans les Archives ;
- trace de Rhéon ;
- conservation des connaissances découvertes ;
- aucune monnaie de Rémanence ;
- aucun +X % global obligatoire.

Le sentiment de récompense doit venir de l'ouverture du réseau de connaissances et de la compréhension de Sarei.

---

# 10. Critères de validation du vertical slice

Le vertical slice est réussi si :

1. la boucle préparation → combat → exploration → boss → Archives fonctionne sans rupture ;
2. les trois voies peuvent vaincre Rhéon seules ;
3. un traumatisme est toujours lié à une cause sévère lisible ;
4. une fontaine ne supprime jamais un traumatisme ;
5. une potion supprime correctement les traumatismes ;
6. aucune potion n'est un drop ennemi ;
7. Le Dernier Flacon est découvert sans mode détective permanent ;
8. la première run ne donne pas prématurément la reconstruction 3 → 4 potions ;
9. le boss utilise le même pipeline dégâts/anatomie/gore que le reste du jeu ;
10. le retour aux Archives rend immédiatement visibles les nouvelles connaissances acquises.

## Ligne directrice

**Les Faubourgs de Sarei doivent apprendre au joueur que survivre à une bataille n'est pas seulement conserver des PV : c'est traverser l'histoire en portant ce que le corps et le monde ont subi.**
