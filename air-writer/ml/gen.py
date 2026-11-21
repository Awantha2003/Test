"""Synthetic air-writing data: letters drawn as finger trails, rasterised to 28x28
exactly like the browser does (distance-to-segment rendering)."""
import numpy as np, math

def arc(cx,cy,rx,ry,a0,a1,steps=18):
    return [[cx+rx*math.cos(math.radians(a0+(a1-a0)*k/steps)), cy+ry*math.sin(math.radians(a0+(a1-a0)*k/steps))] for k in range(steps+1)]
def L(*p): return [list(q) for q in p]

# Each letter: list of variants; each variant: list of strokes; stroke: list of [x,y] on 0..10 grid, y down.
T = {
 'A':[[L([0,10],[5,0],[10,10]),L([2.5,5.5],[7.5,5.5])],
      [L([1,10],[4,0],[6,0],[9,10]),L([2,6],[8,6])],
      [L([5,0],[0,10]),L([5,0],[10,10]),L([2.5,6],[7.5,6])],
      [[[0,10],*arc(5,3,2.2,3,180,360,8)[1:-1],[10,10]],L([2,6.5],[8,6.5])]],
 'B':[[L([0,0],[0,10]),[[0,0],*arc(0,2.5,8,2.5,-90,90)],[[0,5],*arc(0,7.5,9,2.5,-90,90)]],
      [[[0,10],[0,0],*arc(0,2.5,7,2.5,-90,90),*arc(0,7.5,9,2.5,-90,90)]]],
 'C':[[arc(5,5,5,5,-45,-315)],[arc(5,5,4,5,-60,-300)]],
 'D':[[L([0,0],[0,10]),arc(0,5,9,5,-90,90)],[[[0,10],[0,0],*arc(0,5,9,5,-90,90)]],
      [L([0,0],[0,10]),[[0,0],[4,0],*arc(4,5,5,5,-90,90),[0,10]]]],
 'E':[[L([10,0],[0,0],[0,10],[10,10]),L([0,5],[7,5])],[L([0,0],[0,10]),L([0,0],[9,0]),L([0,5],[7,5]),L([0,10],[9,10])]],
 'F':[[L([10,0],[0,0],[0,10]),L([0,5],[7,5])],[L([0,0],[0,10]),L([0,0],[9,0]),L([0,5],[7,5])]],
 'G':[[[*arc(5,5,5,5,-45,-360),[5,5]]],[[*arc(5,5,5,5,-45,-350),[10,10]],L([6,5.5],[10,5.5])]],
 'H':[[L([0,0],[0,10]),L([10,0],[10,10]),L([0,5],[10,5])]],
 'I':[[L([5,0],[5,10])],[L([2,0],[8,0]),L([5,0],[5,10]),L([2,10],[8,10])]],
 'J':[[[[8,0],*arc(4.5,6.5,3.5,3.5,0,180)]],[L([3,0],[10,0]),[[7,0],*arc(4,6.5,3,3.5,0,180)]]],
 'K':[[L([0,0],[0,10]),L([9,0],[0,6],[9,10])],[L([0,0],[0,10]),L([9,0],[0,5]),L([2,4],[9,10])]],
 'L':[[L([0,0],[0,10],[8,10])]],
 'M':[[L([0,10],[0,0],[5,6],[10,0],[10,10])],[L([0,10],[1,0],[5,10],[9,0],[10,10])]],
 'N':[[L([0,10],[0,0],[10,10],[10,0])]],
 'O':[[arc(5,5,5,5,-90,270,24)],[arc(5,5,4,5,-100,260,24)]],
 'P':[[[[0,10],[0,0],*arc(0,2.5,8,2.5,-90,90)]],[L([0,0],[0,10]),[[0,0],*arc(0,2.7,8,2.7,-90,90)]]],
 'Q':[[arc(5,5,5,5,-90,270,24),L([6,7],[10,10])]],
 'R':[[[[0,10],[0,0],*arc(0,2.5,8,2.5,-90,90),[9,10]]],[L([0,0],[0,10]),[[0,0],*arc(0,2.5,8,2.5,-90,90)],L([3,5],[9,10])]],
 'S':[[[*arc(5,2.5,4.5,2.5,-20,-270),*arc(5,7.5,4.5,2.5,-90,160)]]],
 'T':[[L([0,0],[10,0]),L([5,0],[5,10])]],
 'U':[[[[0,0],*arc(5,5,5,5,180,0),[10,0]]],[[[0,0],*arc(5,5,5,5,180,0),[10,0],[10,10]]]],
 'V':[[L([0,0],[5,10],[10,0])]],
 'W':[[L([0,0],[2.5,10],[5,3],[7.5,10],[10,0])],[L([0,0],[2.5,10],[5,0],[7.5,10],[10,0])]],
 'X':[[L([0,0],[10,10]),L([10,0],[0,10])]],
 'Y':[[L([0,0],[5,5],[10,0]),L([5,5],[5,10])],[L([0,0],[5,5]),L([10,0],[0,10])]],
 'Z':[[L([0,0],[10,0],[0,10],[10,10])]],
}
LETTERS=sorted(T)

