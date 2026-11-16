## Il tutorial: una partita vera contro il Clockwork più facile, con una visita guidata del tabellone,
## una lezione per ogni tipo di decisione e una mossa consigliata (obbligata nei primi due round).
class_name Tutor
extends RefCounted

const ROUND_GUIDATI := 2
const CFG := {"modo": "cw2", "seme": 1001, "umano_pm": true, "posti": [{"pol": "gladstone", "tipo": "u"}, {"pol": "aberdeen", "tipo": "cw"}]}

## Visita del tabellone: titolo, testo, zoom e centro (coordinate del tabellone originale).
const INTRO := [
	{"t": "Benvenuto a Westminster", "z": 1.0, "c": [3300, 2550],
		"x": "Sei W.E. Gladstone, Primo Ministro liberale della regina Vittoria. Di fronte hai il Conte di Aberdeen, capo dell'Opposizione conservatrice, guidato dal sistema Clockwork del gioco.\n\nIn questa partita guidata ti spiego ogni cosa quando serve. Nei primi due round ti indico io la mossa da fare; poi giochi tu, e io resto qui con un consiglio.\n\nPrima, un giro del tabellone: lo puoi sempre ingrandire con la rotella o pizzicando con due dita, e spostare trascinandolo."},
	{"t": "Il punteggio", "z": 2.3, "c": [2600, 420],
		"x": "Vince chi arriva a 100 Punti Vittoria mentre è Primo Ministro. Chi li raggiunge dall'Opposizione deve prima conquistare il Governo.\n\nI punti arrivano soprattutto dai disegni di legge approvati, dalle elezioni vinte e, a ogni round, dal semplice fatto di governare (4 punti) o di fare opposizione (2 punti).\n\nI segnalini con l'iniziale sono i giocatori: G sei tu, A è Aberdeen, che nel solitario parte con 5 punti."},
	{"t": "I settori dell'elettorato", "z": 1.9, "c": [1900, 1950],
		"x": "Otto settori: Conservatori, Agricoltori, Gentry, Irlanda, Liberali, Ceto medio, Scozia, Operai. In ognuno i due partiti hanno un disco: blu i Conservatori, arancio i Liberali (il tuo partito).\n\nIl numero accanto al disco sono i punti Popolarità che quel settore ti dà. Più sali, più ne hai. Si sale con l'azione Campagna, con molti disegni di legge e con i Sostenitori.\n\nI numeri su fondo viola sono i deputati Partigiani che quel settore ti garantisce dopo le elezioni: li vedremo fra poco."},
	{"t": "Le proiezioni elettorali", "z": 2.3, "c": [4650, 1950],
		"x": "Si sommano i punti Popolarità di ogni partito: la differenza dice quanti seggi prenderebbe chi è in testa se si votasse oggi. Per esempio, con 9 o 10 punti di vantaggio: 347 seggi contro 311.\n\nServono 330 seggi su 658 per governare. La casella evidenziata è la proiezione di adesso: si parte alla pari, 329 a 329.\n\nLe elezioni arrivano quando hai risolto tutti i disegni di legge in discussione. Le puoi rinviare una volta sola."},
	{"t": "Il Favore di Sua Maestà", "z": 2.0, "c": [5700, 1600],
		"x": "La Regina ha le sue simpatie. Il Favore va da 0 a 8 e conta in tre momenti:\n\n1. Nelle sfide: a parità di Standing, vince lo sfidante solo se ha almeno lo stesso Favore.\n2. Nelle elezioni finite 329 pari: governa chi ha più Favore.\n3. Nell'Interferenza Reale: con certe carte Incertezza il favorito può governare anche in minoranza.\n\nSi guadagna con l'azione Lusinga (Gladstone non ce l'ha: era notoriamente antipatico alla Regina), con alcuni eventi e disegni di legge."},
	{"t": "I deputati di Governo", "z": 2.5, "c": [5600, 4200],
		"x": "Il tuo Governo ha 330 deputati (colonna A, Tutti): 270 Moderati (M) e 60 Partigiani (P). I segnalini dorati indicano le cifre: 3 e 30 fanno 330.\n\nOgni disegno di legge conta su un gruppo diverso: quelli di tipo A su tutti i deputati, quelli M sui soli Moderati, quelli P sui soli Partigiani. Per questo i disegni di partito, che di solito sono A o P, sono più difficili da far passare.\n\nCon l'azione Influenza puoi spostare 10 deputati da un gruppo all'altro."},
	{"t": "I disegni di legge", "z": 2.2, "c": [1700, 4300],
		"x": "Qui stanno i tre disegni in discussione. Accanto a ognuno c'è la colonna delle rettifiche, da +100 a -80: il cerchio bianco indica la rettifica attuale.\n\nVoti previsti = deputati del gruppo giusto + rettifica. Per approvare servono 330 voti.\n\nCon 350 o più il disegno passa di sicuro. Fra 320 e 340 si pesca una carta Incertezza: a 340 passa 5 volte su 6, a 330 una su 2, a 320 una su 6. Sotto 320 non si può nemmeno votare.\n\nL'azione Dibattito sposta la rettifica: tu la alzi, l'Opposizione la abbassa."},
	{"t": "I politici", "z": 1.0, "c": [3300, 2550],
		"x": "A sinistra ci sono i due politici. Lo Standing è il prestigio di ciascuno: decide quanti cubi azione ricevi a ogni round (2 di base, 3 se superi 8, 4 se superi 12) e, soprattutto, le sfide.\n\nSe il capo dell'Opposizione ha più Standing di te (o lo stesso, con almeno il tuo Favore) ti sfida e ti toglie il Governo. Tu parti da 11, lui da 5: ogni disegno bocciato o ritirato ti avvicina a lui.\n\nSotto c'è la carta Clockwork di Aberdeen: per ogni suo cubo esegue la prima opzione utile dall'alto in basso. Toccala per ingrandirla.\n\nSi comincia!"},
]

