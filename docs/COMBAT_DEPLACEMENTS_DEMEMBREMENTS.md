# Combat v5 — déplacements forcés, démembrements et phases de boss

Le combat v5 de **Light in the Dark** superpose quatre couches :

1. moteur de rounds à quatre héros ;
2. rangs et synergies de formation ;
3. démembrements fonctionnels ;
4. déplacements forcés et phases de boss liées à certains membres.

## Déplacements forcés par les héros

Les coups lourds ne servent plus uniquement à augmenter les dégâts.

- **Malvor** : son coup lourd repousse la cible d'un rang.
- **Darius** : son coup lourd repousse la cible d'un rang.
- **Aurélien** : son coup lourd attire la cible d'un rang vers l'avant.
- **Lysandra** : son coup lourd repousse la cible d'un rang.

Le déplacement échange les positions lorsqu'un autre ennemi occupe le rang de destination. Cela réorganise donc réellement l'ordre adverse sans créer de cases vides artificielles.

## Peur et désorganisation

Un héros qui atteint **100 de Peur** peut reculer d'un rang une fois par round. La Peur devient ainsi un danger tactique : elle peut rompre Mur de la Veille, Concorde du Voile ou Faille préparée sans infliger directement des dégâts supplémentaires.

## Démembrement et stabilité

Certains membres perdus changent immédiatement la position de la cible :

- jambe d'appui humanoïde : recul d'un rang ;
- membre postérieur de bête : recul d'un rang ;
- patte arrière d'arachnide : recul d'un rang ;
- appendice d'ancrage d'aberration : recul d'un rang ;
- membre de soutien de boss : recul d'un rang ;
- ancrage corporel de boss : la cible est ramenée vers la première ligne lorsque la formation adverse le permet.

Le démembrement reste donc une mécanique de contrôle et non un simple effet de gore.

## Boss à phase positionnelle

### Général de Silex — Ordre de recul
Tant que son **membre offensif** existe, il peut périodiquement repousser le héros de première ligne et casser la formation.

Si ce membre est détruit, cette manœuvre disparaît. Le boss doit toujours être vaincu normalement ; seule sa capacité à imposer cette organisation est neutralisée.

### La Frontière qui marche — Translation de frontière
Tant que son **ancrage corporel** existe, elle peut échanger les héros des rangs 1 et 4.

La destruction de cet ancrage supprime cette translation brutale de l'avant vers l'arrière.

### Le Consensus Brisé — Permutation des perspectives
Tant que son **ancrage corporel** existe, il peut faire tourner toute la formation d'un rang.

Détruire l'ancrage retire cette capacité à imposer une nouvelle perspective par la position.

### La Rupture Commune — Onde de rupture commune
Tant que son **membre de soutien** existe, elle peut inverser les deux paires R1/R2 et R3/R4 lors de sa manœuvre.

Le perdre permet au joueur de reconstruire plus durablement ses synergies, mais ne supprime ni les phases centrales ni les conditions de résolution du boss final.

## Règle de design

Un membre détruit doit toujours répondre à la question : **« Qu'est-ce que cette partie du corps permettait réellement à l'adversaire de faire ? »**

La réponse doit être visible dans le gameplay : mobilité, portée, pression de Peur, attaque, ancrage au Voile, maintien d'une phase ou contrôle de la formation.

Un démembrement ne doit jamais être un simple bonus de dégâts arbitraire, et un boss ne doit jamais pouvoir être éliminé instantanément par cette mécanique.

## QA

```bash
python -m tools.qa.dismemberment_audit
python -m tools.qa.displacement_combat_audit
```

Le second audit contrôle les poussées/tractions, le recul sous Peur, les déplacements provoqués par les membres perdus et les quatre manœuvres de boss liées à leur anatomie.
