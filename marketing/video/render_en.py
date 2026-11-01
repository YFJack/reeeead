"""English launch film. Shares the low-memory renderer, with English-only art direction."""
import argparse, json, math, subprocess
from PIL import Image, ImageDraw
from render import ROOT, OUT, FF, FPS, BG, INK, MUTED, GREEN, DARKGREEN, text, centered, mark, rr, ease, wrapped, art, cursor, prepare_audio

APP = Image.open(ROOT/'docs/screenshot-home-en.png').convert('RGB')

def frame(scene,t,portrait=False):
 W,H=(720,1280) if portrait else (1280,720)
 im=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(im);m=48 if portrait else 66
 mark(d,m,32,5);text(d,(m+53,28),'Reeeead',28)
 text(d,(W-m,40),'A LITTLE READING COMPANION',12,MUTED,anchor='rt')
 sid=scene['id']
 if sid=='hello':
  art(im,(20 if portrait else 640,390 if portrait else 110,680 if portrait else 600,600 if portrait else 475));d=ImageDraw.Draw(im)
  text(d,(m,165 if portrait else 150),'Eyes: finished.',57 if portrait else 64)
  if t>1.5:
   text(d,(m,250 if portrait else 240),'Brain: who are you?',50 if portrait else 55)
   text(d,(m,330 if portrait else 345),'READ IT. READ IT. REEEEAD IT.',16,MUTED)
 elif sid=='again':
  centered(d,155 if portrait else 120,'Wait. This line looks familiar.',38 if portrait else 49,w=W)
  y=315 if portrait else 220;w=W-2*m;rr(d,(m,y,W-m,y+235),26)
  for j in range(3):
   yy=y+40+j*55;rr(d,(m+24,yy-3,W-m-24,yy+37),5,GREEN if j==1 else 'white')
   text(d,(m+40,yy),'Have I read this sentence already?',25 if portrait else 32)
  count=min(3,1+int(t/1.05));rr(d,(W/2-75,y+265,W/2+75,y+319),27,INK)
  centered(d,y+275,f'TAKE {count:02}',26,'white',w=W)
  if t>2.9:centered(d,y+(375 if portrait else 330),'Round four? Let’s not.',29,DARKGREEN,w=W)
 elif sid=='listen':
  centered(d,155 if portrait else 120,'Let your ears take a shift.',41 if portrait else 55,w=W)
  y=330 if portrait else 235;w=W-2*m;rr(d,(m,y,W-m,y+235),26)
  text(d,(m+30,y+24),'SELECTED-TEXT SPEECH · ILLUSTRATION',13,MUTED)
  rr(d,(m+35,y+72,m+35+(w-70)*ease(t/1.15),y+130),6,GREEN)
  centered(d,y+76,'One line at a time.',40 if portrait else 46,w=W)
  rr(d,(W/2-120,y+170,W/2+120,y+216),14,INK);centered(d,y+180,'CONTROL + OPTION + R',16,'white',w=W)
  if t>1.8:
   for k in range(21):
    hh=8+25*abs(math.sin(t*6+k*.6));xx=W/2-105+k*10
    rr(d,(xx,y+(300 if portrait else 65)+235-hh,xx+4,y+(300 if portrait else 65)+235+hh),2,DARKGREEN)
   if portrait:centered(d,940,'Select → Shortcut → Listen',25,MUTED,w=W)
 elif sid=='ruler':
  centered(d,145 if portrait else 110,'The rest can clock out.',45 if portrait else 55,w=W)
  y=300 if portrait else 210;w=W-2*m;h=490 if portrait else 265
  rr(d,(m,y,W-m,y+h),22,'#fffefb');text(d,(m+22,y+15),'READING BAND · ILLUSTRATION',13,MUTED)
  bandtop=y+110;bandbottom=y+(250 if portrait else 200);scroll=max(0,min(40,(t-3.9)*20))
  for j in range(7):
   yy=y+62+j*(55 if portrait else 34)-scroll
   if yy>y+45 and yy<y+h-32:text(d,(m+28,yy),['One line. A little more room.','Keep the page. Quiet the rest.','Read at your own pace.'][j%3],24 if portrait else 22)
  if t>.75:
   overlay=Image.new('RGBA',(W,H));od=ImageDraw.Draw(overlay);od.rectangle((m,y,W-m,bandtop),fill=(37,37,35,125))
   livebottom=bandtop+(bandbottom-bandtop)*ease((t-1.4)/1.6);od.rectangle((m,livebottom,W-m,y+h),fill=(37,37,35,125))
   im=Image.alpha_composite(im.convert('RGBA'),overlay).convert('RGB');d=ImageDraw.Draw(im)
   d.line((m,bandtop,W-m,bandtop),fill=DARKGREEN,width=3);d.line((m,livebottom,W-m,livebottom),fill=DARKGREEN,width=3)
   if t<3.8:cursor(d,m+w*.72,livebottom)
  centered(d,y+h+30,'1. Set the top.    2. Set the bottom.',23,MUTED,w=W)
  if t>3.9:centered(d,y+h+75,'Band stays put. Scroll as usual.',23,DARKGREEN,w=W)
 elif sid=='app':
  if portrait:
   centered(d,135,'Tiny app. More breathing room.',34,w=W)
   a=APP.resize((420,480),Image.Resampling.LANCZOS);im.paste(a,(150,245));d=ImageDraw.Draw(im)
   centered(d,785,'System voices / MiniMax / your API',26,w=W)
   centered(d,842,'English + Chinese · macOS 14+',24,MUTED,w=W)
   centered(d,890,'REAL APP SCREENSHOT · v0.4.0',14,MUTED,w=W)
  else:
   text(d,(m,160),'Tiny app.',64);text(d,(m,245),'More breathing room.',47)
   text(d,(m,355),'System voices / MiniMax / your API',27)
   text(d,(m,410),'English + Chinese · macOS 14+',24,MUTED)
   a=APP.resize((385,440),Image.Resampling.LANCZOS);im.paste(a,(800,110));d=ImageDraw.Draw(im)
   text(d,(992,560),'REAL APP SCREENSHOT · v0.4.0',14,MUTED,anchor='mt')
 elif sid=='star':
  if portrait:
   art(im,(55,380,610,405));d=ImageDraw.Draw(im);centered(d,155,'Read a little easier.',49,w=W)
   mark(d,185,255,8);text(d,(265,248),'Reeeead',50)
   centered(d,835,'Feed your reading buddy a star.',28,w=W)
   centered(d,900,'github.com/YFJack/reeeead',23,DARKGREEN,w=W)
  else:
   art(im,(695,135,535,380));d=ImageDraw.Draw(im);text(d,(m,150),'Read a little easier.',57)
   mark(d,m,275,8);text(d,(m+85,266),'Reeeead',56)
   text(d,(m,385),'Feed your reading buddy a star.',28)
   text(d,(m,460),'github.com/YFJack/reeeead',26,DARKGREEN)
 # Narration-matched English captions, sized for silent/mobile viewing.
 size=25 if portrait else 26
 lines=wrapped(d,scene['voice'],W-2*m-22,size)
 boxheight=max(95,len(lines)*35+27)
 rr(d,(m-12,H-boxheight-28,W-m+12,H-28),20,INK)
 yy=H-boxheight-15
 for line in lines:centered(d,yy,line,size,'#faf9f3',w=W);yy+=35
 d.rectangle((0,H-4,W*t/scene['duration'],H),fill='#9bab90')
 return im

