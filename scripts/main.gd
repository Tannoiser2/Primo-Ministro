## Primo Ministro: schermate, tavolo di gioco e collegamento online.
extends Control

const ROSSO := Color("7a1418")
const ROSSO_CHIARO := Color("9c2328")
const ORO := Color("b8892d")
const ORO_CHIARO := Color("e8c66a")
const CARTA := Color("efe7d2")
const INCHIOSTRO := Color("231c18")
const VERDE := Color("1f4a2c")
const BLU := Color("244a8f")
const ARANCIO := Color("d2601a")
const MOGANO := Color("24120f")
const FILE_PARTITA := "user://primo_ministro_partita.json"

var f_titolo: Font = preload("res://assets/font/Milonga-Regular.ttf")
var f_testo: Font = preload("res://assets/font/OldStandard-Regular.ttf")
var f_grassetto: Font = preload("res://assets/font/OldStandard-Bold.ttf")
var f_corsivo: Font = preload("res://assets/font/OldStandard-Italic.ttf")
var f_insegna: Font = preload("res://assets/font/Rye-Regular.ttf")

var m: Motore
var rete: Rete
var schermo: Control
var strato: Control
var tab: Tabellone
var tab_or: TabOriginale
var vista_originale := true
var box_giocatori: VBoxContainer
var box_ddl: HBoxContainer
var box_azioni: VBoxContainer
var diario: RichTextLabel
var barra_fase: Label
var sub := ""
var sub_dati := {}
var scelti := []
var visti_reg := 0
## online: codice della stanza, posti di gioco che appartengono a questo dispositivo
var online := {}
var in_attesa := false
var tempo_poll := 0.0
var ultimo_round_salvato := 0
## tutorial: {} se spento; altrimenti {intro: passo della visita, visti: lezioni già mostrate}
var tut := {}

func _ready() -> void:
	rete = Rete.new()
	add_child(rete)
	theme = _tema()
	var sfondo := ColorRect.new()
	sfondo.color = MOGANO
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sfondo)
	schermo = Control.new()
	schermo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(schermo)
	strato = Control.new()
	strato.set_anchors_preset(Control.PRESET_FULL_RECT)
	strato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strato)
	var prova := OS.get_environment("PM_PROVA")
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('prova') || ''")
		prova = str(q) if q != null else ""
	if prova != "":
		_prova(prova)
	else:
		_menu()

# ------------------------------------------------------------------ tema e mattoni

func _sb(colore: Color, bordo: Color, spess := 2, raggio := 6, margine := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = colore
	s.border_color = bordo
	s.set_border_width_all(spess)
	s.set_corner_radius_all(raggio)
	s.set_content_margin_all(margine)
	return s

func _tema() -> Theme:
	var t := Theme.new()
	t.default_font = f_testo
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", _sb(ROSSO, ORO))
	t.set_stylebox("hover", "Button", _sb(ROSSO_CHIARO, ORO_CHIARO))
	t.set_stylebox("pressed", "Button", _sb(Color("5a0e12"), ORO_CHIARO))
	t.set_stylebox("disabled", "Button", _sb(Color("5b4a44"), Color("7d6f5c")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("f7eecd"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("f7eecd"))
	t.set_color("font_disabled_color", "Button", Color("c9bda6"))
	t.set_font("font", "Button", f_grassetto)
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Label", INCHIOSTRO)
	t.set_stylebox("panel", "PanelContainer", _sb(CARTA, ORO, 3, 8, 14))
	t.set_stylebox("normal", "LineEdit", _sb(Color("fbf6e6"), ORO, 2, 4, 8))
	t.set_stylebox("focus", "LineEdit", _sb(Color.WHITE, ORO_CHIARO, 2, 4, 8))
	t.set_color("font_color", "LineEdit", INCHIOSTRO)
	t.set_color("caret_color", "LineEdit", INCHIOSTRO)
	t.set_color("default_color", "RichTextLabel", INCHIOSTRO)
	t.set_font("normal_font", "RichTextLabel", f_testo)
	t.set_font("bold_font", "RichTextLabel", f_grassetto)
	t.set_font("italics_font", "RichTextLabel", f_corsivo)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	t.set_font_size("bold_font_size", "RichTextLabel", 19)
	t.set_font_size("italics_font_size", "RichTextLabel", 19)
	return t

func _lbl(testo: String, px := 22, colore := INCHIOSTRO, font: Font = null, larg := 0.0) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", colore)
	if font != null:
		l.add_theme_font_override("font", font)
	if larg > 0.0:
		# testo a capo solo con una larghezza minima garantita: mai colonne di una lettera
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = larg
	return l

func _btn(testo: String, azione: Callable, larg := 0.0, px := 22) -> Button:
	var b := Button.new()
	b.text = testo
	b.add_theme_font_size_override("font_size", px)
	if larg > 0.0:
		b.custom_minimum_size.x = larg
	b.custom_minimum_size.y = 50
	b.pressed.connect(azione)
	return b

func _btn_chiaro(testo: String, azione: Callable, larg := 0.0) -> Button:
	var b := _btn(testo, azione, larg)
	b.add_theme_stylebox_override("normal", _sb(Color("fbf6e6"), ORO))
	b.add_theme_stylebox_override("hover", _sb(Color.WHITE, ROSSO))
	b.add_theme_stylebox_override("pressed", _sb(Color("e2d6b4"), ROSSO))
	b.add_theme_color_override("font_color", INCHIOSTRO)
	b.add_theme_color_override("font_hover_color", ROSSO)
	b.add_theme_color_override("font_pressed_color", INCHIOSTRO)
	return b

func _pannello(contenuto: Control, colore := CARTA, margine := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(colore, ORO, 3, 8, margine))
	p.add_child(contenuto)
	return p

func _img(percorso: String, alt := 0.0, larg := 0.0) -> TextureRect:
	var t := TextureRect.new()
	if ResourceLoader.exists(percorso):
		t.texture = load(percorso)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if t.texture != null:
		var prop := float(t.texture.get_width()) / float(t.texture.get_height())
		if alt > 0.0:
			t.custom_minimum_size = Vector2(alt * prop, alt)
		elif larg > 0.0:
			t.custom_minimum_size = Vector2(larg, larg / prop)
	return t

## Carta cliccabile: toccandola si ingrandisce (o esegue `azione` se indicata).
func _carta(percorso: String, alt: float, azione := Callable()) -> Control:
	var t := _img(percorso, alt)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	t.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			if azione.is_valid():
				azione.call()
			else:
				_ingrandisci(percorso))
	return t

func _svuota(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _cambia_schermo() -> Control:
	_svuota(schermo)
	_svuota(strato)
	strato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return schermo

# ------------------------------------------------------------------ finestre sopra il tavolo

func _modale(contenuto: Control, chiudibile := true) -> Control:
	_svuota(strato)
	strato.mouse_filter = Control.MOUSE_FILTER_STOP
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0.72)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	strato.add_child(velo)
	if chiudibile:
		velo.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				_chiudi_modale())
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strato.add_child(centro)
	centro.add_child(contenuto)
	return contenuto

func _chiudi_modale() -> void:
	_svuota(strato)
	strato.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ingrandisci(percorso: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var alt := minf(get_viewport_rect().size.y - 140.0, 860.0)
	v.add_child(_img(percorso, alt))
	var b := _btn("Chiudi", _chiudi_modale, 240)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	_modale(v)

func _avviso(testo: String, dopo := Callable()) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.add_child(_lbl(testo, 24, INCHIOSTRO, null, 640))
	var b := _btn("Va bene", func():
		_chiudi_modale()
		if dopo.is_valid():
			dopo.call(), 240)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	_modale(_pannello(v, CARTA, 24), false)

# ------------------------------------------------------------------ menu

func _titolo_grande(testo: String, px := 86) -> Label:
	var l := _lbl(testo, px, ORO_CHIARO, f_titolo)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _avvia_tutorial() -> void:
	tut = {"intro": 0, "visti": []}
	vista_originale = true
	_nuova_partita(Tutor.CFG.duplicate(true))

func _menu() -> void:
	online = {}
	tut = {}
	m = null
	var s := _cambia_schermo()
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	var st := _img("res://assets/ui/stemma_chiaro.png", 190)
	st.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(st)
	v.add_child(_titolo_grande("Primo Ministro"))
	var sot := _lbl("Potere e prestigio nella Gran Bretagna vittoriana", 26, Color("e9dfc6"), f_corsivo)
	sot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sot)
	v.add_child(_spazio(14))
	var voci := [
		["Tutorial: partita guidata", func(): _avvia_tutorial()],
		["Solitario contro il Clockwork", func(): _prepara_solitario()],
		["Partita a più giocatori (con IA)", func(): _prepara_multi(false)],
		["Gioca online con gli amici", func(): _online_menu()],
		["Riprendi la partita salvata", func(): _riprendi()],
		["Come si gioca", func(): _regole()],
	]
	for vc in voci:
		var b := _btn(vc[0], vc[1], 560, 26)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	var nota := _lbl("Versione digitale per uso personale del gioco di Paul Hellyer (GMT Games, 2023)", 17, Color("b9a98c"))
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_spazio(8))
	v.add_child(nota)

