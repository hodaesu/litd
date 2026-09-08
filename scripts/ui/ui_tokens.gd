extends RefCounted
class_name UITokens

# LITD: Les Veilleurs — dark fantasy UI reference palette.
# Keep gameplay meaning independent from color: every critical state must also
# use an icon, shape, label, or other non-color cue.

const COLOR_BACKGROUND := Color("#0B0D0E")
const COLOR_SURFACE := Color("#121619")
const COLOR_SURFACE_RAISED := Color("#1B2024")
const COLOR_SURFACE_PRESSED := Color("#242A2E")
const COLOR_BORDER_METAL := Color("#565A5C")
const COLOR_BONE := Color("#C7BAA2")
const COLOR_IVORY := Color("#E8E0D1")
const COLOR_TEXT_MUTED := Color("#A89F90")
const COLOR_DISABLED := Color("#4B5054")

const COLOR_BLOOD := Color("#A92D32")
const COLOR_BLOOD_BRIGHT := Color("#D5484D")
const COLOR_OCHRE := Color("#C18A3F")
const COLOR_GOLD := Color("#D2A14F")
const COLOR_COLD_BLUE := Color("#4D86A8")
const COLOR_KNOWLEDGE := Color("#5E93B7")
const COLOR_DESAT_GREEN := Color("#557B62")
const COLOR_VIOLET := Color("#71569A")

# Unified gauge palette taken from the approved atlas direction.
const GAUGE_HEALTH := COLOR_BLOOD
const GAUGE_DANGER := COLOR_BLOOD_BRIGHT
const GAUGE_FOCUS := COLOR_OCHRE
const GAUGE_KNOWLEDGE := COLOR_COLD_BLUE
const GAUGE_RECOVERY := COLOR_DESAT_GREEN
const GAUGE_RARE := COLOR_VIOLET
const GAUGE_NEUTRAL := COLOR_BONE

const RARITY_COMMON := COLOR_BORDER_METAL
const RARITY_UNCOMMON := COLOR_DESAT_GREEN
const RARITY_RARE := COLOR_COLD_BLUE
const RARITY_EPIC := COLOR_VIOLET
const RARITY_LEGENDARY := COLOR_OCHRE

const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 16
const SPACE_L := 24
const SPACE_XL := 32

const CORNER_RADIUS_S := 3
const CORNER_RADIUS_M := 6

const TOUCH_MIN_SIZE := 48
const TOUCH_PRIMARY_SIZE := 56

const TEXT_SMALL := 14
const TEXT_BODY := 17
const TEXT_LARGE := 22
const TEXT_TITLE := 30

const ANIM_PRESS_SECONDS := 0.08
const ANIM_OPEN_SECONDS := 0.18
const ANIM_TRANSITION_SECONDS := 0.30
const ANIM_REVEAL_SECONDS := 0.50

static func gauge_color(kind: String) -> Color:
    match kind.to_lower():
        "health", "vitality", "pv":
            return GAUGE_HEALTH
        "danger", "critical":
            return GAUGE_DANGER
        "focus", "progression", "hope":
            return GAUGE_FOCUS
        "knowledge", "remanence":
            return GAUGE_KNOWLEDGE
        "recovery", "success", "stability":
            return GAUGE_RECOVERY
        "rare", "rarity", "mental":
            return GAUGE_RARE
        _:
            return GAUGE_NEUTRAL

static func rarity_color(rarity: String) -> Color:
    match rarity.to_lower():
        "uncommon", "peu_commun", "peu commun":
            return RARITY_UNCOMMON
        "rare":
            return RARITY_RARE
        "epic", "epique", "épique":
            return RARITY_EPIC
        "legendary", "legendaire", "légendaire":
            return RARITY_LEGENDARY
        _:
            return RARITY_COMMON
