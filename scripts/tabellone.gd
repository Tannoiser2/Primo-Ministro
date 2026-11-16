## Il tabellone: settori dell'elettorato, proiezioni elettorali, deputati di Governo, Favore e punteggio.
## Tutto in italiano e disegnato a mano sui colori del tabellone originale.
class_name Tabellone
extends Control

const BLU := Color("244a8f")
const ARANCIO := Color("d2601a")
const ORO := Color("b8892d")
const INCHIOSTRO := Color("231c18")
const CARTA := Color("efe7d2")
const CARTA_SCURA := Color("ddd2b4")
const VIOLA := Color("7d4a9c")
const SEGNALINI := [Color("8c1c2c"), Color("1d6b52"), Color("5b3a94"), Color("a8801a")]

var m: Motore
var f_titolo: Font
var f_testo: Font
var f_grassetto: Font
## settore e partito su cui passa il mouse (per evidenziare le scelte di Campagna)
var evidenzia := {}

func _draw() -> void:
	if m == null:
		return
	var w := size.x
	var h := size.y
	var h_sett := h - 232.0
	_settori(Rect2(0, 0, w, h_sett))
	_proiezioni(Rect2(0, h_sett + 8, w * 0.62, 104))
	_deputati(Rect2(w * 0.62 + 10, h_sett + 8, w * 0.38 - 10, 104))
	_favore(Rect2(0, h_sett + 120, w * 0.36, 104))
	_punteggio(Rect2(w * 0.36 + 10, h_sett + 120, w * 0.64 - 10, 104))

func _riquadro(r: Rect2, titolo := "") -> void:
	draw_rect(r, CARTA)
	draw_rect(r, ORO, false, 2.0)
	if titolo != "":
		draw_string(f_titolo, r.position + Vector2(10, 24), titolo, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 20, Color("7a1418"))

