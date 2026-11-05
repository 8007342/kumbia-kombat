"""Compare sprite scaling filters through a depth move. Usage: depth_scale_probe.py <out_dir>. Simulation in PIL, not the game renderer."""
import json,sys
import numpy as np
from PIL import Image
out=sys.argv[1]
a=json.load(open('assets/art/ensemble/manifest.json'))['atlases']['bartender']
x,y,w,h=a['frames'][a['referenceFrame']]['rect']
art=Image.open('assets/art/ensemble/'+a['image']).convert('RGBA').crop((x,y,x+w,y+h))
pre=art.resize((w*4,h*4),Image.NEAREST)
mip=art.reduce(2)
H=lambda fy:0.1263*(fy-.16)/(.4-.16)*844
n=169;ys=[.42+.16*(.5-.5*np.cos(2*np.pi*i/n)) for i in range(n)]
def size(sc): return max(1,round(w*sc)),max(1,round(h*sc))
M={'nearest':lambda s:art.resize(size(s),Image.NEAREST),
   'bilinear':lambda s:art.resize(size(s),Image.BILINEAR),
   'sharp':lambda s:pre.resize(size(s),Image.BILINEAR,reducing_gap=None)}
def comp(im,c=(400,620)):
    b=Image.new('RGBA',c,(30,40,48,255));b.alpha_composite(im,((c[0]-im.size[0])//2,c[1]-im.size[1]));return b.convert('RGB')
def ideal(s):  # high-quality reference: box-filter the 4x prescale at that size
    return pre.resize(size(s),Image.BOX)
for dpr in (1,2,3):
  print('DPR',dpr)
  for name,f in M.items():
    errs=[];sharp=[];j=[]
    prev=None
    for v in ys[::3]:
        s=H(v)*dpr/h
        A=np.asarray(comp(f(s)),dtype=float);B=np.asarray(comp(ideal(s)),dtype=float)
        errs.append(np.abs(A-B).mean())
        g=A.mean(2);sharp.append(np.abs(np.diff(g,axis=1)).mean())
    e=np.array(errs);sh=np.array(sharp)
    # crawl proxy: how much error against the stable reference varies between neighbouring frames
    print(f'  {name:9s} error vs stable ref {e.mean():.2f}  frame-to-frame jitter of that error {np.abs(np.diff(e)).mean():.3f}  edge energy {sh.mean():.2f}')
idx=[42+k for k in range(6)]
st=Image.new('RGB',(1200,600))
for j,k in enumerate(M):
  for q,i in enumerate(idx):
    s=H(ys[i])*3/h;im=comp(M[k](s));top=620-size(s)[1]
    st.paste(im.crop((150,top,250,top+100)).resize((198,198),Image.NEAREST),(q*200,j*200))
st.save(out+'/head-strip2.png')
fr=[]
for i in range(0,n,2):
    t=Image.new('RGB',(1200,620))
    for j,k in enumerate(M): t.paste(comp(M[k](H(ys[i])*3/h)),(j*400,0))
    fr.append(t.resize((900,465),Image.NEAREST))
fr[0].save(out+'/depth-compare.gif',save_all=True,append_images=fr[1:],duration=33,loop=0)
