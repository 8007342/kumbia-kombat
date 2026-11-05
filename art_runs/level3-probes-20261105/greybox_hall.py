#!/usr/bin/env python3
"""Throwaway probe of N-level reuse: same camera model, a different room. An angled indoor ballroom running to the top LEFT."""
import math, json, sys
import numpy as np
from PIL import Image, ImageDraw
W, H = 1024, 1536; HZ = .24 * H; EYE = 2.4; F = 900.; VPU = 40.; STARTU = 760.; PW = 5.0; END = 12.
a = math.atan((VPU - W/2) / F); d = np.array([math.sin(a), math.cos(a)]); n = np.array([math.cos(a), -math.sin(a)])
y0 = F * EYE / (H - HZ); p0 = np.array([(STARTU - W/2) * y0 / F, y0])
def proj(s, t, z=0.): x, y = p0 + s*d + t*n; return (W/2 + F*x/y, HZ + F*(EYE-z)/y)
def dep(q): return float((p0 + q[0]*d + q[1]*n)[1])
def clip(w, near=.5):
    o = []
    for i, A in enumerate(w):
        B = w[(i+1) % len(w)]; da, db = dep(A)-near, dep(B)-near
        if da >= 0: o.append(A)
        if (da >= 0) != (db >= 0):
            k = da/(da-db); o.append(tuple(A[j]+k*(B[j]-A[j]) for j in range(3)))
    return o
im = Image.new("RGB", (W, H), (35, 25, 60)); D = ImageDraw.Draw(im)
def P(w, c):
    w = clip([tuple(q)+(0.,)*(3-len(q)) for q in w])
    if len(w) >= 3: D.polygon([proj(*q) for q in w], fill=c)
L, R, TOP = -PW/2-.6, PW/2+.6, 4.2
P([(-3,L),(-3,R),(END,R),(END,L)], (150,120,110))      # floor
P([(END,L,0),(END,R,0),(END,R,TOP),(END,L,TOP)], (70,50,90))   # far wall
P([(-3,R,0),(END,R,0),(END,R,TOP),(-3,R,TOP)], (120,85,95))    # right wall
P([(-3,L,0),(END,L,0),(END,L,TOP),(-3,L,TOP)], (95,70,110))    # left wall with tall windows
for s in np.arange(1, END-1, 2.):
    P([(s,L,.5),(s+1.2,L,.5),(s+1.2,L,3.5),(s,L,3.5)], (60,110,160))
    P([(s,R,.0),(s+.5,R,.0),(s+.5,R,TOP),(s,R,TOP)], (235,215,180))
P([(END,-1.4,0),(END,1.4,0),(END,1.4,3),(END,-1.4,3)], (240,190,110))  # bright doorway at the far end
P([(END-2.5,L+.2,.7),(END-.2,L+.2,.7),(END-.2,R-.2,.7),(END-2.5,R-.2,.7)], (150,60,70)) # low stage
P([(END-2.5,L+.2,0),(END-2.5,R-.2,0),(END-2.5,R-.2,.7),(END-2.5,L+.2,.7)], (110,45,55))
for s in np.arange(0, END, 1.5):
    D.line([proj(s,L),proj(s,R)], fill=(100,80,70), width=3)
for t in np.linspace(L,R,6):
    D.line([proj(-1.,t),proj(END,t)], fill=(100,80,70), width=3)
for s,t in [(3.,-3.1),(5.5,-3.1),(8,-3.1),(3.,3.1),(5.5,3.1),(8,3.1)]:   # chandeliers projected from the ceiling
    x,y = proj(s,t,3.5); r = 90/dep((s,t,0))*4; D.ellipse([x-r,y-r,x+r,y+r], fill=(255,225,130))
out = sys.argv[1]; im.save(out+"/hall-1024.png"); im.resize((832,1248), Image.LANCZOS).save(out+"/hall.png")
