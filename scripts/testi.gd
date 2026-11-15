## Testi italiani di carte, partiti e incarichi.
class_name Testi
extends RefCounted

static func ddl(id: String) -> String:
	return "«%s»" % str(DatiGen.IT_DDL[id][0])

static func ddl_titolo(id: String) -> String:
	return str(DatiGen.IT_DDL[id][0])

static func ddl_sotto(id: String) -> String:
	return str(DatiGen.IT_DDL[id][1])

static func evento(n: int) -> String:
	if DatiGen.IT_EVENTI.has(str(n)):
		return str(DatiGen.IT_EVENTI[str(n)][0])
	return "ELEZIONE SUPPLETIVA"

static func evento_opz(n: int, o: int) -> String:
	return str(DatiGen.IT_EVENTI[str(n)][o + 1])

static func sost_ruolo(n: int) -> String:
	return str(DatiGen.IT_SOST[str(n)])

static func partito(par: String) -> String:
	return "il Partito Conservatore" if par == "C" else "il Partito Liberale"

static func partito_pl(par: String) -> String:
	return "I Conservatori" if par == "C" else "I Liberali"

static func partito_agg(par: String) -> String:
	return "Conservatore" if par == "C" else "Liberale"

static func ruolo(r: String) -> String:
	return {"pm": "Primo Ministro", "opp": "Capo dell'Opposizione", "bbg": "Backbencher di Governo", "bbo": "Backbencher d'Opposizione"}.get(r, r)

static func carriera(k: String, lato: String) -> String:
	match k:
		"cw": return "Capogruppo"
		"cc": return "Responsabile della campagna"
		"pc": return "Consigliere privato"
		"dpl": return "Vice Primo Ministro" if lato == "gov" else "Vice capo del partito"
	return k

static func premio(o: String) -> String:
	return {"st+1": "Standing +1", "st-1": "Standing -1", "fav+1": "Favore +1", "fav-1": "Favore -1", "pv2": "2 Punti Vittoria"}.get(o, o)
