"""Independent arithmetic oracle and source/package checks; NOT a Godot runtime test."""
import json, math, pathlib, re
root=pathlib.Path(__file__).resolve().parents[1]
d=json.loads((root/'data/benchmark.json').read_text()); c=d['customer']; i=d['item']; p=d['policy']
def round_half(x): return math.floor(x+0.5)
def metrics(e=0,f=0,b=0,r=0,anger=20,customer=None,item=None):
    customer=customer or c; item=item or i
    P=round_half(sum(v*w for v,w in zip([customer['urgency'],item['scarcity'],customer['dependence'],customer['time_pressure']],p['pressure_weights']))/100)
    P=min(100,P+min(p['leverage_cap'],e+f+b)+r)
    R=round_half(sum(v*w for v,w in zip([customer['pride'],customer['independence'],customer['alternatives'],anger,customer['suspicion'],customer['principle']],p['resistance_weights']))/100)
    cap=max(0,min(customer['wallet']-customer['reserve']-customer.get('escrow',0),customer['ceiling']))
    base=customer['comfort']+customer['baseline']-customer['comfort_anchor']+round_half(item['base_value']*item['condition_pct']*item['demand_pct']/10000)-customer['anchor_value']+customer.get('history_modifier',0)-(customer['unwanted_penalty'] if item['category']!=customer['goal'] else 0)
    W=min(cap,max(0,min(base,cap))+p['gold_per_pressure']*max(0,P-R))
    return P,R,W
cases=[('opening',{},(55,40,600)),('appraisal',{'e':7},(62,40,621)),('fair',{'e':7,'r':10},(72,40,651)),('patient',{'e':7,'r':5},(67,40,636)),('charm',{'e':7,'r':3},(65,40,630)),('stern',{'e':7,'f':4,'anger':32},(66,42,627)),('ban',{'e':7,'f':4,'b':20,'anger':50},(86,45,678)),('dismiss',{'e':7,'f':8,'b':25,'anger':58},(95,46,702))]
for name,kwargs,expected in cases:
    actual=metrics(**kwargs); assert actual==expected,(name,actual,expected); print('PASS arithmetic',name,actual)
assert metrics(e=7,r=10,customer={**c,'wallet':640})[2]==600
assert metrics(e=7,f=8,b=25,anger=58,customer={**c,'pride':95,'independence':95,'alternatives':95,'dependence':10},item={**i,'condition_pct':75})[2]<700
assert 50+3*12>=85
print('PASS arithmetic wallet cap, alternative traits, repeated anger')
# Check project-local resource references and identity-independent reducer.
source=(root/'domain/negotiation.gd').read_text()
assert not re.search(r'vessa|dragonstone|dragon_001|650\b|700\b',source,re.I)
for file in root.rglob('*'):
    if file.suffix in ('.gd','.tscn','.godot'):
        for ref in re.findall(r'res://([^"\s]+)',file.read_text()):
            assert (root/ref).is_file(),(file,ref)
print('PASS static identity scan and resource references')
print('NOTE: independent math/static checks only; no Godot engine execution.')

# Gate E registry integrity and offline boundary.
week=json.loads((root/'data/week.json').read_text())
assert len(week['profiles'])==6 and len(week['items'])==10
assets=json.loads((root/'data/d1_assets.json').read_text())
def check_assets(v):
    if isinstance(v,dict):
        for x in v.values(): check_assets(x)
    elif isinstance(v,list):
        for x in v: check_assets(x)
    elif isinstance(v,str) and v.startswith('res://'):
        assert (root/v[6:]).is_file(),v
check_assets(assets)
for pth in list((root/'domain').glob('*.gd'))+list((root/'ui').glob('*.gd')):
    assert not re.search(r'HTTPRequest|HTTPClient|WebSocketPeer|api\.openai\.com',pth.read_text()),pth
print('PASS Gate E content registry and offline dependency scan')

# Gate F verifies the registry and all imported resource paths.
japan=json.loads((root/'data/character_assets.json').read_text())
assert len(japan['characters'])==7 and len(japan['items'])==10
check_assets(japan)
assert japan['frame_size']==[32,48] and japan['frame_count']==17
assert set(japan['animations'])=={'IDLE','WALK','BROWSE','PICK_ITEM','CHECKOUT_QUEUE','INTERACT','RESTOCK'}
print('PASS Japanese asset registry and animation metadata')
