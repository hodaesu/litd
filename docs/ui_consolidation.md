# Architecture UI consolidée

La scène principale conserve provisoirement la chaîne `main_v2.gd` à `main_v34.gd` comme couche de compatibilité comportementale : chaque fichier ajoute une règle de combat testée et l’héritage empêche la duplication de toute la boucle. Aucun nouveau `main_v35.gd` ne doit être créé.

À partir de cette version, les nouvelles fonctions sont séparées :

- `ui_section_registry.gd` : navigation et titres du menu unifié ;
- `game_menu_ui.gd` : composition des sections hors combat ;
- `combat_preview_director.gd` : prévision des actions ;
- `action_timeline_director.gd` : ordre et intentions ;
- `effect_tooltip_formatter.gd` : descriptions des effets ;
- `expedition_preparation_director.gd` : formations et contrôles ;
- `expedition_report_director.gd` : bilans ;
- `campaign_memory_director.gd` : chronique et codex ;
- `accessibility_director.gd` : application des réglages.

Règles :

1. aucune nouvelle logique métier dans `game_menu_ui.gd` ;
2. aucune nouvelle variante numérotée de `main.gd` ;
3. les composants doivent être testables sans rendu ;
4. les inspections et prévisions ne mettent jamais le combat en pause ;
5. la suppression de la chaîne historique attend le PC, une scène de remplacement et une validation visuelle complète.