func _spazio(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(h, h)
	return c

func _intestazione(titolo: String, indietro: Callable) -> VBoxContainer:
	var s := _cambia_schermo()
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lato in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + lato, 28)
	s.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	mc.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.add_child(_btn("Indietro", indietro, 170))
	var t := _lbl(titolo, 46, ORO_CHIARO, f_titolo)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	v.add_child(h)
	return v

# ---------- solitario

var prep := {}

func _prepara_solitario() -> void:
	prep = {"sistema": 2, "pol": "", "riserva": "", "cw": "", "pm": true, "facile": false}
	_solitario_schermo()

func _solitario_schermo() -> void:
	var v := _intestazione("Solitario contro il Clockwork", _menu)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	riga.add_child(_lbl("Sistema:", 24, Color("e9dfc6")))
	for k in [1, 2]:
		var testo := "I - sei sempre Primo Ministro" if k == 1 else "II - il Governo può cambiare di mano"
		var b := _btn(testo, func():
			prep["sistema"] = k
			prep["riserva"] = ""
			_solitario_schermo())
		if prep["sistema"] != k:
			b.modulate = Color(1, 1, 1, 0.55)
		riga.add_child(b)
	v.add_child(riga)
	var passo := ""
	var elenco := []
	if prep["pol"] == "":
		passo = "Scegli il tuo politico"
		for p in Dati.POLITICI:
			elenco.append(p["id"])
	elif prep["sistema"] == 1 and prep["riserva"] == "":
		passo = "Scegli la riserva: potrà sostituire il tuo Primo Ministro una volta (stesso partito)"
		for p in Dati.POLITICI:
			if p["p"] == Dati.politico(prep["pol"])["p"] and p["id"] != prep["pol"]:
				elenco.append(p["id"])
	elif prep["cw"] == "":
		passo = "Scegli l'avversario automatico (le stelle indicano la difficoltà)"
		for p in Dati.POLITICI:
			if p["p"] != Dati.politico(prep["pol"])["p"]:
				elenco.append(p["id"])
	if passo != "":
		v.add_child(_lbl(passo, 28, Color("f7eecd"), f_grassetto))
		var g := HFlowContainer.new()
		g.add_theme_constant_override("h_separation", 14)
		g.add_theme_constant_override("v_separation", 14)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(g)
		v.add_child(sc)
		for id in elenco:
			var scelta_cw: bool = prep["pol"] != "" and not (prep["sistema"] == 1 and prep["riserva"] == "")
			var perc := "res://assets/carte/pol/%s.webp" % id
			if scelta_cw:
				perc = "res://assets/carte/cw/%s_%s.webp" % [id, "opp" if (prep["sistema"] == 1 or prep["pm"]) else "pm"]
			var col := VBoxContainer.new()
			col.add_child(_carta(perc, 400, func():
				if prep["pol"] == "":
					prep["pol"] = id
				elif prep["sistema"] == 1 and prep["riserva"] == "":
					prep["riserva"] = id
				else:
					prep["cw"] = id
				_solitario_schermo()))
			if scelta_cw:
				var st: Array = Dati.CLOCKWORK[id]["stelle"]
				var quante: int = st[0] if (prep["sistema"] == 1 or prep["pm"]) else st[1]
				var e := _lbl("%s - difficoltà %d su 3" % [Dati.politico(id)["corto"], quante], 20, Color("f7eecd"))
				e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				col.add_child(e)
			g.add_child(col)
		if prep["pol"] != "" and prep["sistema"] == 2 and prep["cw"] == "":
			var r2 := HBoxContainer.new()
			r2.add_theme_constant_override("separation", 12)
			r2.add_child(_lbl("Cominci come:", 24, Color("e9dfc6")))
			for pmv in [true, false]:
				var b := _btn("Primo Ministro" if pmv else "Capo dell'Opposizione", func():
					prep["pm"] = pmv
					_solitario_schermo())
				if prep["pm"] != pmv:
					b.modulate = Color(1, 1, 1, 0.55)
				r2.add_child(b)
			v.add_child(r2)
		return
	# riepilogo
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(_carta("res://assets/carte/pol/%s.webp" % prep["pol"], 430))
	var umano_pm: bool = prep["sistema"] == 1 or prep["pm"]
	h.add_child(_carta("res://assets/carte/cw/%s_%s.webp" % [prep["cw"], "opp" if umano_pm else "pm"], 520))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(_lbl("Tu: %s, %s" % [Dati.politico(prep["pol"])["nome"], "Primo Ministro" if umano_pm else "Capo dell'Opposizione"], 26, Color("f7eecd"), null, 520))
	col.add_child(_lbl("Clockwork: %s" % Dati.politico(prep["cw"])["nome"], 26, Color("f7eecd"), null, 520))
	if prep["sistema"] == 1:
		col.add_child(_lbl("Riserva: %s" % Dati.politico(prep["riserva"])["nome"], 26, Color("f7eecd"), null, 520))
		col.add_child(_lbl("Vinci arrivando a 100 Punti Vittoria. Perdi se l'Opposizione ti toglie il Governo con una sfida o alle elezioni.", 21, Color("d9cdb0"), f_corsivo, 520))
	else:
		col.add_child(_lbl("Vince il primo che arriva a 100 Punti Vittoria mentre è Primo Ministro.", 21, Color("d9cdb0"), f_corsivo, 520))
	var bf := _btn("Plance facili: %s" % ("sì" if prep["facile"] else "no"), func():
		prep["facile"] = not prep["facile"]
		_solitario_schermo(), 520)
	col.add_child(bf)
	col.add_child(_btn("Comincia la partita", func():
		var cfg := {"modo": "cw1" if prep["sistema"] == 1 else "cw2", "seme": randi() % 1000000 + 1, "facile": prep["facile"],
			"umano_pm": umano_pm, "riserva": prep["riserva"],
			"posti": [{"pol": prep["pol"], "tipo": "u"}, {"pol": prep["cw"], "tipo": "cw"}]}
		_nuova_partita(cfg), 520, 28))
	col.add_child(_btn_chiaro("Ricomincia la scelta", _prepara_solitario, 520))
	h.add_child(col)
	v.add_child(h)

# ---------- più giocatori

func _politici_ammessi(par: String, n: int) -> Array:
	var out := []
	for p in Dati.POLITICI:
		if p["p"] != par:
			continue
		if p["id"] == "rosebery" and n <= 3:
			continue
		if p["id"] == "aberdeen" and n == 2:
			continue
		out.append(p["id"])
	return out

func _prepara_multi(per_online: bool) -> void:
	prep = {"n": 4, "posti": [], "online": per_online, "nome": prep.get("nome", "")}
	_multi_componi()
	_multi_schermo()

func _multi_componi() -> void:
	var n: int = prep["n"]
	var partiti: Array = ["L", "C"] if n == 2 else (["L", "C", "C"] if n == 3 else ["L", "C", "L", "C"])
	var usati := []
	var posti := []
	for i in n:
		var amm := _politici_ammessi(partiti[i], n).filter(func(x): return not (x in usati))
		amm.shuffle()
		usati.append(amm[0])
		posti.append({"par": partiti[i], "pol": amm[0], "tipo": "u" if i == 0 else "cw"})
	prep["posti"] = posti

func _multi_schermo() -> void:
	var v := _intestazione("Stanza online" if prep["online"] else "Partita a più giocatori", _online_menu if prep["online"] else _menu)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	riga.add_child(_lbl("Giocatori:", 24, Color("e9dfc6")))
	for k in [2, 3, 4]:
		var b := _btn(str(k), func():
			prep["n"] = k
			_multi_componi()
			_multi_schermo(), 80)
		if prep["n"] != k:
			b.modulate = Color(1, 1, 1, 0.55)
		riga.add_child(b)
	riga.add_child(_btn_chiaro("Rimescola i politici", func():
		_multi_componi()
		_multi_schermo()))
	v.add_child(riga)
	v.add_child(_lbl("Tocca una carta per cambiare politico, il pulsante sotto per decidere chi lo guida. Il Governo iniziale è liberale: il liberale con il numero più basso è Primo Ministro, il conservatore con il numero più basso guida l'Opposizione, gli altri cominciano da Backbencher.", 21, Color("d9cdb0"), f_corsivo, 1500))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in prep["posti"].size():
		var ps: Dictionary = prep["posti"][i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		col.add_child(_carta("res://assets/carte/pol/%s.webp" % ps["pol"], 440, func():
			var amm := _politici_ammessi(ps["par"], prep["n"])
			var presi := []
			for q in prep["posti"]:
				if q != ps:
					presi.append(q["pol"])
			var k := amm.find(ps["pol"])
			for giro in amm.size():
				k = (k + 1) % amm.size()
				if not (amm[k] in presi):
					break
			ps["pol"] = amm[k]
			_multi_schermo()))
		var et := "Giocatore" if ps["tipo"] == "u" else "Intelligenza artificiale"
		if prep["online"] and ps["tipo"] == "u":
			et = "Giocatore online"
		col.add_child(_btn(et, func():
			ps["tipo"] = "cw" if ps["tipo"] == "u" else "u"
			_multi_schermo(), 315))
		h.add_child(col)
	v.add_child(h)
	var umani := 0
	for ps in prep["posti"]:
		if ps["tipo"] == "u":
			umani += 1
	var avvio := _btn("Crea la stanza" if prep["online"] else "Comincia la partita", func():
		if prep["online"]:
			_online_crea()
		else:
			_nuova_partita(_cfg_multi()), 420, 28)
	avvio.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avvio.disabled = umani == 0 or (prep["online"] and umani < 2)
	v.add_child(avvio)
	if prep["online"] and umani < 2:
		var nt := _lbl("Per giocare online servono almeno due posti da giocatore.", 20, Color("e9dfc6"))
		nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nt)

