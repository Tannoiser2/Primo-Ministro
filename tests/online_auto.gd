extends SceneTree
## Un capo di una partita online di prova (host oppure ospite) sul finto Firebase: gioca a caso
## le proprie decisioni, legge dalla rete quelle dell'altro e alla fine stampa l'impronta della partita.
## Lo lancia tests/prova_online.sh: le due impronte devono essere uguali.

func _init() -> void:
	_gioca.call_deferred()

func _gioca() -> void:
	var ruolo := OS.get_environment("PM_RUOLO")
	var file_codice := OS.get_environment("PM_CODICE")
	var net := Rete.new()
	root.add_child(net)
	var codice := ""
	var mio := 0
	var cfg := {"modo": "multi", "seme": 0, "posti": [{"pol": "melbourne", "tipo": "u"}, {"pol": "derby", "tipo": "u"}, {"pol": "gladstone", "tipo": "cw"}, {"pol": "disraeli", "tipo": "cw"}]}
	if ruolo == "host":
		codice = await net.create_room("Host", cfg)
		if codice == "":
			print("PM ERRORE creazione stanza: ", net.last_error)
			quit()
			return
		var f := FileAccess.open(file_codice, FileAccess.WRITE)
		f.store_string(codice)
		f.close()
		while true:
			await create_timer(0.3).timeout
			var room := await net.room(codice)
			if Rete._as_dict(room.get("seats", {})).has("1"):
				break
		cfg["seme"] = 20261116
		await net.start_room(codice, cfg)
	else:
		mio = 1
		while not FileAccess.file_exists(file_codice):
			await create_timer(0.3).timeout
		await create_timer(0.3).timeout
		codice = FileAccess.get_file_as_string(file_codice).strip_edges()
		var posto := await net.join_room(codice, "Ospite", 4)
		if posto != 1:
			print("PM ERRORE ingresso: posto ", posto, " ", net.last_error)
			quit()
			return
		while true:
			var r2 := await net.room(codice)
			if str(r2.get("status", "")) == "playing":
				cfg = JSON.parse_string(str(r2.get("game", "{}")))
				break
			await create_timer(0.3).timeout
	var m := Motore.nuova(cfg)
	m.avanza()
	var g := RandomNumberGenerator.new()
	g.seed = 99 + mio
	var limite := int(OS.get_environment("PM_MOSSE")) if OS.has_environment("PM_MOSSE") else 120
	while m.s["fine"] == null and m.s["att"] != null and int(m.s["n_dec"]) < limite:
		var a: Dictionary = m.s["att"]
		if int(a["posto"]) == mio:
			var r := _scelta(m, g)
			if not await net.post_decision(codice, int(m.s["n_dec"]), r):
				print("PM ERRORE invio decisione: ", net.last_error)
				break
			m.rispondi(r)
			m.avanza()
		else:
			var d = await net.get_decision(codice, int(m.s["n_dec"]))
			if d is Dictionary and d.has("t"):
				if not m.rispondi(d):
					print("PM ERRORE decisione remota rifiutata: ", d)
					break
				m.avanza()
			else:
				await create_timer(0.15).timeout
	print("PM %s: %d decisioni, round %d, PV %s, impronta %d" % [ruolo, m.s["n_dec"], m.s["round"], str(m.s["g"].map(func(x): return x["pv"])), JSON.stringify([m.s["g"], m.s["pop"], m.s["mp"], m.s["tav"], m.s["r"]]).hash()])
	quit()

func _scelta(m: Motore, g: RandomNumberGenerator) -> Dictionary:
	var a: Dictionary = m.s["att"]
	if a["tipo"] in ["scegli", "proponi"]:
		var fonte: Array = (m.s["sel"]["riv"] if a["tipo"] == "scegli" else m.s["sel"]["mano"]).duplicate()
		var ids := []
		for k in int(a["n"]):
			ids.append(fonte.pop_at(g.randi() % fonte.size()))
		return {"t": a["tipo"], "ids": ids}
	var op := m.opzioni()
	if a["tipo"] == "azione":
		var utili := op.filter(func(x): return not (x["t"] in ["fine", "scarta", "dimetti"]))
		if int(m.s["g"][a["posto"]]["cubi"]) == 0 or utili.is_empty():
			for x in op:
				if x["t"] == "fine":
					return x
			for x in op:
				if x["t"] == "scarta":
					return x
		return utili[g.randi() % utili.size()]
	return op[g.randi() % op.size()]