const LEZIONI := {
	"pesca": "SELEZIONE DEI DISEGNI DI LEGGE\nNon ci sono disegni in discussione, quindi ne peschi sei e ne scegli tre. Puoi pescare dal mazzo trasversale o da quello del tuo partito, anche mescolando, e guardi ogni carta prima di decidere la prossima.\n\nI disegni trasversali valgono 2 o 3 punti sia a te sia all'Opposizione, ma passano facilmente. Quelli di partito danno fino a 7 punti solo a te, spostano la Popolarità e sono più rischiosi.\n\nAll'inizio conviene la prudenza: pesca dai trasversali.",
	"scegli": "QUALI METTERE IN DISCUSSIONE\nSotto ogni carta vedi i voti che avrebbe adesso. Su ogni carta leggi, da sinistra: il gruppo di deputati su cui conta (A, M o P), la rettifica iniziale nell'esagono, i Punti Vittoria nella coccarda e, in basso, gli effetti se passa (frecce sui settori, Favore, Standing, Sostenitori).\n\nRicorda che ne risolvi uno solo per round: tre disegni significano tre round prima delle elezioni, e l'Opposizione avrà tempo di attaccarli. Scegli quelli che partono più in alto.",
	"clockwork": "IL TURNO DELL'OPPOSIZIONE\nPrima di te ha giocato Aberdeen: trovi le sue mosse in grassetto nel diario, in basso a destra. Per ogni cubo ha seguito la sua carta: prima opzione utile dall'alto. Attacca con il Dibattito solo i disegni dentro il suo Raggio d'Attacco (da 300 a 350 voti) e sceglie sempre il più basso fra quelli.\n\nUn disegno sopra 350 o sotto 300 lui lo ignora: tienilo a mente quando decidi dove spendere i tuoi cubi.",
	"evento": "L'EVENTO\nIl tuo turno comincia sempre con una carta Evento. Ogni opzione ha un costo in cubi azione (i cubetti disegnati a sinistra) e un effetto: ignorare non costa nulla ma di solito fa danni, reagire costa uno o due cubi che poi non avrai per le azioni.\n\nNon c'è una risposta giusta in assoluto: dipende da quanto ti servono i cubi in questo round. Alcune carte sono elezioni suppletive: se le proiezioni ti danno meno seggi di quelli che hai, perdi Standing.",
	"dib": "DIBATTITO\nÈ l'azione che fa passare le leggi: alza di 10 voti (20 per Gladstone, che ha il Livello 2) la previsione di un disegno.\n\nL'obiettivo è portare il disegno che vuoi votare a 340, meglio ancora a 350. Non serve andare oltre, e non serve nemmeno disperdere i cubi su tre disegni: ne voti uno per round.",
	"camp": "CAMPAGNA\nSali di un gradino in uno dei settori del tuo politico (per Gladstone: Irlanda, Liberali, Operai). Guarda quanti punti Popolarità guadagni: i gradini alti rendono di più.\n\nLa Campagna non dà punti subito: prepara le elezioni. Ogni 10 seggi guadagnati alle urne valgono 1 Punto Vittoria, più 2 di premio, e una proiezione sotto i tuoi seggi attuali ti espone alle suppletive.",
	"hob": "SALOTTI\nPeschi un Sostenitore: un personaggio dell'epoca con due effetti, di cui ne userai uno. Giocarlo non costa cubi, ma solo nel tuo turno; a fine turno ne puoi tenere quattro.\n\nÈ l'azione giusta quando non hai nulla di urgente da fare: un buon Sostenitore al momento giusto vale più di un cubo.",
	"inf": "INFLUENZA\nSposti 10 deputati fra Moderati e Partigiani. Serve per i disegni di tipo M o P: ogni spostamento vale 10 voti su tutti i disegni di quel tipo insieme, ma ne toglie altrettanti a quelli dell'altro tipo.",
	"sost": "GIOCARE UN SOSTENITORE\nHai un Sostenitore utile in mano. Giocarlo è gratis: scegli uno dei suoi due effetti. Le frecce in su e in giù muovono un partito in un settore, l'esagono è un Dibattito, il medaglione con la Regina è il Favore, quello con il Big Ben lo Standing; la mano che indica colpisce un avversario a tua scelta.",
	"fine": "FINE DEL TURNO\nNon hai più nulla di utile da fare. I cubi non spesi vanno persi, quindi chiudi il turno solo quando sei a zero o non c'è davvero niente da fare.",
	"risolvi": "RISOLVERE UN DISEGNO\nA ogni round devi risolverne uno: metterlo ai voti o ritirarlo.\n\nApprovato: i suoi effetti e i suoi punti.\nBocciato: perdi 2 Standing, Aberdeen ne guadagna 2 e fa 3 punti.\nRitirato: perdi 1 Standing, lui ne guadagna 1 e fa 2 punti.\n\nQuindi: vota quando sei a 340 o più; se nessun disegno ci arriva, ritirare il più debole costa meno che farsi bocciare.",
	"tieni": "DUE SOSTENITORI\nNe hai pescati due e ne tieni uno. Confronta gli effetti con la tua situazione: Dibattito se hai disegni in bilico, frecce sui settori se le elezioni si avvicinano.",
	"elezione": "LE ELEZIONI\nNon ci sono più disegni in discussione. Puoi andare alle urne o rinviare, una volta sola, per avere un altro round di Campagna.\n\nSi contano i seggi previsti, poi una carta Incertezza li sposta fino a 12 in più o in meno. Chi guadagna seggi rispetto a prima segna 2 punti più 1 ogni 10 seggi. Chi perde le elezioni passa all'Opposizione; il vincitore diventa Primo Ministro con 6 punti di premio.\n\nDopo il voto i tuoi deputati diventano i seggi ottenuti, e i Partigiani i numeri viola dei settori.",
	"sfida": "LA SFIDA\nHai più Standing del Primo Ministro (o lo stesso, con almeno il suo Favore): puoi prendere il suo posto. Si va subito alle elezioni per contare i tuoi deputati, ma il Governo resta comunque a te.",
	"opposizione": "ALL'OPPOSIZIONE\nHai perso il Governo. Ora il tuo mestiere è un altro: abbassare con il Dibattito i disegni del Primo Ministro perché falliscano (ogni bocciatura ti dà 2 Standing e 3 punti), fare Campagna per le prossime elezioni e aspettare il momento della sfida.\n\nAttenzione: i punti li fai anche qui, ma per vincere devi tornare a governare.",
	"libero": "DA QUI GIOCHI TU\nHai visto un round intero due volte. D'ora in poi le decisioni sono tue: io ti lascio in alto il mio consiglio, con il motivo, e una lezione nuova ogni volta che capita qualcosa che non hai ancora visto.",
}

