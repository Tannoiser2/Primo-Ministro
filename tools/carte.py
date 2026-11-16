#!/usr/bin/env python3
"""Ricompone in italiano le carte del gioco sulla grafica originale e prepara le immagini per Godot.

Uso: python3 tools/carte.py <cartella del materiale estratto dal modulo TTS> [solo: ddl ev sost ...]
Il materiale originale non sta nel repository (diritti GMT Games): servono i fogli del modulo
Tabletop Simulator. Le scritte inglesi vengono cancellate ricostruendo lo sfondo e riscritte in italiano
con font simili agli originali (Milonga per i titoli, Old Standard per i testi, Rye per le intestazioni).
"""
import json, os, sys
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont

R = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(R, '..', 'assets')
F = os.path.join(A, 'font')
Image.MAX_IMAGE_PIXELS = None

def righe(n):
    return [l.rstrip('\n').split('|') for l in open(f'{R}/dati/{n}.txt', encoding='utf-8') if l.strip() and not l.startswith('#')]

def font(nome, px):
    return ImageFont.truetype(f'{F}/{nome}.ttf', px)

class Foglio:
    """Un foglio di carte del modulo (griglia w x h)."""
    def __init__(self, src, nome, w, h):
        self.im = Image.open(os.path.join(src, 'img', nome)).convert('RGB')
        self.w, self.h = w, h
        self.cw, self.ch = self.im.size[0] / w, self.im.size[1] / h
    def carta(self, i):
        x, y = i % self.w, i // self.w
        c = self.im.crop((round(x * self.cw), round(y * self.ch), round((x + 1) * self.cw), round((y + 1) * self.ch)))
        return c if c.size == (750, 1050) else c.resize((750, 1050), Image.LANCZOS)

def cancella(im, box, chiaro, soglia=None, allarga=3, raggio=5):
    """Cancella il testo dentro box ricostruendo lo sfondo. chiaro=True: testo chiaro su fondo scuro."""
    x0, y0, x1, y1 = box
    a = np.asarray(im).copy()
    reg = a[y0:y1, x0:x1]
    g = cv2.cvtColor(reg, cv2.COLOR_RGB2GRAY)
    if soglia is None:
        soglia = int(np.median(g)) + (45 if chiaro else -45)
    m = ((g > soglia) if chiaro else (g < soglia)).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((allarga, allarga), np.uint8), iterations=2)
    reg2 = cv2.inpaint(cv2.cvtColor(reg, cv2.COLOR_RGB2BGR), m, raggio, cv2.INPAINT_TELEA)
    a[y0:y1, x0:x1] = cv2.cvtColor(reg2, cv2.COLOR_BGR2RGB)
    return Image.fromarray(a)

def a_capo(d, testo, ft, larg):
    parole, righe_, cur = testo.split(), [], ''
    for p in parole:
        t = (cur + ' ' + p).strip()
        if d.textlength(t, font=ft) <= larg or not cur:
            cur = t
        else:
            righe_.append(cur)
            cur = p
    if cur:
        righe_.append(cur)
    return righe_

def scrivi(im, testo, box, nome_font, px, colore, max_righe=2, allinea='c', ombra=None, interlinea=1.08, px_min=14):
    """Scrive il testo dentro box, riducendo il corpo finché entra in max_righe righe."""
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = box
    while True:
        ft = font(nome_font, px)
        rr = a_capo(d, testo, ft, x1 - x0)
        asc, desc = ft.getmetrics()
        alt = (asc + desc) * interlinea
        larga = max(d.textlength(r, font=ft) for r in rr)
        if (len(rr) <= max_righe and larga <= x1 - x0 and alt * len(rr) <= (y1 - y0) + 4) or px <= px_min:
            break
        px -= 1
    y = (y0 + y1) / 2 - alt * len(rr) / 2
    for r in rr:
        w = d.textlength(r, font=ft)
        x = (x0 + x1) / 2 - w / 2 if allinea == 'c' else (x1 - w if allinea == 'd' else x0)
        if ombra:
            d.text((x + 2, y + 2), r, font=ft, fill=ombra)
        d.text((x, y), r, font=ft, fill=colore)
        y += alt
    return im

def sostituisci_modello(im, modello, testo, nome_font, px, colore, chiaro, zona=None, soglia=0.72, dx=0):
    """Cerca nella carta una scritta nota (modello ritagliato dall'originale) e la riscrive in italiano."""
    a = cv2.cvtColor(np.asarray(im), cv2.COLOR_RGB2GRAY)
    t = cv2.cvtColor(np.asarray(modello), cv2.COLOR_RGB2GRAY)
    ox = oy = 0
    if zona:
        ox, oy = zona[0], zona[1]
        a = a[zona[1]:zona[3], zona[0]:zona[2]]
    if a.shape[0] < t.shape[0] or a.shape[1] < t.shape[1]:
        return im, 0
    res = cv2.matchTemplate(a, t, cv2.TM_CCOEFF_NORMED)
    n = 0
    while True:
        _, mx, _, loc = cv2.minMaxLoc(res)
        if mx < soglia:
            break
        x, y = loc[0] + ox, loc[1] + oy
        h, w = t.shape
        im = cancella(im, (x - 2, y - 2, x + w + 2, y + h + 2), chiaro)
        im = scrivi(im, testo, (x - 16 + dx, y - 10, x + w + 16 + dx, y + h + 10), nome_font, px, colore, max_righe=2, interlinea=0.9)
        cv2.rectangle(res, (max(0, loc[0] - w), max(0, loc[1] - h)), (loc[0] + w, loc[1] + h), -1, -1)
        n += 1
    return im, n

