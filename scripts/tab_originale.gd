## Il tabellone originale (tradotto) con i segnalini sopra. Si sposta trascinando, si ingrandisce con la
## rotella o pizzicando con due dita; doppio tocco per rimetterlo intero.
class_name TabOriginale
extends Control

signal carta_toccata(percorso: String)

const LARG := 6600.0
const ALT := 5100.0
const BLU := Color("244a8f")
const ARANCIO := Color("d2601a")
const ORO := Color("e8c66a")
## Dischi dei settori: per settore e partito [x, y del gradino più basso]; ogni gradino sale di 121.5.
const DISCHI := {
	"C": {"C": [219, 1868], "L": [655, 1869]}, "F": {"C": [1299, 1743], "L": [1652, 1744]},
	"G": {"C": [2254, 1868], "L": [2607, 1869]}, "I": {"C": [3208, 1743], "L": [3566, 1744]},
	"L": {"C": [219, 3168], "L": [655, 3170]}, "M": {"C": [1299, 3042], "L": [1652, 3044]},
	"S": {"C": [2254, 2917], "L": [2607, 2919]}, "W": {"C": [3208, 3042], "L": [3563, 3044]}}
const PASSO := 121.5
const CASELLA_DDL := [76.0, 3752.0, 747.0, 1042.0]
const PASSO_DDL := 1087.5

var m: Motore
var f_titolo: Font
var f_grassetto: Font
var tex: Texture2D = preload("res://assets/tabellone.webp")
var zoom := 1.0
var centro := Vector2(LARG / 2.0, ALT / 2.0)
var tocchi := {}
var pizzico_d := 0.0
var trascina := false
var mosso := 0.0
var ultimo_tocco := 0
var carte := {}

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _scala() -> float:
	return minf(size.x / LARG, size.y / ALT) * zoom

func _origine() -> Vector2:
	return size / 2.0 - centro * _scala()

func _limita() -> void:
	zoom = clampf(zoom, 1.0, 6.0)
	var mezzo := size / 2.0 / _scala()
	centro.x = clampf(centro.x, minf(mezzo.x, LARG / 2.0), maxf(LARG - mezzo.x, LARG / 2.0))
	centro.y = clampf(centro.y, minf(mezzo.y, ALT / 2.0), maxf(ALT - mezzo.y, ALT / 2.0))

func _zoom_su(punto: Vector2, fattore: float) -> void:
	var prima := (punto - _origine()) / _scala()
	zoom = clampf(zoom * fattore, 1.0, 6.0)
	centro = prima - (punto - size / 2.0) / _scala()
	_limita()
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			tocchi[e.index] = e.position
		else:
			tocchi.erase(e.index)
		if tocchi.size() == 2:
			var p: Array = tocchi.values()
			pizzico_d = p[0].distance_to(p[1])
		return
	if e is InputEventScreenDrag:
		tocchi[e.index] = e.position
		if tocchi.size() == 2:
			var p: Array = tocchi.values()
			var d: float = p[0].distance_to(p[1])
			if pizzico_d > 0.0:
				_zoom_su((p[0] + p[1]) / 2.0, d / pizzico_d)
			pizzico_d = d
			mosso = 99.0
		return
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			_zoom_su(e.position, 1.15)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			_zoom_su(e.position, 1.0 / 1.15)
		elif e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				trascina = true
				mosso = 0.0
				if e.double_click:
					if zoom > 1.01:
						zoom = 1.0
						centro = Vector2(LARG / 2.0, ALT / 2.0)
						queue_redraw()
					else:
						_zoom_su(e.position, 2.5)
			else:
				trascina = false
				if mosso < 8.0:
					_tocco((e.position - _origine()) / _scala())
	elif e is InputEventMouseMotion and trascina and tocchi.size() < 2:
		mosso += e.relative.length()
		centro -= e.relative / _scala()
		_limita()
		queue_redraw()
	elif e is InputEventMagnifyGesture:
		_zoom_su(e.position, e.factor)

func _tocco(p: Vector2) -> void:
	if m == null:
		return
	for i in m.s["tav"].size():
		var r := Rect2(CASELLA_DDL[0] + i * PASSO_DDL, CASELLA_DDL[1], CASELLA_DDL[2], CASELLA_DDL[3])
		if r.has_point(p):
			carta_toccata.emit("res://assets/carte/ddl/%s.webp" % m.s["tav"][i]["id"])

func pos_pv(n: int) -> Vector2:
	n = clampi(n, 0, 100)
	if n <= 35:
		return Vector2(153 + n * 141.25, 278)
	if n <= 70:
		return Vector2(292 + (n - 36) * 141.3, 420)
	if n <= 84:
		return Vector2(288 + (n - 71) * 141.3, 550)
	if n == 85:
		return Vector2(2410, 550)
	if n <= 89:
		return Vector2(2696 + (n - 86) * 141.3, 550)
	if n == 90:
		return Vector2(3400, 550)
	if n <= 99:
		return Vector2(3686 + (n - 91) * 141.75, 550)
	return Vector2(5030, 550)

func pos_proiezione(v: int) -> Vector2:
	if v <= 0:
		return Vector2(4115, 1545)
	if v <= 16:
		var g := (v - 1) / 4
		var r := ((v - 1) % 4) / 2
		var c := (v - 1) % 2
		return Vector2(4310 + 252.5 * g + 115 * c, 1485 + 120 * r)
	if v >= 75:
		return Vector2(5125, 3120)
	var k := v - 17
	return Vector2(4058 + 252.5 * ((k % 10) / 2) + 115 * ((k % 10) % 2), 1855 + 253.3 * (k / 10))