## Quali lezioni proporre per una decisione (si mostra la prima non ancora vista).
static func lezioni_per(m: Motore, tipo: String, r: Dictionary) -> Array:
	var chi: int = m.s["att"]["posto"]
	var out := []
	if m.s["g"][chi]["ruolo"] == "opp":
		out.append("opposizione")
	match tipo:
		"pesca": out.append("pesca")
		"scegli": out.append("scegli")
		"evento":
			out.append("clockwork")
			out.append("evento")
		"azione":
			out.append("clockwork")
			var t := str(r.get("t", "fine"))
			out.append(t if LEZIONI.has(t) else "fine")
		"risolvi": out.append("risolvi")
		"tieni": out.append("tieni")
		"elezione": out.append("elezione")
		"sfida": out.append("sfida")
	if int(m.s["round"]) > ROUND_GUIDATI:
		out.append("libero")
	return out

## La mossa consigliata per la decisione in attesa: {r: risposta, perche: motivo}.
static func consiglio(m: Motore) -> Dictionary:
	var a: Dictionary = m.s["att"]
	var chi: int = a["posto"]
	var p: Dictionary = m.s["g"][chi]
	match str(a["tipo"]):
		"pesca":
			var mazzi := m.opzioni()
			var r: Dictionary = mazzi[0]
			var perche := "I trasversali partono più in alto e passano più facilmente."
			if int(m.s["mp"]["P"]) >= 150 and mazzi.size() > 1 and int(m.s["round"]) > 2:
				r = mazzi[1]
				perche = "Hai molti deputati Partigiani: i disegni di partito ora sono alla tua portata e valgono di più."
			return {"r": r, "perche": perche}
		"scegli", "proponi":
			var fonte: Array = (m.s["sel"]["riv"] if a["tipo"] == "scegli" else m.s["sel"]["mano"]).duplicate()
			fonte.sort_custom(func(x, y):
				if m.voti_iniziali(x) != m.voti_iniziali(y):
					return m.voti_iniziali(x) > m.voti_iniziali(y)
				return int(Dati.ddl(x)["pv"]) > int(Dati.ddl(y)["pv"]))
			return {"r": {"t": a["tipo"], "ids": fonte.slice(0, int(a["n"]))}, "perche": "Sono quelli che partono con più voti: meno cubi da spendere per farli passare."}
		"evento":
			var ev: Dictionary = DatiGen.EVENTI[int(a["n"]) - 1]
			var meglio := 0
			var punti := -999.0
			for o in m.opzioni():
				var op: Dictionary = ev["opz"][int(o["o"])]
				var v := -1.7 * int(op["costo"])
				for e in op["eff"]:
					var t := str(e)
					if t.begins_with("X+"):
						v += 2.0
					elif t.begins_with("X-"):
						v -= 2.0
					elif t.begins_with("S"):
						v += 3.0 * int(t.substr(1))
					elif t.begins_with("Fv"):
						v += 1.5 * int(t.substr(2))
					elif t.begins_with("pFv"):
						v += 1.0
				if v > punti:
					punti = v
					meglio = int(o["o"])
			var costo := int(ev["opz"][meglio]["costo"])
			var perche := "Un cubo vale più o meno come un gradino in un settore: questa è l'opzione che ti costa meno nel complesso."
			if costo == 0:
				perche = "Il danno è sopportabile e ti tieni tutti i cubi per le azioni."
			return {"r": {"t": "ev", "o": meglio}, "perche": perche}
		"azione":
			return _azione(m, chi)
		"tieni":
			return {"r": {"t": "tieni", "c": int(a["carte"][0])}, "perche": "Vanno bene entrambi: l'importante è avere un Sostenitore pronto."}
		"risolvi":
			var tav: Array = m.s["tav"]
			var alto := 0
			var basso := 0
			for b in tav.size():
				if m.voti(tav[b]) > m.voti(tav[alto]):
					alto = b
				if m.voti(tav[b]) < m.voti(tav[basso]):
					basso = b
			var v := m.voti(tav[alto])
			if v >= 340:
				return {"r": {"t": "voto", "b": alto}, "perche": "Con %d voti %s." % [v, "passa di sicuro" if v >= 350 else "passa 5 volte su 6"]}
			if v >= 330 and int(p["st"]) >= 9:
				return {"r": {"t": "voto", "b": alto}, "perche": "A %d voti è una moneta, ma hai Standing da spendere e ritirare costa comunque." % v}
			return {"r": {"t": "ritiro", "b": basso}, "perche": "Nessun disegno arriva a 340: ritirare il più debole ti costa 1 Standing, una bocciatura ne costerebbe 2."}
		"elezione":
			var prev := m.seggi_previsti(str(p["par"]))
			var rinvia := false
			for o in m.opzioni():
				if o["t"] == "rinvia":
					rinvia = true
			if rinvia and (prev < 336 or Dati.arrotonda10(prev) <= int(m.s["mp"]["A"])):
				return {"r": {"t": "rinvia"}, "perche": "Sei dato a %d seggi: troppo pochi per stare tranquillo o per guadagnare punti. Un round di Campagna in più aiuta." % prev}
			return {"r": {"t": "elezione"}, "perche": "Sei dato a %d seggi: abbastanza per vincere e guadagnare seggi." % prev if prev >= 330 else "Non puoi più rinviare: si vota."}
		"sostituisci":
			return {"r": {"t": "sostituisci", "si": false}, "perche": "Tieni il tuo politico finché puoi."}
	return {"r": {"t": str(a["tipo"]), "si": true}, "perche": "Conviene accettare."}

