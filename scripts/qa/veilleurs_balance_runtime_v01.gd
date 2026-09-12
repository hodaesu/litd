extends "res://scripts/core/veilleurs_tactical_combat_runtime_v09.gd"
class_name VeilleursBalanceRuntimeV01

## Non-production adapter used by BalanceLab to exercise the real Godot combat
## runtime with seedable, serialised rolls. Production behaviour remains untouched.

var balance_seed: int = 0
var balance_roll_serial: int = 0

func configure_balance_seed(seed: int) -> void:
    balance_seed = seed
    balance_roll_serial = 0

func _deterministic_roll(a: String, b: String, c: String) -> int:
    if balance_seed == 0:
        return posmod((a + "|" + b + "|" + c + "|" + str(round_index)).hash(), 100) + 1
    var token := "%s|%s|%s|%d|%d|%d" % [a, b, c, round_index, balance_seed, balance_roll_serial]
    balance_roll_serial += 1
    return posmod(token.hash(), 100) + 1

func serialize() -> Dictionary:
    var payload: Dictionary = super.serialize()
    payload["balance_lab_seed"] = balance_seed
    payload["balance_lab_roll_serial"] = balance_roll_serial
    return payload

func deserialize(payload: Dictionary) -> bool:
    if not super.deserialize(payload):
        return false
    balance_seed = int(payload.get("balance_lab_seed", 0))
    balance_roll_serial = int(payload.get("balance_lab_roll_serial", 0))
    return true
