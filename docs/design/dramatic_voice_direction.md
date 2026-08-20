# Direction d'acteur vocale — PASS 31

La direction émotionnelle du PASS 30 reste la base prosodique. Le PASS 31 ajoute une couche dramatique inspirée de principes transférables du théâtre et du jeu caméra : circonstances, objectif, obstacle, action jouable, sous-texte, écoute du partenaire, changement de statut, silence actif et découpage en beats.

## Principe central

Une réplique ne doit plus être dirigée comme « joue la peur 4/5 ». La consigne devient d'abord : **qu'est-ce que le personnage veut obtenir, de qui, qu'est-ce qui l'en empêche, et quelle action joue-t-il pour y arriver ?** L'émotion reste décrite parce qu'elle aide la cohérence vocale, mais elle doit apparaître comme conséquence de l'action, de l'écoute et de la situation.

Chaque ligne reçoit désormais : objectif, obstacle, action, sous-texte, destinataire, rapport de pouvoir au début et à la fin, pensée juste avant la phrase, déclencheur reçu, silence, respiration, beats, contradiction interne et état après la phrase.

## Écoute et réaction

Le système impose une pensée ou un stimulus reçu avant la réponse. Une prise où l'acteur semble réciter une intention préfabriquée doit être moins bien notée qu'une prise où la phrase paraît répondre à ce qui vient réellement de se produire. Le silence n'est jamais ajouté pour « faire dramatique » : il doit contenir une décision, une résistance, une prise de conscience ou une réévaluation.

## Jeu caméra / micro

Une émotion forte ne signifie pas automatiquement une voix forte. Pour LITD, la retenue est la valeur par défaut : une menace peut être calme, un deuil peut être presque sans musique vocale, et une peur intense peut chercher au contraire une diction plus précise pour conserver le contrôle. Les micro-variations, le souffle, la suspension et la récupération après une fissure sont privilégiés aux effets continus.

## Quatrième mur

Les lignes `direct` et `abyssal` sont découpées de façon à ce que la conscience de la présence extérieure puisse apparaître **au milieu de la phrase**. Le premier beat reste dans la logique habituelle du héros, un beat central porte le déplacement de pensée (`awareness_shift`), puis la fin de phrase s'adresse réellement à ce qui vient d'être compris. Cela évite une voix « inquiétante » uniforme dès le premier mot.

## Variantes contrôlées

Toute ligne importante reçoit au moins deux interprétations :

- `contained_truth` : l'objectif domine, l'émotion reste très tenue ;
- `exposed_fissure` : une seule fissure émotionnelle est autorisée sur un beat précis ;
- certaines lignes abyssales ou extrêmes ajoutent `silence_forward`, où la pensée et les silences portent davantage que l'effet vocal.

Le plan `tools/voice/build_voice_performance_plan.py` combine ces directions avec le plan OpenVoice existant. Il fournit des vitesses MeloTTS candidates pour les variantes, mais ne prétend pas contrôler automatiquement sous-texte, écoute, respiration ou statut. Ces éléments restent des critères de direction et d'écoute humaine.

## Étudier théâtre et cinéma sans copier

`data/voice_acting_study_protocol.json` définit la méthode de travail : on peut observer un cours, un exercice ou une scène et relever objectif, écoute, beats, rapport de pouvoir, respiration, retenue et contradiction. Le dépôt ne stocke ni clip, ni transcription, ni longue citation. Seules les observations abstraites sont transférées vers des directions originales de LITD. Aucune imitation d'un acteur réel n'est une cible de production.

## Revue des prises

`tools/voice/acting_take_review.py` génère une fiche par ligne et par variante. La prise est notée sur : clarté de l'objectif, écoute active, vérité du sous-texte, vérité des transitions de beats, continuité du statut, retenue, identité du personnage, naturel et intelligibilité.

Pour une ligne importante, chaque critère doit atteindre 4/5. Le choix final doit privilégier **la prise la plus vraie pour l'action et la relation**, pas celle qui rend l'émotion la plus spectaculaire.

## Limite honnête

Ce système n'est pas un réentraînement neuronal de ChatGPT, d'OpenVoice ou de MeloTTS. C'est une calibration de production : règles, métadonnées, variantes, protocole d'étude et grille d'écoute. Sa valeur augmentera quand les premières prises autorisées seront écoutées sur PC et que les mêmes erreurs pourront être mesurées puis corrigées dans le contrat.