func _centro(c: Vector2, testo: String, px: int, col: Color, font: Font = null) -> void:
	var f := font if font != null else f_grassetto
	var sz := f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	draw_string(f, Vector2(c.x - sz.x / 2.0, c.y + px * 0.34), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _segnalino(c: Vector2, i: int, raggio: float) -> void:
	draw_circle(c + Vector2(6, 8), raggio + 6, Color(0, 0, 0, 0.45))
	draw_circle(c, raggio + 8, Color.WHITE)
	draw_circle(c, raggio, Tabellone.SEGNALINI[i % 4])
	_centro(c, str(m.s["g"][i]["nome"]).substr(0, 1), int(raggio * 1.25), Color.WHITE)

func _carta_tex(id: String) -> Texture2D:
	if not carte.has(id):
		carte[id] = load("res://assets/carte/ddl/%s.webp" % id)
	return carte[id]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("160b09"))
	_limita()
	var k := _scala()
	draw_set_transform(_origine(), 0.0, Vector2(k, k))
	draw_texture_rect(tex, Rect2(0, 0, LARG, ALT), false)
	if m == null:
		return
	# settori
	for sett in Dati.SETTORI:
		for par in ["C", "L"]:
			var d: Array = DISCHI[sett][par]
			var c := Vector2(d[0], d[1] - int(m.s["pop"][par][sett]) * PASSO)
			draw_circle(c + Vector2(6, 8), 62, Color(0, 0, 0, 0.4))
			draw_circle(c, 62, ORO)
			draw_circle(c, 50, BLU if par == "C" else ARANCIO)
			draw_circle(c, 18, Color.WHITE)
	# proiezioni
	var v := m.vantaggio("C")
	var pc := pos_proiezione(absi(v))
	var col := Color.WHITE if v == 0 else (BLU if v > 0 else ARANCIO)
	var rr := Rect2(pc - Vector2(62, 62), Vector2(124, 124)) if v != 0 else Rect2(pc - Vector2(112, 100), Vector2(224, 200))
	draw_rect(rr, Color(col, 0.45))
	draw_rect(rr, col, false, 14.0)
	# punteggio
	var visti := {}
	for i in m.s["g"].size():
		var pv := int(m.s["g"][i]["pv"])
		var n: int = visti.get(pv, 0)
		visti[pv] = n + 1
		_segnalino(pos_pv(pv) + Vector2(n * 26, n * 22), i, 46)
	# favore
	for f in Dati.FAVORE_MAX + 1:
		var qui := []
		for i in m.s["g"].size():
			if int(m.s["g"][i]["fav"]) == f:
				qui.append(i)
		for q in qui.size():
			_segnalino(Vector2(6170 + (q - (qui.size() - 1) / 2.0) * 96, 433 + (8 - f) * 306.3 + 40), qui[q], 46)
	# deputati di Governo
	var colonne := {"A": [4884, 5106], "M": [5446, 5666], "P": [6005, 6224]}
	for t in ["A", "M", "P"]:
		var n := int(m.s["mp"][t])
		for j in 2:
			var cifra: int = n / 100 if j == 0 else (n % 100) / 10
			var c := Vector2(colonne[t][j], 4844 - 117.6 * cifra)
			draw_circle(c, 36, Color("f4d27a"))
			draw_circle(c, 36, Color("7a5a1a"), false, 6.0)
	# disegni di legge
	for i in m.s["tav"].size():
		var b: Dictionary = m.s["tav"][i]
		var r := Rect2(CASELLA_DDL[0] + i * PASSO_DDL, CASELLA_DDL[1], CASELLA_DDL[2], CASELLA_DDL[3])
		draw_rect(Rect2(r.position + Vector2(14, 18), r.size), Color(0, 0, 0, 0.5))
		draw_texture_rect(_carta_tex(str(b["id"])), r, false)
		var ret := int(b["ret"])
		var hc := Vector2(910 + i * PASSO_DDL, 3721 + (100 - ret) / 10.0 * 138.1) if ret > 0 else Vector2(1032 + i * PASSO_DDL, 3797 + (-ret) / 10.0 * 138.4)
		draw_circle(hc, 58, Color(1, 1, 1, 0.3))
		draw_arc(hc, 58, 0, TAU, 40, Color.WHITE, 14.0)
		var voti := m.voti(b)
		var et := Rect2(r.position.x + 120, r.end.y - 150, r.size.x - 240, 132)
		var cv := Color("1f4a2c") if voti >= 340 else (Color("7a1418") if voti < 320 else Color("8a5e00"))
		draw_rect(et, cv)
		draw_rect(et, ORO, false, 8.0)
		_centro(et.get_center(), "%d voti" % voti, 92, Color.WHITE)
	# segnalino delle elezioni: presente = si possono ancora rinviare
	if m.s["marc"]:
		draw_arc(Vector2(4012, 4512), 262, 0, TAU, 64, Color.WHITE, 22.0)
		_centro(Vector2(4012, 4860), "rinviabili una volta", 70, Color("f7eecd"))
	else:
		_centro(Vector2(4012, 4860), "non rinviabili", 70, Color("f0a0a0"))
	if m.multi():
		if m.s["patto"]:
			draw_rect(Rect2(6330, 1150, 100, 100), Color.WHITE)
			draw_rect(Rect2(6330, 1150, 100, 100), Color("333333"), false, 8.0)
		var bbg := m._ruolo("bbg")
		if bbg >= 0 and m.s["g"][bbg]["dim"]:
			_segnalino(Vector2(6380, 1985), bbg, 46)
