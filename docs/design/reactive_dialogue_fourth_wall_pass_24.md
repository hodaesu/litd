# Pass 24 — Dialogue réactif, mortalité et quatrième mur

## Principe

Les héros de Light in the Dark parlent, mais aucun héros mortel ne porte seul une information indispensable à la campagne. Leur présence enrichit le récit ; leur mort retire réellement une voix, une attitude et certaines réactions sans casser une quête.

Le `DialogueDirector` reçoit un événement et choisit une réplique parmi les personnages encore vivants. Si aucun héros compatible ne peut parler, la scène peut tomber sur une narration neutre ou sur le silence. Le moteur ne transfère jamais automatiquement une phrase écrite pour un héros mort vers un autre personnage.

Ordre de secours :

`réplique spécifique du héros → héros compatible → narration → silence`

Les textes restent écrits et validés dans les données du jeu. Le runtime sélectionne ; il ne génère pas de dialogue improvisé.

## Profils de voix

`data/voice_profiles.json` décrit pour chaque héros : registre, texture, rythme, longueur des phrases, vocabulaire, ironie, rapport au silence, peur, colère, sujets évités, habitudes et manière propre de fissurer le quatrième mur.

Ces profils doivent rester originaux. Ils ne sont jamais formulés comme une imitation de la voix ou du jeu d'un acteur réel.

## Quatrième mur

Le quatrième mur doit être une anomalie rare, pas la tonalité normale du jeu. Les héros peuvent parfois sembler sentir qu'une volonté extérieure choisit leurs pas, observe leurs morts ou répète une situation, mais ils ne comprennent pas l'existence d'un moteur de jeu.

Trois intensités existent :

- `fissure` : ambiguïté encore explicable dans le monde ;
- `direct` : le héros paraît parler à celui qui décide ;
- `abyssal` : le héros touche à la répétition, à la mortalité ou à l'existence du joueur de façon franchement inquiétante.

Règles de production :

- maximum deux fractures du quatrième mur par expédition ;
- au moins huit événements entre deux fractures ordinaires ;
- probabilité de base de 5 %, encore réduite pour les lignes `direct` et `abyssal` ;
- jamais d'information critique de scénario dans une réplique méta ;
- jamais de plaisanterie sur le code, les menus ou l'interface ;
- jamais de réplique méta pour remplacer le silence qui suit une mort importante ;
- un héros mort ne continue pas à commenter la partie ;
- les lignes méta conservent la voix propre du personnage.

## Exemples intégrés

Darius peut percevoir le joueur comme un commandant invisible :

> « Quelqu'un choisit nos pas avec une assurance remarquable pour quelqu'un qui ne risque pas sa peau. »

Malvor ramène la situation au corps :

> « J'espère que tu sais ce que tu fais. Moi, je n'ai pas de deuxième corps. »

Lysandra reste plus ambiguë :

> « Parfois, quand tout se tait, j'ai l'impression que quelqu'un lit nos hésitations. »

Aurélien perçoit surtout une présence derrière les décisions :

> « Tu hésites. Je le sens jusque d'ici. Pourtant c'est ma main qui va ouvrir la porte. »

Ces lignes ne remplacent jamais le dialogue narratif principal. Elles donnent au joueur l'impression très rare que le monde l'a remarqué.

## Mort permanente

Si Darius meurt, toutes les lignes dont `speaker_id = darius` deviennent immédiatement inéligibles. Un événement partagé peut encore recevoir une réaction de Lysandra, Malvor ou Aurélien s'ils possèdent leur propre texte pour cet événement. Si personne n'a de texte adapté, le système préfère le silence plutôt que de voler la voix d'un mort.

Pour une information de scénario essentielle, le `DialogueDirector` exige une source `critical_safe`, actuellement portée par la narration. À terme, ce même contrat pourra inclure des PNJ persistants, archives et éléments environnementaux.
