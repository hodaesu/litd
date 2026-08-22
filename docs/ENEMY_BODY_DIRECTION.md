# Direction corporelle des ennemis

Chaque ennemi conserve une silhouette et un rythme reconnaissables avant même son attaque. La diversité ne repose pas sur du bruit aléatoire : elle est déterministe et lisible.

La pose visible est composée dans cet ordre :

1. archétype anatomique et famille de rig ;
2. tempérament ;
3. rôle tactique ;
4. asymétrie individuelle ;
5. blessure ou mobilité réduite ;
6. peur ou folie ;
7. intention de combat ;
8. décalage de cycle propre à l'individu.

Les 39 ennemis ont 39 signatures uniques. Le registre emploie 12 archétypes corporels, 10 tempéraments et plus de 15 rôles de posture. Deux créatures partageant un rig ne partagent donc pas nécessairement leur appui, leur centre moteur, leur cadence, leur regard ou leur manière d'occuper l'espace.

Les états ne remplacent jamais l'espèce. Une Goule paniquée reste une Goule : son angle corporel révèle davantage la sortie, mais sa locomotion demeure prédatrice et frontale. Un chevalier blessé protège son côté atteint sans perdre sa structure lourde et disciplinée.

Les ennemis capturés conservent leur signature corporelle lorsqu'ils rejoignent le groupe. Les boss n'utilisent jamais l'idle générique. Godot garde l'autorité sur l'IA et les événements de combat ; Blender fournit les clips et les poses additives.

Audit :

```bash
python tools/animation/enemy_body_profiles.py
```
