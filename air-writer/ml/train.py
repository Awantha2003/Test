import numpy as np, torch, torch.nn as nn, gen, time, json, base64
from multiprocessing import Pool
def make(args):
    seed,n,hard=args; rng=np.random.default_rng(seed); X=[];Y=[]
    for i in range(n):
        c=i%26; X.append(gen.raster(gen.sample(gen.LETTERS[c],rng,hard),r=rng.uniform(.8,1.5))); Y.append(c)
    return np.array(X),np.array(Y)
def data(seed,per,hard=False):
    with Pool(4) as p: parts=p.map(make,[(seed*100+k,per,hard) for k in range(8)])
    return np.concatenate([a for a,_ in parts]),np.concatenate([b for _,b in parts])
if __name__=='__main__':
    t=time.time()
    Xtr,Ytr=data(1,16250); Xte,Yte=data(2,650); Xh,Yh=data(3,650,True)
    print('data',Xtr.shape,round(time.time()-t),'s',flush=True)
    torch.manual_seed(0)
    net=nn.Sequential(
        nn.Conv2d(1,12,3,padding=1),nn.ReLU(),nn.MaxPool2d(2),     # 14
        nn.Conv2d(12,24,3,padding=1),nn.ReLU(),nn.MaxPool2d(2),    # 7
        nn.Conv2d(24,48,3,padding=1),nn.ReLU(),nn.MaxPool2d(2,ceil_mode=True), # 4
        nn.Flatten(),nn.Dropout(0.2),nn.Linear(48*16,26))
    print('params',sum(p.numel() for p in net.parameters()))
    Xtr_t=torch.tensor(Xtr)[:,None]; Ytr_t=torch.tensor(Ytr)
    opt=torch.optim.Adam(net.parameters(),2e-3); E=10
    sched=torch.optim.lr_scheduler.OneCycleLR(opt,4e-3,total_steps=E*(len(Xtr)//256+1))
    def acc(X,Y):
        net.eval()
        with torch.no_grad(): p=net(torch.tensor(X)[:,None]).argmax(1).numpy()
        net.train(); return (p==Y).mean(),p
    for ep in range(E):
        perm=torch.randperm(len(Xtr_t))
        for i in range(0,len(perm),256):
            idx=perm[i:i+256]; x=Xtr_t[idx]
            # random shift augmentation
            dx,dy=np.random.randint(-1,2,2); x=torch.roll(x,(int(dy),int(dx)),(2,3))
            loss=nn.functional.cross_entropy(net(x),Ytr_t[idx],label_smoothing=0.05)
            opt.zero_grad(); loss.backward(); opt.step(); sched.step()
        print(ep,'loss %.3f'%loss.item(),'test %.4f'%acc(Xte,Yte)[0],'hard %.4f'%acc(Xh,Yh)[0],flush=True)
    a,p=acc(Xh,Yh)
    from collections import Counter
    print('hard confusions',Counter((gen.LETTERS[y]+'->'+gen.LETTERS[q]) for y,q in zip(Yh,p) if y!=q).most_common(12))
    torch.save(net.state_dict(),'net.pt')
    # export int8-quantised weights (per-tensor scale) as base64 for the browser
    out=[]
    for name,t in net.state_dict().items():
        w=t.numpy().astype(np.float32); s=float(np.abs(w).max()/127) or 1.0
        q=np.round(w/s).astype(np.int8)
        out.append({'n':name,'shape':list(w.shape),'s':s,'d':base64.b64encode(q.tobytes()).decode()})
    json.dump(out,open('weights.json','w'))
    print('done')
