extends Node

const REPORT_PATH := "res://reports/player-bot-v19-economy-stress.json"
const FIXED_SEEDS: Array[int] = [1901, 2902, 3903, 4904, 5905]
const CYCLES_PER_SEED := 20
const SHOCKS_PER_CYCLE := 3
const RECOVERY_INCOME: Array[int] = [35, 55, 80]
const MIN_SURVIVAL_GOLD := 0

var market := VeilleursMarketService.new()
var recruitment := VeilleursHeroRecruitmentService.new()
var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var started := Time.get_ticks_msec()
    var bankruptcies := 0
    var successful_recoveries := 0
    for seed_value in FIXED_SEEDS:
        for cycle in range(CYCLES_PER_SEED):
            GameState.reset_new_game()
            EquipmentManager.reset_new_game(seed_value * 100 + cycle)
            GameState.gold = 180
            var row := {
                "seed": seed_value,
                "cycle": cycle + 1,
                "starting_gold": GameState.gold,
                "shocks": [],
                "ending_gold": 0,
                "bankrupt": false
            }
            for shock in range(SHOCKS_PER_CYCLE):
                var alive := GameState.alive_heroes()
                if alive.is_empty():
                    failures.append("seed_%d_cycle_%d_no_alive_hero" % [seed_value, cycle + 1])
                    break
                var fallen: Dictionary = alive[(cycle + shock) % alive.size()]
                var fallen_id := str(fallen.get("id", ""))
                fallen["hp"] = 0
                var candidates := recruitment.generate_replacement_candidates(fallen_id, seed_value * 10000 + cycle * 100 + shock, 3)
                var shock_row := {"index": shock + 1, "gold_before": GameState.gold, "recruit_cost": 0, "recovery_income": RECOVERY_INCOME[shock], "gold_after": GameState.gold}
                if candidates.is_empty():
                    failures.append("seed_%d_cycle_%d_shock_%d_no_candidate" % [seed_value, cycle + 1, shock + 1])
                    break
                var candidate: Dictionary = (candidates[0] as Dictionary).get("candidate", {})
                var replacement := recruitment.replace_dead(fallen_id, candidate)
                if not bool(replacement.get("ok", false)):
                    failures.append("seed_%d_cycle_%d_shock_%d_recruit_%s" % [seed_value, cycle + 1, shock + 1, str(replacement.get("reason", "unknown"))])
                    break
                shock_row["recruit_cost"] = int(replacement.get("cost", 0))

                var offers := market.generate_offers(seed_value * 100000 + cycle * 10 + shock)
                var cheapest := _cheapest_affordable(offers)
                if not cheapest.is_empty():
                    var bought := market.buy_offer(cheapest, "v19_%d_%d_%d" % [seed_value, cycle, shock])
                    if bool(bought.get("ok", false)):
                        var item: Dictionary = bought.get("item", {})
                        var instance_id := str(item.get("instance_id", ""))
                        if instance_id != "":
                            market.sell(instance_id)

                # Représente un rendement d'extraction contrôlé. Le but de v19 est de
                # tester la résilience stratégique des coûts de production, pas le combat.
                GameState.gold += RECOVERY_INCOME[shock]
                shock_row["gold_after"] = GameState.gold
                (row["shocks"] as Array).append(shock_row)

                if GameState.gold < MIN_SURVIVAL_GOLD:
                    row["bankrupt"] = true
                    bankruptcies += 1
                    break

            row["ending_gold"] = GameState.gold
            if not bool(row.get("bankrupt", false)) and GameState.alive_heroes().size() == GameState.party.size():
                successful_recoveries += 1
            rows.append(row)

    var total_cycles := FIXED_SEEDS.size() * CYCLES_PER_SEED
    var recovery_rate := float(successful_recoveries) / maxf(1.0, float(total_cycles))
    if recovery_rate < 0.90:
        failures.append("recovery_rate_below_90_percent")
    var report := {
        "schema_version": 19,
        "suite": "player_bot_v19_economy_stress",
        "method": "production_market_and_recruitment_with_controlled_extraction_income",
        "cycles": total_cycles,
        "shocks_per_cycle": SHOCKS_PER_CYCLE,
        "successful_recoveries": successful_recoveries,
        "recovery_rate": recovery_rate,
        "bankruptcies": bankruptcies,
        "rows": rows,
        "failures": failures,
        "duration_ms": Time.get_ticks_msec() - started,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write(report)
    if failures.is_empty():
        print("PLAYER_BOT_V19_OK cycles=%d recovery_rate=%.3f" % [total_cycles, recovery_rate])
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("PLAYER_BOT_V19: " + failure)
        get_tree().quit(1)

func _cheapest_affordable(offers: Array) -> Dictionary:
    var best: Dictionary = {}
    var best_price := 2147483647
    for offer_value in offers:
        var offer: Dictionary = offer_value
        var price := int(offer.get("price", 0))
        if price <= GameState.gold and price < best_price:
            best_price = price
            best = offer.duplicate(true)
    return best

func _write(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        push_error("PLAYER_BOT_V19: report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
