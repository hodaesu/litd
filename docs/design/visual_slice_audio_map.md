# Audio minimum du vertical slice

Le slice Darius vs Goule réutilise les runtimes audio existants. Il ne crée pas une deuxième architecture audio et n'ajoute aucun binaire tiers.

| Événement slice | Famille demandée | Rôle |
| --- | --- | --- |
| pas sur cendre | `footstep_ash` | ancrage au sol |
| préparation attaque | `combat_telegraph` | lisibilité tactique |
| impact d'arme | `weapon_impact` | confirmation de coup |
| vocalisation Goule | `ghoul_vocal` | identité ennemi |
| boucle Terres de Cendre | `ashlands_wind` | ambiance |
| entrée combat | `combat_music` | mode musical combat |

Le runtime appelle les directeurs existants seulement si leurs méthodes sont disponibles. L'absence d'un asset audio reste un fallback silencieux et ne doit jamais casser le mini-combat.
