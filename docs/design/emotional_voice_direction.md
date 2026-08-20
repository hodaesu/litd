# Direction vocale émotionnelle — PASS 30

## But

La direction vocale de *Light in the Dark* sépare trois choses : le texte écrit, l'intention de jeu et le moteur de production. Le système ne réentraîne pas ChatGPT, OpenVoice ou MeloTTS. Il construit une grammaire de jeu propre au projet, puis l'affine par écoute de prises autorisées.

Chaque réplique reçoit une émotion principale, une émotion secondaire éventuelle, une intensité de 1 à 5, un état physique et psychologique, une relation, une prosodie cible, quelques mots d'appui, une transition et une note de jeu. L'identité du personnage reste prioritaire sur l'étiquette émotionnelle.

## Chaîne de production

1. Le dialogue reste écrit dans les données narratives existantes.
2. `tools/voice/build_voice_direction_registry.py` rassemble les dialogues réactifs et les barks de démo, applique les defaults événementiels et les overrides explicites, puis valide toutes les directions.
3. `tools/voice/openvoice_v2_pipeline.py plan` embarque la direction dans chaque entrée de production. MeloTTS ne reçoit automatiquement que le multiplicateur de vitesse : pitch, souffle, articulation, pauses, accentuation et transitions restent des consignes de jeu et des critères d'écoute, car le backend actuel ne les garantit pas directement.
4. Les références vocales restent locales et doivent toujours satisfaire le registre de consentement existant : voix originale ou autorisée, usage commercial autorisé, aucune imitation de célébrité ou d'acteur.
5. Après rendu ou enregistrement, `tools/voice/voice_take_review.py` produit une feuille de calibration. Les prises sont notées sur reconnaissance de l'émotion, conservation de l'identité, naturel, intelligibilité, retenue et adéquation au contexte.
6. Une prise n'entre dans Godot qu'après écoute humaine. Les intensités 5 sont toujours revues manuellement.

## Intensité

- **1 — sous-texte** : l'émotion est presque invisible et la personnalité domine.
- **2 — contenue** : l'émotion se lit sans prendre le contrôle.
- **3 — explicite contrôlée** : l'émotion est nette mais le personnage se maîtrise.
- **4 — forte** : l'émotion devient dominante et altère partiellement le contrôle.
- **5 — extrême, rare** : rupture exceptionnelle, jamais validée automatiquement.

## Personnages

Les baselines de Darius, Aurélien, Malvor et Lysandra prolongent `data/voice_profiles.json`. Elles sont volontairement marquées comme provisoires jusqu'à l'écoute des vraies références autorisées. Une même peur ne doit donc pas produire quatre voix identiques : Aurélien tente de l'analyser, Malvor la convertit plus facilement en agressivité ou humour noir, Lysandra resserre son attention, Darius devient plus tactique et moins patient.

## Calibration plutôt que caricature

Le corpus `data/voice_emotion_calibration.json` contient des phrases originales couvrant peur, colère, deuil, espoir fragile, dissociation, perception altérée, douleur, autorité, menace calme et autres nuances. Les signaux d'échec sont aussi importants que les signaux recherchés : pas de « rire fou », de voix démoniaque, de growl systématique, de sanglot automatique, de voix de bande-annonce ou de chuchotement artificiellement dramatique.

La Folie n'est donc pas une intonation unique. Une perception altérée peut rester lucide, précise et humaine. De même, le deuil de LITD privilégie la retenue par défaut et la panique n'est pas un cri permanent.

## Commandes utiles

```bash
python tools/voice/build_voice_direction_registry.py --check
python tools/voice/build_voice_direction_registry.py
python tools/voice/voice_take_review.py --check
python tools/voice/voice_take_review.py --template reports/voice-calibration-sheet.json
python -m tools.voice.openvoice_v2_pipeline plan --output reports/voice-generation-plan.json
```

Après avoir rempli une feuille d'écoute :

```bash
python tools/voice/voice_take_review.py --score reports/voice-calibration-sheet.json
```

Le résultat sert à ajuster les profils, les intensités et les notes de jeu du projet. Il ne modifie jamais automatiquement les poids d'un modèle vocal.