def salva(im, percorso, larg=420, q=84):
    os.makedirs(os.path.dirname(percorso), exist_ok=True)
    if larg and im.size[0] != larg:
        im = im.resize((larg, round(im.size[1] * larg / im.size[0])), Image.LANCZOS)
    im.save(percorso, 'WEBP', quality=q, method=6)

CREMA = (247, 238, 205)
BLU_TESTO = (26, 30, 46)

# ---------------------------------------------------------------- disegni di legge
def ddl(src):
    it = {p[0]: p for p in righe('it_ddl')}
    fogli = {'X': Foglio(src, 'i02.png', 7, 6), 'C': Foglio(src, 'i00.png', 5, 4), 'L': Foglio(src, 'i04.png', 5, 4)}
    n_mazzo = {'X': 40, 'C': 18, 'L': 18}
    # modelli delle scritte piccole, ritagliati da carte note
    x8 = fogli['X'].carta(7)
    m_for = x8.crop((406, 828, 462, 896))       # "For PM"
    m_keep = x8.crop((552, 826, 646, 888))      # "KEEP ONE"
    for mz, fg in fogli.items():
        for i in range(n_mazzo[mz]):
            c = fg.carta(i)
            idc = f'{mz}{i + 1}'
            c = cancella(c, (52, 338, 698, 442), True)
            c = scrivi(c, it[idc][1], (62, 340, 688, 440), 'Milonga-Regular', 56, CREMA, max_righe=1, ombra=(60, 20, 20) if mz != 'C' else (10, 16, 40))
            c = cancella(c, (40, 458, 710, 548), False)
            c = scrivi(c, it[idc][2], (56, 458, 694, 548), 'OldStandard-Regular', 32, BLU_TESTO, max_righe=3, px_min=20)
            c, _ = sostituisci_modello(c, m_for, 'Al PM', 'OldStandard-Regular', 31, (22, 34, 60), False, zona=(0, 720, 750, 1040))
            c, _ = sostituisci_modello(c, m_keep, 'TIENINE UNA', 'OldStandard-Regular', 25, (15, 15, 15), False, zona=(0, 720, 750, 1040))
            salva(c, f'{A}/carte/ddl/{idc}.webp')
    for mz, nome in (('X', 'i03.jpg'), ('C', 'i01.jpg'), ('L', 'i05.jpg')):
        salva(Image.open(os.path.join(src, 'img', nome)).convert('RGB'), f'{A}/carte/ddl/dorso_{mz}.webp', 300)

# ---------------------------------------------------------------- eventi
ROSSO_SCURO_OMBRA = (50, 8, 10)
def eventi(src):
    it = {int(p[0]): p[1:] for p in righe('it_eventi')}
    fg = Foglio(src, 'i24.png', 7, 6)
    righe_y = [(566, 700), (708, 846), (852, 996)]
    for i in range(40):
        c = fg.carta(i)
        n = i + 1
        if n in it:
            c = cancella(c, (40, 388, 710, 532), True)
            c = scrivi(c, it[n][0], (52, 390, 698, 530), 'Milonga-Regular', 52, CREMA, max_righe=2, ombra=ROSSO_SCURO_OMBRA, px_min=26, interlinea=1.0)
            opz = it[n][1:]
            dove = [0, 2] if len(opz) == 2 else [0, 1, 2]
            for k, r in enumerate(dove):
                y0, y1 = righe_y[r]
                x0 = 74 if r == 0 else 132
                c = cancella(c, (x0, y0 + 2, 394, y1 - 2), False, allarga=3)
                c = scrivi(c, opz[k], (x0 + 4, y0 + 6, 392, y1 - 6), 'OldStandard-Regular', 31, (25, 22, 20), max_righe=3, allinea='s', px_min=19, interlinea=0.98)
        else:
            c = suppletiva(c, n <= 36)
        salva(c, f'{A}/carte/ev/{n}.webp')
    salva(Image.open(os.path.join(src, 'img', 'i25.jpg')).convert('RGB'), f'{A}/carte/ev/dorso.webp', 300)

def suppletiva(c, per_pm, cw=False):
    """Carta Elezione suppletiva (stessa struttura per gli eventi normali e Clockwork)."""
    if not cw:
        c = cancella(c, (150, 100, 610, 185), True)
        c = scrivi(c, 'ELEZIONE SUPPLETIVA', (110, 100, 640, 185), 'Rye-Regular', 40, (240, 205, 120), max_righe=1)
        c = cancella(c, (70, 262, 700, 345), False)
        c = scrivi(c, 'Arrotonda alla decina le tue Proiezioni elettorali.', (70, 262, 690, 345), 'OldStandard-Bold', 29, (20, 20, 20), max_righe=2)
        zone = [(250, 350, 500, 395, 'SE'), (70, 425, 335, 480, 'questo numero è'), (240, 518, 510, 568, 'ALLORA'),
                (90, 640, 372, 790, 'Al PM' if per_pm else "Al Capo dell'Opposizione"), (90, 870, 400, 940, "All'Opposizione")]
    else:
        c = cancella(c, (150, 225, 610, 285), True)
        c = scrivi(c, 'ELEZIONE SUPPLETIVA', (140, 225, 610, 285), 'Rye-Regular', 29, (240, 205, 120), max_righe=1)
        c = cancella(c, (70, 300, 700, 380), False)
        c = scrivi(c, 'Arrotonda alla decina le Proiezioni elettorali del PM.', (70, 300, 690, 380), 'OldStandard-Bold', 28, (20, 20, 20), max_righe=2)
        zone = [(250, 385, 500, 430, 'SE'), (70, 455, 335, 520, 'questo numero è'), (240, 548, 510, 598, 'ALLORA'),
                ]
        if per_pm:
            zone += [(100, 690, 345, 765, 'Al PM'), (60, 862, 405, 948, "Al Capo dell'Opposizione")]
        else:
            zone += [(60, 728, 368, 822, "Al Capo dell'Opposizione")]
    for x0, y0, x1, y1, tx in zone:
        c = cancella(c, (x0, y0, x1, y1), False)
        c = scrivi(c, tx, (x0, y0, x1, y1), 'OldStandard-Bold', 32, (20, 20, 20), max_righe=2, allinea='c' if tx in ('SE', 'ALLORA') else 'd')
    return c