def densify(s,step=0.25):
    out=[]
    for a,b in zip(s[:-1],s[1:]):
        n=max(1,int(math.dist(a,b)/step))
        for j in range(n): out.append([a[0]+(b[0]-a[0])*j/n,a[1]+(b[1]-a[1])*j/n])
    out.append(list(s[-1])); return np.array(out,float)

def smooth(p,w):
    if w<=1 or len(p)<w: return p
    k=np.ones(w)/w; pad=w//2
    q=np.pad(p,((pad,pad),(0,0)),mode='edge')
    return np.stack([np.convolve(q[:,0],k,'valid'),np.convolve(q[:,1],k,'valid')],1)[:len(p)]

def sample(letter,rng,hard=False):
    v=T[letter][rng.integers(len(T[letter]))]
    strokes=[list(map(list,s)) for s in v]
    # random stroke order / direction
    if rng.random()<0.25: strokes=strokes[::-1]
    strokes=[s[::-1] if rng.random()<0.3 else s for s in strokes]
    # air-writing: usually one continuous trail including travel lines
    if len(strokes)>1 and rng.random()<0.7:
        joined=[]
        for s in strokes: joined+=s
        strokes=[joined]
    out=[]
    for s in strokes:
        p=densify(s)
        p=smooth(p,int(rng.integers(1,8)))          # rounded corners
        n=len(p); t=np.linspace(0,1,n)
        amp=rng.uniform(0,0.7 if hard else 0.45)
        for d in (0,1):                              # low-frequency wobble
            f=rng.uniform(1,4); ph=rng.uniform(0,6.3)
            p[:,d]+=amp*np.sin(2*math.pi*f*t+ph)
        p+=rng.normal(0,0.12 if hard else 0.07,p.shape)  # jitter
        # trim or add a small hook at the ends
        if n>12:
            a=int(rng.integers(0,max(1,n//12))); b=int(rng.integers(0,max(1,n//12)))
            p=p[a:n-b if b else n]
        if rng.random()<0.25:
            d=rng.normal(0,1.2,2); p=np.vstack([p[0]+d*np.linspace(1,0,6)[:,None],p])
        out.append(p)
    # global affine
    th=math.radians(rng.uniform(-18,18)); sh=rng.uniform(-.35,.35); sx=float(np.exp(rng.uniform(np.log(.38),np.log(1.5))))
    M=np.array([[math.cos(th),-math.sin(th)],[math.sin(th),math.cos(th)]])@np.array([[sx,sh],[0,1]])
    return [p@M.T for p in out]

def raster(strokes,size=28,box=20,r=None,rng=None):
    """Fit trail into a box x box square (keep aspect), centre in size x size, draw with radius r."""
    allp=np.vstack(strokes); mn=allp.min(0); mx=allp.max(0)
    s=box/max(mx[0]-mn[0],mx[1]-mn[1],1e-6)
    off=(size-(mx-mn)*s)/2
    if r is None: r=1.1
    yy,xx=np.mgrid[0:size,0:size]; P=np.stack([xx.ravel()+.5,yy.ravel()+.5],1)
    dmin=np.full(len(P),1e9)
    for st in strokes:
        q=(st-mn)*s+off
        if len(q)==1: q=np.vstack([q,q])
        A=q[:-1]; B=q[1:]; AB=B-A; L2=(AB**2).sum(1)+1e-9
        # chunk over segments
        for i in range(0,len(A),64):
            a=A[i:i+64]; ab=AB[i:i+64]; l2=L2[i:i+64]
            t=np.clip(((P[:,None,:]-a[None])*ab[None]).sum(2)/l2[None],0,1)
            proj=a[None]+t[...,None]*ab[None]
            d=np.sqrt(((P[:,None,:]-proj)**2).sum(2)).min(1)
            dmin=np.minimum(dmin,d)
    img=np.clip(r+0.5-dmin,0,1)
    return img.reshape(size,size).astype(np.float32)
