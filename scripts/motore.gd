## Motore delle regole di Prime Minister (GMT Games, Paul Hellyer).
## Lo stato `s` è un dizionario serializzabile: basta per salvare, riprendere e rigiocare una partita.
## Il motore avanza da solo (avanza) finché serve la decisione di un giocatore umano: allora `s.att`
## descrive la decisione e `opzioni()` elenca le risposte lecite; `rispondi()` la applica.
## I politici automatici (Clockwork e IA) decidono dentro il motore, con il generatore di numeri dello stato:
## la stessa sequenza di decisioni umane dà sempre la stessa partita (serve per l'online).
class_name Motore
extends RefCounted

var s := {}

# ------------------------------------------------------------------ avvio

## cfg: modo ("cw1", "cw2", "multi"), posti [{pol, tipo ("u" umano, "cw" automatico), nome}], facile,
## riserva (cw1: secondo politico), umano_pm (cw2), seme.
static func nuova(cfg: Dictionary) -> Motore:
	var m := Motore.new()
	m._avvia(cfg)
	return m

static func da_stato(stato: Dictionary) -> Motore:
	var m := Motore.new()
	m.s = stato
	return m

func _avvia(cfg: Dictionary) -> void:
	s = {"cfg": cfg, "r": int(cfg.get("seme", 1)) & 0x7fffffff, "round": 0, "fase": "round", "att": null, "fine": null,
		"reg": [], "tav": [], "marc": true, "patto": cfg["modo"] == "multi", "patto_rotto": false, "sfida_round": false,
		"mp": {"A": 330, "M": 270, "P": 60}, "seggi_prima": {"L": 330, "C": 330}, "pop": {"C": {}, "L": {}},
		"g": [], "mazzi": {}, "sel": null, "turno": null, "sost_pm": false, "n_dec": 0}
	if s["r"] == 0:
		s["r"] = 12345
	for k in Dati.SETTORI:
		s["pop"]["C"][k] = Dati.TRACCE[k]["C"]["i"]
		s["pop"]["L"][k] = Dati.TRACCE[k]["L"]["i"]
	var mz: Dictionary = s["mazzi"]
	for k in ["X", "C", "L"]:
		mz[k] = []
		mz[k + "_s"] = []
	for d in DatiGen.DDL:
		mz[d["mazzo"]].append(d["id"])
	for k in ["X", "C", "L"]:
		_mescola(mz[k])
	mz["sost"] = _serie(DatiGen.SOSTENITORI.size())
	mz["scw"] = _serie(DatiGen.SOSTENITORI_CW.size())
	mz["ev"] = _serie(DatiGen.EVENTI.size())
	mz["evc"] = _serie(DatiGen.EVENTI_CW.size())
	for k in ["sost", "scw", "ev", "evc"]:
		_mescola(mz[k])
		mz[k + "_s"] = []
	var posti: Array = cfg["posti"]
	for i in posti.size():
		var pol: Dictionary = Dati.politico(posti[i]["pol"])
		s["g"].append({"pol": pol["id"], "par": pol["p"], "ruolo": "", "st": 0, "fav": 1, "pv": 0, "sost": [], "cubi": 0,
			"tipo": posti[i].get("tipo", "u"), "nome": posti[i].get("nome", pol["corto"]), "tenute": [], "da_giocare": [],
			"dim": false, "carr": [], "dib": -1})
	if cfg["modo"] == "multi":
		_ruoli_multi()
	else:
		var u_pm: bool = cfg["modo"] == "cw1" or cfg.get("umano_pm", true)
		s["g"][0]["ruolo"] = "pm" if u_pm else "opp"
		s["g"][1]["ruolo"] = "opp" if u_pm else "pm"
	for i in s["g"].size():
		var p: Dictionary = s["g"][i]
		p["st"] = Dati.PLANCE[plancia(i)]["start"]
		if cfg["modo"] != "multi" and p["ruolo"] == "opp":
			p["pv"] = 5
	s["gov"] = s["g"][pm()]["par"]
	if cfg["modo"] == "multi" and s["g"].size() == 3:
		# in tre il liberale è solo: due Sostenitori gratis
		for k in 2:
			_pesca_sost(pm())
	_log("Comincia la partita: %s è Primo Ministro, %s guida l'Opposizione." % [nome(pm()), nome(opp())])

## Ruoli iniziali del gioco a più giocatori: governo liberale, PM il liberale con il numero più basso.
func _ruoli_multi() -> void:
	var lib := []
	var con := []
	for i in s["g"].size():
		if s["g"][i]["par"] == "L":
			lib.append(i)
		else:
			con.append(i)
	lib.sort_custom(func(a, b): return Dati.politico(s["g"][a]["pol"])["n"] < Dati.politico(s["g"][b]["pol"])["n"])
	con.sort_custom(func(a, b): return Dati.politico(s["g"][a]["pol"])["n"] < Dati.politico(s["g"][b]["pol"])["n"])
	for k in lib.size():
		s["g"][lib[k]]["ruolo"] = "pm" if k == 0 else "bbg"
	for k in con.size():
		s["g"][con[k]]["ruolo"] = "opp" if k == 0 else "bbo"

# ------------------------------------------------------------------ utilità

func _rnd(n: int) -> int:
	s["r"] = (int(s["r"]) * 1103515245 + 12345) & 0x7fffffff
	return (int(s["r"]) >> 8) % n

