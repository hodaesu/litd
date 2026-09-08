# Audit combat — Les Veilleurs

Base auditée : `main` à partir de `a41cd18829bfc9c79dd720de9e28f0b32641bb7c`.

## Objectif

Figer les règles de combat suffisamment pour passer du stade « système opérationnel » au stade « combat prêt au playtest tactile humain ».

## Périmètre

- boucle de tour et résolution d'actions ;
- compétences, états et blessures anatomiques ;
- IA ennemie ;
- victoire, défaite et retraite ;
- Rémanence et persistance inter-combats ;
- soumission non létale et recrutement ;
- phases de boss ;
- lisibilité et rythme mobile ;
- critères d'équilibrage avant playtest.

## État confirmé

La v0.9 a relié les combats tactiques aux six donjons de production, à la persistance des blessures, aux Némésis, à la soumission/recrutement, aux phases de boss et à la sauvegarde/reprise. Les tests Godot 4.3 et régressions associés ont été validés avant fusion.

## Décisions pré-playtest à figer

1. Aucune modification majeure de structure de combat avant le premier playtest humain : les changements doivent d'abord viser lisibilité, feedback, durée et tuning.
2. La soumission reste réservée aux ennemis vivants non-boss et doit rester lisible avant validation de l'action.
3. Les boss restent immunisés à la soumission et conservent leurs transitions de phases pilotées par les PV.
4. Les blessures anatomiques et la Rémanence restent des conséquences persistantes et ne doivent pas être réduites à de simples modificateurs temporaires.
5. Le recrutement reste post-victoire uniquement ; retraite et défaite n'ouvrent pas ce choix.
6. La sauvegarde/reprise doit préserver exactement l'état tactique et persistant du combat.

## Cibles d'équilibrage pour le premier playtest tactile

Ces valeurs servent de garde-fous, pas de vérité finale :

- combat standard : viser 4 à 7 rounds ;
- élite/Némésis : viser 6 à 10 rounds ;
- boss : viser 10 à 16 rounds selon le nombre de phases ;
- une action importante doit produire un feedback visuel/sonore immédiatement compréhensible ;
- éviter qu'un héros perde sa capacité d'agir plusieurs tours d'affilée sans contre-jeu ;
- éviter qu'une seule compétence domine systématiquement une rotation ;
- les compétences de soin/contrôle ne doivent pas annuler durablement la pression de l'attrition ;
- chaque arbre doit conserver une identité tactique distincte ;
- la difficulté doit venir des décisions, blessures, synergies et priorités de cible, pas de PV artificiellement gonflés.

## Critères GO / NO-GO pour le playtest PC/mobile

### GO

- combat complet jusqu'à victoire/défaite/retraite sans erreur ;
- chaque action disponible est sélectionnable et résolue ;
- états/blessures visibles et compréhensibles ;
- IA termine ses tours sans blocage ;
- boss changent de phase correctement ;
- Rémanence et blessures survivent au retour au donjon et à la sauvegarde/reprise ;
- recrutement n'apparaît que lorsque les conditions sont valides.

### NO-GO

- soft-lock de tour ;
- action sans cible valide mais néanmoins exécutable ;
- état persistant perdu après transition/sauvegarde ;
- boss soumis/recrutable ;
- divergence entre PV affichés et état interne ;
- interaction tactile nécessitant une précision incompatible avec un écran de téléphone ;
- information critique uniquement disponible par texte trop petit ou ambigu.

## Ordre du prochain playtest humain

1. combat standard simple ;
2. combat avec contrôle/saignement/blessure ;
3. combat élite/Némésis ;
4. soumission puis recrutement ;
5. retraite ;
6. défaite ;
7. boss trois phases ;
8. sauvegarde au milieu d'un combat puis reprise ;
9. enchaînement de plusieurs combats pour vérifier l'attrition et la Rémanence ;
10. répétition sur interface tactile.

Ce document doit être complété par les mesures réelles du playtest : durée, rounds, taux de victoire, actions par minute, compétences dominantes, dégâts subis, contrôles subis, blessures, retraites et erreurs de compréhension.