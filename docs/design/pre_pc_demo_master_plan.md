# Light in the Dark — PASS 29 — Préparation complète avant PC

Ce document verrouille tout ce qui peut être décidé utilement avant d'ouvrir Blender ou de valider visuellement Godot. Il complète le pipeline automatisé du PASS 28 et ne remplace pas l'Art Bible : en cas de conflit graphique, l'Art Bible approuvée reste autoritaire.

## 1. Combat Darius contre Goule affamée

Le combat reste au tour par tour. Une action choisie verrouille brièvement l'entrée pendant sa présentation, applique son résultat uniquement au marqueur d'impact, puis rend la main à la fin de la récupération. Les durées ne modifient pas l'initiative. Les timings exacts, les dégâts, la garde, les télégraphes, les réactions, la séquence de démonstration et les conditions de victoire/défaite sont définis dans `data/visual_slice_choreography.json`.

Le mode de capture vidéo est déterministe afin que deux captures puissent être comparées. Le mode normal autorise une IA pondérée de la Goule, sans répétition abusive d'une même attaque.

## 2. Fiches d'animation définitives

`data/visual_slice_animation_specs.json` fixe pour Darius et la Goule : durée, anticipation, impact, récupération, déplacement racine, contacts, transitions et intention de silhouette. Le mouvement secondaire ne doit jamais masquer une lecture tactique. Les animations finales restent à fabriquer et à juger sur PC, mais leur contrat de production n'est plus à inventer.

## 3. VFX

`data/visual_slice_presentation.json` définit les effets obligatoires et leurs limites : cendre, traînée, impact, étincelles, sang discret, lanterne, garde, critique et Peur. Les effets sont volontairement sobres, lisibles et compatibles mobile. Aucun filtre psychologique permanent ne doit dégrader la lecture tactique.

## 4. Sound design

Le même contrat décrit le moment exact des sons, leur priorité dans le mix, le nombre minimum de variantes et les cooldowns anti-répétition. Les télégraphes restent prioritaires sur les voix de créatures et la musique. Les fichiers audio finaux restent à produire ou sélectionner, mais la logique d'usage est verrouillée.

## 5. Caméra

La caméra de base conserve 42° de champ de vision. Les profils léger, lourd, garde, griffe, bond, critique et mort utilisent de petits mouvements contrôlés et reviennent toujours au cadre tactique avant le prochain choix. Le tremblement est réglable et désactivable. Les ultimes et changements de phase pourront sortir temporairement du cadre standard uniquement si la lisibilité est restaurée avant de rendre le contrôle.

## 6. Ordre de production après validation du vertical slice

Le passage au reste du jeu est défini dans `data/demo_roadmap.json` : Aurélien, Malvor, Lysandra, Oni, Jorōgumo, Ange inversé, set d'environnements des Terres de Cendre, armes/reliques puis Sanctuaire. Aucun modèle final supplémentaire ne doit être engagé avant que Darius, la Goule, l'arène, le shader, la caméra et la performance aient validé la grammaire 3D.

## 7. Contenu de la première démo

`data/demo_content_pack.json` contient une démo originale intitulée **Les Cendres se souviennent** : boucle Sanctuaire → expédition → choix de terrain → Goule/capture optionnelle → Témoin des Cendres → retour et conséquence. Elle s'appuie sur les systèmes et rencontres déjà présents au lieu de créer un canon parallèle.

Le pack ajoute un parcours de 45 à 65 minutes, quatre quêtes ou pistes, six événements, huit textes anciens originaux, douze répliques contextuelles, les interactions de Sanctuaire nécessaires, une opportunité de capture de Goule et le boss du chapitre 1. Les informations essentielles ne dépendent d'aucun héros mortel.

## 8. Équilibrage

`data/demo_balance_targets.json` fixe des objectifs plutôt que de réécrire arbitrairement toutes les valeurs existantes. Les combats standards visent 3 à 6 tours, les élites 5 à 8, les boss 8 à 14. Les attaques majeures doivent être télégraphiées. La mort permanente est autorisée, mais elle ne doit pas provenir d'une attaque routinière opaque.

Le contrat conserve les invariants déjà décidés : Peur 0–100 comme seule jauge psychologique visible, Folie et Espoir événementiels, trois arbres de quinze compétences, choix d'arbre exclusif, ultimes aux niveaux 16/32/48, équipement seedé et identités de rareté existantes.

## 9. Interface finale

`data/final_ui_contract.json` prépare les écrans combat, inventaire, équipement, arbres de compétences, journal, Sanctuaire, recrutement, capture et réglages. La direction visuelle reprend parchemin, encre sombre, filets d'or terni, rouge braise rare et ornements sobres. Le HUD reste contextuel et caché en exploration. Aucune jauge de morale, réputation, relation, Espoir ou Folie n'est ajoutée.

La cible principale reste l'iPhone paysage : zones tactiles d'au moins 48 px, safe areas, texte redimensionnable, réduction des mouvements et shake désactivable.

## 10. Feuille de route jusqu'à une vraie démo

`data/demo_roadmap.json` découpe le travail en six étapes : préparation sans PC, validation du vertical slice sur PC, casting de démo, monde de démo, polish puis test externe. Une démo présentable doit pouvoir être terminée par quelqu'un qui ne connaît pas le projet, sans outil de développement, sans crash ni blocage de progression et avec une direction graphique immédiatement reconnaissable.

## Ce qui reste réellement impossible à valider sans PC

Trois catégories restent volontairement ouvertes :

1. la fidélité réelle du cel shading et des matériaux en mouvement ;
2. la qualité des modèles, déformations, animations et cadrages vus dans le moteur ;
3. la performance réelle sur le matériel cible, en particulier l'iPhone.

Le pipeline peut mesurer et préparer ces points, mais il ne peut pas remplacer une validation visuelle sur une machine réelle.

## État attendu après PASS 29

Une fois ce pass fusionné, il ne doit plus rester de décision de préproduction majeure à prendre avant la première session PC. La session PC pourra être consacrée à exécuter le pipeline, regarder les résultats, corriger les écarts visuels et accepter ou refuser les assets au lieu de rédiger encore des spécifications.