# ---------------------------------------------------------------- sostenitori
NOMI_SOST = {2: "Duca di Argyll", 10: "Duca di Devonshire", 14: "Cardinale Newman", 15: "Conte di Iddesleigh", 17: "Conte di Malmesbury",
    21: "Duca di York", 23: "Principe Alberto", 24: "Principe di Galles", 25: "Principessa Elena", 26: "Principessa di Galles",
    31: "Duca di Wellington", 32: "Duca di Westminster", 34: "Conte Grey"}
def sostenitori(src):
    it = {int(p[0]): p[1] for p in righe('it_sost')}
    fg = Foglio(src, 'i26.png', 7, 5)
    m_or = fg.carta(1).crop((345, 852, 393, 892))   # "or" del Duca di Argyll
    for i in range(34):
        c = fg.carta(i)
        n = i + 1
        if n in NOMI_SOST:
            c = cancella(c, (150, 568, 600, 660), True, soglia=150)
            c = scrivi(c, NOMI_SOST[n], (150, 568, 600, 660), 'Milonga-Regular', 50, CREMA, max_righe=1, ombra=(8, 40, 22))
        if n != 26:
            c = cancella(c, (140, 676, 610, 728), True, soglia=120)
            c = scrivi(c, it[n], (150, 676, 600, 728), 'OldStandard-Regular', 30, (205, 170, 80), max_righe=1, px_min=17)
        c, k = sostituisci_modello(c, m_or, 'o', 'OldStandard-Bold', 30, (255, 255, 255), True, zona=(0, 740, 750, 1050), soglia=0.6)
        salva(c, f'{A}/carte/sost/{n}.webp')
    salva(Image.open(os.path.join(src, 'img', 'i27.jpg')).convert('RGB'), f'{A}/carte/sost/dorso.webp', 300)

# ---------------------------------------------------------------- carte Clockwork, Incertezza, politici, tabellone
def clockwork(src):
    fg = Foglio(src, 'i14.png', 6, 5)
    m_or = fg.carta(0).crop((335, 505, 415, 540))    # "OR"
    for i in range(28):
        c = fg.carta(i)
        c, k = sostituisci_modello(c, m_or, 'O', 'OldStandard-Bold', 30, (20, 20, 20), False, zona=(200, 440, 550, 880), soglia=0.6)
        salva(c, f'{A}/carte/scw/{i + 1}.webp')
    dorsi = Foglio(src, 'i15.png', 6, 5)
    d0 = dorsi.carta(0)
    d0 = cancella(d0, (190, 500, 560, 570), True, soglia=150)
    d0 = scrivi(d0, 'Sostenitori', (180, 496, 570, 574), 'Milonga-Regular', 60, CREMA, max_righe=1)
    salva(d0, f'{A}/carte/scw/dorso.webp', 300)
    d1 = dorsi.carta(20)
    d1 = cancella(d1, (190, 500, 560, 570), True, soglia=150)
    d1 = scrivi(d1, 'Sostenitori', (180, 496, 570, 574), 'Milonga-Regular', 60, CREMA, max_righe=1)
    d1 = cancella(d1, (240, 660, 520, 760), True, soglia=150)
    d1 = scrivi(d1, 'DA TENERE PER LE ELEZIONI', (230, 656, 530, 764), 'Milonga-Regular', 34, CREMA, max_righe=2)
    salva(d1, f'{A}/carte/scw/dorso_tieni.webp', 300)
    fe = Foglio(src, 'i12.png', 6, 4)
    for i in range(18):
        c = fe.carta(i)
        n = i + 1
        if n >= 15:
            c = suppletiva(c, n <= 16, cw=True)
        else:
            for x0, y0, x1, y1, tx in ((300, 262, 450, 300, 'SE'), (240, 738, 510, 786, 'ALLORA')):
                c = cancella(c, (x0, y0, x1, y1), False)
                c = scrivi(c, tx, (x0, y0, x1, y1), 'OldStandard-Bold', 34, (20, 20, 20), max_righe=1)
            if 3 <= n <= 6:
                c = cancella(c, (100, 380, 660, 650), False)
                c = scrivi(c, 'PM dato perdente alle prossime elezioni', (110, 380, 650, 650), 'Milonga-Regular', 62, (20, 20, 20), max_righe=3)
            else:
                c = cancella(c, (300, 500, 450, 540), False)
                c = scrivi(c, 'E', (300, 500, 450, 540), 'OldStandard-Bold', 34, (20, 20, 20), max_righe=1)
                c = cancella(c, (190, 590, 430, 690), False)
                c = scrivi(c, 'DISEGNO PIÙ ALTO', (150, 590, 425, 690), 'OldStandard-Regular', 36, (20, 20, 20), max_righe=2, interlinea=0.9)
        salva(c, f'{A}/carte/evc/{n}.webp')
    salva(Image.open(os.path.join(src, 'img', 'i13.jpg')).convert('RGB'), f'{A}/carte/evc/dorso.webp', 300)

