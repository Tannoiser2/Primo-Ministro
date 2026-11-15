## Partite automatiche per provare il motore: godot --headless --path . -s tests/sim.gd -- <partite> [modo]
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 50
	var modo := str(args[1]) if args.size() > 1 else "tutti"
	var modi := ["cw1", "cw2", "cw2opp", "multi2", "multi3", "multi4", "multi4u"] if modo == "tutti" else [modo]
	var errori := 0
	for md in modi:
		var vitt := {}
		var rounds := 0
		var bloccate := 0
		for k in n:
			var m := Motore.nuova(_cfg(md, k + 1))
			var passi := 0
			var g := RandomNumberGenerator.new()
			g.seed = k * 7919 + 13
			m.avanza()
			while m.s["fine"] == null and passi < 6000:
				passi += 1
				var a = m.s["att"]
				if a == null:
					print("ERRORE: nessuna attesa e partita non finita (", md, " seme ", k + 1, " fase ", m.s["fase"], ")")
					errori += 1
					break
				var r := _scelta(m, g)
				if not m.rispondi(r):
					print("ERRORE: risposta rifiutata ", r, " a ", a)
					errori += 1
					break
				m.avanza()
			if m.s["fine"] == null:
				bloccate += 1
			else:
				var v: int = m.s["fine"]["vince"]
				var chiave := "%s(%s)" % [m.s["g"][v]["tipo"], v]
				vitt[chiave] = int(vitt.get(chiave, 0)) + 1
			rounds += int(m.s["round"])
			# lo stato deve restare serializzabile
			var js := JSON.stringify(m.s)
			if JSON.parse_string(js) == null:
				print("ERRORE: stato non serializzabile")
				errori += 1
		print("%s: %d partite, vittorie %s, non finite %d, round medi %.1f" % [md, n, vitt, bloccate, rounds / float(n)])
	print("ERRORI: ", errori)
	quit(1 if errori > 0 else 0)

func _cfg(md: String, seme: int) -> Dictionary:
	var lib := ["gladstone", "melbourne", "palmerston", "russell", "rosebery"]
	var con := ["derby", "disraeli", "peel", "salisbury", "aberdeen"]
	var l: String = lib[seme % 4]
	var c: String = con[(seme / 4) % 4]
	match md:
		"cw1":
			return {"modo": "cw1", "seme": seme, "riserva": lib[(seme + 1) % 4], "posti": [{"pol": l, "tipo": "u"}, {"pol": c, "tipo": "cw"}]}
		"cw2":
			return {"modo": "cw2", "seme": seme, "umano_pm": true, "posti": [{"pol": c, "tipo": "u"}, {"pol": l, "tipo": "cw"}]}
		"cw2opp":
			return {"modo": "cw2", "seme": seme, "umano_pm": false, "posti": [{"pol": l, "tipo": "u"}, {"pol": c, "tipo": "cw"}]}
		"multi2":
			return {"modo": "multi", "seme": seme, "posti": [{"pol": l, "tipo": "u"}, {"pol": c, "tipo": "u"}]}
		"multi3":
			return {"modo": "multi", "seme": seme, "posti": [{"pol": l, "tipo": "u"}, {"pol": c, "tipo": "cw"}, {"pol": con[(seme / 4 + 1) % 4], "tipo": "u"}]}
		"multi4":
			return {"modo": "multi", "seme": seme, "posti": [{"pol": l, "tipo": "cw"}, {"pol": c, "tipo": "cw"}, {"pol": lib[(seme + 1) % 5], "tipo": "cw"}, {"pol": con[(seme / 4 + 1) % 5], "tipo": "cw"}]}
		_:
			return {"modo": "multi", "seme": seme, "posti": [{"pol": l, "tipo": "u"}, {"pol": c, "tipo": "cw"}, {"pol": lib[(seme + 1) % 5], "tipo": "cw"}, {"pol": con[(seme / 4 + 1) % 5], "tipo": "u"}]}

## Giocatore di prova: sceglie a caso fra le risposte lecite (con una preferenza per finire il turno senza cubi).
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
		var cubi: int = m.s["g"][a["posto"]]["cubi"]
		if cubi == 0 or utili.is_empty() or g.randf() < 0.08:
			for x in op:
				if x["t"] == "fine":
					return x
			for x in op:
				if x["t"] == "scarta":
					return x
		return utili[g.randi() % utili.size()]
	return op[g.randi() % op.size()]
