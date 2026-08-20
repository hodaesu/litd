# Ingestion GLB validée — vertical slice

Le vertical slice utilise un mécanisme de remplacement progressif. Le proxy reste présent tant qu'un asset GLB n'existe pas ou n'a pas passé le contrat de validation.

## Darius et Goule

Validation requise avant remplacement du proxy :

- GLB importé comme `PackedScene` ;
- au moins un `MeshInstance3D` ;
- un `Skeleton3D` ;
- os minimum du contrat humanoïde ;
- sockets `SOCKET_weapon_r`, `SOCKET_weapon_l`, `SOCKET_head`, `SOCKET_back`, `SOCKET_fx_root` ;
- `AnimationPlayer` ;
- clips minimum correspondant au rôle ;
- limites de triangles, matériaux, os, meshes skinnés et textures respectées dans le rapport de validation hors ligne.

## Arène

Le proxy d'arène n'est remplacé que si le GLB existe et contient une géométrie. Les budgets visibles sont contrôlés par rapport JSON avant promotion.

## Principe

Un export invalide ne doit jamais casser la scène : le loader garde le proxy, signale les raisons de rejet et permet de continuer le travail.