def incertezza(src):
    fg = Foglio(src, 'i10.png', 5, 4)
    m_or = fg.carta(0).crop((345, 480, 405, 520))
    for i in range(18):
        c = fg.carta(i)
        c, k = sostituisci_modello(c, m_or, 'o', 'OldStandard-Bold', 32, (20, 20, 20), False, soglia=0.6)
        salva(c, f'{A}/carte/inc/{i + 1}.webp', 300)
    salva(Image.open(os.path.join(src, 'img', 'i11.jpg')).convert('RGB'), f'{A}/carte/inc/dorso.webp', 300)

ORD_POL = ['aberdeen', 'derby', 'disraeli', 'gladstone', 'melbourne', 'palmerston', 'peel', 'rosebery', 'russell', 'salisbury']
NOMI_POL = {'aberdeen': 'Conte di Aberdeen', 'derby': 'Conte di Derby', 'melbourne': 'Visconte Melbourne', 'palmerston': 'Visconte Palmerston',
    'rosebery': 'Conte di Rosebery', 'russell': 'Conte Russell', 'salisbury': 'Marchese di Salisbury'}
ABIL = {'CAMPAIGN': 'CAMPAGNA', 'DEBATE': 'DIBATTITO', 'FLATTER': 'LUSINGA', 'HOBNOB': 'SALOTTI', 'INFLUENCE': 'INFLUENZA'}
ABIL_POL = {'aberdeen': ['CAMPAIGN', 'DEBATE', 'FLATTER', 'HOBNOB'], 'derby': ['DEBATE', 'HOBNOB', 'INFLUENCE', 'FLATTER'],
    'disraeli': ['CAMPAIGN', 'DEBATE', 'FLATTER', 'HOBNOB'], 'gladstone': ['CAMPAIGN', 'DEBATE', 'HOBNOB', 'INFLUENCE'],
    'melbourne': ['DEBATE', 'FLATTER', 'HOBNOB', 'INFLUENCE'], 'palmerston': ['CAMPAIGN', 'DEBATE', 'HOBNOB', 'INFLUENCE'],
    'peel': ['CAMPAIGN', 'DEBATE', 'HOBNOB', 'INFLUENCE'], 'rosebery': ['CAMPAIGN', 'DEBATE', 'FLATTER', 'HOBNOB'],
    'russell': ['CAMPAIGN', 'DEBATE', 'HOBNOB', 'INFLUENCE'], 'salisbury': ['CAMPAIGN', 'DEBATE', 'HOBNOB', 'INFLUENCE']}