func _cfg_multi() -> Dictionary:
	var posti := []
	for ps in prep["posti"]:
		posti.append({"pol": ps["pol"], "tipo": ps["tipo"]})
	return {"modo": "multi", "seme": randi() % 1000000 + 1, "posti": posti}

# ---------- regole

func _regole() -> void:
	var v := _intestazione("Come si gioca", _menu)
	var testo := RichTextLabel.new()
	testo.bbcode_enabled = true
	testo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	testo.custom_minimum_size.x = 900
	testo.add_theme_font_size_override("normal_font_size", 23)
	testo.add_theme_font_size_override("bold_font_size", 23)
	testo.text = Guida.TESTO
	v.add_child(_pannello(testo, CARTA, 24))
	v.get_child(1).size_flags_vertical = Control.SIZE_EXPAND_FILL

# ------------------------------------------------------------------ partita

func _nuova_partita(cfg: Dictionary) -> void:
	m = Motore.nuova(cfg)
	visti_reg = 0
	ultimo_round_salvato = 0
	m.avanza()
	_tavolo()
	_dopo_mossa()

func _riprendi() -> void:
	var st := _carica_locale()
	if st.is_empty():
		_avviso("Su questo dispositivo non c'è una partita salvata. Se l'avevi salvata online, puoi scaricarla.", func(): _riprendi_cloud())
		return
	m = Motore.da_stato(st)
	visti_reg = m.s["reg"].size()
	ultimo_round_salvato = int(m.s["round"])
	_tavolo()
	_aggiorna()

func _riprendi_cloud() -> void:
	var st := await rete.carica_partita()
	if st.is_empty():
		_avviso("Nessuna partita salvata online per questo dispositivo." + ("\n" + rete.last_error if rete.last_error != "" else ""))
		return
	m = Motore.da_stato(st)
	visti_reg = m.s["reg"].size()
	_tavolo()
	_aggiorna()

func _salva_locale() -> void:
	if not online.is_empty() or m == null or not tut.is_empty():
		return
	var f := FileAccess.open(FILE_PARTITA, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(m.s))
	# una copia online a ogni round: la partita si può riprendere da un altro dispositivo con lo stesso accesso
	if int(m.s["round"]) != ultimo_round_salvato and OS.get_environment("PM_PROVA") == "":
		ultimo_round_salvato = int(m.s["round"])
		rete.salva_partita(m.s)

func _carica_locale() -> Dictionary:
	if not FileAccess.file_exists(FILE_PARTITA):
		return {}
	var f := FileAccess.open(FILE_PARTITA, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary and d.has("g") else {}

## Il posto di gioco è guidato da questo dispositivo?
func _mio(posto: int) -> bool:
	if not m.umano(posto):
		return false
	if online.is_empty():
		return true
	return posto in online["miei"]

func _tavolo() -> void:
	var s := _cambia_schermo()
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lato in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + lato, 10)
	s.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mc.add_child(v)
	# barra in alto
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 14)
	barra.add_child(_lbl("Primo Ministro", 34, ORO_CHIARO, f_titolo))
	barra_fase = _lbl("", 21, Color("f7eecd"), f_grassetto)
	barra_fase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_fase.clip_text = true
	barra.add_child(barra_fase)
	barra.add_child(_btn("Cambia tabellone", func():
		vista_originale = not vista_originale
		_applica_vista(), 220, 19))
	barra.add_child(_btn("Regole", func(): _regole_in_gioco(), 130, 19))
	barra.add_child(_btn("Menu", func(): _menu_in_gioco(), 120, 19))
	v.add_child(barra)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	# sinistra: giocatori
	var sx := ScrollContainer.new()
	sx.custom_minimum_size.x = 400
	sx.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_giocatori = VBoxContainer.new()
	box_giocatori.add_theme_constant_override("separation", 8)
	box_giocatori.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sx.add_child(box_giocatori)
	h.add_child(sx)
	# centro: disegni di legge e tabellone
	var cx := VBoxContainer.new()
	cx.add_theme_constant_override("separation", 8)
	cx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(cx)
	box_ddl = HBoxContainer.new()
	box_ddl.add_theme_constant_override("separation", 10)
	box_ddl.custom_minimum_size.y = 318
	cx.add_child(box_ddl)
	tab = Tabellone.new()
	tab.m = m
	tab.f_titolo = f_titolo
	tab.f_testo = f_testo
	tab.f_grassetto = f_grassetto
	tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.custom_minimum_size = Vector2(700, 560)
	cx.add_child(tab)
	tab_or = TabOriginale.new()
	tab_or.m = m
	tab_or.f_titolo = f_titolo
	tab_or.f_grassetto = f_grassetto
	tab_or.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_or.custom_minimum_size = Vector2(700, 560)
	tab_or.carta_toccata.connect(_ingrandisci)
	cx.add_child(tab_or)
	_applica_vista()
	# destra: decisioni e diario
	var dx := VBoxContainer.new()
	dx.add_theme_constant_override("separation", 8)
	dx.custom_minimum_size.x = 470
	h.add_child(dx)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 1.5
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box_azioni = VBoxContainer.new()
	box_azioni.add_theme_constant_override("separation", 8)
	box_azioni.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box_azioni)
	dx.add_child(_pannello(sc, CARTA, 12))
	dx.get_child(0).size_flags_vertical = Control.SIZE_EXPAND_FILL
	dx.get_child(0).size_flags_stretch_ratio = 1.5
	diario = RichTextLabel.new()
	diario.bbcode_enabled = true
	diario.scroll_following = true
	diario.custom_minimum_size = Vector2(430, 200)
	diario.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pd := _pannello(diario, Color("f6f0dc"), 10)
	pd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dx.add_child(pd)

## Due modi di vedere il tavolo: il tabellone originale tradotto (si ingrandisce e si sposta) o lo schema leggibile.
func _applica_vista() -> void:
	tab.visible = not vista_originale
	tab_or.visible = vista_originale
	box_ddl.visible = not vista_originale
	if m != null:
		_aggiorna_ddl()

func _menu_in_gioco() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(_lbl("Partita in corso", 30, ROSSO, f_titolo))
	v.add_child(_btn("Torna alla partita", _chiudi_modale, 420))
	if online.is_empty():
		v.add_child(_btn("Salva online (Firebase)", func():
			_chiudi_modale()
			var ok := await rete.salva_partita(m.s)
			_avviso("Partita salvata online: la puoi riprendere da questo dispositivo con «Riprendi la partita salvata»." if ok else "Salvataggio online non riuscito.\n" + rete.last_error), 420))
	v.add_child(_btn("Esci al menu principale", func():
		_chiudi_modale()
		_menu(), 420))
	_modale(_pannello(v, CARTA, 24))

func _regole_in_gioco() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var testo := RichTextLabel.new()
	testo.bbcode_enabled = true
	testo.custom_minimum_size = Vector2(1100, 720)
	testo.add_theme_font_size_override("normal_font_size", 22)
	testo.add_theme_font_size_override("bold_font_size", 22)
	testo.text = Guida.TESTO
	v.add_child(testo)
	var b := _btn("Chiudi", _chiudi_modale, 240)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	_modale(_pannello(v, CARTA, 20))

## Dopo ogni decisione: fa avanzare il motore, salva e ridisegna.
func _dopo_mossa() -> void:
	m.avanza()
	_salva_locale()
	_aggiorna()

func _aggiorna() -> void:
	if m == null or tab == null:
		return
	tab.m = m
	tab.queue_redraw()
	tab_or.m = m
	tab_or.queue_redraw()
	_aggiorna_barra()
	_aggiorna_giocatori()
	_aggiorna_ddl()
	_aggiorna_diario()
	_aggiorna_azioni()

const FASI := {"round": "Inizio round", "selezione": "Selezione dei disegni di legge", "dopo_selezione": "Selezione dei disegni di legge",
	"azioni": "Turni d'azione", "risolvi": "Il Primo Ministro risolve un disegno", "dopo_risolvi": "Il Primo Ministro risolve un disegno",
	"sfide": "Sfide", "elezioni": "Elezioni"}

func _aggiorna_barra() -> void:
	var t := "Round %d  |  %s  |  Governo %s" % [m.s["round"], FASI.get(m.s["fase"], ""), Testi.partito_agg(str(m.s["gov"]))]
	if m.multi():
		t += "  |  Patto %s" % ("in vigore" if m.s["patto"] else "rotto")
	t += "  |  Elezioni: %s" % ("rinviabili una volta" if m.s["marc"] else "obbligatorie alla prossima occasione")
	if not online.is_empty():
		t += "  |  Stanza %s" % online["code"]
	barra_fase.text = t

