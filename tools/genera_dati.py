#!/usr/bin/env python3
"""Genera scripts/dati_gen.gd dai file di testo in tools/dati (trascritti dalle carte originali)."""
import json, os
R = os.path.dirname(os.path.abspath(__file__))
def righe(n):
    return [l.rstrip('\n') for l in open(f'{R}/dati/{n}.txt', encoding='utf-8') if l.strip() and not l.startswith('#')]
def ddl(n, pre):
    out = []
    for l in righe(n):
        num, tit, sub, tipo, adj, pv, eff = l.split('|')
        out.append({'id': f'{pre}{num}', 'n': int(num), 'mazzo': pre, 'titolo': tit, 'sotto': sub, 'tipo': tipo,
                    'ret': int(adj), 'pv': int(pv), 'eff': eff.split()})
    return out
dati = {}
dati['DDL'] = ddl('ddl_x', 'X') + ddl('ddl_con', 'C') + ddl('ddl_lib', 'L')
dati['INCERTEZZA'] = [dict(zip(('n', 'voti', 'seggi', 'reale'), map(int, l.split('|')))) for l in righe('incertezza')]
ev = []
for l in righe('eventi'):
    p = l.split('|')
    if p[1] == 'BY-ELECTION':
        ev.append({'n': int(p[0]), 'titolo': p[1], 'supp': p[2]})
    else:
        ops = []
        for o in p[2:]:
            nome, costo, eff = o.split('~')
            ops.append({'nome': nome, 'costo': int(costo), 'eff': eff.split()})
        ev.append({'n': int(p[0]), 'titolo': p[1], 'opz': ops})
dati['EVENTI'] = ev
evc = []
for l in righe('eventi_cw'):
    p = l.split('|')
    if p[1] == 'BYE':
        evc.append({'n': int(p[0]), 'supp': p[2]})
    else:
        evc.append({'n': int(p[0]), 'cond': p[1], 'costo': int(p[2]), 'eff': p[3]})
dati['EVENTI_CW'] = evc
dati['SOSTENITORI'] = [dict(n=int(p[0]), nome=p[1], ruolo=p[2], opz=[p[3].split(), p[4].split()])
                       for p in (l.split('|') for l in righe('sostenitori'))]
dati['SOSTENITORI_CW'] = [dict(n=int(p[0]), opz=[p[1], p[2], p[3]], tieni=int(p[0]) >= 18)
                          for p in (l.split('|') for l in righe('sostenitori_cw'))]
it = lambda n: [l.rstrip('\n').split('|') for l in open(f'{R}/dati/{n}.txt', encoding='utf-8') if l.strip() and not l.startswith('#')]
dati['IT_DDL'] = {p[0]: [p[1], p[2]] for p in it('it_ddl')}
dati['IT_EVENTI'] = {p[0]: p[1:] for p in it('it_eventi')}
dati['IT_SOST'] = {p[0]: p[1] for p in it('it_sost')}
with open(f'{R}/../scripts/dati_gen.gd', 'w', encoding='utf-8') as f:
    f.write('## Generato da tools/genera_dati.py: non modificare a mano.\nclass_name DatiGen\nextends RefCounted\n\n')
    for k, v in dati.items():
        f.write(f'const {k} := {json.dumps(v, ensure_ascii=False)}\n\n')
print({k: len(v) for k, v in dati.items()})
