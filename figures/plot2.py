import csv,collections,numpy as np
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
plt.rcParams.update({'font.family':'Liberation Serif','font.size':10,'axes.labelsize':10,'xtick.labelsize':10,'ytick.labelsize':10,
 'legend.fontsize':10,'axes.linewidth':0.7,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.color':'#d9d9d9','grid.linewidth':0.5,'axes.axisbelow':True})
D=collections.defaultdict(dict)
for r in csv.DictReader(open('/tmp/claude-0/rev/figs/figure_data_digitised.csv')):
    D[(int(r['figure']),r['scheme'])][int(r['snr_db'])]=float(r['value'])
ST={'LDPC':('#0072B2','o','LDPC'),'Turbo':('#009E73','s','Turbo'),'Polar':('#D55E00','D','Polar (SC)'),'Conv':('#E69F00','^','Convolutional')}
ORDER=['LDPC','Turbo','Polar','Conv']; snr=np.arange(-5,21)
def get(f,k): return np.array([D[(f,k)][s] for s in snr])
def draw(ax,f):
    for k in ORDER:
        c,m,_=ST[k]; ax.plot(snr,get(f,k),color=c,marker=m,ms=3.6,lw=1.2,mew=0)
    ax.set_xlim(-5.6,20.6); ax.set_xticks(range(-5,21,5))
def legend(fig,y):
    hs=[Line2D([0],[0],color=ST[k][0],marker=ST[k][1],ms=4.2,lw=1.3,label=ST[k][2]) for k in ORDER]
    fig.legend(handles=hs,loc='upper center',ncol=4,frameon=False,bbox_to_anchor=(0.5,y),handlelength=1.8,columnspacing=1.6)
# Fig 1: BER 2x2
fig,axs=plt.subplots(2,2,figsize=(7.0,4.3),sharex=True,sharey=True)
for ax,f,lab in zip(axs.flat,(1,4,11,8),('(a) Channel 1, rate 1/3','(b) Channel 1, rate 1/2','(c) Channel 2, rate 1/3','(d) Channel 2, rate 1/2')):
    draw(ax,f); ax.set_ylim(-0.012,0.56); ax.set_yticks(np.arange(0,0.6,0.1)); ax.set_title(lab,fontsize=10,pad=3)
for ax in axs[1]: ax.set_xlabel('SNR (dB)')
for ax in axs[:,0]: ax.set_ylabel('BER')
legend(fig,1.03); fig.tight_layout(rect=(0,0,1,0.96)); fig.savefig('f/figBER.png',dpi=300,bbox_inches='tight',pad_inches=0.03); plt.close(fig)
# Fig 2: time + throughput, scenario A
fig,axs=plt.subplots(1,2,figsize=(7.0,2.35))
draw(axs[0],2); axs[0].set_ylabel('Execution time (s)'); axs[0].set_title('(a) Per-frame execution time',fontsize=10,pad=3); axs[0].set_ylim(0.2,0.9)
draw(axs[1],3); axs[1].set_ylabel('Throughput (kbps)'); axs[1].set_title('(b) Throughput, K / time',fontsize=10,pad=3); axs[1].set_ylim(20,80)
for ax in axs: ax.set_xlabel('SNR (dB)')
legend(fig,1.07); fig.tight_layout(rect=(0,0,1,0.93)); fig.savefig('f/figTIME.png',dpi=300,bbox_inches='tight',pad_inches=0.03); plt.close(fig)
# Fig 3: time and throughput for B,C,D, log axes
fig,axs=plt.subplots(2,3,figsize=(7.0,4.4),sharex=True)
labs=('(a) Channel 1, rate 1/2','(b) Channel 2, rate 1/2','(c) Channel 2, rate 1/3')
for j,(ft,fh,lab) in enumerate(zip((5,7,10),(6,9,12),labs)):
    draw(axs[0,j],ft); axs[0,j].set_yscale('log'); axs[0,j].set_ylim(0.12,40); axs[0,j].set_title(lab,fontsize=10,pad=3)
    draw(axs[1,j],fh); axs[1,j].set_yscale('log'); axs[1,j].set_ylim(0.5,300); axs[1,j].set_xlabel('SNR (dB)')
axs[0,0].set_ylabel('Time (s)'); axs[1,0].set_ylabel('Throughput (kbps)')
for ax in axs[0,1:]: ax.tick_params(labelleft=False)
for ax in axs[1,1:]: ax.tick_params(labelleft=False)
legend(fig,1.04); fig.tight_layout(rect=(0,0,1,0.95)); fig.savefig('f/figTIME2.png',dpi=300,bbox_inches='tight',pad_inches=0.03); plt.close(fig)