static func _azione(m: Motore, chi: int) -> Dictionary:
	var p: Dictionary = m.s["g"][chi]
	var az := m.azioni_possibili(chi)
	var gov: bool = p["ruolo"] == "pm"
	var tav: Array = m.s["tav"]
	if int(p["cubi"]) > 0:
		# 1. Dibattito sul disegno giusto
		var bers := -1
		for b in tav.size():
			var v := m.voti(tav[b])
			if gov and v >= 290 and v < 350 and (bers < 0 or v > m.voti(tav[bers])):
				bers = b
			if not gov and v >= 310 and v <= 350 and (bers < 0 or v < m.voti(tav[bers])):
				bers = b
		if bers >= 0:
			var scelta = null
			for a in az:
				if a["t"] == "dib" and int(a["b"]) == bers and (int(a["v"]) > 0) == gov:
					var dopo := m.voti(tav[bers]) + int(a["v"])
					if scelta == null or (gov and dopo <= 350 and absi(int(a["v"])) > absi(int(scelta["v"]))) or (not gov and absi(int(a["v"])) > absi(int(scelta["v"]))):
						scelta = a
			if scelta != null:
				var dopo := m.voti(tav[bers]) + int(scelta["v"])
				var perche := "Porta %s a %d voti: %s." % [Testi.ddl(tav[bers]["id"]), dopo, "è il disegno che voterai" if gov else "così rischia di essere bocciato"]
				return {"r": scelta, "perche": perche}
		# 2. Campagna dove rende di più
		var meglio = null
		var guad := 0
		for a in az:
			if a["t"] == "camp":
				var par := str(p["par"])
				var tr: Array = Dati.TRACCE[a["s"]][par]["p"]
				var da: int = m.s["pop"][par][a["s"]]
				var arr := mini(da + int(a["n"]), tr.size() - 1)
				if int(tr[arr]) - int(tr[da]) > guad:
					guad = int(tr[arr]) - int(tr[da])
					meglio = a
		if meglio != null:
			return {"r": meglio, "perche": "I disegni sono a posto: %d punti Popolarità in più avvicinano la vittoria alle elezioni." % guad}
		# 3. Salotti
		for a in az:
			if a["t"] == "hob":
				return {"r": a, "perche": "Niente di urgente: un Sostenitore in mano torna sempre utile."}
	# Sostenitori utili
	for a in az:
		if a["t"] == "sost" and m._ia_sost_buona(chi, a):
			var eff: Array = m.sostenitore(int(a["c"]))["opz"][int(a["o"])]
			var ok := true
			for e in eff:
				if str(e).begins_with("D"):
					var v := m.voti(tav[int(a["b"])])
					if gov and (v >= 350 or v < 290):
						ok = false
					if not gov and (v > 350 or v < 310):
						ok = false
			if ok:
				return {"r": a, "perche": "È gratis: %s." % m._descrivi_sost(chi, eff, a)}
	for a in az:
		if a["t"] == "fine":
			return {"r": a, "perche": "Hai speso i cubi e i Sostenitori rimasti conviene tenerli."}
	for a in az:
		if a["t"] == "scarta":
			return {"r": a, "perche": "Hai più di quattro Sostenitori: uno va scartato."}
	return {"r": az[0], "perche": ""}

