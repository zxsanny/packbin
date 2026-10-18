# the pasted "other agent" Huffman scheme, unchanged, measured on the same corpus (filtered to its alphabet)
import heapq, random, sys, os
S=os.environ.get('PACKBIN_BENCH_DIR', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UKR_FREQ_ORDER = " оаеиінрвкдлпмустзбгчшжйхцщфїєюяґ"
LAT_FREQ_ORDER = " etaoinsrhdlcumwfgypbvkjxqz"
SHARED_CHARS   = ".,!?_0123456789"
WEIGHTS = [180,110,95,85,75,70,65,55,50,45,38,36,34,32,30,28,25,22,18,16,15,12,10,9,8,7,6,5,4,4,3,3,2,1]
SHARED_WEIGHTS = [20,20,8,8,5,6,5,5,4,4,4,3,3,3,3]
SWITCH_WEIGHT=10
class Node:
    def __init__(self,sym,weight,left=None,right=None):
        self.sym=sym;self.weight=weight;self.left=left;self.right=right
    def __lt__(self,o): return self.weight<o.weight
def build_huffman():
    heap=[]
    for i,w in enumerate(WEIGHTS): heapq.heappush(heap,Node(i,w))
    for i,w in enumerate(SHARED_WEIGHTS): heapq.heappush(heap,Node(34+i,w))
    heapq.heappush(heap,Node(49,SWITCH_WEIGHT))
    while len(heap)>1:
        l,r=heapq.heappop(heap),heapq.heappop(heap)
        heapq.heappush(heap,Node(None,l.weight+r.weight,l,r))
    codes={}
    def walk(n,p=""):
        if n.sym is not None: codes[n.sym]=p;return
        walk(n.left,p+"0");walk(n.right,p+"1")
    walk(heap[0]);return codes,heap[0]
CODES,TREE=build_huffman()
def encode(text):
    mode="ukr";bits=[]
    for ch in text:
        if ch in SHARED_CHARS: sym=34+SHARED_CHARS.index(ch)
        elif ch==" ": sym=0
        elif mode=="ukr" and ch in UKR_FREQ_ORDER: sym=UKR_FREQ_ORDER.index(ch)
        elif mode=="lat" and ch in LAT_FREQ_ORDER: sym=LAT_FREQ_ORDER.index(ch)
        else:
            bits.append(CODES[49]);mode="lat" if mode=="ukr" else "ukr"
            order=UKR_FREQ_ORDER if mode=="ukr" else LAT_FREQ_ORDER
            sym=order.index(ch)
        bits.append(CODES[sym])
    bs="".join(bits);pad=(8-(len(bs)+3)%8)%8
    fb=f"{pad:03b}"+bs+"0"*pad
    return int(fb,2).to_bytes(len(fb)//8,"big")
def decode(data):
    bs="".join(f"{b:08b}" for b in data);pad=int(bs[:3],2)
    payload=bs[3:len(bs)-pad if pad else len(bs)]
    mode="ukr";out=[];node=TREE
    for b in payload:
        node=node.left if b=="0" else node.right
        if node.sym is not None:
            s=node.sym
            if s==49: mode="lat" if mode=="ukr" else "ukr"
            elif s>=34: out.append(SHARED_CHARS[s-34])
            else: out.append((UKR_FREQ_ORDER if mode=="ukr" else LAT_FREQ_ORDER)[s])
            node=TREE
    return "".join(out)
random.seed(7)
for lang,name in (("ukr","ua"),("eng","en")):
    rows=[l.rstrip("\n").split("\t",2)[2].lower() for l in open(f"{S}/corpus/{lang}_sentences.tsv",encoding="utf8")]
    ok=set(UKR_FREQ_ORDER+LAT_FREQ_ORDER+SHARED_CHARS)
    rows=[r for r in rows if 3<=len(r)<=100 and all(c in ok for c in r)]
    print(name,"sentences fully inside their alphabet:",len(rows))
    sample=random.sample(rows,min(1500,len(rows)))
    tb=0;tc=0;bad=0
    for t in sample:
        try:
            p=encode(t)
            if decode(p)!=t: bad+=1
        except Exception as e:
            bad+=1;continue
        tb+=len(p);tc+=len(t)
    print(f"  their scheme: {8*tb/tc:.2f} bits/char without length header, {8*(tb+len(sample))/tc:.2f} with 1 header byte; round-trip failures {bad}/{len(sample)}")
# a message with a capital, an apostrophe and a colon
for t in ["Привіт","м'яч","a:b"]:
    try: encode(t);print(repr(t),"ok")
    except Exception as e: print(repr(t),"->",type(e).__name__,e)