func _centro(font: Font, c: Vector2, testo: String, px: int, col: Color) -> void:
	var sz := font.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	draw_string(font, Vector2(c.x - sz.x / 2.0, c.y + px * 0.34), testo, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _settori(r: Rect2) -> void:
	var n := Dati.SETTORI.size()
	var lw := r.size.x / n
	for i in n:
		var k: String = Dati.SETTORI[i]
		var col := Rect2(r.position.x + i * lw + 3, r.position.y, lw - 6, r.size.y)
		draw_rect(col, CARTA)
		draw_rect(col, ORO, false, 2.0)
		# intestazione: lettera del settore e nome
		draw_rect(Rect2(col.position, Vector2(col.size.x, 46)), Color("7a1418"))
		_centro(f_titolo, col.position + Vector2(20, 23), k, 30, Color("f7eecd"))
		var nome_s: String = Dati.NOME_SETTORE[k]
		var px := 20
		while px > 11 and f_titolo.get_string_size(nome_s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > col.size.x - 44:
			px -= 1
		draw_string(f_titolo, col.position + Vector2(38, 23 + px * 0.34), nome_s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("f7eecd"))
		var alto := col.size.y - 56
		var ch := minf(alto / 8.0, 64.0)
		var cw := (col.size.x - 18) / 2.0
		var j := 0
		for par: String in ["C", "L"]:
			var tr: Dictionary = Dati.TRACCE[k][par]
			var base := BLU if par == "C" else ARANCIO
			var x: float = col.position.x + 6 + j * (cw + 6)
			for g in tr["p"].size():
				var y: float = col.position.y + col.size.y - 6 - (g + 1) * ch
				var cella := Rect2(x, y + 2, cw, ch - 4)
				var qui: bool = int(m.s["pop"][par][k]) == g
				draw_rect(cella, base if qui else Color(base, 0.13))
				draw_rect(cella, Color(base, 0.9), false, 2.0 if qui else 1.0)
				if g == int(tr["i"]) and not qui:
					draw_rect(cella.grow(-2), ORO, false, 1.5)
				var testo := str(tr["p"][g])
				var con_q: bool = int(tr["q"][g]) > 0
				_centro(f_grassetto, cella.get_center() - Vector2(cw * 0.24 if con_q else 0.0, 0), testo, 21 if con_q else 22, Color.WHITE if qui else INCHIOSTRO)
				if con_q:
					_centro(f_grassetto, cella.get_center() + Vector2(cw * 0.2, 1), str(tr["q"][g]), 13, Color("f0e0ff") if qui else VIOLA)
			if evidenzia.get("s", "") == k and evidenzia.get("p", "") == par:
				draw_rect(Rect2(x - 2, col.position.y + 50, cw + 4, col.size.y - 54), Color("f0c040"), false, 3.0)
			j += 1

func _proiezioni(r: Rect2) -> void:
	_riquadro(r, "Proiezioni elettorali")
	var gov := str(m.s["gov"])
	var sc := m.seggi_previsti("C")
	var sl := Dati.SEGGI - sc
	var v := m.vantaggio("C")
	var testo := "Partiti alla pari"
	if v > 0:
		testo = "Conservatori avanti di %d punti" % v
	elif v < 0:
		testo = "Liberali avanti di %d punti" % -v
	draw_string(f_testo, r.position + Vector2(250, 24), testo, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 260, 20, INCHIOSTRO)
	var bar := Rect2(r.position.x + 12, r.position.y + 40, r.size.x - 24, 30)
	var xc := bar.size.x * sc / float(Dati.SEGGI)
	draw_rect(Rect2(bar.position, Vector2(xc, bar.size.y)), BLU)
	draw_rect(Rect2(bar.position + Vector2(xc, 0), Vector2(bar.size.x - xc, bar.size.y)), ARANCIO)
	var meta := bar.position.x + bar.size.x / 2.0
	draw_line(Vector2(meta, bar.position.y - 4), Vector2(meta, bar.end.y + 4), INCHIOSTRO, 3.0)
	draw_string(f_grassetto, bar.position + Vector2(8, 23), "Conservatori %d" % sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	var t2 := "Liberali %d" % sl
	var sz := f_grassetto.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 21)
	draw_string(f_grassetto, Vector2(bar.end.x - sz.x - 8, bar.position.y + 23), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	var prev := m.seggi_previsti(gov)
	var diff: int = Dati.arrotonda10(prev) - int(m.s["mp"]["A"])
	var t3 := "Servono 330 seggi. Governo: %d oggi, %d previsti." % [m.s["mp"]["A"], prev]
	if diff != 0:
		t3 += " Alle urne ne %s circa %d." % ["guadagna" if diff > 0 else "perde", absi(diff)]
	draw_string(f_testo, r.position + Vector2(12, 94), t3, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 18, INCHIOSTRO)

func _deputati(r: Rect2) -> void:
	_riquadro(r, "Deputati di Governo")
	var nomi := {"A": "Tutti", "M": "Moderati", "P": "Partigiani"}
	var col := {"A": Color("55565a"), "M": Color("7d9db8"), "P": VIOLA}
	var lw := (r.size.x - 24) / 3.0
	var i := 0
	for k in ["A", "M", "P"]:
		var c := Rect2(r.position.x + 12 + i * lw, r.position.y + 34, lw - 6, 60)
		draw_rect(c, col[k])
		draw_rect(c, ORO, false, 2.0)
		_centro(f_grassetto, c.get_center() - Vector2(0, 10), str(m.s["mp"][k]), 30, Color.WHITE)
		_centro(f_testo, c.get_center() + Vector2(0, 19), "%s (%s)" % [nomi[k], k], 15, Color.WHITE)
		i += 1

func _favore(r: Rect2) -> void:
	_riquadro(r, "Favore di Sua Maestà")
	var n := Dati.FAVORE_MAX + 1
	var lw := (r.size.x - 20) / n
	for v in n:
		var c := Rect2(r.position.x + 10 + v * lw, r.position.y + 36, lw - 4, 58)
		draw_rect(c, Color("8f1d21", 0.16))
		draw_rect(c, Color("8f1d21"), false, 1.5)
		draw_string(f_grassetto, c.position + Vector2(4, 16), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INCHIOSTRO)
		var qui := []
		for i in m.s["g"].size():
			if int(m.s["g"][i]["fav"]) == v:
				qui.append(i)
		for q in qui.size():
			var cc := Vector2(c.position.x + c.size.x / 2.0 + (q - (qui.size() - 1) / 2.0) * 13, c.position.y + 36)
			_segnalino(cc, qui[q], 11)

func _punteggio(r: Rect2) -> void:
	_riquadro(r, "Punti Vittoria")
	draw_string(f_testo, r.position + Vector2(190, 24), "vince il Primo Ministro che arriva a 100", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 200, 17, INCHIOSTRO)
	var x0 := r.position.x + 22
	var x1 := r.end.x - 22
	var y := r.position.y + 72
	draw_line(Vector2(x0, y), Vector2(x1, y), INCHIOSTRO, 3.0)
	for t in range(0, 101, 5):
		var x := lerpf(x0, x1, t / 100.0)
		var grande := t % 10 == 0
		draw_line(Vector2(x, y - (9 if grande else 5)), Vector2(x, y + (9 if grande else 5)), INCHIOSTRO, 2.0)
		if grande:
			_centro(f_testo, Vector2(x, y + 22), str(t), 15, Color("7a1418") if t >= 90 else INCHIOSTRO)
	var x85 := lerpf(x0, x1, 0.85)
	draw_line(Vector2(x85, y - 26), Vector2(x85, y + 9), Color("8f1d21"), 2.0)
	draw_string(f_testo, Vector2(x85 - 150, y - 22), "da 85: niente rinvio", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8f1d21"))
	# segnalini: quelli con lo stesso punteggio si affiancano in verticale
	var visti := {}
	for i in m.s["g"].size():
		var pv := int(m.s["g"][i]["pv"])
		var k: int = visti.get(pv, 0)
		visti[pv] = k + 1
		_segnalino(Vector2(lerpf(x0, x1, pv / 100.0), y - 14 - k * 4) + Vector2(k * 9, 0), i, 11)

func _segnalino(c: Vector2, i: int, raggio: float) -> void:
	draw_circle(c, raggio + 2, Color.WHITE)
	draw_circle(c, raggio, SEGNALINI[i % SEGNALINI.size()])
	_centro(f_grassetto, c, str(m.s["g"][i]["nome"]).substr(0, 1), 14, Color.WHITE)
