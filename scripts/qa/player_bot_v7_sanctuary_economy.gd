extends Node

const REPORT_PATH := "res://reports/player-bot-v7-sanctuary-economy.json"
const FIXED_SEEDS: Array[int] = [101, 202, 303, 404, 505]
const CAMPAIGNS_PER_SEED := 50
const MIN_POST_RECRUIT_RESERVE := 30
const MAX_RECRUITMENT_SHARE := 0.60

var failures: Array[String] = []
var alerts: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var market := VeilleursMarketService.new()
var recruitment := VeilleursHeroRecruitmentService.new()

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    await get_tree().process_frame
    var started_ms := Time.get_ticks_msec()
    var total_recruits := 0
    var total_purchases := 0
    var total_sales := 0
    var total_market_checks := 0
    var recruit_identity_seen: Dictionary = {}
    var min_post_recruit_gold := 2147483647
    var min_ending_gold := 2147483647
    var ending_gold_total := 0
    var max_recruitment_share := 0.0

    for seed_value in FIXED_SEEDS:
        for campaign_index in range(CAMPAIGNS_PER_SEED):
            var campaign_seed := seed_value * 10000 + campaign_index
            GameState.reset_new_game()
            EquipmentManager.reset_new_game(campaign_seed * 17 + 3)

            var row := {
                "seed": seed_value,
                "campaign": campaign_index + 1,
                "campaign_seed": campaign_seed,
                "starting_gold": GameState.gold,
                "market_offers": 0,
                "purchases": 0,
                "sales": 0,
                "recruits": 0,
                "recruitment_cost": 0,
                "post_recruit_gold": GameState.gold,
                "ending_gold": 0
            }

            var drop_before := EquipmentManager.drop_counter
            var offers_a := market.generate_offers(campaign_seed)
            var offers_b := market.generate_offers(campaign_seed)
            total_market_checks += 1
            row["market_offers"] = offers_a.size()
            if JSON.stringify(offers_a) != JSON.stringify(offers_b):
                failures.append("seed_%d_campaign_%d_market_nondeterministic" % [seed_value, campaign_index + 1])
            if EquipmentManager.drop_counter != drop_before:
                failures.append("seed_%d_campaign_%d_market_preview_consumed_drop" % [seed_value, campaign_index + 1])
            if offers_a.is_empty():
                failures.append("seed_%d_campaign_%d_market_empty" % [seed_value, campaign_index + 1])
                rows.append(row)
                continue

            var fallen_index := campaign_index % GameState.party.size()
            var fallen: Dictionary = GameState.party[fallen_index]
            var fallen_id := str(fallen.get("id", ""))
            var fallen_class := str(fallen.get("class_id", ""))
            fallen["hp"] = 0

            var candidates := recruitment.generate_replacement_candidates(fallen_id, campaign_seed, 3)
            if candidates.is_empty():
                failures.append("seed_%d_campaign_%d_no_replacement_candidates" % [seed_value, campaign_index + 1])
            else:
                var candidate_row: Dictionary = candidates[0]
                var candidate: Dictionary = candidate_row.get("candidate", {})
                if str(candidate.get("class_id", "")) != fallen_class:
                    failures.append("seed_%d_campaign_%d_replacement_class_mismatch" % [seed_value, campaign_index + 1])
                var gold_before_recruit := GameState.gold
                var replacement := recruitment.replace_dead(fallen_id, candidate)
                if not bool(replacement.get("ok", false)):
                    failures.append("seed_%d_campaign_%d_recruit_failed_%s" % [seed_value, campaign_index + 1, str(replacement.get("reason", "unknown"))])
                else:
                    row["recruits"] = 1
                    total_recruits += 1
                    var recruited: Dictionary = replacement.get("recruit", {})
                    var cost := int(replacement.get("cost", 0))
                    row["recruitment_cost"] = cost
                    row["post_recruit_gold"] = GameState.gold
                    min_post_recruit_gold = mini(min_post_recruit_gold, GameState.gold)
                    var share := float(cost) / maxf(1.0, float(gold_before_recruit))
                    max_recruitment_share = maxf(max_recruitment_share, share)
                    if GameState.gold < MIN_POST_RECRUIT_RESERVE:
                        failures.append("seed_%d_campaign_%d_recovery_reserve_below_%d" % [seed_value, campaign_index + 1, MIN_POST_RECRUIT_RESERVE])
                    if share > MAX_RECRUITMENT_SHARE:
                        failures.append("seed_%d_campaign_%d_recruitment_share_above_limit" % [seed_value, campaign_index + 1])
                    var identity_id := str(recruited.get("recruit_identity_id", ""))
                    if identity_id == "":
                        failures.append("seed_%d_campaign_%d_missing_recruit_identity" % [seed_value, campaign_index + 1])
                    elif recruit_identity_seen.has(identity_id):
                        failures.append("duplicate_recruit_identity_%s" % identity_id)
                    else:
                        recruit_identity_seen[identity_id] = true
                    if GameState.gold != gold_before_recruit - cost:
                        failures.append("seed_%d_campaign_%d_recruit_gold_accounting" % [seed_value, campaign_index + 1])
                    if GameState.alive_heroes().size() != GameState.party.size():
                        failures.append("seed_%d_campaign_%d_party_not_restored" % [seed_value, campaign_index + 1])
                    var name_before := str(recruited.get("name", ""))
                    GameState.canonicalize_party_identity(GameState.party)
                    if str(GameState.party[fallen_index].get("name", "")) != name_before:
                        failures.append("seed_%d_campaign_%d_recruit_identity_overwritten" % [seed_value, campaign_index + 1])

            var affordable := _cheapest_affordable_offer(offers_a)
            if not affordable.is_empty():
                var gold_before_buy := GameState.gold
                var bought := market.buy_offer(affordable, "v7_%d_%d" % [seed_value, campaign_index])
                if bool(bought.get("ok", false)):
                    total_purchases += 1
                    row["purchases"] = 1
                    var paid := int(bought.get("price", 0))
                    if GameState.gold != gold_before_buy - paid:
                        failures.append("seed_%d_campaign_%d_buy_gold_accounting" % [seed_value, campaign_index + 1])
                    var item: Dictionary = bought.get("item", {})
                    var instance_id := str(item.get("instance_id", ""))
                    if instance_id == "" or not EquipmentManager.has_instance(instance_id):
                        failures.append("seed_%d_campaign_%d_bought_item_missing" % [seed_value, campaign_index + 1])
                    else:
                        var gold_before_sell := GameState.gold
                        var sold := market.sell(instance_id)
                        if not bool(sold.get("ok", false)):
                            failures.append("seed_%d_campaign_%d_sell_failed_%s" % [seed_value, campaign_index + 1, str(sold.get("reason", "unknown"))])
                        else:
                            total_sales += 1
                            row["sales"] = 1
                            if GameState.gold != gold_before_sell + int(sold.get("price", 0)):
                                failures.append("seed_%d_campaign_%d_sell_gold_accounting" % [seed_value, campaign_index + 1])
                            if EquipmentManager.has_instance(instance_id):
                                failures.append("seed_%d_campaign_%d_sold_item_still_present" % [seed_value, campaign_index + 1])

            row["ending_gold"] = GameState.gold
            min_ending_gold = mini(min_ending_gold, GameState.gold)
            ending_gold_total += GameState.gold
            rows.append(row)

    if total_recruits < FIXED_SEEDS.size() * CAMPAIGNS_PER_SEED:
        alerts.append({"id":"recruitment_coverage_below_target","count":total_recruits})
    if total_market_checks != FIXED_SEEDS.size() * CAMPAIGNS_PER_SEED:
        failures.append("market_coverage_count")

    var report := {
        "schema_version": 7,
        "suite": "player_bot_v7_sanctuary_economy",
        "driver": "production_sanctuary_services",
        "fixed_seeds": FIXED_SEEDS,
        "campaigns_per_seed": CAMPAIGNS_PER_SEED,
        "campaign_cycles": rows.size(),
        "market_checks": total_market_checks,
        "recruitments": total_recruits,
        "purchases": total_purchases,
        "sales": total_sales,
        "unique_recruit_identities": recruit_identity_seen.size(),
        "economy_health": {
            "min_post_recruit_gold": 0 if min_post_recruit_gold == 2147483647 else min_post_recruit_gold,
            "min_ending_gold": 0 if min_ending_gold == 2147483647 else min_ending_gold,
            "avg_ending_gold": float(ending_gold_total) / maxf(1.0, float(rows.size())),
            "max_recruitment_share": max_recruitment_share,
            "min_post_recruit_reserve_required": MIN_POST_RECRUIT_RESERVE,
            "max_recruitment_share_allowed": MAX_RECRUITMENT_SHARE
        },
        "alerts": alerts,
        "failures": failures,
        "rows": rows,
        "duration_ms": Time.get_ticks_msec() - started_ms,
        "status": "passed" if failures.is_empty() else "failed"
    }
    _write_report(report)
    if failures.is_empty():
        print("PLAYER_BOT_V7_OK cycles=%d recruits=%d purchases=%d sales=%d" % [rows.size(), total_recruits, total_purchases, total_sales])
        get_tree().quit(0)
        return
    for failure in failures:
        push_error("PLAYER_BOT_V7: " + failure)
    get_tree().quit(1)

func _cheapest_affordable_offer(offers: Array) -> Dictionary:
    var result: Dictionary = {}
    var best_price := 2147483647
    for offer_value in offers:
        var offer: Dictionary = offer_value
        var price := int(offer.get("price", 0))
        if price <= GameState.gold and price < best_price:
            best_price = price
            result = offer.duplicate(true)
    return result

func _write_report(report: Dictionary) -> void:
    var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
    if file == null:
        failures.append("report_write")
        return
    file.store_string(JSON.stringify(report, "  "))
    file.store_line("")
    file.close()