func _aggiorna_giocatori() -> void:
	_svuota(box_giocatori)
	var ordine := []
	for r in ["pm", "bbg", "opp", "bbo"]:
		var i := m._ruolo(r)
		if i >= 0:
			ordine.append(i)
	var compatto := ordine.size() > 2
	for i in ordine:
		box_giocatori.add_child(_scheda_giocatore(i, compatto))
	if not compatto:
		# in due c'è posto per la carta del politico automatico: è la sua "testa", conviene averla sott'occhio
		for i in ordine:
			var p: Dictionary = m.s["g"][i]
			if p["tipo"] == "cw":
				box_giocatori.add_child(_lbl("La carta di %s (tocca per ingrandire)" % p["nome"], 18, Color("e9dfc6"), f_corsivo))
				var c := _carta("res://assets/carte/cw/%s_%s.webp" % [p["pol"], p["ruolo"]], 520)
				c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				box_giocatori.add_child(c)

func _scheda_giocatore(i: int, compatto: bool) -> Control:
	var p: Dictionary = m.s["g"][i]
	var gov: bool = p["ruolo"] in ["pm", "bbg"]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var carta_perc := "res://assets/carte/pol/%s.webp" % p["pol"]
	if p["tipo"] == "cw" and p["ruolo"] in ["pm", "opp"]:
		carta_perc = "res://assets/carte/cw/%s_%s.webp" % [p["pol"], p["ruolo"]]
	var rit := _img("res://assets/carte/pol/%s_ritratto.webp" % p["pol"], 96 if compatto else 128)
	rit.mouse_filter = Control.MOUSE_FILTER_STOP
	rit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rit.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_ingrandisci(carta_perc))
	h.add_child(rit)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := _lbl(str(p["nome"]), 25, Tabellone.SEGNALINI[i % 4], f_titolo)
	nm.clip_text = true
	nm.custom_minimum_size.x = 220
	col.add_child(nm)
	var tipo := "Clockwork" if p["tipo"] == "cw" else "giocatore"
	col.add_child(_lbl("%s%s" % [Testi.ruolo(str(p["ruolo"])), " (dimesso)" if p["dim"] else ""], 19, ROSSO if gov else INCHIOSTRO, f_grassetto))
	col.add_child(_lbl("%s, %s" % [Testi.partito_agg(str(p["par"])), tipo], 17, BLU if p["par"] == "C" else ARANCIO))
	h.add_child(col)
	v.add_child(h)
	var pl: Dictionary = Dati.PLANCE[m.plancia(i)]
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 12)
	riga.add_child(_valore("res://assets/ui/standing.png", "Standing", "%d" % p["st"], "da %d a %d" % [pl["min"], pl["max"]]))
	riga.add_child(_valore("res://assets/ui/favore.png", "Favore", "%d" % p["fav"], ""))
	riga.add_child(_valore("", "Punti", "%d" % p["pv"], ""))
	v.add_child(riga)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	r2.add_child(_lbl("Cubi azione:", 18))
	var prossimi := m._cubi_reddito(i)
	for k in maxi(int(p["cubi"]), 0):
		var q := ColorRect.new()
		q.color = Color.WHITE
		q.custom_minimum_size = Vector2(20, 20)
		var bordo := ReferenceRect.new()
		bordo.border_color = INCHIOSTRO
		bordo.editor_only = false
		bordo.set_anchors_preset(Control.PRESET_FULL_RECT)
		q.add_child(bordo)
		r2.add_child(q)
	r2.add_child(_lbl("(%d al prossimo round)" % prossimi, 16, Color("5b4a44")))
	v.add_child(r2)
	var n_sost: int = p["sost"].size() + p["tenute"].size() + p["da_giocare"].size()
	var extra := "Sostenitori in mano: %d" % n_sost
	if not p["tenute"].is_empty():
		extra += " (%d tenuti per le elezioni)" % p["tenute"].size()
	if not p["carr"].is_empty():
		var nomi := []
		for c in p["carr"]:
			nomi.append(Testi.carriera(c, "gov" if gov else "opp"))
		extra += "\nIncarichi: " + ", ".join(nomi)
	v.add_child(_lbl(extra, 17, Color("3d322b"), null, 340))
	var colore := Color("f3e9cf") if gov else Color("e7e3d6")
	var pan := _pannello(v, colore, 10)
	var a = m.s["att"]
	if a != null and int(a["posto"]) == i:
		pan.add_theme_stylebox_override("panel", _sb(colore, Color("e0a020"), 5, 8, 8))
	return pan

