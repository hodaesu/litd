extends "res://scripts/ui/main_v36.gd"

# v37 : cycle passif d'Hémocorde au-dessus des réactions cliniques validées en v36.
# Le resolver vasculaire reste séparé du runtime anatomique/médical et réutilise
# leurs états corporels réels au lieu d'introduire une jauge sanguine parallèle.

func show_combat() -> void:
    VeilleursSkillResolverRouter.refresh_specialized_passives(GameState.party, GameState.battle_enemies)
    super.show_combat()

func enemy_turn() -> void:
    await super.enemy_turn()
    VeilleursSkillResolverRouter.advance_specialized_round_states(GameState.party)
    VeilleursSkillResolverRouter.refresh_specialized_passives(GameState.party, GameState.battle_enemies)
    if GameState.current_screen == "combat":
        battle_locked = false
        show_screen("combat")
