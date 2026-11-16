## Prova del tutorial: gioca partite intere seguendo sempre la mossa consigliata.
## godot --headless --path . -s tests/tutor.gd -- <partite>
extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 30
	var errori := 0
	var vinte := 0
	var rounds := 0
	for k in n:
		var cfg: Dictionary = Tutor.CFG.duplicate(true)
		if k > 0:
			cfg["seme"] = 1000 + k
		var m := Motore.nuova(cfg)
		m.avanza()
		var passi := 0
		while m.s["fine"] == null and passi < 4000:
			passi += 1
			if m.s["att"] == null:
				print("ERRORE: nessuna attesa")
				errori += 1
				break
			var c := Tutor.consiglio(m)
			var tipo := str(m.s["att"]["tipo"])
			for l in Tutor.lezioni_per(m, tipo, c["r"]):
				if not Tutor.LEZIONI.has(l):
					print("ERRORE: lezione mancante ", l)
					errori += 1
			if Tutor.descrivi(m, c["r"]) == "":
				errori += 1
			if not m.rispondi(c["r"]):
				print("ERRORE: consiglio rifiutato ", c["r"], " per ", m.s["att"])
				errori += 1
				break
			m.avanza()
		if m.s["fine"] == null:
			print("ERRORE: partita non finita, seme ", cfg["seme"])
			errori += 1
		elif int(m.s["fine"]["vince"]) == 0:
			vinte += 1
		rounds += int(m.s["round"])
		if k == 0:
			print("Partita del tutorial (seme %d): vince %s in %d round" % [cfg["seme"], m.nome(int(m.s["fine"]["vince"])) if m.s["fine"] != null else "?", m.s["round"]])
	print("Seguendo i consigli: %d vittorie su %d, round medi %.1f" % [vinte, n, rounds / float(n)])
	print("ERRORI: ", errori)
	quit(1 if errori > 0 else 0)