def main():
 p=argparse.ArgumentParser();p.add_argument('--portrait',action='store_true');p.add_argument('--stills-only',action='store_true');args=p.parse_args()
 scenes,total=prepare_audio(json.loads((ROOT/'marketing/video/scenes.en.json').read_text()),language='en')
 suffix='portrait' if args.portrait else 'landscape';W,H=(720,1280) if args.portrait else (1280,720)
 for s in scenes:frame(s,min(4.3,s['duration']*.72),args.portrait).save(OUT/(s['id']+'-en-'+suffix+'.jpg'),quality=92)
 if args.stills_only:return
 target=OUT/f'reeeead-launch-en-{suffix}.mp4'
 cmd=[FF,'-y','-loglevel','error','-threads','1','-f','rawvideo','-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-i',str(OUT/'narration-en.wav'),'-c:v','libx264','-threads','1','-preset','fast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart','-shortest',str(target)]
 proc=subprocess.Popen(cmd,stdin=subprocess.PIPE)
 try:
  for s in scenes:
   for n in range(round(s['duration']*FPS)):proc.stdin.write(frame(s,n/FPS,args.portrait).tobytes())
   print('rendered',s['id'],suffix,flush=True)
 finally:proc.stdin.close()
 if proc.wait()!=0:raise SystemExit('FFmpeg encoding failed')
 print(json.dumps({'file':str(target),'seconds':total,'width':W,'height':H,'fps':FPS,'bytes':target.stat().st_size}),flush=True)
if __name__=='__main__':main()
