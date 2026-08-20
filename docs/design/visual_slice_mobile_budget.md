# Budget technique mobile — vertical slice LITD

Cible initiale : iPhone en paysage, 60 fps visés. Ces budgets servent de garde-fou avant profilage réel sur appareil.

| Poste | Budget initial |
| --- | ---: |
| Personnage LOD0 | 60 000 triangles max |
| Personnage LOD1 | 30 000 triangles max |
| Personnage LOD2 | 12 000 triangles max |
| Matériaux par personnage | 3 max |
| Os par personnage | 80 max |
| Meshes skinnés par personnage | 3 max |
| Texture personnage | 2048 px max |
| Arène visible | 180 000 triangles max |
| Matériaux visibles arène | 18 max |
| Texture arène | 2048 px max |
| Texture 4K | 0 |
| Directional avec ombres | 1 max |
| Omni dynamiques | 2 max, sans ombres |
| Systèmes de particules simultanés | 8 max |
| Particules visibles | 1 200 max |
| Draw calls | objectif ≤ 220 |
| Framerate | cible 60, validation minimale 50 |

Le premier profilage sur appareil réel doit mesurer GPU time, CPU frame time, draw calls, mémoire texture, overdraw, skinning et pics de particules. Si un budget doit être réduit pour stabiliser le framerate, la silhouette et la lisibilité passent avant le micro-détail.