func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rnd(i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _serie(n: int) -> Array:
	var a := []
	for i in n:
		a.append(i + 1)
	return a

func _log(t: String, posto := -1) -> void:
	s["reg"].append({"t": t, "p": posto, "r": s["round"]})
	if s["reg"].size() > 400:
		s["reg"] = s["reg"].slice(s["reg"].size() - 300)

func nome(i: int) -> String:
	return str(s["g"][i]["nome"])

func _ruolo(r: String) -> int:
	for i in s["g"].size():
		if s["g"][i]["ruolo"] == r:
			return i
	return -1

func pm() -> int:
	return _ruolo("pm")

func opp() -> int:
	return _ruolo("opp")

func altro(par: String) -> String:
	return "L" if par == "C" else "C"

func umano(i: int) -> bool:
	return s["g"][i]["tipo"] == "u"

func multi() -> bool:
	return s["cfg"]["modo"] == "multi"

## Chiave della plancia usata da un posto (dipende dal ruolo e dal tipo di giocatore).
func plancia(i: int) -> String:
	var p: Dictionary = s["g"][i]
	if p["ruolo"] in ["bbg", "bbo"]:
		return "bb"
	if p["tipo"] == "cw":
		return "cw_" + str(p["ruolo"])
	var facile: bool = s["cfg"].get("facile", false) or (multi() and s["g"].size() == 3 and p["par"] == "L")
	return str(p["ruolo"]) + ("_facile" if facile else "")

func punti(par: String) -> int:
	var t := 0
	for k in Dati.SETTORI:
		t += int(Dati.TRACCE[k][par]["p"][s["pop"][par][k]])
	return t

func partigiani(par: String) -> int:
	var t := 0
	for k in Dati.SETTORI:
		t += int(Dati.TRACCE[k][par]["q"][s["pop"][par][k]])
	return t

func vantaggio(par: String) -> int:
	return punti(par) - punti(altro(par))

func seggi_previsti(par: String) -> int:
	var v := vantaggio(par)
	return Dati.seggi_in_testa(v) if v >= 0 else Dati.SEGGI - Dati.seggi_in_testa(-v)

## Sposta un partito di `d` gradini in un settore; restituisce i gradini davvero percorsi.
func _pop(par: String, sett: String, d: int) -> int:
	var tr: Array = Dati.TRACCE[sett][par]["p"]
	var da: int = s["pop"][par][sett]
	var a: int = clampi(da + d, 0, tr.size() - 1)
	s["pop"][par][sett] = a
	return a - da

func _pop_possibile(par: String, sett: String, d: int) -> bool:
	var tr: Array = Dati.TRACCE[sett][par]["p"]
	var da: int = s["pop"][par][sett]
	return clampi(da + d, 0, tr.size() - 1) != da

func _st(i: int, d: int) -> int:
	var pl: Dictionary = Dati.PLANCE[plancia(i)]
	var da: int = s["g"][i]["st"]
	s["g"][i]["st"] = clampi(da + d, pl["min"], pl["max"])
	return int(s["g"][i]["st"]) - da

func _fav(i: int, d: int) -> int:
	var da: int = s["g"][i]["fav"]
	s["g"][i]["fav"] = clampi(da + d, 0, Dati.FAVORE_MAX)
	return int(s["g"][i]["fav"]) - da

func voti(b: Dictionary) -> int:
	return int(s["mp"][Dati.ddl(b["id"])["tipo"]]) + int(b["ret"])

func _ret(b: Dictionary, d: int) -> int:
	var da: int = b["ret"]
	b["ret"] = clampi(da + d, Dati.RET_MIN, Dati.RET_MAX)
	return int(b["ret"]) - da

## Sposta deputati del Governo fra Moderati e Partigiani (d > 0: verso i Partigiani).
func _inf(d: int) -> int:
	var mp: Dictionary = s["mp"]
	var q: int = d
	if d > 0:
		q = mini(d, int(mp["M"]))
	else:
		q = -mini(-d, int(mp["P"]))
	mp["P"] = int(mp["P"]) + q
	mp["M"] = int(mp["M"]) - q
	return q

## I posti che dividono i PV con il posto `i` (lui compreso).
func cordata(i: int) -> Array:
	if not multi():
		return [i]
	var p: Dictionary = s["g"][i]
	if p["dim"]:
		return [i]
	var out := []
	for j in s["g"].size():
		var q: Dictionary = s["g"][j]
		if q["dim"]:
			continue
		var gov_i: bool = p["ruolo"] in ["pm", "bbg"]
		var gov_j: bool = q["ruolo"] in ["pm", "bbg"]
		if s["patto"] or gov_i == gov_j:
			out.append(j)
	return out

## Assegna PV al posto `i` e a tutta la sua cordata.
func _pv(i: int, n: int) -> void:
	if n == 0 or i < 0:
		return
	for j in cordata(i):
		s["g"][j]["pv"] = clampi(int(s["g"][j]["pv"]) + n, 0, Dati.PV_VITTORIA)
	_controlla_vittoria()

func _controlla_vittoria() -> void:
	if s["fine"] != null:
		return
	var p := pm()
	if int(s["g"][p]["pv"]) >= Dati.PV_VITTORIA:
		s["fine"] = {"vince": p, "motivo": "%s raggiunge 100 Punti Vittoria da Primo Ministro." % nome(p)}
		_log(s["fine"]["motivo"], p)
	elif s["cfg"]["modo"] == "cw1" and int(s["g"][0]["pv"]) >= Dati.PV_VITTORIA:
		s["fine"] = {"vince": 0, "motivo": "Hai raggiunto 100 Punti Vittoria."}

func _pesca(mazzo: String):
	var mz: Dictionary = s["mazzi"]
	if mz[mazzo].is_empty():
		if mz[mazzo + "_s"].is_empty():
			return null
		mz[mazzo] = mz[mazzo + "_s"]
		mz[mazzo + "_s"] = []
		_mescola(mz[mazzo])
	return mz[mazzo].pop_back()

func _pesca_sost(i: int) -> int:
	var c = _pesca("sost")
	if c == null:
		return 0
	s["g"][i]["sost"].append(c)
	return int(c)

func sostenitore(n: int) -> Dictionary:
	return DatiGen.SOSTENITORI[n - 1]

func _cubi_reddito(i: int) -> int:
	var pl: Dictionary = Dati.PLANCE[plancia(i)]
	var n := 0
	for t in pl["cubi"]:
		if int(s["g"][i]["st"]) > int(t):
			n += 1
	return n

func puo_sfidare(sf: int, dif: int) -> bool:
	var a: Dictionary = s["g"][sf]
	var b: Dictionary = s["g"][dif]
	return int(a["st"]) > int(b["st"]) or (int(a["st"]) == int(b["st"]) and int(a["fav"]) >= int(b["fav"]))

# ------------------------------------------------------------------ ciclo

func avanza() -> void:
	var guardia := 0
	while s["att"] == null and s["fine"] == null and guardia < 5000:
		guardia += 1
		_passo()

func _passo() -> void:
	match s["fase"]:
		"round": _fase_round()
		"selezione": _fase_selezione()
		"dopo_selezione": _fase_dopo_selezione()
		"azioni": _fase_azioni()
		"risolvi": _fase_risolvi()
		"dopo_risolvi": _fase_dopo_risolvi()
		"sfide": _fase_sfide()
		"elezioni": _fase_elezioni()
		"elezioni_fine": _elezioni_fine()

func _fase_round() -> void:
	s["round"] = int(s["round"]) + 1
	s["sfida_round"] = false
	s["sfide_fatte"] = []
	if int(s["round"]) > 1:
		if multi() and s["patto"]:
			_pv(pm(), 6)
		else:
			_pv(pm(), 4)
			_pv(opp(), 2)
		if s["fine"] != null:
			return
	for i in s["g"].size():
		s["g"][i]["cubi"] = _cubi_reddito(i)
		var pl := plancia(i)
		if pl == "opp_facile" and int(s["g"][i]["st"]) >= 11:
			_pesca_sost(i)
			_log("%s riceve un Sostenitore gratuito." % nome(i), i)
		if "dpl" in s["g"][i]["carr"]:
			_pesca_sost(i)
			_log("%s (Vice capo del partito) riceve un Sostenitore." % nome(i), i)
	_log("Round %d." % s["round"])
	s["fase"] = "selezione" if s["tav"].is_empty() else "azioni"
	s["sel"] = null
	s["turno"] = null

# ------------------------------------------------------------------ selezione dei disegni di legge

## Chi pesca e propone prima del PM, e quante carte: [posto, pescate, proposte].
func _proponenti() -> Array:
	var out := []
	if not multi():
		return out
	var bbg := _ruolo("bbg")
	var bbo := _ruolo("bbo")
	if bbg >= 0:
		out.append([bbg, 2, 1])
	out.append([opp(), 2 if bbo >= 0 else 4, 1 if bbo >= 0 else 2])
	if bbo >= 0:
		out.append([bbo, 2, 1])
	return out

func _fase_selezione() -> void:
	if s["sel"] == null:
		var prop := _proponenti()
		var n_pm := 6
		for q in prop:
			n_pm -= int(q[2])
		s["sel"] = {"prop": prop, "ip": 0, "mano": [], "riv": [], "da": {}, "scarti": [], "n_pm": n_pm, "pm_pesc": 0}
	var sel: Dictionary = s["sel"]
	# proposte degli altri giocatori
	while int(sel["ip"]) < sel["prop"].size():
		var q: Array = sel["prop"][sel["ip"]]
		var chi: int = q[0]
		if sel["mano"].size() < int(q[1]):
			if umano(chi) and _mazzi_ddl().size() > 1:
				s["att"] = {"tipo": "pesca", "posto": chi}
				return
			var c = _pesca(_ia_mazzo(chi))
			if c == null:
				c = _pesca("X")
			if c == null:
				q[1] = sel["mano"].size()
				continue
			sel["mano"].append(c)
			continue
		if umano(chi):
			s["att"] = {"tipo": "proponi", "posto": chi, "n": mini(int(q[2]), sel["mano"].size())}
			return
		_proposta(chi, _ia_proponi(chi, sel["mano"], int(q[2])))
	# pescate del PM
	var p := pm()
	while int(sel["pm_pesc"]) < int(sel["n_pm"]):
		if umano(p):
			if _mazzi_ddl().size() > 1:
				s["att"] = {"tipo": "pesca", "posto": p}
				return
			var c0 = _pesca(_mazzi_ddl()[0]) if not _mazzi_ddl().is_empty() else null
			if c0 == null:
				break
			sel["riv"].append(c0)
		else:
			var mazzo := _cw_mazzo(p)
			var c = _pesca(mazzo)
			if c == null:
				c = _pesca("X" if mazzo != "X" else str(s["gov"]))
			if c == null:
				break
			sel["riv"].append(c)
		sel["pm_pesc"] = int(sel["pm_pesc"]) + 1
	if sel["riv"].is_empty():
		_log("Non ci sono più disegni di legge da pescare.")
		s["fase"] = "elezioni"
		return
	if umano(p):
		s["att"] = {"tipo": "scegli", "posto": p, "n": mini(3, sel["riv"].size())}
		return
	_piazza(_cw_scegli(p, sel["riv"]))

## I mazzi da cui si può pescare adesso (trasversali e del partito di Governo), se non sono finiti.
func _mazzi_ddl() -> Array:
	var out := []
	for k in ["X", str(s["gov"])]:
		if not (s["mazzi"][k].is_empty() and s["mazzi"][k + "_s"].is_empty()):
			out.append(k)
	return out

func _proposta(chi: int, ids: Array) -> void:
	var sel: Dictionary = s["sel"]
	for c in sel["mano"]:
		if c in ids:
			sel["riv"].append(c)
			sel["da"][c] = chi
		else:
			sel["scarti"].append(c)
	sel["mano"] = []
	sel["ip"] = int(sel["ip"]) + 1
	_log("%s propone %d disegn%s di legge." % [nome(chi), ids.size(), "o" if ids.size() == 1 else "i"], chi)

func _piazza(ids: Array) -> void:
	var sel: Dictionary = s["sel"]
	var p := pm()
	var nomi := []
	for c in ids:
		var d: Dictionary = Dati.ddl(c)
		s["tav"].append({"id": c, "ret": int(d["ret"]), "dib": []})
		nomi.append(str(d["titolo"]))
		if d["mazzo"] != "X" and s["patto"]:
			_rompi_patto("%s presenta un disegno di legge di partito: il Patto è rotto." % nome(p))
	for c in ids:
		if sel["da"].has(c) and int(sel["da"][c]) != p:
			_pv(int(sel["da"][c]), 1)
			_log("%s riceve 1 PV: il suo disegno è stato scelto." % nome(int(sel["da"][c])), int(sel["da"][c]))
	for c in sel["riv"] + sel["scarti"]:
		if not (c in ids):
			s["mazzi"][str(Dati.ddl(c)["mazzo"]) + "_s"].append(c)
	_log("%s mette in discussione: %s." % [nome(p), ", ".join(nomi)], p)
	s["sel"] = null
	s["fase"] = "dopo_selezione"

func _fase_dopo_selezione() -> void:
	s["fase"] = "azioni"
	if multi() and not s["patto"] and s["patto_rotto"]:
		var tutti_x: bool = s["tav"].size() == 3
		for b in s["tav"]:
			if Dati.ddl(b["id"])["mazzo"] != "X":
				tutti_x = false
		if tutti_x:
			var o := opp()
			if umano(o):
				s["att"] = {"tipo": "patto_riparti", "posto": o}
			elif _ia_riparti_patto(o):
				_riparti_patto()

func _rompi_patto(testo: String) -> void:
	if not s["patto"]:
		return
	# i segnalini si separano: da qui ognuno ha il suo punteggio
	s["patto"] = false
	s["patto_rotto"] = true
	_log(testo)

func _riparti_patto() -> void:
	s["patto"] = true
	_log("%s ripristina il Patto: Governo e Opposizione tornano a dividere i PV." % nome(opp()), opp())

# ------------------------------------------------------------------ turni d'azione

func _ordine_turni() -> Array:
	var out := []
	for r in ["bbg", "opp", "bbo", "pm"]:
		var i := _ruolo(r)
		if i >= 0:
			out.append(i)
	return out

func _fase_azioni() -> void:
	if s["turno"] == null:
		s["turno"] = {"ord": _ordine_turni(), "i": 0, "ini": false, "ev": false}
	var t: Dictionary = s["turno"]
	if int(t["i"]) >= t["ord"].size():
		s["turno"] = null
		s["fase"] = "risolvi"
		return
	var chi: int = t["ord"][t["i"]]
	var p: Dictionary = s["g"][chi]
	if not t["ini"]:
		t["ini"] = true
		t["doppi"] = p["sost"].duplicate() if decano() == chi else []
		if p["ruolo"] == "opp" and multi() and s["patto"]:
			if umano(chi):
				s["att"] = {"tipo": "patto_rompi", "posto": chi}
				return
			if _ia_rompi_patto(chi):
				_rompi_patto("%s rompe il Patto." % nome(chi))
	if p["ruolo"] == "pm" and not t["ev"]:
		t["ev"] = true
		_evento(chi)
		if s["att"] != null or s["fine"] != null:
			return
	if umano(chi):
		s["att"] = {"tipo": "azione", "posto": chi}
		return
	if p["ruolo"] in ["pm", "opp"]:
		_cw_turno(chi)
	else:
		_ia_turno_bb(chi)
	_fine_turno(chi)

func _fine_turno(chi: int) -> void:
	var p: Dictionary = s["g"][chi]
	p["cubi"] = 0
	if p["ruolo"] in ["bbg", "bbo"]:
		if _st(chi, 1) != 0:
			_log("%s guadagna 1 Standing a fine turno." % nome(chi), chi)
		_attiva_carriere(chi)
	var t: Dictionary = s["turno"]
	t["i"] = int(t["i"]) + 1
	t["ini"] = false

# ---------- evento del PM

func _evento(chi: int) -> void:
	if umano(chi):
		var c = _pesca("ev")
		var ev: Dictionary = DatiGen.EVENTI[int(c) - 1]
		s["mazzi"]["ev_s"].append(c)
		if ev.has("supp"):
			_suppletiva(str(ev["supp"]))
			return
		s["att"] = {"tipo": "evento", "posto": chi, "n": int(c)}
	else:
		var c = _pesca("evc")
		var ev: Dictionary = DatiGen.EVENTI_CW[int(c) - 1]
		s["mazzi"]["evc_s"].append(c)
		if ev.has("supp"):
			_suppletiva(str(ev["supp"]))
			return
		_cw_evento(chi, ev)

func _suppletiva(tipo: String) -> void:
	var p := pm()
	var prev := Dati.arrotonda10(seggi_previsti(str(s["gov"])))
	if prev < int(s["mp"]["A"]):
		if tipo == "PM":
			_st(p, -1)
			_log("Elezione suppletiva persa (previsti %d seggi contro %d): %s perde 1 Standing, l'Opposizione fa 1 PV." % [prev, s["mp"]["A"], nome(p)], p)
		else:
			_st(opp(), 1)
			_log("Elezione suppletiva persa (previsti %d seggi contro %d): %s guadagna 1 Standing, l'Opposizione fa 1 PV." % [prev, s["mp"]["A"], nome(opp())], p)
		_pv(opp(), 1)
	else:
		_log("Elezione suppletiva vinta dal Governo (previsti %d seggi): nessun effetto." % prev, p)

## Applica gli effetti di un'opzione Evento o di un Sostenitore giocato dal posto `chi`.
## par: scelte del giocatore (par = partito colpito dal dito, b/v = disegno e verso del Dibattito,
## chi/v = bersaglio del Favore, inf = verso dell'Influenza). k: moltiplicatore (Decano = 2).
func _effetti(chi: int, eff: Array, par := {}, k := 1) -> void:
	var p: Dictionary = s["g"][chi]
	var mio := str(p["par"])
	for e in eff:
		var t := str(e)
		if t.begins_with("X"):
			_pop(mio, t.substr(2, 1), (1 if t[1] == "+" else -1) * k)
		elif t.begins_with("p-"):
			_pop(str(par.get("par", altro(mio))), t.substr(2, 1), -1 * k)
		elif t.begins_with("pFv") or t.begins_with("pS"):
			var bers: int = int(par.get("chi", _avversario(chi)))
			var v := 0
			if t.contains("~"):
				v = int(par.get("v", -1))
			else:
				v = int(t.substr(t.find("-")))
			if t.begins_with("pFv"):
				_fav(bers, v * k)
			else:
				_st(bers, v * k)
		elif t.begins_with("Fv"):
			_fav(chi, int(t.substr(2)) * k)
		elif t.begins_with("S"):
			_st(chi, int(t.substr(1)) * k)
		elif t.begins_with("D"):
			var b: Dictionary = s["tav"][int(par.get("b", 0))]
			var segno := 1 if int(par.get("v", 1)) > 0 else -1
			_ret(b, segno * int(t.substr(1)) * k)
		elif t.begins_with("INF"):
			var segno := 1 if int(par.get("inf", 1)) > 0 else -1
			_inf(segno * int(t.substr(3)) * k)

## Il capo dell'altro schieramento (bersaglio naturale degli effetti "a scelta").
func _avversario(chi: int) -> int:
	var r: String = s["g"][chi]["ruolo"]
	return opp() if r in ["pm", "bbg"] else pm()

func descrivi_effetti(eff: Array) -> String:
	if eff.is_empty():
		return "nessun effetto"
	var out := []
	for e in eff:
		var t := str(e)
		if t.begins_with("X"):
			out.append("%s in %s" % ["sali" if t[1] == "+" else "scendi", Dati.NOME_SETTORE[t.substr(2, 1)]])
		elif t.begins_with("p-"):
			out.append("un partito a scelta scende in %s" % Dati.NOME_SETTORE[t.substr(2, 1)])
		elif t.begins_with("pFv~"):
			out.append("Favore +1 o -1 a un giocatore a scelta")
		elif t.begins_with("pFv"):
			out.append("Favore %s a un giocatore a scelta" % t.substr(3))
		elif t.begins_with("pS"):
			out.append("Standing %s a un giocatore a scelta" % t.substr(2))
		elif t.begins_with("Fv"):
			out.append("Favore %s" % t.substr(2))
		elif t.begins_with("S"):
			out.append("Standing %s" % t.substr(1))
		elif t.begins_with("D"):
			out.append("Dibattito di %s voti (su o giù)" % t.substr(1))
		elif t.begins_with("INF"):
			out.append("Influenza su %s deputati" % t.substr(3))
	return ", ".join(out)

# ---------- azioni di un giocatore umano

## Il Decano della Camera: chi raddoppia i Sostenitori che aveva a inizio turno (PM a 90 PV o più).
func decano() -> int:
	if not multi() or int(s["g"][pm()]["pv"]) < 90:
		return -1
	var bbo := _ruolo("bbo")
	return bbo if bbo >= 0 else opp()

func _puo_attaccare(chi: int) -> bool:
	var p: Dictionary = s["g"][chi]
	if p["ruolo"] == "pm":
		return true
	if p["ruolo"] == "bbg":
		return p["dim"]
	return not s["patto"]

## Tutte le azioni lecite del posto `chi` nel suo turno d'azione.
func azioni_possibili(chi: int) -> Array:
	var out := []
	var p: Dictionary = s["g"][chi]
	var pol: Dictionary = Dati.politico(p["pol"])
	var cubi: int = p["cubi"]
	var capo: bool = p["ruolo"] in ["pm", "opp"]
	var attacca := _puo_attaccare(chi)
	if cubi >= 1:
		if capo and int(pol["camp"]) > 0:
			for k in pol["set"]:
				for n in range(1, int(pol["camp"]) + 1):
					out.append({"t": "camp", "s": k, "n": n})
		var liv_dib: int = int(pol["dib"]) if capo else 1
		if liv_dib > 0:
			for b in s["tav"].size():
				for n in range(1, liv_dib + 1):
					out.append({"t": "dib", "b": b, "v": 10 * n})
					if attacca:
						out.append({"t": "dib", "b": b, "v": -10 * n})
		if capo and int(pol["lus"]) >= 1:
			out.append({"t": "lus", "chi": chi, "v": 1})
			if int(pol["lus"]) >= 2:
				for j in s["g"].size():
					out.append({"t": "lus", "chi": j, "v": 2})
					out.append({"t": "lus", "chi": j, "v": -2})
		var liv_hob: int = int(pol["hob"]) if capo else 1
		if liv_hob >= 1:
			out.append({"t": "hob", "n": 1})
			if liv_hob >= 2:
				out.append({"t": "hob", "n": 2})
		var q := 0
		if p["ruolo"] == "pm":
			q = 10 * int(pol["inf"])
		elif p["ruolo"] == "opp" and int(pol["inf"]) >= 2 and attacca:
			q = 10
		for n in range(10, q + 1, 10):
			out.append({"t": "inf", "v": n})
			out.append({"t": "inf", "v": -n})
		out.append_array(_azioni_carriera(chi))
		out.append_array(_azioni_dibattito(chi))
	for c in p["sost"]:
		var card: Dictionary = sostenitore(int(c))
		for o in 2:
			out.append_array(_varianti_sost(chi, int(c), o, card["opz"][o]))
		out.append({"t": "scarta", "c": int(c)})
	if p["ruolo"] == "bbg" and not p["dim"] and int(p["pv"]) < 90 and cubi >= 1 and cubi == _cubi_turno(chi):
		out.append({"t": "dimetti"})
	if p["sost"].size() <= 4:
		out.append({"t": "fine"})
	return out

func _cubi_turno(chi: int) -> int:
	return _cubi_reddito(chi)

## Le varianti di gioco di un'opzione Sostenitore (una per ogni scelta possibile del giocatore).
func _varianti_sost(chi: int, c: int, o: int, eff: Array) -> Array:
	var base := {"t": "sost", "c": c, "o": o}
	var out := [base]
	var attacca := _puo_attaccare(chi)
	for e in eff:
		var t := str(e)
		var nuovo := []
		if t.begins_with("p-"):
			for par in ["C", "L"]:
				for x in out:
					var y: Dictionary = x.duplicate()
					y["par"] = par
					nuovo.append(y)
		elif t.begins_with("pFv") or t.begins_with("pS"):
			for j in s["g"].size():
				for v in ([1, -1] if t.contains("~") else [0]):
					for x in out:
						var y: Dictionary = x.duplicate()
						y["chi"] = j
						if v != 0:
							y["v"] = v
						nuovo.append(y)
		elif t.begins_with("D"):
			for b in s["tav"].size():
				for v in ([1, -1] if attacca else [1]):
					for x in out:
						var y: Dictionary = x.duplicate()
						y["b"] = b
						y["v"] = v
						nuovo.append(y)
		elif t.begins_with("INF"):
			if s["g"][chi]["ruolo"] == "pm" or attacca:
				for v in [1, -1]:
					for x in out:
						var y: Dictionary = x.duplicate()
						y["inf"] = v
						nuovo.append(y)
		else:
			continue
		out = nuovo
	return out

func opzioni() -> Array:
	var a = s["att"]
	if a == null:
		return []
	var chi: int = a["posto"]
	match a["tipo"]:
		"azione":
			return azioni_possibili(chi)
		"pesca":
			var out := []
			for k in _mazzi_ddl():
				out.append({"t": "pesca", "m": k})
			return out
		"evento":
			var ev: Dictionary = DatiGen.EVENTI[int(a["n"]) - 1]
			var out := []
			for o in ev["opz"].size():
				if int(ev["opz"][o]["costo"]) <= int(s["g"][chi]["cubi"]):
					out.append({"t": "ev", "o": o})
			return out
		"tieni":
			var out := []
			for c in a["carte"]:
				out.append({"t": "tieni", "c": c})
			return out
		"risolvi":
			var out := []
			for b in s["tav"].size():
				if voti(s["tav"][b]) >= 320:
					out.append({"t": "voto", "b": b})
				out.append({"t": "ritiro", "b": b})
				if multi():
					out.append({"t": "accordo", "b": b})
			return out
		"elezione":
			var out := [{"t": "elezione"}]
			if s["marc"] and int(s["g"][chi]["pv"]) < 85:
				out.append({"t": "rinvia"})
			return out
		"sostituisci", "sfida", "reale", "patto_rompi", "patto_riparti", "accordo", "rientro":
			return [{"t": a["tipo"], "si": true}, {"t": a["tipo"], "si": false}]
		"premio":
			var out := []
			for o in a["opz"]:
				out.append({"t": "premio", "o": o})
			return out
	return []

## Controlla che la risposta sia fra quelle lecite. Le scelte multiple (scegli, proponi) si controllano a parte.
func lecita(r: Dictionary) -> bool:
	var a = s["att"]
	if a == null:
		return false
	if a["tipo"] in ["scegli", "proponi"]:
		if r.get("t", "") != a["tipo"] or not (r.get("ids") is Array):
			return false
		var ids: Array = r["ids"]
		var fonte: Array = s["sel"]["riv"] if a["tipo"] == "scegli" else s["sel"]["mano"]
		if ids.size() != int(a["n"]):
			return false
		for i in ids.size():
			if not (ids[i] in fonte) or ids.find(ids[i]) != i:
				return false
		return true
	var js := JSON.stringify(_norm(r))
	for o in opzioni():
		if JSON.stringify(_norm(o)) == js:
			return true
	return false

## Chiavi ordinate e numeri interi: così il confronto non dipende da come è arrivata la risposta (rete, file).
static func _norm(d: Dictionary) -> Dictionary:
	var k := d.keys()
	k.sort()
	var out := {}
	for x in k:
		var v = d[x]
		if v is float and v == floor(v):
			v = int(v)
		elif v is Array:
			var a := []
			for y in v:
				a.append(str(y))
			v = a
		out[x] = v
	return out

func rispondi(r: Dictionary) -> bool:
	r = _norm(r)
	if not lecita(r):
		return false
	var a: Dictionary = s["att"]
	var chi: int = a["posto"]
	s["att"] = null
	s["n_dec"] = int(s["n_dec"]) + 1
	match a["tipo"]:
		"azione":
			_azione(chi, r)
		"pesca":
			var c = _pesca(str(r["m"]))
			if c != null:
				if chi == pm() and int(s["sel"]["ip"]) >= s["sel"]["prop"].size():
					s["sel"]["riv"].append(c)
					s["sel"]["pm_pesc"] = int(s["sel"]["pm_pesc"]) + 1
				else:
					s["sel"]["mano"].append(c)
		"proponi":
			_proposta(chi, r["ids"])
		"scegli":
			_piazza(r["ids"])
		"evento":
			var ev: Dictionary = DatiGen.EVENTI[int(a["n"]) - 1]
			var o: Dictionary = ev["opz"][int(r["o"])]
			s["g"][chi]["cubi"] = int(s["g"][chi]["cubi"]) - int(o["costo"])
			_effetti(chi, o["eff"])
			_log("Evento «%s»: %s sceglie «%s» (%s)." % [titolo_evento(int(a["n"])), nome(chi), opzione_evento(int(a["n"]), int(r["o"])), descrivi_effetti(o["eff"])], chi)
		"tieni":
			for c in a["carte"]:
				if int(c) == int(r["c"]):
					s["g"][chi]["sost"].append(int(c))
				else:
					s["mazzi"]["sost_s"].append(int(c))
		"risolvi":
			_risolvi(chi, str(r["t"]), int(r["b"]))
		"elezione":
			if r["t"] == "rinvia":
				s["marc"] = false
				_log("%s rinvia le elezioni." % nome(chi), chi)
				s["fase"] = "round"
			else:
				_vota_elezione()
		"sostituisci":
			if r["si"]:
				_sostituisci_pm()
			s["sost_chiesto"] = true
		"sfida":
			s["sfide_fatte"].append(chi)
			if r["si"]:
				_sfida(chi, int(a["contro"]))
		"reale":
			_elezione_esito(int(a["u"]), int(a["seggi"]), r["si"])
		"patto_rompi":
			if r["si"]:
				_rompi_patto("%s rompe il Patto." % nome(chi))
		"patto_riparti":
			if r["si"]:
				_riparti_patto()
		"accordo":
			_accordo_risposta(int(a["b"]), r["si"])
		"rientro":
			if r["si"]:
				_rientra(int(a["bb"]))
		"premio":
			_premio(chi, str(r["o"]))
	_controlla_vittoria()
	return true

func titolo_evento(n: int) -> String:
	return Testi.evento(n)

func opzione_evento(n: int, o: int) -> String:
	return Testi.evento_opz(n, o)

func _azione(chi: int, r: Dictionary) -> void:
	var p: Dictionary = s["g"][chi]
	var pol: Dictionary = Dati.politico(p["pol"])
	match str(r["t"]):
		"camp":
			p["cubi"] = int(p["cubi"]) - 1
			var q := _pop(str(p["par"]), str(r["s"]), int(r["n"]))
			_log("%s fa Campagna in %s (%d gradin%s)." % [nome(chi), Dati.NOME_SETTORE[r["s"]], q, "o" if q == 1 else "i"], chi)
		"dib":
			p["cubi"] = int(p["cubi"]) - 1
			var b: Dictionary = s["tav"][int(r["b"])]
			_ret(b, int(r["v"]))
			_log("%s Dibatte %s: %+d voti (ora %d)." % [nome(chi), Testi.ddl(b["id"]), int(r["v"]), voti(b)], chi)
		"lus":
			p["cubi"] = int(p["cubi"]) - 1
			_fav(int(r["chi"]), int(r["v"]))
			if int(r["chi"]) == chi:
				_log("%s Lusinga Sua Maestà: Favore %+d." % [nome(chi), int(r["v"])], chi)
			else:
				_log("%s Lusinga Sua Maestà: Favore di %s %+d." % [nome(chi), nome(int(r["chi"])), int(r["v"])], chi)
		"hob":
			p["cubi"] = int(p["cubi"]) - 1
			if int(r["n"]) == 1:
				_pesca_sost(chi)
				_log("%s Frequenta i salotti e pesca un Sostenitore." % nome(chi), chi)
			else:
				var c1 = _pesca("sost")
				var c2 = _pesca("sost")
				_log("%s Frequenta i salotti: pesca due Sostenitori e ne tiene uno." % nome(chi), chi)
				if c1 != null and c2 != null:
					s["att"] = {"tipo": "tieni", "posto": chi, "carte": [c1, c2]}
				elif c1 != null:
					p["sost"].append(c1)
		"inf":
			p["cubi"] = int(p["cubi"]) - 1
			var q := _inf(int(r["v"]))
			_log("%s Influenza i deputati: %d passano ai %s." % [nome(chi), absi(q), "Partigiani" if q > 0 else "Moderati"], chi)
		"sost":
			var card: Dictionary = sostenitore(int(r["c"]))
			var k := 2 if int(r["c"]) in s["turno"].get("doppi", []) else 1
			_effetti(chi, card["opz"][int(r["o"])], r, k)
			p["sost"].erase(int(r["c"]))
			s["mazzi"]["sost_s"].append(int(r["c"]))
			_log("%s gioca il Sostenitore %s%s: %s." % [nome(chi), card["nome"], " (raddoppiato dal Decano)" if k == 2 else "", _descrivi_sost(chi, card["opz"][int(r["o"])], r)], chi)
		"scarta":
			p["sost"].erase(int(r["c"]))
			s["mazzi"]["sost_s"].append(int(r["c"]))
			_log("%s scarta un Sostenitore." % nome(chi), chi)
		"carr":
			_carriera(chi, r)
		"cdib":
			_gioca_dibattito(chi, r)
		"dimetti":
			_dimetti(chi)
		"fine":
			_fine_turno(chi)

func _descrivi_sost(chi: int, eff: Array, r: Dictionary) -> String:
	var out := []
	var mio := str(s["g"][chi]["par"])
	for e in eff:
		var t := str(e)
		if t.begins_with("X"):
			out.append("%s %s in %s" % [Testi.partito(mio), "sale" if t[1] == "+" else "scende", Dati.NOME_SETTORE[t.substr(2, 1)]])
		elif t.begins_with("p-"):
			out.append("%s scende in %s" % [Testi.partito(str(r.get("par", altro(mio)))), Dati.NOME_SETTORE[t.substr(2, 1)]])
		elif t.begins_with("pFv") or t.begins_with("pS"):
			var v: int = int(r.get("v", 0)) if t.contains("~") else int(t.substr(t.find("-")))
			out.append("%s di %s %+d" % ["Favore" if t.begins_with("pFv") else "Standing", nome(int(r.get("chi", 0))), v])
		elif t.begins_with("Fv"):
			out.append("Favore %s" % t.substr(2))
		elif t.begins_with("S"):
			out.append("Standing %s" % t.substr(1))
		elif t.begins_with("D"):
			out.append("%s %s%s voti" % [Testi.ddl(s["tav"][int(r.get("b", 0))]["id"]), "+" if int(r.get("v", 1)) > 0 else "-", t.substr(1)])
		elif t.begins_with("INF"):
			out.append("%s deputati ai %s" % [t.substr(3), "Partigiani" if int(r.get("inf", 1)) > 0 else "Moderati"])
	return ", ".join(out)

# ------------------------------------------------------------------ risoluzione di un disegno di legge

func _fase_risolvi() -> void:
	var p := pm()
	if s["tav"].is_empty():
		s["fase"] = "sfide"
		return
	if umano(p):
		s["att"] = {"tipo": "risolvi", "posto": p}
		return
	var d := _cw_risolvi(p)
	_risolvi(p, str(d["t"]), int(d["b"]))

func _risolvi(chi: int, modo: String, ib: int) -> void:
	s["fase"] = "dopo_risolvi"
	var b: Dictionary = s["tav"][ib]
	var d: Dictionary = Dati.ddl(b["id"])
	if modo == "accordo":
		var o := opp()
		if umano(o):
			s["att"] = {"tipo": "accordo", "posto": o, "b": ib}
			s["fase"] = "risolvi"
		else:
			_accordo_risposta(ib, _ia_accordo(o, ib))
		return
	if modo == "ritiro":
		_log("%s ritira %s." % [nome(chi), Testi.ddl(b["id"])], chi)
		_bocciato(ib, true)
		return
	var v := voti(b)
	var testo := "%s mette ai voti %s: %d voti previsti" % [nome(chi), Testi.ddl(b["id"]), v]
	if v >= 320 and v <= 340:
		var u: Dictionary = DatiGen.INCERTEZZA[_rnd(DatiGen.INCERTEZZA.size())]
		v += int(u["voti"])
		testo += ", Incertezza %+d: %d" % [int(u["voti"]), v]
	if v >= 330:
		_log(testo + ". Approvato!", chi)
		_approvato(ib)
	else:
		_log(testo + ". Bocciato.", chi)
		_bocciato(ib, false)

func _accordo_risposta(ib: int, si: bool) -> void:
	var b: Dictionary = s["tav"][ib]
	if si:
		_log("%s accetta l'accordo su %s: il disegno passa e l'Opposizione fa 5 PV." % [nome(opp()), Testi.ddl(b["id"])], opp())
		s["fase"] = "dopo_risolvi"
		_pv(opp(), 5)
		if s["fine"] == null:
			_approvato(ib)
	else:
		_log("%s rifiuta l'accordo su %s." % [nome(opp()), Testi.ddl(b["id"])], opp())
		s["accordo_no"] = true
		s["fase"] = "risolvi"

func _approvato(ib: int) -> void:
	var b: Dictionary = s["tav"][ib]
	var d: Dictionary = Dati.ddl(b["id"])
	var p := pm()
	s["tav"].remove_at(ib)
	s["approvati"] = s.get("approvati", []) + [b["id"]]
	var sup := 0
	for e in d["eff"]:
		var t := str(e)
		if t.begins_with("PMSUP"):
			sup = int(t.substr(5))
		elif t.begins_with("PMF"):
			_fav(p, int(t.substr(3)))
		elif t.begins_with("PMS"):
			_st(p, int(t.substr(3)))
		else:
			var par := str(s["gov"]) if t[0] == "X" else t.substr(0, 1)
			_pop(par, t.substr(2, 1), 1 if t[1] == "+" else -1)
	if d["mazzo"] == "X":
		_pv(p, int(d["pv"]))
		if not (opp() in cordata(p)):
			_pv(opp(), int(d["pv"]))
	else:
		_pv(p, int(d["pv"]))
	_premi_dibattito(b, true)
	if sup > 0 and s["fine"] == null:
		if umano(p):
			if sup == 1:
				_pesca_sost(p)
			else:
				var c1 = _pesca("sost")
				var c2 = _pesca("sost")
				if c1 != null and c2 != null:
					s["coda_att"] = s.get("coda_att", []) + [{"tipo": "tieni", "posto": p, "carte": [c1, c2]}]
				elif c1 != null:
					s["g"][p]["sost"].append(c1)
		else:
			var c = _pesca("scw")
			if c != null:
				s["g"][p]["da_giocare"].append({"n": int(c), "liv": sup})
				_log("%s riceve un Sostenitore Clockwork coperto." % nome(p), p)

func _bocciato(ib: int, ritirato: bool) -> void:
	var b: Dictionary = s["tav"][ib]
	var d: Dictionary = Dati.ddl(b["id"])
	var p := pm()
	var o := opp()
	s["tav"].remove_at(ib)
	s["mazzi"][str(d["mazzo"]) + "_s"].append(b["id"])
	_st(p, -1 if ritirato else -2)
	_st(o, 1 if ritirato else 2)
	if not (multi() and s["patto"]):
		_pv(o, 2 if ritirato else 3)
	_premi_dibattito(b, false)

func _fase_dopo_risolvi() -> void:
	var coda: Array = s.get("coda_att", [])
	if not coda.is_empty():
		s["att"] = coda.pop_front()
		s["coda_att"] = coda
		return
	s["accordo_no"] = false
	s["fase"] = "sfide"

# ------------------------------------------------------------------ sfide

func _fase_sfide() -> void:
	var p := pm()
	var o := opp()
	# Sistema I: il giocatore può sostituire il suo PM con la riserva, una volta per partita
	if s["cfg"]["modo"] == "cw1" and not s["sost_pm"] and not s.get("sost_chiesto", false) and s["cfg"].get("riserva", "") != "":
		if puo_sfidare(o, p) or int(s["g"][p]["st"]) <= 8:
			s["att"] = {"tipo": "sostituisci", "posto": p}
			return
	s["sost_chiesto"] = false
	# ordine: Backbencher di Governo contro il PM, Backbencher d'Opposizione contro il suo capo, capo contro PM
	for coppia in [["bbg", "pm"], ["bbo", "opp"], ["opp", "pm"]]:
		var a := _ruolo(coppia[0])
		var b := _ruolo(coppia[1])
		if a < 0 or b < 0 or a in s["sfide_fatte"]:
			continue
		if not puo_sfidare(a, b):
			continue
		if umano(a):
			s["att"] = {"tipo": "sfida", "posto": a, "contro": b}
			return
		s["sfide_fatte"].append(a)
		if _ia_sfida(a, b):
			_sfida(a, b)
			if s["fine"] != null:
				return
			if s["fase"] != "sfide":
				return
	s["fase"] = "elezioni"

func _sostituisci_pm() -> void:
	var p := pm()
	var g: Dictionary = s["g"][p]
	var nuovo: Dictionary = Dati.politico(str(s["cfg"]["riserva"]))
	_log("%s lascia: %s diventa Primo Ministro (6 PV di penalità)." % [nome(p), nuovo["corto"]], p)
	g["pol"] = nuovo["id"]
	g["nome"] = nuovo["corto"]
	g["st"] = 11
	s["sost_pm"] = true
	_togli_ddl()
	g["pv"] = maxi(0, int(g["pv"]) - 6)

func _togli_ddl() -> void:
	for b in s["tav"]:
		s["mazzi"][str(Dati.ddl(b["id"])["mazzo"]) + "_s"].append(b["id"])
		for c in b["dib"]:
			s["g"][int(c)]["dib"] = -1
	s["tav"] = []

func _sfida(sf: int, dif: int) -> void:
	var a: Dictionary = s["g"][sf]
	var b: Dictionary = s["g"][dif]
	_log("%s sfida %s (Standing %d contro %d, Favore %d contro %d) e ne prende il posto." % [nome(sf), nome(dif), a["st"], b["st"], a["fav"], b["fav"]], sf)
	if a["ruolo"] == "opp":
		# cambia il partito al Governo
		if s["cfg"]["modo"] == "cw1":
			s["fine"] = {"vince": 1, "motivo": "%s ti ha sfidato e ha preso il Governo: hai perso." % nome(sf)}
			return
		_cambio_governo()
		_togli_ddl()
		s["marc"] = false
		s["sfida_round"] = true
		s["perdente_sfida"] = dif
		s["fase"] = "elezioni"
		_controlla_vittoria()
		return
	# sfida interna al partito: i due si scambiano le plance
	var ruolo_a: String = a["ruolo"]
	var era_dimesso: bool = a["dim"]
	var st_a: int = a["st"]
	a["ruolo"] = b["ruolo"]
	b["ruolo"] = ruolo_a
	a["dim"] = false
	b["dim"] = false
	a["st"] = maxi(int(Dati.PLANCE[plancia(sf)]["start"]), st_a)
	a["st"] = mini(int(a["st"]), int(Dati.PLANCE[plancia(sf)]["max"]))
	b["st"] = Dati.PLANCE[plancia(dif)]["start"]
	a["carr"] = []
	b["carr"] = []
	if a["dib"] >= 0:
		_ritira_carta_dibattito(sf)
	if a["ruolo"] == "pm":
		if era_dimesso:
			a["pv"] = clampi(int(a["pv"]) + 6, 0, 100)
		else:
			_pv(sf, 6)
		_togli_ddl()
	_controlla_vittoria()

func _cambio_governo() -> void:
	var p := pm()
	var o := opp()
	var bbg := _ruolo("bbg")
	var bbo := _ruolo("bbo")
	s["g"][p]["ruolo"] = "opp"
	s["g"][o]["ruolo"] = "pm"
	s["g"][p]["st"] = Dati.PLANCE[plancia(p)]["start"]
	s["g"][o]["st"] = Dati.PLANCE[plancia(o)]["start"]
	if bbg >= 0:
		s["g"][bbg]["ruolo"] = "bbo"
		s["g"][bbg]["dim"] = false
		s["g"][bbg]["carr"] = []
		_attiva_carriere(bbg)
	if bbo >= 0:
		s["g"][bbo]["ruolo"] = "bbg"
		s["g"][bbo]["carr"] = []
		_attiva_carriere(bbo)
	s["gov"] = s["g"][o]["par"]
	_pv(o, 6)
	_log("Cambio di Governo: %s è il nuovo Primo Ministro (6 PV), %s passa all'Opposizione." % [nome(o), nome(p)], o)

# ------------------------------------------------------------------ elezioni

func _fase_elezioni() -> void:
	if not s["tav"].is_empty():
		s["fase"] = "round"
		return
	var p := pm()
	if s["sfida_round"]:
		_vota_elezione()
		return
	if umano(p):
		if s["marc"] and int(s["g"][p]["pv"]) < 85:
			s["att"] = {"tipo": "elezione", "posto": p}
		else:
			_vota_elezione()
		return
	# PM automatico: vota se è dato vincente e guadagnerebbe seggi, altrimenti rinvia finché può
	var prev := seggi_previsti(str(s["gov"]))
	var conviene := prev >= 330 and Dati.arrotonda10(prev) > int(s["mp"]["A"])
	if s["marc"] and int(s["g"][p]["pv"]) < 85 and not conviene:
		s["marc"] = false
		_log("%s rinvia le elezioni." % nome(p), p)
		s["fase"] = "round"
	else:
		_vota_elezione()

func _vota_elezione() -> void:
	var iu := _rnd(DatiGen.INCERTEZZA.size())
	var u: Dictionary = DatiGen.INCERTEZZA[iu]
	var gov := str(s["gov"])
	var seggi := clampi(seggi_previsti(gov) + int(u["seggi"]), 0, Dati.SEGGI)
	_log("ELEZIONI. Previsione %d seggi per il Governo, Incertezza %+d: %d seggi al Governo, %d all'Opposizione." % [seggi_previsti(gov), int(u["seggi"]), seggi, Dati.SEGGI - seggi])
	var p := pm()
	var o := opp()
	if not s["sfida_round"] and int(u["reale"]) > 0:
		# Interferenza Reale: il favorito di Sua Maestà può formare un governo di minoranza
		var vince_gov := _vince_governo(seggi)
		var fav_p: int = s["g"][p]["fav"]
		var fav_o: int = s["g"][o]["fav"]
		var cand := -1
		if not vince_gov and fav_p > fav_o and seggi >= int(u["reale"]):
			cand = p
		elif vince_gov and fav_o > fav_p and Dati.SEGGI - seggi >= int(u["reale"]):
			cand = o
		if cand >= 0:
			if umano(cand):
				s["att"] = {"tipo": "reale", "posto": cand, "u": iu, "seggi": seggi}
				return
			_elezione_esito(iu, seggi, true)
			return
	_elezione_esito(iu, seggi, false)

func _vince_governo(seggi: int) -> bool:
	if seggi >= 330:
		return true
	if Dati.SEGGI - seggi >= 330:
		return false
	return int(s["g"][pm()]["fav"]) > int(s["g"][opp()]["fav"])

func _elezione_esito(_iu: int, seggi: int, interferenza: bool) -> void:
	var gov := str(s["gov"])
	var resta := true
	if not s["sfida_round"]:
		resta = _vince_governo(seggi)
		if interferenza:
			resta = not resta
			_log("Interferenza Reale: Sua Maestà affida il Governo al suo favorito, %s." % nome(pm() if resta else opp()))
	var dopo := {gov: Dati.arrotonda10(seggi), altro(gov): Dati.arrotonda10(Dati.SEGGI - seggi)}
	var prima: Dictionary = s["seggi_prima"]
	for par in ["L", "C"]:
		var diff: int = int(dopo[par]) - int(prima[par])
		if diff > 0:
			var capo := pm() if par == gov else opp()
			var n := 2 + diff / 10
			_log("%s guadagnano %d seggi: %d PV a %s." % [Testi.partito_pl(par), diff, n, nome(capo)], capo)
			_pv(capo, n)
			if s["fine"] != null:
				return
	if not resta:
		if s["cfg"]["modo"] == "cw1":
			s["fine"] = {"vince": 1, "motivo": "Hai perso le elezioni: il Governo passa all'Opposizione."}
			_log(s["fine"]["motivo"])
			return
		_cambio_governo()
		gov = str(s["gov"])
	else:
		_log("%s resta Primo Ministro." % nome(pm()), pm())
	var a: int = dopo[gov]
	var q: int = mini(partigiani(gov), a)
	s["mp"] = {"A": a, "P": q, "M": a - q}
	s["seggi_prima"] = {gov: a, altro(gov): Dati.arrotonda10(Dati.SEGGI - a)}
	s["marc"] = true
	s["sfida_round"] = false
	_log("Nuovo Parlamento: %d deputati di Governo (%d Moderati, %d Partigiani)." % [a, a - q, q])
	s["fase"] = "round"
	_controlla_vittoria()

func _elezioni_fine() -> void:
	s["fase"] = "round"

# ------------------------------------------------------------------ Backbencher: carriere, carte Dibattito, dimissioni

const CARRIERE := {
	"cw": {"nome": "Capogruppo", "abil": "inf", "gov": [3, 3], "opp": [2, 3]},
	"cc": {"nome": "Responsabile della campagna", "abil": "camp", "gov": [3, 5], "opp": [2, 5]},
	"pc": {"nome": "Consigliere privato", "abil": "lus", "gov": [0, 1], "opp": [0, 1]},
	"dpl": {"nome": "Vice", "abil": "", "gov": [5, 8], "opp": [4, 8]},
}

## Attiva le carte Carriera di cui il Backbencher ha i requisiti (valutati solo all'attivazione).
func _attiva_carriere(i: int) -> void:
	var p: Dictionary = s["g"][i]
	if not (p["ruolo"] in ["bbg", "bbo"]) or p["dim"]:
		return
	var pol: Dictionary = Dati.politico(p["pol"])
	var lato := "gov" if p["ruolo"] == "bbg" else "opp"
	for k in CARRIERE:
		if k in p["carr"]:
			continue
		var c: Dictionary = CARRIERE[k]
		if c["abil"] != "" and int(pol[c["abil"]]) == 0:
			continue
		var ok: bool = int(p["fav"]) >= int(c[lato][0])
		if k == "dpl":
			ok = ok and int(p["st"]) == 8
		else:
			ok = ok and int(p["st"]) >= int(c[lato][1])
		if ok:
			p["carr"].append(k)
			_log("%s ottiene l'incarico: %s." % [nome(i), Testi.carriera(k, lato)], i)

func _azioni_carriera(chi: int) -> Array:
	var out := []
	var p: Dictionary = s["g"][chi]
	if p["dim"] or not (p["ruolo"] in ["bbg", "bbo"]):
		return out
	var pol: Dictionary = Dati.politico(p["pol"])
	var cubi: int = p["cubi"]
	var gov: bool = p["ruolo"] == "bbg"
	if "cw" in p["carr"]:
		if gov:
			out.append({"t": "carr", "c": "cw", "v": 10})
			out.append({"t": "carr", "c": "cw", "v": -10})
		elif cubi >= 2 and not s["patto"]:
			for b in s["tav"].size():
				out.append({"t": "carr", "c": "cw", "b": b})
	if "cc" in p["carr"]:
		for k in Dati.SETTORI:
			if k in pol["set"]:
				out.append({"t": "carr", "c": "cc", "s": k})
			elif cubi >= 2:
				out.append({"t": "carr", "c": "cc", "s": k})
	if "pc" in p["carr"]:
		out.append({"t": "carr", "c": "pc", "chi": chi})
		if cubi >= 2:
			for a in s["g"].size():
				for b in s["g"].size():
					if a != b:
						out.append({"t": "carr", "c": "pc", "su": a, "giu": b})
	return out

func _carriera(chi: int, r: Dictionary) -> void:
	var p: Dictionary = s["g"][chi]
	var pol: Dictionary = Dati.politico(p["pol"])
	match str(r["c"]):
		"cw":
			if r.has("v"):
				p["cubi"] = int(p["cubi"]) - 1
				var q := _inf(int(r["v"]))
				_log("%s (Capogruppo) Influenza %d deputati verso i %s." % [nome(chi), absi(q), "Partigiani" if q > 0 else "Moderati"], chi)
			else:
				p["cubi"] = int(p["cubi"]) - 2
				var b: Dictionary = s["tav"][int(r["b"])]
				_ret(b, -30)
				_log("%s (Capogruppo) coordina il Dibattito contro %s: -30 voti (ora %d)." % [nome(chi), Testi.ddl(b["id"]), voti(b)], chi)
		"cc":
			p["cubi"] = int(p["cubi"]) - (1 if str(r["s"]) in pol["set"] else 2)
			_pop(str(p["par"]), str(r["s"]), 1)
			_log("%s (Responsabile della campagna) fa Campagna in %s." % [nome(chi), Dati.NOME_SETTORE[r["s"]]], chi)
		"pc":
			if r.has("chi"):
				p["cubi"] = int(p["cubi"]) - 1
				_fav(chi, 1)
				_log("%s (Consigliere privato) Lusinga Sua Maestà: Favore +1." % nome(chi), chi)
			else:
				p["cubi"] = int(p["cubi"]) - 2
				_fav(int(r["su"]), 1)
				_fav(int(r["giu"]), -1)
				_log("%s (Consigliere privato): Favore +1 a %s e -1 a %s." % [nome(chi), nome(int(r["su"])), nome(int(r["giu"]))], chi)

## Carta Dibattito del Backbencher: scommette la sua reputazione su un disegno di legge.
func _azioni_dibattito(chi: int) -> Array:
	var out := []
	var p: Dictionary = s["g"][chi]
	if not (p["ruolo"] in ["bbg", "bbo"]) or int(p["dib"]) >= 0:
		return out
	var costo := 1 if int(p["st"]) <= 2 else 2
	if int(p["cubi"]) < costo:
		return out
	var su: bool = p["ruolo"] == "bbg" or s["patto"]
	for b in s["tav"].size():
		var v := voti(s["tav"][b])
		if su and v <= (340 if s["patto"] else 350):
			out.append({"t": "cdib", "b": b})
		elif not su and v >= 290:
			out.append({"t": "cdib", "b": b})
	return out

func _gioca_dibattito(chi: int, r: Dictionary) -> void:
	var p: Dictionary = s["g"][chi]
	var su: bool = p["ruolo"] == "bbg" or s["patto"]
	p["cubi"] = int(p["cubi"]) - (1 if int(p["st"]) <= 2 else 2)
	var b: Dictionary = s["tav"][int(r["b"])]
	_ret(b, 10 if su else -10)
	b["dib"].append(chi)
	p["dib"] = 1 if s["patto"] else 0
	_log("%s gioca la carta Dibattito su %s: %s voti (ora %d)." % [nome(chi), Testi.ddl(b["id"]), "+10" if su else "-10", voti(b)], chi)

func _ritira_carta_dibattito(chi: int) -> void:
	for b in s["tav"]:
		b["dib"].erase(chi)
	s["g"][chi]["dib"] = -1

## Premi e penalità delle carte Dibattito quando il disegno è risolto.
func _premi_dibattito(b: Dictionary, passato: bool) -> void:
	for c in b["dib"]:
		var chi := int(c)
		var p: Dictionary = s["g"][chi]
		var patto: bool = int(p["dib"]) == 1
		p["dib"] = -1
		if not (p["ruolo"] in ["bbg", "bbo"]):
			continue
		var gov: bool = p["ruolo"] == "bbg"
		var opz := []
		if gov or patto:
			opz = ["st+1", "fav+1"] if passato else ["st-1", "fav-1"]
			if gov and not patto and passato:
				opz.append("pv2")
		else:
			if passato:
				continue
			opz = ["st+1", "fav+1", "pv2"]
		if umano(chi):
			s["coda_att"] = s.get("coda_att", []) + [{"tipo": "premio", "posto": chi, "opz": opz}]
		else:
			_premio(chi, _ia_premio(chi, opz))

func _premio(chi: int, o: String) -> void:
	match o:
		"st+1": _st(chi, 1)
		"st-1": _st(chi, -1)
		"fav+1": _fav(chi, 1)
		"fav-1": _fav(chi, -1)
		"pv2": _pv(chi, 2)
	_log("Carta Dibattito di %s: %s." % [nome(chi), Testi.premio(o)], chi)

func _dimetti(chi: int) -> void:
	var p: Dictionary = s["g"][chi]
	p["cubi"] = 0
	p["dim"] = true
	p["carr"] = []
	_st(pm(), -2)
	_log("%s si DIMETTE dagli incarichi di Governo: %s perde 2 Standing." % [nome(chi), nome(pm())], chi)
	_fine_turno(chi)

func _rientra(bb: int) -> void:
	s["g"][bb]["dim"] = false
	_st(pm(), 2)
	_log("%s rientra nel Governo: %s recupera 2 Standing." % [nome(bb), nome(pm())], bb)

# ------------------------------------------------------------------ Clockwork

func _cw(i: int) -> Dictionary:
	return Dati.CLOCKWORK[s["g"][i]["pol"]]

## Aggiustamenti di fine partita: per il Capo dell'Opposizione quando il PM ha 90 PV o più,
## per il PM quando l'Opposizione ne ha 85 o più.
func _cw_finale(i: int) -> bool:
	if s["g"][i]["ruolo"] == "opp":
		return int(s["g"][pm()]["pv"]) >= 90
	return int(s["g"][opp()]["pv"]) >= 85

## Valore di un disegno di legge secondo gli Spareggi (C.3.3): più alto = più prezioso per il PM.
func valore_ddl(id: String) -> Array:
	var d: Dictionary = Dati.ddl(id)
	var p := pm()
	var gov := str(s["gov"])
	var st := 0
	var fav := 0
	var sup := 0
	var pop := 0
	var sim: Dictionary = s["pop"][gov].duplicate()
	for e in d["eff"]:
		var t := str(e)
		if t.begins_with("PMSUP"):
			sup = int(t.substr(5))
		elif t.begins_with("PMF"):
			if int(t.substr(3)) > 0 and int(s["g"][p]["fav"]) < Dati.FAVORE_MAX:
				fav = 1
		elif t.begins_with("PMS"):
			if int(s["g"][p]["st"]) < int(Dati.PLANCE[plancia(p)]["max"]):
				st = 1
		elif t[0] == "X" or t.substr(0, 1) == gov:
			var k := t.substr(2, 1)
			var tr: Array = Dati.TRACCE[k][gov]["p"]
			var a: int = clampi(int(sim[k]) + (1 if t[1] == "+" else -1), 0, tr.size() - 1)
			pop += int(tr[a]) - int(tr[sim[k]])
			sim[k] = a
	return [int(d["pv"]), st, pop, 1 if sup == 2 else 0, 1 if sup == 1 else 0, fav]

static func _cmp(a: Array, b: Array) -> int:
	for i in a.size():
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0

func _in_raggio(v: int, r: Array) -> bool:
	return v >= int(r[0]) and v <= int(r[1])

func _raggio(i: int, b: Dictionary) -> Array:
	var c := _cw(i)
	if s["g"][i]["ruolo"] == "opp":
		return c["att"]
	if c.has("difmp") and Dati.ddl(b["id"])["tipo"] != "A":
		return c["difmp"]
	return c["dif"]

## Il disegno su cui il Clockwork agisce: indice sul tavolo, -1 se nessuno è nel raggio.
## Opposizione: il più basso nel raggio (a parità il più prezioso). PM: il più alto nel raggio.
func _cw_bersaglio(i: int, solo_mp := false) -> int:
	var attacco: bool = s["g"][i]["ruolo"] == "opp"
	var migliore := -1
	var cand := []
	for b in s["tav"].size():
		var bd: Dictionary = s["tav"][b]
		if solo_mp and Dati.ddl(bd["id"])["tipo"] == "A":
			continue
		if _in_raggio(voti(bd), _raggio(i, bd)):
			cand.append(b)
	if cand.is_empty() and attacco and _cw_finale(i) and s["tav"].size() >= 2:
		# fine partita: accetta bersagli fuori raggio, il più vicino al raggio
		var dist := 99999
		for b in s["tav"].size():
			var bd: Dictionary = s["tav"][b]
			if solo_mp and Dati.ddl(bd["id"])["tipo"] == "A":
				continue
			var r := _raggio(i, bd)
			var v := voti(bd)
			var dd: int = int(r[0]) - v if v < int(r[0]) else v - int(r[1])
			if dd < dist:
				dist = dd
				cand = [b]
			elif dd == dist:
				cand.append(b)
	for b in cand:
		if migliore < 0:
			migliore = b
			continue
		var va := voti(s["tav"][b])
		var vm := voti(s["tav"][migliore])
		if (attacco and va < vm) or (not attacco and va > vm):
			migliore = b
		elif va == vm and _cmp(valore_ddl(s["tav"][b]["id"]), valore_ddl(s["tav"][migliore]["id"])) > 0:
			migliore = b
	return migliore

## Il disegno con la proiezione più alta (a parità il più prezioso).
func _piu_alto() -> int:
	var m := -1
	for b in s["tav"].size():
		if m < 0:
			m = b
			continue
		var va := voti(s["tav"][b])
		var vm := voti(s["tav"][m])
		if va > vm or (va == vm and _cmp(valore_ddl(s["tav"][b]["id"]), valore_ddl(s["tav"][m]["id"])) > 0):
			m = b
	return m

## Con un solo disegno rimasto il PM Clockwork non ci spende nulla se non può farlo passare in questo round.
func _cw_inutile_ultimo(i: int, b: int, aumento: int) -> bool:
	if s["g"][i]["ruolo"] != "pm" or s["tav"].size() != 1:
		return false
	var soglia := 340
	if _cw_finale(i) and _ritiro_porta_sfida():
		soglia = 320
	var manca := soglia - voti(s["tav"][b]) - aumento
	if manca <= 0:
		return false
	var c := _cw(i)
	var tipo: String = Dati.ddl(s["tav"][b]["id"])["tipo"]
	var disp := 0
	var restanti: int = int(s["g"][i]["cubi"]) - 1 if s.get("cw_cubo", -1) >= 0 else int(s["g"][i]["cubi"])
	var da: int = int(s.get("cw_cubo", -1)) + 1
	for k in range(da, mini(da + restanti, c["pm"].size())):
		var mx := 0
		for o in c["pm"][k]:
			var t := str(o)
			if t.begins_with("D"):
				mx = maxi(mx, int(t.substr(t.find("+") + 1)))
			elif t.begins_with("INF") and tipo != "A":
				mx = maxi(mx, int(t.substr(3)))
		disp += mx
	return disp < manca

func _ritiro_porta_sfida() -> bool:
	var p: Dictionary = s["g"][pm()]
	var o: Dictionary = s["g"][opp()]
	var sp: int = maxi(int(p["st"]) - 1, int(Dati.PLANCE[plancia(pm())]["min"]))
	var so: int = mini(int(o["st"]) + 1, int(Dati.PLANCE[plancia(opp())]["max"]))
	return so > sp or (so == sp and int(o["fav"]) >= int(p["fav"]))

## Prova a eseguire un'opzione del Clockwork (carta politico o Sostenitore). false = Futile.
## Formati: F+n, Fp-n, D-n, D+n, DHB+n, C:X, CC:X, INFn, e quelli dei Sostenitori Clockwork
## (Dn, +X, ++X, p-X, p--X, S+1, pS-1, Fv+n, pFv-n).
func _cw_esegui(i: int, o: String, da_carta_politico: bool) -> bool:
	var p: Dictionary = s["g"][i]
	var mio := str(p["par"])
	var av := _avversario(i)
	var lead: int = int(p["fav"]) - int(s["g"][av]["fav"])
	var attacco: bool = p["ruolo"] == "opp"
	if o.begins_with("F+") or o.begins_with("Fv+"):
		var n := int(o.substr(o.find("+")))
		if lead >= 3 or int(p["fav"]) >= Dati.FAVORE_MAX:
			return false
		_fav(i, n)
		_log("%s Lusinga Sua Maestà: Favore +%d." % [nome(i), n], i)
		return true
	if o.begins_with("Fp-") or o.begins_with("pFv-"):
		var n := int(o.substr(o.find("-")))
		if lead >= 3 or int(s["g"][av]["fav"]) <= 0:
			return false
		_fav(av, n)
		_log("%s trama a corte: il Favore di %s scende di %d." % [nome(i), nome(av), -n], i)
		return true
	if o == "S+1":
		if _st(i, 1) == 0:
			return false
		_log("%s guadagna 1 Standing." % nome(i), i)
		return true
	if o == "pS-1":
		if _st(av, -1) == 0:
			return false
		_log("%s fa perdere 1 Standing a %s." % [nome(i), nome(av)], i)
		return true
	if o.begins_with("C:") or o.begins_with("CC:"):
		var n := 2 if o.begins_with("CC") else 1
		var k := o.substr(o.find(":") + 1)
		if attacco and _cw_finale(i) and s["tav"].size() >= 2:
			return false
		if not _pop_possibile(mio, k, n):
			return false
		var q := _pop(mio, k, n)
		_log("%s fa Campagna in %s (%d gradin%s)." % [nome(i), Dati.NOME_SETTORE[k], q, "o" if q == 1 else "i"], i)
		return true
	if o.begins_with("+"):
		var n := o.count("+")
		var k := o.substr(n, 1)
		if not _pop_possibile(mio, k, n):
			return false
		_pop(mio, k, n)
		_log("%s: %s salgono in %s." % [nome(i), Testi.partito_pl(mio), Dati.NOME_SETTORE[k]], i)
		return true
	if o.begins_with("p-"):
		var n := o.count("-")
		var k := o.substr(1 + n, 1)
		var par := str(s["g"][av]["par"])
		if not _pop_possibile(par, k, -n):
			return false
		_pop(par, k, -n)
		_log("%s: %s scendono in %s." % [nome(i), Testi.partito_pl(par), Dati.NOME_SETTORE[k]], i)
		return true
	if o.begins_with("INF"):
		var n := int(o.substr(3))
		if attacco and multi() and s["patto"]:
			return false
		var b := _cw_bersaglio(i, true)
		if b < 0:
			return false
		var tipo: String = Dati.ddl(s["tav"][b]["id"])["tipo"]
		# il PM alza il disegno bersaglio, l'Opposizione lo abbassa
		var verso_p: bool = (tipo == "P") != attacco
		if not attacco and _cw_inutile_ultimo(i, b, n):
			return false
		var q := _inf(n if verso_p else -n)
		if q == 0:
			return false
		_log("%s Influenza i deputati: %d passano ai %s." % [nome(i), absi(q), "Partigiani" if q > 0 else "Moderati"], i)
		return true
	if o.begins_with("D"):
		var hb := o.begins_with("DHB")
		var n := int(o.substr(o.find("+") + 1)) if o.contains("+") else int(o.substr(o.find("-") + 1)) if o.contains("-") else int(o.substr(1))
		if attacco and multi() and s["patto"]:
			return false
		var b := -1
		if hb:
			b = _piu_alto()
			if b < 0 or not _in_raggio(voti(s["tav"][b]), _raggio(i, s["tav"][b])):
				return false
		else:
			b = _cw_bersaglio(i)
		if b < 0:
			return false
		if not attacco and _cw_inutile_ultimo(i, b, n):
			return false
		var bd: Dictionary = s["tav"][b]
		if _ret(bd, -n if attacco else n) == 0:
			return false
		_log("%s Dibatte %s: %s%d voti (ora %d)." % [nome(i), Testi.ddl(bd["id"]), "-" if attacco else "+", n, voti(bd)], i)
		return true
	return false

## Traduce un'opzione di un Sostenitore Clockwork per il partito di chi la gioca.
func _cw_opz_sost(i: int, o: String) -> String:
	var t := o
	if t.contains("/"):
		var parti := t.split("/")
		t = parti[0] if s["g"][i]["par"] == "C" else parti[1]
		t = t.substr(1)
	elif t.begins_with("X"):
		t = t.substr(1)
	return t

func _cw_opz_pop(t: String) -> bool:
	return t.begins_with("+") or t.begins_with("p-")

func _cw_pesca_sost(i: int, liv: int) -> void:
	var c = _pesca("scw")
	if c == null:
		return
	var card: Dictionary = DatiGen.SOSTENITORI_CW[int(c) - 1]
	if card["tieni"] and not _cw_finale(i) and s["tav"].size() > 1:
		s["g"][i]["tenute"].append({"n": int(c), "liv": liv})
		_log("%s pesca un Sostenitore Clockwork e lo tiene per le elezioni." % nome(i), i)
		return
	_log("%s pesca un Sostenitore Clockwork." % nome(i), i)
	_cw_gioca_sost(i, int(c), liv)

func _cw_gioca_sost(i: int, c: int, liv: int) -> void:
	var card: Dictionary = DatiGen.SOSTENITORI_CW[c - 1]
	s["mazzi"]["scw_s"].append(c)
	if liv == 2:
		# Livello 2: conta solo la prima opzione; se è Futile si pesca una carta di rimpiazzo (fino a tre in tutto)
		var cc := c
		for giro in 3:
			if _cw_esegui(i, _cw_opz_sost(i, str(DatiGen.SOSTENITORI_CW[cc - 1]["opz"][0])), false):
				return
			if giro == 2:
				break
			var n = _pesca("scw")
			if n == null:
				break
			cc = int(n)
			s["mazzi"]["scw_s"].append(cc)
		_log("Il Sostenitore di %s non ha effetto." % nome(i), i)
		return
	var finale: bool = s["g"][i]["ruolo"] == "opp" and _cw_finale(i) and s["tav"].size() >= 2
	for giro in (2 if finale else 1):
		for o in card["opz"]:
			var t := _cw_opz_sost(i, str(o))
			if finale and giro == 0 and _cw_opz_pop(t):
				continue
			if _cw_esegui(i, t, false):
				return
	_log("Il Sostenitore di %s non ha effetto." % nome(i), i)

func _cw_turno(i: int) -> void:
	var p: Dictionary = s["g"][i]
	var c := _cw(i)
	# Sostenitori ricevuti dai disegni di legge
	var dg: Array = p["da_giocare"]
	p["da_giocare"] = []
	for x in dg:
		var card: Dictionary = DatiGen.SOSTENITORI_CW[int(x["n"]) - 1]
		if card["tieni"] and not _cw_finale(i) and s["tav"].size() > 1:
			p["tenute"].append(x)
		else:
			_log("%s rivela un Sostenitore Clockwork." % nome(i), i)
			_cw_gioca_sost(i, int(x["n"]), int(x["liv"]))
	# carte tenute per le elezioni: si giocano quando resta un solo disegno (o a fine partita)
	if not p["tenute"].is_empty() and (s["tav"].size() <= 1 or _cw_finale(i)):
		var tn: Array = p["tenute"]
		p["tenute"] = []
		for x in tn:
			_log("%s rivela un Sostenitore tenuto per le elezioni." % nome(i), i)
			_cw_gioca_sost(i, int(x["n"]), int(x["liv"]))
			if s["fine"] != null:
				return
	var lato: Array = c[p["ruolo"]]
	var k := 0
	while int(p["cubi"]) > 0 and s["fine"] == null:
		var opz: Array = lato[mini(k, lato.size() - 1)]
		s["cw_cubo"] = mini(k, lato.size() - 1)
		for o in opz:
			var t := str(o)
			if t == "S" or t == "S2":
				_cw_pesca_sost(i, 2 if t == "S2" else 1)
				break
			if _cw_esegui(i, t, true):
				break
		p["cubi"] = int(p["cubi"]) - 1
		k += 1
	s["cw_cubo"] = -1

func _cw_evento(i: int, ev: Dictionary) -> void:
	var p: Dictionary = s["g"][i]
	var cond := str(ev["cond"])
	var ok := false
	var hb := _piu_alto()
	var vhb: int = voti(s["tav"][hb]) if hb >= 0 else 0
	if cond == "LOSE":
		ok = vantaggio(str(s["gov"])) < 0
	elif cond.begins_with("ST<=12"):
		ok = int(p["st"]) <= 12 and vhb >= 340
	else:
		ok = int(p["st"]) >= 9 and vhb >= 320
	if not ok or int(p["cubi"]) < int(ev["costo"]):
		_log("Evento Clockwork: nessun effetto.", i)
		return
	var eff := _cw_opz_sost(i, str(ev["eff"]))
	if _cw_esegui(i, eff, false):
		p["cubi"] = int(p["cubi"]) - int(ev["costo"])
		_log("(Evento Clockwork: %s spende %d cub%s.)" % [nome(i), int(ev["costo"]), "o" if int(ev["costo"]) == 1 else "i"], i)
	else:
		_log("Evento Clockwork: nessun effetto.", i)

## Da quale mazzo pesca il PM Clockwork: quello di partito se ha abbastanza deputati Partigiani.
func _cw_mazzo(i: int) -> String:
	if s["sel"].has("cw_mazzo"):
		return str(s["sel"]["cw_mazzo"])
	var m := str(s["gov"]) if int(s["mp"]["P"]) >= int(_cw(i)["pb"]) else "X"
	if s["mazzi"][m].is_empty() and s["mazzi"][m + "_s"].is_empty():
		m = "X" if m != "X" else str(s["gov"])
	s["sel"]["cw_mazzo"] = m
	return m

func voti_iniziali(id: String) -> int:
	var d: Dictionary = Dati.ddl(id)
	return int(s["mp"][d["tipo"]]) + int(d["ret"])

func _cw_scegli(i: int, riv: Array) -> Array:
	var c := _cw(i)
	var dentro := []
	var fuori := []
	for id in riv:
		var soglia: int = c["sel"]
		if c.has("selmp") and Dati.ddl(id)["tipo"] != "A":
			soglia = c["selmp"]
		if voti_iniziali(id) >= soglia:
			dentro.append(id)
		else:
			fuori.append(id)
	var n := mini(3, riv.size())
	if dentro.size() > n:
		dentro.sort_custom(func(a, b):
			var k := _cmp(valore_ddl(a), valore_ddl(b))
			if k != 0:
				return k > 0
			return voti_iniziali(a) > voti_iniziali(b))
		return dentro.slice(0, n)
	fuori.sort_custom(func(a, b):
		if voti_iniziali(a) != voti_iniziali(b):
			return voti_iniziali(a) > voti_iniziali(b)
		return _cmp(valore_ddl(a), valore_ddl(b)) > 0)
	return dentro + fuori.slice(0, n - dentro.size())

func _cw_risolvi(i: int) -> Dictionary:
	var tav: Array = s["tav"]
	# priorità: esattamente 350, più di 350, 340
	for prova in 3:
		var cand := []
		for b in tav.size():
			var v := voti(tav[b])
			if (prova == 0 and v == 350) or (prova == 1 and v > 350) or (prova == 2 and v == 340):
				cand.append(b)
		if not cand.is_empty():
			var m: int = cand[0]
			for b in cand:
				if _cmp(valore_ddl(tav[b]["id"]), valore_ddl(tav[m]["id"])) > 0:
					m = b
			return {"t": "voto", "b": m}
	# nel gioco a più giocatori prova prima l'accordo con l'Opposizione
	if multi() and not s.get("accordo_no", false):
		var hb := _piu_alto()
		if hb >= 0 and voti(tav[hb]) >= 300:
			return {"t": "accordo", "b": hb}
	if _cw_finale(i) and _ritiro_porta_sfida():
		var hb := _piu_alto()
		if hb >= 0 and voti(tav[hb]) >= 320:
			return {"t": "voto", "b": hb}
	var m := 0
	for b in tav.size():
		var vb := voti(tav[b])
		var vm := voti(tav[m])
		if vb < vm or (vb == vm and _cmp(valore_ddl(tav[b]["id"]), valore_ddl(tav[m]["id"])) < 0):
			m = b
	return {"t": "ritiro", "b": m}

# ------------------------------------------------------------------ IA per le decisioni fuori dal Clockwork

func _ia_mazzo(_chi: int) -> String:
	return "X"

func _ia_proponi(_chi: int, mano: Array, n: int) -> Array:
	var ord := mano.duplicate()
	ord.sort_custom(func(a, b): return voti_iniziali(a) > voti_iniziali(b))
	return ord.slice(0, mini(n, ord.size()))

## Il capo dell'Opposizione automatico rompe il Patto quando il traguardo si avvicina o quando è a tiro di sfida.
func _ia_rompi_patto(o: int) -> bool:
	var p := pm()
	if int(s["g"][p]["pv"]) >= 45:
		return true
	if int(s["g"][o]["st"]) >= int(s["g"][p]["st"]) - 1:
		return true
	return int(s["round"]) >= 6

func _ia_riparti_patto(_o: int) -> bool:
	return false

func _ia_accordo(o: int, ib: int) -> bool:
	var p := pm()
	var b: Dictionary = s["tav"][ib]
	var d: Dictionary = Dati.ddl(b["id"])
	if s["patto"]:
		return true
	if int(s["g"][p]["pv"]) + int(d["pv"]) >= 95:
		return false
	if voti(b) >= 350:
		return true
	# rinuncia a Standing e PV del ritiro solo se il disegno non regala troppo al PM
	return int(d["pv"]) <= 3 and int(s["g"][o]["pv"]) <= int(s["g"][p]["pv"])

func _ia_sfida(a: int, b: int) -> bool:
	var r: String = s["g"][a]["ruolo"]
	if r == "opp":
		if s["cfg"]["modo"] == "cw1":
			return true
		var par := str(s["g"][a]["par"])
		return seggi_previsti(par) >= 289 or int(s["g"][a]["pv"]) >= 85 or int(s["g"][b]["pv"]) >= 85
	return true

func _ia_premio(chi: int, opz: Array) -> String:
	if "pv2" in opz and int(s["g"][chi]["st"]) >= 6:
		return "pv2"
	return str(opz[0])

## Turno di un Backbencher automatico: carta Dibattito se conviene, altrimenti incarichi, Dibattito e salotti.
func _ia_turno_bb(chi: int) -> void:
	var p: Dictionary = s["g"][chi]
	var giri := 0
	while int(p["cubi"]) > 0 and giri < 6:
		giri += 1
		var az := azioni_possibili(chi)
		var scelta = null
		var gov: bool = p["ruolo"] == "bbg"
		for a in az:
			if a["t"] == "cdib":
				var v := voti(s["tav"][int(a["b"])])
				if (gov or s["patto"]) and v >= 320 and v <= 340:
					scelta = a
				elif not gov and not s["patto"] and v >= 300 and v <= 340:
					scelta = a
		if scelta == null:
			for a in az:
				if a["t"] == "carr" and (a["c"] == "pc" and a.has("chi") or a["c"] == "cc" and int(p["cubi"]) >= 1 and str(a["s"]) in Dati.politico(p["pol"])["set"]):
					scelta = a
					break
		if scelta == null:
			for a in az:
				if a["t"] == "dib":
					var v := voti(s["tav"][int(a["b"])])
					if (gov or s["patto"]) and int(a["v"]) > 0 and v >= 300 and v < 350:
						scelta = a
					elif not gov and not s["patto"] and int(a["v"]) < 0 and v >= 310 and v <= 350:
						scelta = a
		if scelta == null:
			for a in az:
				if a["t"] == "hob":
					scelta = a
					break
		if scelta == null:
			break
		_azione(chi, scelta)
	# gioca i Sostenitori utili al partito, tenendone al massimo quattro
	var guard := 0
	while not p["sost"].is_empty() and guard < 8:
		guard += 1
		var c: int = p["sost"][0]
		var fatto := false
		for a in azioni_possibili(chi):
			if a["t"] == "sost" and int(a["c"]) == c and _ia_sost_buona(chi, a):
				_azione(chi, a)
				fatto = true
				break
		if not fatto:
			if p["sost"].size() > 4:
				_azione(chi, {"t": "scarta", "c": c})
			else:
				break

func _ia_sost_buona(chi: int, a: Dictionary) -> bool:
	var p: Dictionary = s["g"][chi]
	var eff: Array = sostenitore(int(a["c"]))["opz"][int(a["o"])]
	var gov: bool = p["ruolo"] in ["pm", "bbg"]
	for e in eff:
		var t := str(e)
		if t.begins_with("p-") and str(a.get("par", "")) == str(p["par"]):
			return false
		if (t.begins_with("pFv") or t.begins_with("pS")) and int(a.get("chi", -1)) in cordata(chi) and int(a.get("v", -1)) < 0:
			return false
		if t.begins_with("pFv~") and int(a.get("v", 1)) > 0 and int(a.get("chi", -1)) != chi:
			return false
		if t.begins_with("D"):
			if s["tav"].is_empty():
				return false
			if (int(a.get("v", 1)) > 0) != (gov or s["patto"]):
				return false
		if t.begins_with("INF"):
			return false
		if t.begins_with("X-") or t == "S-1":
			return false
	return true
