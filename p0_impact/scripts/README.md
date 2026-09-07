# P0 scripts

- `combat_test.gd`: standalone playable prototype scene logic.
- `p0_constants.gd`: canonical P0 values matching the current paper design.

The standalone P0 intentionally favors clarity over architecture. Once the interaction is validated in Godot, the logic should be split into reusable `Grid`, `Unit`, `SkillResolver`, `PushResolver`, `CollisionResolver`, and `TurnController` components rather than expanding this single script indefinitely.
