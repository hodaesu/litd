# Production vocale — OpenVoice V2

## But

La synthèse vocale est un outil de production hors jeu. Le build iPhone ne dépend d'aucun service IA, d'aucune connexion réseau et d'aucun moteur de synthèse embarqué. Les dialogues restent écrits dans `data/reactive_dialogues.json`; le pipeline ne génère jamais le texte.

## Versions testées et épinglées

Le contrat du projet épingle :

- OpenVoice `74a1d147b17a8c3092dd5430504bd83ef6c7eb23` ;
- MeloTTS `209145371cff8fc3bd60d7be902ea69cbdb7965a` ;
- langue de base `FR` ;
- checkpoints OpenVoice V2 dans `checkpoints_v2`.

OpenVoice V2 et MeloTTS sont utilisés comme outils externes de production. Leurs codes sont sous licence MIT aux commits épinglés. Les checkpoints et dépendances doivent rester installés localement selon les instructions officielles.

## Installation locale recommandée

Créer un environnement Python séparé du projet Godot, idéalement avec Python 3.9 comme dans la documentation officielle OpenVoice.

```bash
conda create -n litd-voice python=3.9
conda activate litd-voice

git clone https://github.com/myshell-ai/OpenVoice.git
cd OpenVoice
git checkout 74a1d147b17a8c3092dd5430504bd83ef6c7eb23
pip install -e .
pip install git+https://github.com/myshell-ai/MeloTTS.git@209145371cff8fc3bd60d7be902ea69cbdb7965a
python -m unidic download
```

Télécharger ensuite les checkpoints V2 depuis la source indiquée par la documentation officielle OpenVoice et les extraire dans `OpenVoice/checkpoints_v2`.

## Références vocales

Les références ne sont jamais stockées dans Git.

1. Copier `docs/templates/voice_reference_registry.example.json` vers `local/voice_refs/registry.json`.
2. Placer les WAV de référence dans `local/voice_refs/`.
3. Pour chaque voix, confirmer explicitement dans le registre local :
   - consentement de la personne enregistrée ;
   - voix originale ou légalement autorisée ;
   - autorisation d'utilisation commerciale dans le jeu.
4. Ne jamais utiliser ce pipeline pour imiter un acteur, une célébrité ou une personne non consentante.

Le script refuse le rendu tant que ces trois validations ne sont pas `true`.

## Étape 1 — plan déterministe

Cette étape n'a besoin ni de PyTorch ni d'OpenVoice :

```bash
python -m tools.voice.openvoice_v2_pipeline plan
```

Le plan est construit à partir de :

- `data/reactive_dialogues.json` ;
- `data/voice_profiles.json` ;
- `data/voice_production.json`.

Chaque ligne reçoit un identifiant stable, le texte exact, son SHA-256, une direction de jeu, une vitesse, une référence vocale attendue et ses chemins de rendu/ingestion.

## Étape 2 — rendu OpenVoice V2

```bash
python -m tools.voice.openvoice_v2_pipeline render \
  --openvoice-root /chemin/vers/OpenVoice
```

Filtres utiles :

```bash
python -m tools.voice.openvoice_v2_pipeline render \
  --openvoice-root /chemin/vers/OpenVoice \
  --speaker darius

python -m tools.voice.openvoice_v2_pipeline render \
  --openvoice-root /chemin/vers/OpenVoice \
  --line-id fw_dar_abyss_01
```

Le rendu se fait d'abord dans `build/voice_rendered`. Il n'entre pas automatiquement dans les assets du jeu.

Le pipeline suit le mécanisme V2 officiel : MeloTTS produit la base française, OpenVoice extrait l'empreinte de la voix de référence et le convertisseur de couleur vocale produit le WAV final. Le script conserve également le hash de la référence et du rendu dans le rapport local.

## Étape 3 — écoute humaine

Aucun fichier n'est intégré automatiquement après synthèse. Il faut écouter les lignes et vérifier au minimum :

- intelligibilité du français ;
- nom propre et prononciation ;
- émotion conforme à la scène ;
- absence d'artefact majeur ;
- cohérence de la voix entre les répliques ;
- quatrième mur joué sans effet comique ou surjoué ;
- volume et souffle exploitables au mixage.

Une ligne incorrecte est régénérée ou remplacée avant ingestion.

## Étape 4 — ingestion Godot

Après validation à l'écoute :

```bash
python -m tools.voice.openvoice_v2_pipeline ingest \
  --approve-reviewed
```

Cette commande :

- vérifie que les fichiers n'ont pas changé depuis le rapport de rendu ;
- revérifie le registre de droits local ;
- copie les WAV dans `assets/audio/voices/<personnage>/` ;
- calcule leur SHA-256 ;
- met à jour `data/voice_assets.json`.

Le flag `--approve-reviewed` est volontairement obligatoire : l'IA ne doit jamais auto-approuver ses propres rendus.

## Runtime Godot

`VoiceRuntime` lit uniquement `data/voice_assets.json`. Quand `DialogueDirector` sélectionne une ligne :

- si un WAV approuvé existe, il est joué sur le bus `Dialogue` et le mix narratif est ducké ;
- s'il manque, le texte reste affichable et le jeu continue normalement ;
- la mort permanente reste contrôlée par `DialogueDirector`, donc aucun fichier vocal d'un héros mort ne peut ressusciter sa réplique.

## Quatrième mur

Les niveaux `fissure`, `direct` et `abyssal` modifient seulement la direction et légèrement le rythme de synthèse. Ils ne changent jamais les règles de rareté du `DialogueDirector`.

Les lignes abyssales doivent rester calmes. Plus la phrase est impossible, moins l'interprétation doit souligner qu'elle est « spéciale ».