func _valore(icona: String, nome_v: String, valore: String, nota: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	if icona != "":
		h.add_child(_img(icona, 44))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.add_child(_lbl(valore, 30, INCHIOSTRO, f_grassetto))
	v.add_child(_lbl(nome_v + (" " + nota if nota != "" else ""), 14, Color("5b4a44")))
	h.add_child(v)
	return h

func _probabilita(v: int) -> String:
	if v >= 350:
		return "passa di sicuro"
	if v == 340:
		return "passa 5 volte su 6"
	if v == 330:
		return "passa 1 volta su 2"
	if v == 320:
		return "passa 1 volta su 6"
	return "non si può votare (servono 320)"

func _aggiorna_ddl() -> void:
	_svuota(box_ddl)
	if m.s["tav"].is_empty():
		var l := _lbl("Nessun disegno di legge in discussione", 26, Color("e9dfc6"), f_corsivo)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box_ddl.add_child(l)
		return
	for b in m.s["tav"]:
		var d: Dictionary = Dati.ddl(b["id"])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(_carta("res://assets/carte/ddl/%s.webp" % b["id"], 290))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		var voti := m.voti(b)
		v.add_child(_lbl("%d" % voti, 46, VERDE if voti >= 340 else (ROSSO if voti < 320 else Color("9a6a00")), f_grassetto))
		v.add_child(_lbl("voti previsti", 17))
		var base := {"A": "tutti i deputati", "M": "i Moderati", "P": "i Partigiani"}
		v.add_child(_lbl("%s (%d) %s%d" % [base[d["tipo"]], m.s["mp"][d["tipo"]], "+" if int(b["ret"]) >= 0 else "", int(b["ret"])], 16, Color("3d322b"), null, 150))
		v.add_child(_lbl(_probabilita(voti), 17, INCHIOSTRO, f_corsivo, 150))
		v.add_child(_lbl("%d PV %s" % [d["pv"], "a entrambi" if d["mazzo"] == "X" else "al Governo"], 17, INCHIOSTRO, f_grassetto, 150))
		h.add_child(v)
		var pan := _pannello(h, CARTA, 8)
		pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box_ddl.add_child(pan)

func _aggiorna_diario() -> void:
	var reg: Array = m.s["reg"]
	var righe := []
	var da := maxi(0, reg.size() - 80)
	for k in range(da, reg.size()):
		var e: Dictionary = reg[k]
		var t := str(e["t"]).replace("[", "(").replace("]", ")")
		var nuovo: bool = k >= visti_reg
		if t.begins_with("Round "):
			righe.append("[b][color=#7a1418]%s[/color][/b]" % t)
		elif nuovo:
			righe.append("[b]%s[/b]" % t)
		else:
			righe.append(t)
	diario.text = "\n".join(righe)

# ------------------------------------------------------------------ decisioni del giocatore

func _rispondi(r: Dictionary) -> void:
	if m == null or m.s["att"] == null:
		return
	visti_reg = m.s["reg"].size()
	sub = ""
	sub_dati = {}
	scelti = []
	_chiudi_modale()
	if not online.is_empty():
		var n := int(m.s["n_dec"])
		if not m.lecita(Motore._norm(r)):
			return
		in_attesa = true
		_messaggio_attesa("Invio la decisione...")
		var ok := await rete.post_decision(online["code"], n, r)
		in_attesa = false
		if not ok:
			_avviso("Non riesco a inviare la decisione: controlla la connessione e riprova.\n" + rete.last_error, func(): _aggiorna())
			return
	if not m.rispondi(r):
		push_warning("risposta rifiutata: %s" % JSON.stringify(r))
	_dopo_mossa()

func _messaggio_attesa(t: String) -> void:
	_svuota(box_azioni)
	box_azioni.add_child(_lbl(t, 24, INCHIOSTRO, f_corsivo, 400))

func _titolo_azioni(t: String, sotto := "") -> void:
	box_azioni.add_child(_lbl(t, 27, ROSSO, f_titolo, 410))
	if sotto != "":
		box_azioni.add_child(_lbl(sotto, 19, INCHIOSTRO, null, 410))

func _aggiorna_azioni() -> void:
	_svuota(box_azioni)
	if m.s["fine"] != null:
		var fine: Dictionary = m.s["fine"]
		_titolo_azioni("Partita finita", str(fine["motivo"]))
		box_azioni.add_child(_lbl("Vince %s." % m.nome(int(fine["vince"])), 26, VERDE, f_grassetto, 410))
		box_azioni.add_child(_btn("Torna al menu", _menu, 410))
		return
	var a = m.s["att"]
	if a == null:
		return
	var chi := int(a["posto"])
	if not _mio(chi):
		_titolo_azioni("In attesa", "Tocca a %s (%s)." % [m.nome(chi), Testi.ruolo(str(m.s["g"][chi]["ruolo"]))])
		return
	if not tut.is_empty() and _ui_tutorial(a):
		return
	var umani_locali := 0
	for i in m.s["g"].size():
		if _mio(i):
			umani_locali += 1
	if umani_locali > 1:
		box_azioni.add_child(_lbl("Decide: %s" % m.nome(chi), 22, Tabellone.SEGNALINI[chi % 4], f_grassetto))
	match str(a["tipo"]):
		"azione": _ui_azione(chi)
		"pesca": _ui_pesca(chi)
		"proponi", "scegli": _ui_scegli(chi, a)
		"evento": _ui_evento(chi, a)
		"tieni": _ui_tieni(chi, a)
		"risolvi": _ui_risolvi(chi)
		"elezione": _ui_elezione(chi)
		"premio": _ui_premio(chi, a)
		_: _ui_si_no(chi, a)

# ---------- tutorial

func _testo_tutor(testo: String, px := 19) -> void:
	box_azioni.add_child(_lbl(testo, px, INCHIOSTRO, null, 410))

## Mostra la parte del tutorial per la decisione in attesa. Restituisce true se occupa tutto il pannello.
func _ui_tutorial(a: Dictionary) -> bool:
	var passo: int = tut["intro"]
	if passo < Tutor.INTRO.size():
		var p: Dictionary = Tutor.INTRO[passo]
		if not vista_originale:
			vista_originale = true
			_applica_vista()
		var zona := Rect2(p["r"][0], p["r"][1], p["r"][2], p["r"][3])
		tab_or.inquadra.call_deferred(zona)
		box_azioni.add_child(_lbl("Visita guidata  %d di %d" % [passo + 1, Tutor.INTRO.size()], 17, Color("5b4a44"), f_corsivo))
		_titolo_azioni(str(p["t"]))
		_testo_tutor(str(p["x"]), 20)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		if passo > 0:
			h.add_child(_btn_chiaro("Indietro", func():
				tut["intro"] = passo - 1
				_aggiorna_azioni(), 150))
		h.add_child(_btn("Avanti" if passo < Tutor.INTRO.size() - 1 else "Comincia la partita", func():
			tut["intro"] = passo + 1
			if passo + 1 >= Tutor.INTRO.size():
				tab_or.inquadra(Rect2(0, 0, 6600, 5100))
			_aggiorna_azioni(), 250))
		box_azioni.add_child(h)
		return true
	var c := Tutor.consiglio(m)
	var r: Dictionary = c["r"]
	var guidato: bool = int(m.s["round"]) <= Tutor.ROUND_GUIDATI
	var lezione := ""
	for k in Tutor.lezioni_per(m, str(a["tipo"]), r):
		if not (k in tut["visti"]):
			lezione = k
			break
	if lezione != "":
		# la lezione si legge con calma: un passo alla volta
		var testo: String = Tutor.LEZIONI[lezione]
		var a_capo := testo.find("\n")
		box_azioni.add_child(_lbl("Lezione", 17, Color("5b4a44"), f_corsivo))
		_titolo_azioni(testo.substr(0, 1) + testo.substr(1, a_capo - 1).to_lower() if a_capo > 0 else "Lezione")
		_testo_tutor(testo.substr(a_capo + 1) if a_capo > 0 else testo, 20)
		_mostra_contesto(a)
		box_azioni.add_child(_btn("Ho capito", func():
			tut["visti"].append(lezione)
			_aggiorna_azioni(), 410))
		return true
	var pan := VBoxContainer.new()
	pan.add_theme_constant_override("separation", 6)
	pan.add_child(_lbl("Il consiglio del tutor" if not guidato else "Round guidato: fai questa mossa", 21, VERDE, f_grassetto, 380))
	pan.add_child(_lbl(str(c["perche"]), 18, INCHIOSTRO, f_corsivo, 380))
	var b := _btn_testo_lungo(Tutor.descrivi(m, r), func(): _rispondi(r))
	b.custom_minimum_size.x = 380
	pan.add_child(b)
	box_azioni.add_child(_pannello(pan, Color("e4eed8"), 10))
	if guidato:
		_mostra_contesto(a)
		return true
	box_azioni.add_child(_btn_chiaro("Chiudi il tutorial e gioca da solo", func():
		tut = {}
		_aggiorna_azioni(), 410))
	return false

## Le carte di cui parla la decisione, da guardare mentre si legge.
func _mostra_contesto(a: Dictionary) -> void:
	match str(a["tipo"]):
		"evento":
			var c := _carta("res://assets/carte/ev/%d.webp" % int(a["n"]), 330)
			c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box_azioni.add_child(c)
		"scegli", "proponi":
			_fila_ddl(m.s["sel"]["riv"] if a["tipo"] == "scegli" else m.s["sel"]["mano"], false)
		"pesca":
			var sel: Dictionary = m.s["sel"]
			_fila_ddl(sel["riv"], false)
		"tieni":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			for c in a["carte"]:
				h.add_child(_carta("res://assets/carte/sost/%d.webp" % int(c), 280))
			box_azioni.add_child(h)
		"azione":
			var p: Dictionary = m.s["g"][int(a["posto"])]
			if not p["sost"].is_empty():
				var fl := HFlowContainer.new()
				fl.custom_minimum_size.x = 410
				for c in p["sost"]:
					fl.add_child(_carta("res://assets/carte/sost/%d.webp" % int(c), 184))
				box_azioni.add_child(fl)

func _ui_si_no(chi: int, a: Dictionary) -> void:
	var tipo := str(a["tipo"])
	var titolo := ""
	var testo := ""
	var si := "Sì"
	var no := "No"
	match tipo:
		"sostituisci":
			titolo = "Sostituire il Primo Ministro?"
			testo = "Puoi far subentrare %s, una sola volta nella partita: lo Standing torna a 11, i disegni in discussione vengono tolti e perdi 6 Punti Vittoria. Conviene quando l'Opposizione sta per sfidarti." % Dati.politico(str(m.s["cfg"]["riserva"]))["nome"]
			si = "Sostituisci"
			no = "Resto io"
		"sfida":
			var c := int(a["contro"])
			titolo = "Lanciare la sfida?"
			testo = "Hai Standing e Favore sufficienti per prendere il posto di %s (%s)." % [m.nome(c), Testi.ruolo(str(m.s["g"][c]["ruolo"]))]
			if m.s["g"][chi]["ruolo"] == "opp":
				testo += " Diventi Primo Ministro (6 PV), i disegni in discussione vengono tolti e si va subito alle elezioni per contare i tuoi deputati: previsti %d seggi." % m.seggi_previsti(str(m.s["g"][chi]["par"]))
			si = "Sfida"
			no = "Non ora"
		"reale":
			titolo = "Interferenza Reale"
			testo = "Sua Maestà preferisce te e ti offre di formare un Governo di minoranza con %d seggi." % (int(a["seggi"]) if chi == m.pm() else Dati.SEGGI - int(a["seggi"]))
			si = "Accetta"
			no = "Rifiuta"
		"patto_rompi":
			titolo = "Rompere il Patto?"
			testo = "Finché dura il Patto, Governo e Opposizione dividono tutti i Punti Vittoria e non puoi attaccare i disegni di legge. Rompendolo cominci a segnare i tuoi punti a parte."
			si = "Rompi il Patto"
			no = "Mantieni il Patto"
		"patto_riparti":
			titolo = "Ripristinare il Patto?"
			testo = "Sul tavolo ci sono tre disegni trasversali: puoi tornare a dividere i punti con il Governo."
		"accordo":
			var b: Dictionary = m.s["tav"][int(a["b"])]
			titolo = "Accordo sul disegno di legge"
			testo = "%s ti chiede di sostenere %s. Se accetti passa senza voto, con i suoi effetti, e l'Opposizione guadagna 5 Punti Vittoria in più." % [m.nome(m.pm()), Testi.ddl(b["id"])]
			si = "Accetta"
			no = "Rifiuta"
		"rientro":
			titolo = "Rientro nel Governo"
			testo = "%s chiede di rientrare nel Governo." % m.nome(int(a["bb"]))
	_titolo_azioni(titolo, testo)
	box_azioni.add_child(_btn(si, func(): _rispondi({"t": tipo, "si": true}), 410))
	box_azioni.add_child(_btn_chiaro(no, func(): _rispondi({"t": tipo, "si": false}), 410))

func _ui_premio(_chi: int, a: Dictionary) -> void:
	_titolo_azioni("Carta Dibattito", "Il disegno su cui avevi puntato è stato risolto. Scegli:")
	for o in a["opz"]:
		box_azioni.add_child(_btn(Testi.premio(str(o)), func(): _rispondi({"t": "premio", "o": o}), 410))

func _ui_pesca(chi: int) -> void:
	var sel: Dictionary = m.s["sel"]
	var del_pm: bool = chi == m.pm() and int(sel["ip"]) >= sel["prop"].size()
	var quante: int = int(sel["n_pm"]) - int(sel["pm_pesc"]) if del_pm else int(sel["prop"][sel["ip"]][1]) - sel["mano"].size()
	_titolo_azioni("Pesca i disegni di legge", "Ne devi pescare ancora %d. Puoi guardare ogni carta prima di decidere da quale mazzo pescare la prossima." % quante)
	var nomi := {"X": "Trasversali (2-3 PV a entrambi)", "C": "Conservatori (PV solo al Governo)", "L": "Liberali (PV solo al Governo)"}
	for o in m.opzioni():
		var k := str(o["m"])
		box_azioni.add_child(_btn("Pesca dai %s" % nomi[k], func(): _rispondi({"t": "pesca", "m": k}), 410, 19))
	var carte: Array = sel["riv"] if del_pm else sel["mano"]
	_fila_ddl(carte, false)

func _fila_ddl(carte: Array, selezionabili: bool) -> void:
	var g := HFlowContainer.new()
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	g.custom_minimum_size.x = 410
	for id in carte:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var c := _carta("res://assets/carte/ddl/%s.webp" % id, 180)
		col.add_child(c)
		var info := _lbl("%d voti" % m.voti_iniziali(id), 17, INCHIOSTRO, f_grassetto)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(info)
		if selezionabili:
			var b := _btn("Scelto" if id in scelti else "Scegli", func():
				if id in scelti:
					scelti.erase(id)
				else:
					scelti.append(id)
				_aggiorna_azioni(), 128, 17)
			b.custom_minimum_size.y = 36
			if not (id in scelti):
				b.add_theme_stylebox_override("normal", _sb(Color("fbf6e6"), ORO))
				b.add_theme_color_override("font_color", INCHIOSTRO)
			col.add_child(b)
		g.add_child(col)
	box_azioni.add_child(g)

func _ui_scegli(_chi: int, a: Dictionary) -> void:
	var n := int(a["n"])
	var proponi: bool = a["tipo"] == "proponi"
	if proponi:
		_titolo_azioni("Proponi un disegno di legge", "Scegline %d da proporre al Primo Ministro: se lo mette in discussione guadagni 1 Punto Vittoria. Tocca una carta per ingrandirla." % n)
	else:
		_titolo_azioni("Scegli i disegni di legge", "Mettine %d in discussione. Sotto ogni carta i voti che avrebbe adesso: per passare ne servono 330. Tocca una carta per ingrandirla." % n)
	var carte: Array = m.s["sel"]["mano"] if proponi else m.s["sel"]["riv"]
	_fila_ddl(carte, true)
	var b := _btn("Conferma (%d di %d)" % [scelti.size(), n], func(): _rispondi({"t": a["tipo"], "ids": scelti.duplicate()}), 410)
	b.disabled = scelti.size() != n
	box_azioni.add_child(b)

func _ui_evento(chi: int, a: Dictionary) -> void:
	var n := int(a["n"])
	var ev: Dictionary = DatiGen.EVENTI[n - 1]
	_titolo_azioni("Evento", "Hai %d cubi azione: quelli spesi qui non li avrai per le azioni." % m.s["g"][chi]["cubi"])
	var c := _carta("res://assets/carte/ev/%d.webp" % n, 330)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box_azioni.add_child(c)
	for o in ev["opz"].size():
		var op: Dictionary = ev["opz"][o]
		var costo := int(op["costo"])
		var t := "%s%s: %s" % [Testi.evento_opz(n, o), "" if costo == 0 else " (%d cub%s)" % [costo, "o" if costo == 1 else "i"], m.descrivi_effetti(op["eff"])]
		var b := _btn_testo_lungo(t, func(): _rispondi({"t": "ev", "o": o}))
		b.disabled = costo > int(m.s["g"][chi]["cubi"])
		box_azioni.add_child(b)

## Pulsante con testo lungo: va a capo dentro una larghezza fissa.
func _btn_testo_lungo(testo: String, azione: Callable, chiaro := false) -> Button:
	var b := _btn_chiaro("", azione, 410) if chiaro else _btn("", azione, 410)
	var l := _lbl(testo, 19, INCHIOSTRO if chiaro else Color("f7eecd"), f_grassetto, 380)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 12
	l.offset_right = -12
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	var righe := ceili(f_grassetto.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x / 370.0)
	b.custom_minimum_size.y = maxf(50.0, 22.0 + righe * 25.0)
	return b

func _ui_tieni(_chi: int, a: Dictionary) -> void:
	_titolo_azioni("Due Sostenitori", "Tocca quello che vuoi tenere: l'altro viene scartato.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for c in a["carte"]:
		h.add_child(_carta("res://assets/carte/sost/%d.webp" % int(c), 280, func(): _rispondi({"t": "tieni", "c": int(c)})))
	box_azioni.add_child(h)

func _ui_risolvi(chi: int) -> void:
	_titolo_azioni("Risolvi un disegno di legge", "Devi metterne uno ai voti oppure ritirarlo. Bocciato: perdi 2 Standing, il Capo dell'Opposizione ne guadagna 2 e 3 PV. Ritirato: 1 Standing ciascuno e 2 PV.")
	for b in m.s["tav"].size():
		var bd: Dictionary = m.s["tav"][b]
		var v := m.voti(bd)
		box_azioni.add_child(_lbl("%s - %d voti" % [Testi.ddl_titolo(bd["id"]), v], 20, INCHIOSTRO, f_grassetto, 410))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var bv := _btn("Vota", func(): _rispondi({"t": "voto", "b": b}), 124, 19)
		bv.disabled = v < 320
		bv.tooltip_text = _probabilita(v)
		h.add_child(bv)
		h.add_child(_btn_chiaro("Ritira", func(): _rispondi({"t": "ritiro", "b": b}), 124))
		if m.multi():
			h.add_child(_btn_chiaro("Accordo", func(): _rispondi({"t": "accordo", "b": b}), 140))
		box_azioni.add_child(h)
		box_azioni.add_child(_lbl(_probabilita(v), 17, Color("5b4a44"), f_corsivo))
	if m.multi():
		box_azioni.add_child(_lbl("Accordo: chiedi al Capo dell'Opposizione di sostenere il disegno. Se accetta passa senza voto e l'Opposizione fa 5 PV.", 17, Color("5b4a44"), f_corsivo, 410))
	var _c := chi

func _ui_elezione(chi: int) -> void:
	var par := str(m.s["g"][chi]["par"])
	var prev := m.seggi_previsti(par)
	_titolo_azioni("Elezioni", "Non ci sono più disegni in discussione. Il tuo partito è dato a %d seggi (ne servono 330), con un'Incertezza fino a 12 in più o in meno. Puoi rinviare una sola volta." % prev)
	box_azioni.add_child(_btn("Indici le elezioni", func(): _rispondi({"t": "elezione"}), 410))
	for o in m.opzioni():
		if o["t"] == "rinvia":
			box_azioni.add_child(_btn_chiaro("Rinvia le elezioni", func(): _rispondi({"t": "rinvia"}), 410))

# ---------- il turno d'azione

func _gruppi_azioni(chi: int) -> Dictionary:
	var g := {}
	for o in m.azioni_possibili(chi):
		var k := str(o["t"])
		if not g.has(k):
			g[k] = []
		g[k].append(o)
	return g

func _ui_azione(chi: int) -> void:
	var p: Dictionary = m.s["g"][chi]
	var g := _gruppi_azioni(chi)
	if sub != "":
		_ui_sotto_azione(chi, g)
		return
	var cubi := int(p["cubi"])
	_titolo_azioni("Il tuo turno", "Hai %d cub%s azione. Ogni azione costa un cubo; giocare un Sostenitore è gratis." % [cubi, "o" if cubi == 1 else "i"])
	var voci := [["camp", "Campagna", "sali in un settore dell'elettorato"], ["dib", "Dibattito", "sposta i voti di un disegno"],
		["lus", "Lusinga", "guadagna il Favore della Regina"], ["hob", "Salotti", "pesca un Sostenitore"],
		["inf", "Influenza", "sposta deputati fra Moderati e Partigiani"], ["carr", "Incarichi", "azioni delle carte Carriera"],
		["cdib", "Carta Dibattito", "punta la tua reputazione su un disegno"]]
	for vc in voci:
		if g.has(vc[0]):
			box_azioni.add_child(_btn_testo_lungo("%s: %s" % [vc[1], vc[2]], func():
				sub = vc[0]
				_aggiorna_azioni()))
	if g.has("rientra"):
		box_azioni.add_child(_btn_testo_lungo("Chiedi di rientrare nel Governo: se il Primo Ministro accetta recupera 2 Standing", func(): _rispondi({"t": "rientra"}), true))
	if g.has("dimetti"):
		box_azioni.add_child(_btn_testo_lungo("Dimissioni: spendi tutti i cubi, il Primo Ministro perde 2 Standing", func(): _rispondi({"t": "dimetti"}), true))
	if not p["sost"].is_empty():
		box_azioni.add_child(_lbl("I tuoi Sostenitori (tocca per giocarne uno):", 20, INCHIOSTRO, f_grassetto, 410))
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		fl.add_theme_constant_override("v_separation", 6)
		fl.custom_minimum_size.x = 410
		for c in p["sost"]:
			fl.add_child(_carta("res://assets/carte/sost/%d.webp" % int(c), 184, func(): _apri_sostenitore(chi, int(c))))
		box_azioni.add_child(fl)
	if g.has("fine"):
		var bf := _btn("Fine del turno", func(): _fine_turno(chi), 410)
		box_azioni.add_child(bf)
	else:
		box_azioni.add_child(_lbl("Puoi tenere al massimo 4 Sostenitori: giocane o scartane uno per chiudere il turno.", 18, ROSSO, f_corsivo, 410))

func _fine_turno(chi: int) -> void:
	if int(m.s["g"][chi]["cubi"]) > 0:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		v.add_child(_lbl("Hai ancora cubi azione: quelli non spesi vanno persi. Chiudo il turno lo stesso?", 24, INCHIOSTRO, null, 560))
		v.add_child(_btn("Sì, chiudi il turno", func(): _rispondi({"t": "fine"}), 560))
		v.add_child(_btn_chiaro("No, continuo", _chiudi_modale, 560))
		_modale(_pannello(v, CARTA, 24))
	else:
		_rispondi({"t": "fine"})

func _ui_sotto_azione(chi: int, g: Dictionary) -> void:
	var p: Dictionary = m.s["g"][chi]
	var par := str(p["par"])
	var opz: Array = g.get(sub, [])
	box_azioni.add_child(_btn_chiaro("Torna alle azioni", func():
		sub = ""
		sub_dati = {}
		_aggiorna_azioni(), 410))
	match sub:
		"camp":
			_titolo_azioni("Campagna", "Scegli il settore. Fra parentesi i punti Popolarità che guadagni.")
			for o in opz:
				var k := str(o["s"])
				var tr: Array = Dati.TRACCE[k][par]["p"]
				var da: int = m.s["pop"][par][k]
				var a := mini(da + int(o["n"]), tr.size() - 1)
				var t := "%s: %d gradin%s (+%d punti)" % [Dati.NOME_SETTORE[k], int(o["n"]), "o" if int(o["n"]) == 1 else "i", int(tr[a]) - int(tr[da])]
				var b := _btn(t, func(): _rispondi(o), 410, 20)
				b.disabled = a == da
				b.mouse_entered.connect(func():
					tab.evidenzia = {"s": k, "p": par}
					tab.queue_redraw())
				b.mouse_exited.connect(func():
					tab.evidenzia = {}
					tab.queue_redraw())
				box_azioni.add_child(b)
		"dib":
			_titolo_azioni("Dibattito", "Scegli il disegno e di quanto spostare i voti previsti.")
			for b in m.s["tav"].size():
				var bd: Dictionary = m.s["tav"][b]
				box_azioni.add_child(_lbl("%s - %d voti" % [Testi.ddl_titolo(bd["id"]), m.voti(bd)], 20, INCHIOSTRO, f_grassetto, 410))
				var h := HBoxContainer.new()
				h.add_theme_constant_override("separation", 6)
				for o in opz:
					if int(o["b"]) == b:
						var v := int(o["v"])
						var bt := _btn("%+d" % v, func(): _rispondi(o), 94, 22) if v > 0 else _btn_chiaro("%+d" % v, func(): _rispondi(o), 94)
						h.add_child(bt)
				box_azioni.add_child(h)
		"lus":
			_titolo_azioni("Lusinga", "Il Favore decide le sfide e le elezioni in bilico.")
			for o in opz:
				var su := int(o["chi"])
				var t := "Il tuo Favore %+d" % int(o["v"]) if su == chi else "Favore di %s %+d" % [m.nome(su), int(o["v"])]
				box_azioni.add_child(_btn(t, func(): _rispondi(o), 410, 20))
		"hob":
			_titolo_azioni("Salotti", "I Sostenitori si giocano gratis nel tuo turno.")
			for o in opz:
				var t := "Pesca un Sostenitore" if int(o["n"]) == 1 else "Pescane due e tienine uno"
				box_azioni.add_child(_btn(t, func(): _rispondi(o), 410, 20))
		"inf":
			_titolo_azioni("Influenza", "I disegni M contano i Moderati, i disegni P i Partigiani. Ora: %d Moderati, %d Partigiani." % [m.s["mp"]["M"], m.s["mp"]["P"]])
			for o in opz:
				var v := int(o["v"])
				var t := "%d deputati diventano %s" % [absi(v), "Partigiani" if v > 0 else "Moderati"]
				box_azioni.add_child(_btn(t, func(): _rispondi(o), 410, 20))
		"carr":
			_titolo_azioni("Incarichi", "Le azioni delle tue carte Carriera.")
			for o in opz:
				box_azioni.add_child(_btn_testo_lungo(_testo_carriera(chi, o), func(): _rispondi(o)))
		"cdib":
			var su: bool = p["ruolo"] == "bbg" or m.s["patto"]
			_titolo_azioni("Carta Dibattito", "Costa %d cub%s. Sposti il disegno di 10 voti %s e, quando sarà risolto, ricevi un premio o una penalità." % [1 if int(p["st"]) <= 2 else 2, "o" if int(p["st"]) <= 2 else "i", "in su" if su else "in giù"])
			for o in opz:
				var bd: Dictionary = m.s["tav"][int(o["b"])]
				box_azioni.add_child(_btn_testo_lungo("%s - %d voti" % [Testi.ddl_titolo(bd["id"]), m.voti(bd)], func(): _rispondi(o)))

func _testo_carriera(chi: int, o: Dictionary) -> String:
	match str(o["c"]):
		"cw":
			if o.has("v"):
				return "Capogruppo: 10 deputati diventano %s" % ("Partigiani" if int(o["v"]) > 0 else "Moderati")
			return "Capogruppo (2 cubi): -30 voti a %s" % Testi.ddl_titolo(m.s["tav"][int(o["b"])]["id"])
		"cc":
			var pol: Dictionary = Dati.politico(m.s["g"][chi]["pol"])
			return "Campagna in %s (%s)" % [Dati.NOME_SETTORE[o["s"]], "1 cubo" if str(o["s"]) in pol["set"] else "2 cubi"]
		"pc":
			if o.has("chi"):
				return "Consigliere privato: il tuo Favore +1"
			return "Consigliere privato (2 cubi): Favore +1 a %s, -1 a %s" % [m.nome(int(o["su"])), m.nome(int(o["giu"]))]
	return str(o)

func _apri_sostenitore(chi: int, c: int) -> void:
	var card: Dictionary = m.sostenitore(c)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.add_child(_img("res://assets/carte/sost/%d.webp" % c, 660))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 660)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	h.add_child(sc)
	var raddoppia: bool = c in m.s["turno"].get("doppi", [])
	v.add_child(_lbl(str(card["nome"]), 32, ROSSO, f_titolo))
	v.add_child(_lbl(Testi.sost_ruolo(c) + (". Decano della Camera: effetti raddoppiati." if raddoppia else ""), 19, Color("5b4a44"), f_corsivo, 560))
	var tutte := m.azioni_possibili(chi).filter(func(o): return o["t"] == "sost" and int(o["c"]) == c)
	for lato in 2:
		v.add_child(_lbl("%s effetto" % ("Primo" if lato == 0 else "Secondo"), 22, INCHIOSTRO, f_grassetto))
		var qui := tutte.filter(func(o): return int(o["o"]) == lato)
		if qui.is_empty():
			v.add_child(_lbl("Non giocabile adesso.", 19, Color("5b4a44"), f_corsivo))
		for o in qui:
			var b := _btn("", func(): _rispondi(o), 560)
			var l := _lbl(m._descrivi_sost(chi, card["opz"][lato], o), 19, Color("f7eecd"), f_grassetto, 530)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			l.offset_left = 12
			l.offset_right = -12
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			b.add_child(l)
			var righe := ceili(f_grassetto.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x / 520.0)
			b.custom_minimum_size.y = maxf(46.0, 22.0 + righe * 25.0)
			v.add_child(b)
	v.add_child(_spazio(6))
	v.add_child(_btn_chiaro("Scarta senza effetto", func(): _rispondi({"t": "scarta", "c": c}), 560))
	v.add_child(_btn_chiaro("Chiudi", _chiudi_modale, 560))
	_modale(_pannello(h, CARTA, 20))

# ------------------------------------------------------------------ online

func _online_menu() -> void:
	var v := _intestazione("Gioca online", _menu)
	var c := CenterContainer.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(c)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	c.add_child(col)
	var saved := rete.load_session()
	col.add_child(_lbl("Il tuo nome", 24, Color("f7eecd")))
	var nome_e := LineEdit.new()
	nome_e.text = str(saved.get("name", prep.get("nome", "")))
	nome_e.max_length = 20
	nome_e.custom_minimum_size = Vector2(520, 54)
	col.add_child(nome_e)
	col.add_child(_btn("Crea una stanza", func():
		if nome_e.text.strip_edges() == "":
			_avviso("Scrivi il tuo nome.")
			return
		prep["nome"] = nome_e.text.strip_edges()
		rete._save({"name": prep["nome"]})
		_prepara_multi(true), 520, 26))
	col.add_child(_spazio(10))
	col.add_child(_lbl("Codice della stanza (4 lettere)", 24, Color("f7eecd")))
	var cod := LineEdit.new()
	cod.text = str(saved.get("room", ""))
	cod.max_length = 4
	cod.custom_minimum_size = Vector2(520, 54)
	col.add_child(cod)
	col.add_child(_btn("Entra nella stanza", func():
		if nome_e.text.strip_edges() == "" or cod.text.strip_edges().length() != 4:
			_avviso("Scrivi il tuo nome e il codice di 4 lettere.")
			return
		prep["nome"] = nome_e.text.strip_edges()
		rete._save({"name": prep["nome"]})
		_online_entra(cod.text.strip_edges().to_upper()), 520, 26))
	col.add_child(_lbl("Chi crea la stanza sceglie politici e posti; gli amici entrano con il codice. Se la connessione cade si rientra con lo stesso nome e lo stesso codice.", 20, Color("d9cdb0"), f_corsivo, 520))

func _online_crea() -> void:
	var cfg := _cfg_multi()
	var s := _cambia_schermo()
	var l := _titolo_grande("Creo la stanza...", 40)
	l.set_anchors_preset(Control.PRESET_CENTER)
	s.add_child(l)
	var code := await rete.create_room(str(prep["nome"]), cfg)
	if code == "":
		_avviso("Non riesco a creare la stanza.\n" + rete.last_error, func(): _online_menu())
		return
	rete.remember_room(code, 0)
	online = {"code": code, "seat": 0, "host": true, "cfg": cfg, "miei": []}
	_lobby()

func _online_entra(code: String) -> void:
	var s := _cambia_schermo()
	var l := _titolo_grande("Entro nella stanza %s..." % code, 40)
	l.set_anchors_preset(Control.PRESET_CENTER)
	s.add_child(l)
	var seat := await rete.join_room(code, str(prep["nome"]), 4)
	if seat < 0:
		_avviso("Stanza piena." if seat == -1 else "Stanza non trovata, oppure la partita è già cominciata senza di te.\n" + rete.last_error, func(): _online_menu())
		return
	rete.remember_room(code, seat)
	var cfg = JSON.parse_string(str(rete.last_room.get("cfg", "{}")))
	online = {"code": code, "seat": seat, "host": seat == 0 and rete.last_room.get("host", "") == rete.uid, "cfg": cfg if cfg is Dictionary else {}, "miei": []}
	_lobby()

## I posti di gioco "umani", nell'ordine: il k-esimo va al k-esimo giocatore entrato nella stanza.
func _posti_umani(cfg: Dictionary) -> Array:
	var out := []
	for i in cfg["posti"].size():
		if cfg["posti"][i]["tipo"] == "u":
			out.append(i)
	return out

var lobby_box: VBoxContainer
var in_lobby := false

func _lobby() -> void:
	var v := _intestazione("Stanza %s" % online["code"], func():
		in_lobby = false
		_online_menu())
	v.add_child(_lbl("Dai questo codice agli amici: entrano da «Gioca online» con «Entra nella stanza».", 24, Color("f7eecd"), null, 1400))
	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 10)
	lobby_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(lobby_box)
	in_lobby = true
	tempo_poll = 99.0