def or_piccoli(c, zona):
    """Sulla riga Campagna sostituisce i piccoli "or" con "o": li riconosce perché sono molto più bassi delle lettere dei settori."""
    x0, y0, x1, y1 = zona
    g = cv2.cvtColor(np.asarray(c)[y0:y1, x0:x1], cv2.COLOR_RGB2GRAY)
    n, _, st, _ = cv2.connectedComponentsWithStats((g > 165).astype(np.uint8), 8)
    piccoli = sorted([s for s in st[1:] if s[3] <= 24 and s[4] >= 12 and s[2] <= 26], key=lambda s: s[0])
    gruppi = []
    for s in piccoli:
        if gruppi and s[0] - (gruppi[-1][0] + gruppi[-1][2]) < 12:
            u = gruppi[-1]
            nx0, ny0 = min(u[0], s[0]), min(u[1], s[1])
            nx1, ny1 = max(u[0] + u[2], s[0] + s[2]), max(u[1] + u[3], s[1] + s[3])
            gruppi[-1] = [nx0, ny0, nx1 - nx0, ny1 - ny0]
        else:
            gruppi.append([s[0], s[1], s[2], s[3]])
    for u in gruppi:
        if u[2] < 14 or u[2] > 44:
            continue
        bx = (x0 + u[0] - 1, y0 + u[1] - 2, x0 + u[0] + u[2] + 1, y0 + u[1] + u[3] + 2)
        c = cancella(c, bx, True, soglia=150)
        testo_c(c, 'o', (bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2 - 4, 32, 'OldStandard-Bold', (236, 232, 222))
    return c

def politici(src):
    fg = Foglio(src, 'i51.png', 4, 3)
    for i, k in enumerate(ORD_POL):
        c = fg.carta(i)
        rit = c.crop((40, 20, 710, 590))
        salva(rit, f'{A}/carte/pol/{k}_ritratto.webp', 300, 86)
        if k in NOMI_POL:
            c = cancella(c, (70, 588, 680, 676), True, soglia=150)
            c = scrivi(c, NOMI_POL[k], (80, 586, 670, 678), 'Milonga-Regular', 56, CREMA, max_righe=1, ombra=(20, 20, 30))
        for r, ab in enumerate(ABIL_POL[k]):
            y = 712 + r * 70
            c = cancella(c, (40, y, 330, y + 66), True, soglia=140, allarga=3)
            c = scrivi(c, ABIL[ab], (40, y, 322, y + 66), 'OldStandard-Bold', 36, (236, 232, 222), max_righe=1, allinea='d')
        c = or_piccoli(c, (430, 704, 748, 776))
        c = cancella(c, (150, 990, 600, 1040), True, soglia=110)
        if k == 'aberdeen':
            c = scrivi(c, 'Non si usa in 2 giocatori', (150, 990, 600, 1036), 'OldStandard-Bold', 24, (215, 160, 60), max_righe=1)
        if k == 'rosebery':
            c = scrivi(c, 'Non si usa in 2 o 3 giocatori', (150, 990, 600, 1036), 'OldStandard-Bold', 24, (215, 160, 60), max_righe=1)
        salva(c, f'{A}/carte/pol/{k}.webp')
    fo = Image.open(os.path.join(src, 'img', 'i45.png')).convert('RGB')
    fp = Image.open(os.path.join(src, 'img', 'i46.png')).convert('RGB')
    w, h = fo.size[0] / 4, fo.size[1] / 3
    for i, k in enumerate(ORD_POL):
        box = (round((i % 4) * w), round((i // 4) * h), round((i % 4 + 1) * w), round((i // 4 + 1) * h))
        opp, pm = carte_clockwork(fo.crop(box).resize((825, 1425), Image.LANCZOS), fp.crop(box).resize((825, 1425), Image.LANCZOS), k)
        salva(opp, f'{A}/carte/cw/{k}_opp.webp', 480, 86)
        salva(pm, f'{A}/carte/cw/{k}_pm.webp', 480, 86)

# att, dif, difmp, pb, sel, selmp, partito (gli stessi numeri di scripts/dati.gd)
CW = {'aberdeen': ((300, 350), (270, 340), None, 280, 300, None, 'C'), 'derby': ((290, 370), (260, 340), None, 260, 290, None, 'C'),
    'disraeli': ((300, 350), (280, 340), None, 280, 310, None, 'C'), 'gladstone': ((300, 370), (260, 340), None, 260, 290, None, 'L'),
    'melbourne': ((300, 350), (270, 340), None, 270, 300, None, 'L'), 'palmerston': ((310, 340), (290, 340), None, 270, 320, None, 'L'),
    'peel': ((310, 340), (290, 340), None, 270, 320, None, 'C'), 'rosebery': ((300, 350), (270, 340), None, 280, 300, None, 'L'),
    'russell': ((300, 350), (280, 340), (250, 340), 250, 310, 280, 'L'), 'salisbury': ((300, 350), (280, 340), (250, 340), 250, 310, 280, 'C')}
ORO_C = (185, 133, 43)
NERO_T = (24, 22, 20)

def esagono(im, cx, cy, testo, larg=124, alt=108, px=46):
    d = ImageDraw.Draw(im)
    def punti(w, h):
        return [(cx - w / 2, cy), (cx - w / 4, cy - h / 2), (cx + w / 4, cy - h / 2), (cx + w / 2, cy), (cx + w / 4, cy + h / 2), (cx - w / 4, cy + h / 2)]
    d.polygon(punti(larg, alt), fill=ORO_C)
    d.polygon(punti(larg - 14, alt - 12), fill=(28, 26, 24))
    d.line(punti(larg - 26, alt - 22) + [punti(larg - 26, alt - 22)[0]], fill=ORO_C, width=2)
    ft = font('OldStandard-Regular', px)
    w = d.textlength(testo, font=ft)
    asc, desc = ft.getmetrics()
    d.text((cx - w / 2, cy - (asc + desc) / 2 - 2), testo, font=ft, fill=(214, 164, 70))

def riquadro_tipo(im, tipo, cx, cy, lato=58):
    ic = Image.open(f'{A}/ui/tipo_{tipo}.png').convert('RGB').resize((lato, lato), Image.LANCZOS)
    im.paste(ic, (int(cx - lato / 2), int(cy - lato / 2)))

def testo_c(im, testo, cx, cy, px, nome='OldStandard-Regular', colore=NERO_T):
    d = ImageDraw.Draw(im)
    ft = font(nome, px)
    w = d.textlength(testo, font=ft)
    asc, desc = ft.getmetrics()
    d.text((cx - w / 2, cy - (asc + desc) / 2), testo, font=ft, fill=colore)
    return w

def filetto(im, y, x0=110, x1=715):
    d = ImageDraw.Draw(im)
    d.line([(x0, y), (x1, y)], fill=ORO_C, width=3)
    cx = (x0 + x1) / 2
    d.polygon([(cx - 11, y), (cx, y - 11), (cx + 11, y), (cx, y + 11)], fill=(30, 40, 60), outline=ORO_C)

def carta_vuota(im, toppa, y0, y1):
    """Copre la fascia y0..y1 con la carta vuota presa da `toppa` (ripetuta a specchio)."""
    h = toppa.size[1]
    y, giro = y0, 0
    while y < y1:
        pezzo = toppa if giro % 2 == 0 else toppa.transpose(Image.FLIP_TOP_BOTTOM)
        taglio = min(h, y1 - y)
        im.paste(pezzo.crop((0, 0, toppa.size[0], taglio)), (40, y))
        y += taglio
        giro += 1

def trova_filetto(c, da, a):
    """Riga del primo filetto dorato orizzontale fra le righe da..a (quello che chiude le opzioni dei cubi)."""
    arr = np.asarray(c)[da:a, 150:680].astype(int)
    oro = (abs(arr[..., 0] - 185) < 45) & (abs(arr[..., 1] - 133) < 45) & (arr[..., 2] < 110)
    righe_ = np.where(oro.sum(axis=1) > 300)[0]
    return da + int(righe_[0]) if len(righe_) else None

def carte_clockwork(opp, pm, k):
    att, dif, difmp, pb, sel, selmp, par = CW[k]
    out = []
    for c, ruolo, lato in ((opp, "CAPO DELL'OPPOSIZIONE", 'opp'), (pm, 'PRIMO MINISTRO', 'pm')):
        c = cancella(c, (138, 310, 478, 354), True, soglia=None, allarga=3)
        c = scrivi(c, ruolo, (140, 310, 476, 354), 'OldStandard-Bold', 30, (214, 164, 70), max_righe=1, px_min=18)
        for n, cx in enumerate((172, 410, 660)):
            c = cancella(c, (cx - 52, 466, cx + 52, 524), False)
            testo_c(c, '%d°' % (n + 1), cx, 495, 44)
        yf = trova_filetto(c, 860, 1100)
        if lato == 'opp':
            toppa = c.crop((40, yf + 16, 785, yf + 30))   # carta vuota: sotto il filetto dell'Opposizione non c'è nulla
        if lato == 'opp':
            carta_vuota(c, toppa, yf + 16, 1290)
            cy = (yf + 1300) // 2
            c = scrivi(c, "RAGGIO D'ATTACCO", (70, cy - 60, 320, cy + 60), 'OldStandard-Regular', 42, NERO_T, max_righe=2, interlinea=0.92)
            esagono(c, 400, cy, str(att[0]), 140, 122, 52)
            testo_c(c, 'a', 525, cy - 4, 50)
            esagono(c, 650, cy, str(att[1]), 140, 122, 52)
        else:
            y0 = yf + 16
            carta_vuota(c, toppa, y0, 1392)
            filetto(c, 1396)
            f = (1392 - y0) / 480.0
            def Y(v):
                return int(y0 + (v - 912) * f)
            def Z(v):
                return max(10, int(v * (0.55 + 0.45 * f)))
            mazzo = 'LIBERALI' if par == 'L' else 'CONSERVATORI'
            if difmp is None:
                c = scrivi(c, 'RAGGIO DI DIFESA', (80, Y(935), 330, Y(1045)), 'OldStandard-Regular', Z(40), NERO_T, max_righe=2, interlinea=0.92)
                esagono(c, 410, Y(990), str(dif[0]), Z(124), Z(108), Z(46))
                testo_c(c, 'a', 520, Y(986), Z(48))
                esagono(c, 640, Y(990), str(dif[1]), Z(124), Z(108), Z(46))
            else:
                testo_c(c, 'RAGGIO DI DIFESA', 412, Y(940), Z(36))
                riquadro_tipo(c, 'A', 82, Y(1015), Z(50))
                esagono(c, 170, Y(1015), str(dif[0]), Z(100), Z(88), Z(38))
                testo_c(c, 'a', 242, Y(1011), Z(36))
                esagono(c, 314, Y(1015), str(dif[1]), Z(100), Z(88), Z(38))
                riquadro_tipo(c, 'M', 418, Y(1015) - Z(25), Z(44))
                riquadro_tipo(c, 'P', 418, Y(1015) + Z(25), Z(44))
                esagono(c, 520, Y(1015), str(difmp[0]), Z(100), Z(88), Z(38))
                testo_c(c, 'a', 592, Y(1011), Z(36))
                esagono(c, 664, Y(1015), str(difmp[1]), Z(100), Z(88), Z(38))
            d = ImageDraw.Draw(c)
            d.line([(170, Y(1078)), (655, Y(1078))], fill=ORO_C, width=3)
            testo_c(c, 'PESCA I DISEGNI ' + mazzo, 412, Y(1118), Z(34))
            w1 = testo_c(c, 'SE I PARTIGIANI', 330, Y(1172), Z(34))
            riquadro_tipo(c, 'P', 330 + w1 / 2 + 44, Y(1172), Z(50))
            x0 = 330 + w1 / 2 + 82
            d.rectangle((x0, Y(1172) - Z(25), x0 + 132, Y(1172) + Z(25)), fill=(196, 150, 208), outline=ORO_C, width=3)
            testo_c(c, '\u2265 %d' % pb, x0 + 66, Y(1170), Z(36), colore=(40, 50, 120))
            d.line([(170, Y(1228)), (655, Y(1228))], fill=ORO_C, width=3)
            if selmp is None:
                c = scrivi(c, 'RAGGIO DI SELEZIONE', (130, Y(1252), 420, Y(1372)), 'OldStandard-Regular', Z(40), NERO_T, max_righe=2, interlinea=0.92)
                esagono(c, 548, Y(1312), '\u2265%d' % sel, Z(164), Z(122), Z(42))
            else:
                c = scrivi(c, 'RAGGIO DI SELEZIONE', (62, Y(1256), 270, Y(1368)), 'OldStandard-Regular', Z(32), NERO_T, max_righe=2, interlinea=0.92)
                riquadro_tipo(c, 'A', 312, Y(1312), Z(50))
                esagono(c, 414, Y(1312), '\u2265%d' % sel, Z(134), Z(100), Z(31))
                riquadro_tipo(c, 'M', 520, Y(1312) - Z(26), Z(44))
                riquadro_tipo(c, 'P', 520, Y(1312) + Z(26), Z(44))
                esagono(c, 640, Y(1312), '\u2265%d' % selmp, Z(134), Z(100), Z(31))
        out.append(c)
    return out[0], out[1]

def testo_arco(im, testo, cx, cy_apice, raggio, nome, px, colore, spaziatura=1.0):
    """Scrive il testo lungo un arco di cerchio (centro sotto il testo), centrato sull'apice."""
    import math
    ft = font(nome, px)
    d = ImageDraw.Draw(im)
    larg = [d.textlength(ch, font=ft) * spaziatura for ch in testo]
    tot = sum(larg)
    asc, desc = ft.getmetrics()
    ang = -tot / 2 / raggio
    cyc = cy_apice + raggio
    for ch, w in zip(testo, larg):
        a = ang + w / 2 / raggio
        if ch != ' ':
            tile = Image.new('RGBA', (int(w + px), int(asc + desc + 8)), (0, 0, 0, 0))
            ImageDraw.Draw(tile).text(((tile.size[0] - w / spaziatura) / 2, 4), ch, font=ft, fill=colore + (255,))
            rot = tile.rotate(-math.degrees(a), resample=Image.BICUBIC, expand=True)
            x = cx + raggio * math.sin(a)
            y = cyc - raggio * math.cos(a)
            im.paste(rot, (int(x - rot.size[0] / 2), int(y - rot.size[1] / 2)), rot)
        ang += w / raggio

def tabellone(src):
    """Tabellone originale con tutte le scritte in italiano."""
    b = Image.open(os.path.join(src, 'img', 'i42.jpg')).convert('RGB')
    CR = (250, 244, 222)
    # titolo e note del punteggio
    b = cancella(b, (2190, 60, 3080, 222), True, soglia=170, allarga=5, raggio=7)
    b = scrivi(b, 'PUNTEGGIO', (2100, 60, 3170, 226), 'Milonga-Regular', 150, CR, max_righe=1, ombra=(60, 10, 12))
    b = cancella(b, (2280, 604, 2560, 688), True, soglia=150)
    b = scrivi(b, 'NIENTE RINVIO DELLE ELEZIONI', (2230, 604, 2600, 690), 'OldStandard-Bold', 36, CR, max_righe=2, interlinea=0.9)
    b = cancella(b, (3200, 604, 3600, 696), True, soglia=150)
    b = scrivi(b, 'DECANO DELLA CAMERA, NIENTE DIMISSIONI', (3150, 604, 3650, 696), 'OldStandard-Bold', 36, CR, max_righe=2, interlinea=0.9)
    # nastri dei settori
    nastri = [(570, 785, 'CONSERVATORI'), (1565, 785, 'AGRICOLTORI'), (2520, 785, 'GENTRY'), (3475, 785, 'IRLANDA'),
              (570, 2067, 'LIBERALI'), (1565, 2067, 'CETO MEDIO'), (2520, 2067, 'SCOZIA'), (3475, 2067, 'OPERAI')]
    for cx, cy, nome in nastri:
        b = cancella(b, (cx - 215, cy - 62, cx + 215, cy + 78), True, soglia=205, allarga=3, raggio=4)
        testo_arco(b, nome, cx, cy - 6, 470, 'OldStandard-Bold', 46 if len(nome) > 9 else 52, (250, 248, 236), 1.06)
    # proiezioni elettorali
    b = cancella(b, (4215, 1070, 5065, 1265), False, soglia=85, allarga=5, raggio=6)
    testo_arco(b, 'PROIEZIONI', 4650, 1168, 1030, 'Rye-Regular', 118, (38, 36, 34), 1.04)
    b = cancella(b, (4368, 1256, 4915, 1362), False, soglia=85, allarga=4, raggio=5)
    testo_arco(b, 'ELETTORALI', 4650, 1304, 980, 'OldStandard-Bold', 58, (38, 36, 34), 1.12)
    b = cancella(b, (4012, 1498, 4222, 1590), True, soglia=170)
    b = scrivi(b, 'PARI', (4010, 1498, 4224, 1592), 'OldStandard-Bold', 76, (236, 234, 228), max_righe=1)
    # Favore e linguette
    b = cancella(b, (5900, 118, 6475, 256), True, soglia=125, allarga=5, raggio=7)
    b = scrivi(b, 'FAVORE', (5890, 118, 6480, 256), 'Rye-Regular', 122, (214, 164, 70), max_righe=1, ombra=(40, 26, 12))
    for cx, cy, lung, nome, px in ((6517, 1200, 150, 'Patto', 52), (6508, 1985, 520, 'BB di Governo dimesso', 46)):
        d = ImageDraw.Draw(b)
        d.rectangle((cx - 40, cy - lung / 2, cx + 40, cy + lung / 2), fill=(2, 12, 6))
        tile = Image.new('RGBA', (lung + 40, 90), (0, 0, 0, 0))
        dt = ImageDraw.Draw(tile)
        ft = font('Milonga-Regular', px)
        w = dt.textlength(nome, font=ft)
        dt.text(((tile.size[0] - w) / 2, 8), nome, font=ft, fill=(206, 160, 70, 255))
        rot = tile.rotate(90, expand=True)
        b.paste(rot, (int(cx - rot.size[0] / 2), int(cy - rot.size[1] / 2)), rot)
    # deputati di Governo
    for box, nome, px in (((5040, 3410, 6150, 3548), 'DEPUTATI DI GOVERNO', 120), ((5000, 3584, 5170, 3676), 'TUTTI', 60),
                          ((5436, 3584, 5850, 3676), 'MODERATI', 60), ((6026, 3584, 6410, 3676), 'PARTIGIANI', 60),
                          ((5200, 4912, 6010, 5016), '330 VOTI PER APPROVARE', 56)):
        b = cancella(b, box, True, soglia=140, allarga=5, raggio=6)
        b = scrivi(b, nome, (box[0] + (22 if px == 60 else -10), box[1], box[2] + 40, box[3]), 'OldStandard-Bold', px, (252, 240, 196), max_righe=1, allinea='c' if px != 60 else 's')
    # caselle dei disegni di legge e segnalino delle elezioni
    for sx in (449, 1537, 2624):
        b = cancella(b, (sx - 190, 4200, sx + 190, 4380), True, soglia=150, allarga=5, raggio=6)
        b = scrivi(b, 'LEGGE', (sx - 200, 4200, sx + 200, 4380), 'Milonga-Regular', 110, (236, 200, 170), max_righe=1)
    b = cancella(b, (3770, 4448, 4252, 4580), False, soglia=95, allarga=5, raggio=6)
    b = scrivi(b, 'ELEZIONI', (3770, 4444, 4254, 4582), 'Rye-Regular', 86, (44, 40, 34), max_righe=1)
    salva(b, f'{A}/tabellone.webp', 3300, 88)

PASSI = {'ddl': ddl, 'ev': eventi, 'sost': sostenitori, 'cw': clockwork, 'inc': incertezza, 'ico': None, 'pol': politici, 'tab': tabellone}

# ---------------------------------------------------------------- icone
def scontorna(im, toll=38):
    """Rende trasparente il fondo carta partendo dai bordi del ritaglio."""
    a = cv2.cvtColor(np.asarray(im.convert('RGB')), cv2.COLOR_RGB2BGR)
    h, w = a.shape[:2]
    m = np.zeros((h + 2, w + 2), np.uint8)
    for x in range(0, w, 3):
        for y in (0, h - 1):
            if m[y + 1, x + 1] == 0:
                cv2.floodFill(a, m, (x, y), (0, 0, 0), (toll,) * 3, (toll,) * 3, 8 | cv2.FLOODFILL_MASK_ONLY | cv2.FLOODFILL_FIXED_RANGE | (255 << 8))
    for y in range(0, h, 3):
        for x in (0, w - 1):
            if m[y + 1, x + 1] == 0:
                cv2.floodFill(a, m, (x, y), (0, 0, 0), (toll,) * 3, (toll,) * 3, 8 | cv2.FLOODFILL_MASK_ONLY | cv2.FLOODFILL_FIXED_RANGE | (255 << 8))
    alfa = 255 - m[1:-1, 1:-1]
    alfa = cv2.GaussianBlur(cv2.erode(alfa, np.ones((2, 2), np.uint8)), (3, 3), 0)
    out = im.convert('RGBA')
    out.putalpha(Image.fromarray(alfa))
    return out

def icone(src):
    x = Foglio(src, 'i02.png', 7, 6)
    ev = Foglio(src, 'i24.png', 7, 6)
    patto = Image.open(os.path.join(src, 'img', 'i06.jpg')).convert('RGB').resize((750, 1050), Image.LANCZOS)
    os.makedirs(f'{A}/ui', exist_ok=True)
    ritagli = {
        'esagono': (x.carta(0), (340, 580, 480, 696)),
        'coccarda_C': (patto, (36, 24, 210, 340)),
        'coccarda_L': (patto, (540, 24, 714, 340)),
    }
    for nome, (carta, box) in ritagli.items():
        c = scontorna(carta.crop(box))
        c.save(f'{A}/ui/{nome}.png')
    # medaglioni di Favore (la Regina) e Standing (il Big Ben): maschera a ellisse più il fregio in alto
    for nome, carta, cx, cy, rx, ry, fregio in (('favore', x.carta(13), 318, 864, 58, 76, (286, 752, 346, 800)),
                                               ('standing', x.carta(22), 345, 870, 57, 76, (312, 766, 376, 806))):
        box = (cx - rx - 4, fregio[1] - 2, cx + rx + 4, cy + ry + 4)
        c = carta.crop(box).convert('RGBA')
        m = Image.new('L', c.size, 0)
        d = ImageDraw.Draw(m)
        d.ellipse((cx - rx - box[0], cy - ry - box[1], cx + rx - box[0], cy + ry - box[1]), fill=255)
        fr = scontorna(carta.crop(fregio), 30)
        m.paste(fr.getchannel('A'), (fregio[0] - box[0], fregio[1] - box[1]))
        d.ellipse((cx - rx - box[0], cy - ry - box[1], cx + rx - box[0], cy + ry - box[1]), fill=255)
        c.putalpha(m)
        c.save(f'{A}/ui/{nome}.png')
    x.carta(25).crop((200, 582, 316, 694)).save(f'{A}/ui/tipo_M.png')
    Foglio(src, 'i00.png', 5, 4).carta(9).crop((200, 582, 316, 694)).save(f'{A}/ui/tipo_P.png')
    # carta da lettere: una zona vuota di una carta, resa ripetibile specchiandola
    t = x.carta(0).crop((44, 592, 184, 688))
    w, h = t.size
    T = Image.new('RGB', (w * 2, h * 2))
    T.paste(t, (0, 0)); T.paste(t.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    T.paste(t.transpose(Image.FLIP_TOP_BOTTOM), (0, h)); T.paste(t.transpose(Image.ROTATE_180), (w, h))
    T.save(f'{A}/ui/carta.png')
    stemma = scontorna(x.carta(0).crop((180, 20, 570, 318)), 60)
    stemma.save(f'{A}/ui/stemma.png')

PASSI['ico'] = icone

if __name__ == '__main__':
    src = sys.argv[1]
    quali = sys.argv[2:] or list(PASSI)
    for q in quali:
        PASSI[q](src)
        print('fatto', q)

