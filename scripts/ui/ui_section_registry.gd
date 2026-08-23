extends RefCounted

const SECTIONS: Array[Dictionary] = [
    {"id":"inventory","label":"INVENTAIRE","title":"INVENTAIRE"},
    {"id":"map","label":"CARTE","title":"CARTE"},
    {"id":"journal","label":"JOURNAL","title":"JOURNAL DE QUÊTES"},
    {"id":"characters","label":"PERSONNAGES","title":"PERSONNAGES ET COMPÉTENCES"},
    {"id":"preparation","label":"PRÉPARATION","title":"PRÉPARATION D’EXPÉDITION"},
    {"id":"bestiary","label":"BESTIAIRE","title":"BESTIAIRE"},
    {"id":"records","label":"PRIMES","title":"CONTRATS ET FAITS D’ARMES"},
    {"id":"chronicle","label":"CHRONIQUE","title":"MÉMOIRE DE LA CAMPAGNE"},
    {"id":"reports","label":"BILANS","title":"BILANS D’EXPÉDITION"},
    {"id":"help","label":"AIDE","title":"TUTORIEL ET GLOSSAIRE"},
    {"id":"saves","label":"SAUVEGARDES","title":"SAUVEGARDES"},
    {"id":"options","label":"OPTIONS","title":"OPTIONS ET RÉGLAGES"}
]

static func entries() -> Array[Dictionary]:
    return SECTIONS.duplicate(true)

static func title(section_id: String) -> String:
    for entry: Dictionary in SECTIONS:
        if String(entry.get("id", "")) == section_id:
            return String(entry.get("title", "MENU"))
    return "MENU"
