from PIL import Image
from pathlib import Path
import json,sys
path=Path(sys.argv[1]);im=Image.open(path);w,h=im.size
m=bytearray(1 if x>32 else 0 for x in im.getchannel('A').tobytes());comps=[]
for i in range(w*h):
 if not m[i]:continue
 m[i]=0;stack=[i];n=0;left=w;right=0;top=h;bottom=0
 while stack:
  j=stack.pop();x=j%w;y=j//w;n+=1;left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
  for k in ([j-1] if x else [])+([j+1] if x<w-1 else [])+([j-w] if y else [])+([j+w] if y<h-1 else []):
   if m[k]:m[k]=0;stack.append(k)
 if n>1000:comps.append([left,top,right+1,bottom+1,n])
print(json.dumps({'width':w,'height':h,'components':comps}))
