import numpy as np, json, sys
Fs=10000
def read_arr(f):
    t=open(f).read().split()
    # '2D', freq, Nsz, sz..., Nrz, rz..., Nrr, rr...
    i=1; freq=float(t[i]); i+=1
    nsz=int(t[i]); i+=1+nsz
    nrz=int(t[i]); i+=1; rz=[float(x) for x in t[i:i+nrz]]; i+=nrz
    nrr=int(t[i]); i+=1; rr=[float(x) for x in t[i:i+nrr]]; i+=nrr
    nmax=int(t[i]); i+=1
    n=int(t[i]); i+=1
    d=np.array(t[i:i+8*n],float).reshape(n,8)
    A=d[:,0]*np.exp(1j*np.deg2rad(d[:,1])); tau=d[:,2]+1j*d[:,3]
    return dict(freq=freq,rz=rz,rr=rr,n=n,A=A,tau=tau.real,srcang=d[:,4],topb=d[:,6],botb=d[:,7])
def cir(a):
    tau=a['tau']-a['tau'].min(); sd=np.round(tau*Fs).astype(int)
    h=np.zeros(sd.max()+1,complex)
    for k in range(len(sd)): h[sd[k]]+=a['A'][k]
    return h/np.linalg.norm(h), sd
def shorten(h,n):
    idx=np.argsort(-np.abs(h))[:n]; idx=np.sort(idx)
    hs=np.zeros(idx.max()+1,complex); hs[idx]=h[idx]; return hs/np.linalg.norm(hs), idx
def Hgrid(h,N=64,k0=8,nu=48):
    n=np.arange(len(h)); k=np.arange(k0,k0+nu)
    return (h[None,:]*np.exp(-2j*np.pi*np.outer(k,n)/N)).sum(1)
out={}
for tag,f in [('Comm10km','/tmp/claude-0/proj2/UWA_Communication.arr'),('Complex','/tmp/claude-0/proj2/UWA_10kHz_Complex.arr'),('Comm1km','/tmp/claude-0/proj2/UWA_Comm.arr')]:
    a=read_arr(f); h,sd=cir(a)
    P=np.abs(a['A'])**2
    r={}
    r['n_arrivals']=a['n']; r['range_m']=a['rr'][0]; r['src_depth']=None
    r['delay_first_s']=float(a['tau'].min()); r['delay_last_s']=float(a['tau'].max())
    r['span_ms_all']=1e3*float(a['tau'].max()-a['tau'].min())
    r['n_distinct_samples']=int(np.count_nonzero(h))
    # arrival power fraction retained by N strongest *arrivals* (paper definition)
    o=np.sort(P)[::-1]; r['arr_power_frac']={n:float(o[:n].sum()/P.sum()) for n in [1,3,5,10,15,20,30]}
    # CIR-sample level (after discretization & merge)
    Pc=np.abs(h)**2; oc=np.sort(Pc)[::-1]
    r['cir_power_frac']={n:float(oc[:n].sum()/Pc.sum()) for n in [1,3,5,10,15,20,30]}
    h5,idx5=shorten(h,5)
    taps=[(int(i-idx5[0]),1e3*(i-idx5[0])/Fs,complex(h[i]/np.linalg.norm(h[idx5]))) for i in idx5]
    r['taps5']=[dict(sample=t[0],ms=t[1],re=t[2].real,im=t[2].imag,mag=abs(t[2])) for t in taps]
    r['taps5_span_samples']=int(idx5[-1]-idx5[0]); r['taps5_span_ms']=1e3*(idx5[-1]-idx5[0])/Fs
    r['taps5_power_frac_cir']=float(np.sum(Pc[idx5])/Pc.sum())
    # frequency selectivity over the 48 used OFDM bins (64-pt grid, bins 8..55)
    def sel(hh):
        H=Hgrid(hh/np.linalg.norm(hh)); m=20*np.log10(np.abs(H)+1e-12)
        return dict(std_db=float(m.std()),min_db=float(m.min()),max_db=float(m.max()),
                    rms_over_mean=float(np.abs(H).std()/np.abs(H).mean()))
    r['freqsel']={'full':sel(h),'N5':sel(h5),'N15':sel(shorten(h,15)[0]),'N30':sel(shorten(h,30)[0])}
    # energy that the 5-tap channel puts outside a CP-length window anchored at best start
    tap_i=idx5; best=0
    for s in tap_i:
        e=np.sum(np.abs(h5[s:s+17])**2); best=max(best,e)
    r['five_tap_energy_in_best_CP_window']=float(best)
    # worst-case: first tap-aligned
    out[tag]=r
json.dump(out,open('chan.json','w'),indent=1,default=float)
for t,r in out.items():
    print('==',t,'arrivals',r['n_arrivals'],'range',r['range_m'],'span_all_ms %.1f'%r['span_ms_all'],'distinct samples',r['n_distinct_samples'])
    print(' arrival-power frac:',{k:round(v,3) for k,v in r['arr_power_frac'].items()})
    print(' CIR-power frac    :',{k:round(v,3) for k,v in r['cir_power_frac'].items()})
    print(' 5 taps: ',[(x['sample'],round(x['ms'],1),round(x['mag'],3)) for x in r['taps5']],'span ms %.1f'%r['taps5_span_ms'],'frac %.3f'%r['taps5_power_frac_cir'],'in-CP-window %.3f'%r['five_tap_energy_in_best_CP_window'])
    print(' freqsel',{k:{a:round(b,2) for a,b in v.items()} for k,v in r['freqsel'].items()})
