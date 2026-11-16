## Riassunto delle regole mostrato nel gioco.
class_name Guida
extends RefCounted

const TESTO := """[b]Lo scopo[/b]
Vince il primo Primo Ministro che arriva a 100 Punti Vittoria (PV). Chi tocca i 100 PV dall'Opposizione deve prima conquistare il Governo.

[b]Il round (Ordine parlamentare)[/b]
1. Inizio: dal secondo round il Governo segna 4 PV e l'Opposizione 2 (6 in comune durante il Patto). Ognuno prende i cubi azione che gli spettano in base allo Standing.
2. Se non ci sono disegni di legge sul tavolo, il Primo Ministro ne pesca sei (trasversali o del suo partito) e ne mette tre in discussione. Nel gioco a più giocatori gli altri ne propongono alcuni: chi vede scelto il suo fa 1 PV.
3. Turni d'azione: prima l'Opposizione, poi il Primo Ministro, che comincia pescando un Evento.
4. Il Primo Ministro risolve un disegno: lo mette ai voti oppure lo ritira.
5. Sfide: chi ha più Standing del suo capo (o lo stesso Standing e almeno lo stesso Favore) può prenderne il posto.
6. Se non restano disegni: elezioni, rinviabili una sola volta (mai con 85 PV o più).

[b]Le azioni[/b] (un cubo ciascuna, secondo le abilità del tuo politico)
Campagna: sali di un gradino in un settore dell'elettorato. I punti Popolarità decidono le Proiezioni elettorali.
Dibattito: sposta di 10 voti (20 al Livello 2) la previsione di un disegno.
Lusinga: Favore +1 (al Livello 2: 2 punti in più o in meno a chi vuoi).
Salotti: pesca un Sostenitore (al Livello 2 ne peschi due e ne tieni uno). I Sostenitori si giocano gratis nel tuo turno; a fine turno ne puoi tenere quattro.
Influenza: sposta 10 deputati di Governo fra Moderati e Partigiani (20 al Livello 2 per il Primo Ministro).

[b]I disegni di legge[/b]
Ogni disegno conta su tutti i deputati di Governo (A), sui Moderati (M) o sui Partigiani (P), più o meno la sua rettifica. Servono 330 voti. Si può votare da 320 in su: fra 320 e 340 si pesca una carta Incertezza (a 320 passa 1 volta su 6, a 330 una su 2, a 340 cinque su 6); da 350 passa di sicuro.
Approvato: si applicano gli effetti. I disegni trasversali danno 2 o 3 PV a Governo e Opposizione, quelli di partito da 2 a 7 PV al solo Governo.
Bocciato: il Primo Ministro perde 2 Standing, il Capo dell'Opposizione ne guadagna 2 e l'Opposizione fa 3 PV.
Ritirato: 1 Standing in meno e 1 in più, 2 PV all'Opposizione.

[b]Le elezioni[/b]
Il partito in vantaggio di Popolarità è dato vincente; la carta Incertezza sposta il risultato fino a 12 seggi. Servono 330 seggi su 658; a 329 pari decide il Favore. Chi guadagna seggi segna 2 PV più 1 ogni 10 seggi guadagnati. Dopo il voto i deputati di Governo sono i seggi ottenuti (arrotondati alla decina); i Partigiani sono i punti viola dei settori. Chi conquista il Governo segna 6 PV e riparte da Standing 11; chi lo perde riparte da 5.
Interferenza Reale: alcune carte Incertezza permettono al favorito della Regina di governare in minoranza, se ha più Favore e abbastanza seggi.

[b]Solitario contro il Clockwork[/b]
Sistema I: sei sempre Primo Ministro; perdi se l'Opposizione ti toglie il Governo. Una volta puoi sostituire il tuo politico con la riserva (Standing a 11, 6 PV di penalità).
Sistema II: il Clockwork può governare. Come Primo Ministro sceglie i disegni dentro il suo Raggio di Selezione, li difende dentro il Raggio di Difesa e mette ai voti quelli a 350 o 340; altrimenti ritira il più debole. Come Capo dell'Opposizione attacca i disegni dentro il Raggio d'Attacco e ti sfida appena può (nel Sistema II solo se il suo partito è dato almeno a 289 seggi, o se qualcuno ha 85 PV). Tocca il suo ritratto per vedere la sua carta: per ogni cubo segue le opzioni dall'alto in basso e salta quelle inutili. Sulla carta «HB» indica il disegno con più voti previsti.

[b]Gioco a più giocatori[/b]
Si comincia in Patto: Governo e Opposizione dividono tutti i PV e l'Opposizione non attacca i disegni. Il Capo dell'Opposizione può romperlo all'inizio del suo turno; il Primo Ministro lo rompe presentando un disegno di partito.
I Backbencher hanno un solo cubo (due con Standing sopra 2), guadagnano 1 Standing a fine turno, fanno solo Dibattito e Salotti, ma possono puntare la carta Dibattito su un disegno e ottenere incarichi (Capogruppo, Responsabile della campagna, Consigliere privato, Vice) che aprono nuove azioni. Il Backbencher di Governo può dimettersi per indebolire il suo Primo Ministro e poi sfidarlo.
Il Primo Ministro può anche chiedere un Accordo all'Opposizione: il disegno passa senza voto e l'Opposizione fa 5 PV.
I posti affidati all'intelligenza artificiale giocano con le carte Clockwork del regolamento, adattate ai ruoli del gioco a più giocatori."""