func _lobby_aggiorna(room: Dictionary) -> void:
	if not in_lobby or lobby_box == null:
		return
	_svuota(lobby_box)
	var cfg: Dictionary = online["cfg"]
	var seats := Rete._as_dict(room.get("seats", {}))
	var umani := _posti_umani(cfg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var pieni := 0
	for i in cfg["posti"].size():
		var ps: Dictionary = cfg["posti"][i]
		var col := VBoxContainer.new()
		col.add_child(_img("res://assets/carte/pol/%s.webp" % ps["pol"], 380))
		var chi := "Intelligenza artificiale"
		if ps["tipo"] == "u":
			var k := umani.find(i)
			if seats.has(str(k)):
				chi = str(seats[str(k)].get("name", "?"))
				pieni += 1
			else:
				chi = "posto libero"
		var e := _lbl(chi, 24, Color("f7eecd"), f_grassetto)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(e)
		h.add_child(col)
	lobby_box.add_child(h)
	if online["host"]:
		var b := _btn("Comincia la partita", func(): _online_avvia(), 420, 28)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.disabled = pieni < umani.size()
		lobby_box.add_child(b)
		if pieni < umani.size():
			var nt := _lbl("In attesa che tutti i posti da giocatore siano occupati (%d su %d)." % [pieni, umani.size()], 21, Color("e9dfc6"))
			nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lobby_box.add_child(nt)
	else:
		var nt := _lbl("In attesa che chi ha creato la stanza cominci la partita...", 22, Color("e9dfc6"), f_corsivo)
		nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lobby_box.add_child(nt)

func _online_avvia() -> void:
	var cfg: Dictionary = online["cfg"]
	var room := await rete.room(online["code"])
	var seats := Rete._as_dict(room.get("seats", {}))
	var umani := _posti_umani(cfg)
	for k in umani.size():
		if seats.has(str(k)):
			cfg["posti"][umani[k]]["nome"] = str(seats[str(k)].get("name", ""))
	cfg["seme"] = randi() % 1000000 + 1
	if not await rete.start_room(online["code"], cfg):
		_avviso("Non riesco ad avviare la partita.\n" + rete.last_error)

func _online_comincia(game: Dictionary) -> void:
	in_lobby = false
	online["cfg"] = game
	var umani := _posti_umani(game)
	online["miei"] = [umani[int(online["seat"])]] if int(online["seat"]) < umani.size() else []
	m = Motore.nuova(game)
	visti_reg = 0
	m.avanza()
	_tavolo()
	_aggiorna()
	tempo_poll = 99.0

func _process(dt: float) -> void:
	if online.is_empty() or in_attesa:
		return
	tempo_poll += dt
	if tempo_poll < 1.6:
		return
	tempo_poll = 0.0
	if in_lobby:
		in_attesa = true
		var room := await rete.room(online["code"])
		in_attesa = false
		if room.is_empty() or not in_lobby:
			return
		if str(room.get("status", "")) == "playing" and room.has("game"):
			var game = JSON.parse_string(str(room["game"]))
			if game is Dictionary:
				_online_comincia(game)
			return
		_lobby_aggiorna(room)
		return
	if m == null or m.s["fine"] != null:
		return
	var a = m.s["att"]
	if a == null or _mio(int(a["posto"])):
		return
	# aspetto la decisione di un altro giocatore
	in_attesa = true
	var decs := await rete.get_decisions(online["code"], int(m.s["n_dec"]))
	in_attesa = false
	var cambiato := false
	while m != null and decs.has(int(m.s["n_dec"])) and m.s["att"] != null and not _mio(int(m.s["att"]["posto"])):
		visti_reg = m.s["reg"].size() if not cambiato else visti_reg
		if not m.rispondi(decs[int(m.s["n_dec"])]):
			break
		m.avanza()
		cambiato = true
	if cambiato:
		_aggiorna()

# ------------------------------------------------------------------ prove automatiche (screenshot)

func _prova(quale: String) -> void:
	var cfg := {"modo": "cw2", "seme": 7, "umano_pm": true, "posti": [{"pol": "gladstone", "tipo": "u"}, {"pol": "disraeli", "tipo": "cw"}]}
	match quale:
		"menu":
			_menu()
			return
		"solitario":
			_prepara_solitario()
			return
		"multi":
			_prepara_multi(false)
			return
		"regole":
			_regole()
			return
		"online":
			_online_menu()
			return
		"tutorial":
			_avvia_tutorial()
			var n_intro := int(OS.get_environment("PM_INTRO")) if OS.get_environment("PM_INTRO") != "" else 0
			tut["intro"] = n_intro
			for k in int(OS.get_environment("PM_PASSI")) if OS.get_environment("PM_PASSI") != "" else 0:
				if m.s["att"] == null or m.s["fine"] != null:
					break
				tut["visti"] = Tutor.LEZIONI.keys() if OS.get_environment("PM_LEZIONI") == "no" else tut["visti"]
				m.rispondi(Tutor.consiglio(m)["r"])
				m.avanza()
			_aggiorna()
			return
		"multi4":
			cfg = {"modo": "multi", "seme": 5, "posti": [{"pol": "melbourne", "tipo": "u"}, {"pol": "derby", "tipo": "cw"}, {"pol": "gladstone", "tipo": "cw"}, {"pol": "disraeli", "tipo": "cw"}]}
	m = Motore.nuova(cfg)
	m.avanza()
	var passi := int(OS.get_environment("PM_PASSI")) if OS.get_environment("PM_PASSI") != "" else 0
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("new URLSearchParams(location.search).get('passi') || '0'")
		passi = int(str(q))
	var g := RandomNumberGenerator.new()
	g.seed = 3
	for k in passi:
		var a = m.s["att"]
		if a == null or m.s["fine"] != null:
			break
		if a["tipo"] in ["scegli", "proponi"]:
			var fonte: Array = (m.s["sel"]["riv"] if a["tipo"] == "scegli" else m.s["sel"]["mano"]).duplicate()
			m.rispondi({"t": a["tipo"], "ids": fonte.slice(0, int(a["n"]))})
		else:
			var op := m.opzioni()
			var utili := op.filter(func(x): return not (x["t"] in ["scarta", "dimetti", "sost"]))
			if utili.is_empty():
				utili = op
			m.rispondi(utili[g.randi() % utili.size()])
		m.avanza()
	_tavolo()
	_aggiorna()
	var ap := OS.get_environment("PM_APRI")
	if OS.get_environment("PM_VISTA") == "schema":
		vista_originale = false
		_applica_vista()
	var zz := OS.get_environment("PM_ZOOM").split(",")
	if zz.size() == 3:
		tab_or.zoom = float(zz[0])
		tab_or.centro = Vector2(float(zz[1]), float(zz[2]))
	if ap == "sost" and m.s["att"] != null and not m.s["g"][0]["sost"].is_empty():
		_apri_sostenitore(0, int(m.s["g"][0]["sost"][0]))
	elif ap != "":
		sub = ap
		_aggiorna_azioni()