## La mossa in parole, per il pulsante.
static func descrivi(m: Motore, r: Dictionary) -> String:
	var chi: int = m.s["att"]["posto"]
	match str(r["t"]):
		"pesca":
			return "Pesca dai %s" % {"X": "trasversali", "C": "Conservatori", "L": "Liberali"}[r["m"]]
		"scegli", "proponi":
			var nomi := []
			for id in r["ids"]:
				nomi.append(Testi.ddl_titolo(id))
			return "Scegli: " + ", ".join(nomi)
		"ev":
			return "Scegli «%s»" % Testi.evento_opz(int(m.s["att"]["n"]), int(r["o"]))
		"camp":
			return "Campagna in %s (%d gradin%s)" % [Dati.NOME_SETTORE[r["s"]], int(r["n"]), "o" if int(r["n"]) == 1 else "i"]
		"dib":
			return "Dibattito: %+d voti a %s" % [int(r["v"]), Testi.ddl_titolo(m.s["tav"][int(r["b"])]["id"])]
		"hob":
			return "Salotti: pesca un Sostenitore"
		"inf":
			return "Influenza: %d deputati ai %s" % [absi(int(r["v"])), "Partigiani" if int(r["v"]) > 0 else "Moderati"]
		"lus":
			return "Lusinga: Favore %+d" % int(r["v"])
		"sost":
			return "Gioca %s" % m.sostenitore(int(r["c"]))["nome"]
		"scarta":
			return "Scarta %s" % m.sostenitore(int(r["c"]))["nome"]
		"fine":
			return "Fine del turno"
		"tieni":
			return "Tieni %s" % m.sostenitore(int(r["c"]))["nome"]
		"voto":
			return "Metti ai voti %s" % Testi.ddl_titolo(m.s["tav"][int(r["b"])]["id"])
		"ritiro":
			return "Ritira %s" % Testi.ddl_titolo(m.s["tav"][int(r["b"])]["id"])
		"elezione":
			return "Indici le elezioni"
		"rinvia":
			return "Rinvia le elezioni"
		"sfida":
			return "Lancia la sfida" if r["si"] else "Non sfidare"
		"sostituisci":
			return "Sostituisci il Primo Ministro" if r["si"] else "Resta al tuo posto"
		"reale":
			return "Accetta l'offerta della Regina"
	var _c := chi
	return "Prosegui"
