"""Low-memory launch film renderer. Original typography/animation + real app screenshot.
Requires Pillow and imageio-ffmpeg. No browser, frame directory or API credentials.
"""
import argparse, json, math, pathlib, subprocess, wave
from functools import lru_cache
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'local/launch-output'; OUT.mkdir(parents=True,exist_ok=True)
FF=imageio_ffmpeg.get_ffmpeg_exe(); FPS=24
BG='#f6f4ee'; INK='#252523'; MUTED='#73776e'; GREEN='#dce5d5'; DARKGREEN='#4c6249'
FONT=ROOT/'Sources/Reeeead/Resources/Fonts/SpaceGrotesk-Medium.otf'
CN=pathlib.Path('/System/Library/Fonts/STHeiti Medium.ttc')
@lru_cache(128)
def font(size,cn=False): return ImageFont.truetype(str(CN if cn else FONT),int(size))
def text(d,xy,s,size=30,color=INK,cn=False,anchor=None): d.text(xy,s,font=font(size,cn),fill=color,anchor=anchor)
def centered(d,y,s,size=30,color=INK,cn=False,w=1280): text(d,(w/2,y),s,size,color,cn,'mt')
def mark(d,x,y,u=7):
 for k,c in enumerate(['#d2d0ca','#aaa9a2',INK]):
  for yy,row in enumerate(['0111','1000','1111','1000','0111']):
   for xx,p in enumerate(row):
    if p=='1': d.rectangle((x+(xx+2*k)*u,y+(yy+k)*u,x+(xx+2*k+1)*u-1,y+(yy+k+1)*u-1),fill=c)
def rr(d,box,r=18,fill='white',outline=None): d.rounded_rectangle(tuple(map(int,box)),r,fill=fill,outline=outline)
def ease(t): t=max(0,min(1,t)); return 1-(1-t)**3
def wrapped(d,s,maxwidth,size,cn=False):
 words=list(s) if cn else s.split(' '); lines=[]; line=''
 for word in words:
  candidate=line+('' if cn or not line else ' ')+word
  if d.textlength(candidate,font=font(size,cn))>maxwidth and line: lines.append(line); line=word
  else: line=candidate
 if line: lines.append(line)
 return lines
def wrapdraw(d,xy,s,maxwidth,size,color=INK,cn=False,spacing=1.25):
 x,y=xy
 for line in wrapped(d,s,maxwidth,size,cn): text(d,(x,y),line,size,color,cn); y+=size*spacing
 return y

def prepare_audio(scenes):
 chunks=[]; rate=32000; timeline=[]; now=0
 for scene in scenes:
  mp3=OUT/'audio'/(scene['id']+'.mp3'); wav=OUT/'audio'/(scene['id']+'.wav')
  subprocess.run([FF,'-y','-loglevel','error','-i',str(mp3),'-ar',str(rate),'-ac','1','-c:a','pcm_s16le',str(wav)],check=True)
  with wave.open(str(wav),'rb') as f: raw=f.readframes(f.getnframes())
  length=len(raw)/2/rate
  duration=math.ceil(max(scene['minDuration'],length+0.8)*FPS)/FPS
  lead=int(.3*rate); tail=round(duration*rate)-lead-len(raw)//2
  chunks.append(b'\0\0'*lead+raw+b'\0\0'*max(0,tail))
  scene.update(start=now,duration=duration,spoken=length); timeline.append(scene); now+=duration
 with wave.open(str(OUT/'narration.wav'),'wb') as f:
  f.setnchannels(1); f.setsampwidth(2); f.setframerate(rate)
  for chunk in chunks:f.writeframes(chunk)
 (OUT/'timing.json').write_text(json.dumps(timeline,ensure_ascii=False,indent=2))
 # Text-only captions stay useful for muted playback and accessibility.
 def stamp(t,sep=','):
  ms=round(t*1000); return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02}{sep}{ms%1000:03}'
 srt=[];vtt=['WEBVTT\n']
 for i,s in enumerate(timeline):
  start=s['start']+.3;end=start+s['spoken']
  srt.append(f"{i+1}\n{stamp(start)} --> {stamp(end)}\n{s['voice']}\n{s['en']}\n")
  vtt.append(f"{stamp(start,'.')} --> {stamp(end,'.')}\n{s['voice']}\n{s['en']}\n")
 (OUT/'reeeead-launch.srt').write_text('\n'.join(srt))
 (OUT/'reeeead-launch.vtt').write_text('\n'.join(vtt))
 return timeline,now

ART=Image.open(ROOT/'marketing/assets/reading-again.png').convert('RGB')
APP=Image.open(ROOT/'docs/screenshot-home.png').convert('RGB')
def art(im,box):
 x,y,w,h=box; a=ART.copy(); a.thumbnail((w,h),Image.Resampling.LANCZOS); im.paste(a,(int(x+(w-a.width)/2),int(y+(h-a.height)/2)))
def cursor(d,x,y): d.polygon([(x,y),(x+9,y+32),(x+16,y+23),(x+27,y+22)],fill=INK,outline='white',width=2)
def frame(scene,t,portrait=False):
 W,H=(720,1280) if portrait else (1280,720)
 im=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(im)
 margin=48 if portrait else 66
 mark(d,margin,32,5);text(d,(margin+53,28),'Reeeead',28)
 text(d,(W-margin,40),'A LITTLE READING COMPANION',12,MUTED,anchor='rt')
 sid=scene['id'];q=t/scene['duration']; contentbottom=H-(220 if portrait else 125)
 if sid=='hello':
  art(im,(20 if portrait else 610,370 if portrait else 110,680 if portrait else 620,620 if portrait else 475));d=ImageDraw.Draw(im)
  text(d,(margin,170 if portrait else 155),'眼睛：读完了。',48 if portrait else 62,cn=True)
  if t>1.35:
   text(d,(margin,245 if portrait else 244),'脑子：你谁？',48 if portrait else 62,cn=True)
   text(d,(margin,320 if portrait else 345),'READ IT. READ IT. REEEEAD IT.',16,MUTED)
 elif sid=='again':
  centered(d,155 if portrait else 125,'这行，怎么有点眼熟。',42 if portrait else 54,cn=True,w=W)
  x=margin;y=320 if portrait else 215;w=W-2*margin
  rr(d,(x,y,x+w,y+280 if portrait else y+235),26)
  count=min(3,1+int(t/1.05));
  for j in range(3):
   yy=y+40+j*55;rr(d,(x+30,yy-3,x+w-30,yy+37),5,GREEN if j==1 else 'white')
   text(d,(x+45,yy),'我刚刚是不是已经读过这一行了？',26 if portrait else 32,cn=True)
  rr(d,(W/2-75,y+(300 if portrait else 260),W/2+75,y+(354 if portrait else 314)),27,INK)
  centered(d,y+(310 if portrait else 270),f'TAKE {count:02}',26,'white',w=W)
  if t>2.6: centered(d,y+(390 if portrait else 330),'第四遍？先别。',30,DARKGREEN,True,w=W)
 elif sid=='listen':
  centered(d,150 if portrait else 115,'让耳朵，接个班。',44 if portrait else 56,cn=True,w=W)
  x=margin;y=330 if portrait else 235;w=W-2*margin
  rr(d,(x,y,x+w,y+240),26)
  label='One line at a time.'
  rr(d,(x+35,y+72,x+35+(w-70)*ease(t/1.15),y+130),6,GREEN)
  centered(d,y+76,label,40 if portrait else 46,w=W)
  text(d,(x+30,y+24),'ILLUSTRATIVE DEMO  /  选区朗读示意',14,MUTED,True)
  rr(d,(W/2-120,y+170,W/2+120,y+216),14,INK)
  centered(d,y+180,'CONTROL + OPTION + R',16,'white',w=W)
  if t>1.8:
   for k in range(21):
    hh=8+25*abs(math.sin(t*6+k*.6));xx=W/2-105+k*10
    rr(d,(xx,y+295-hh,xx+4,y+295+hh),2,DARKGREEN)
   centered(d,y+345,'选中文字 → 按快捷键 → 听',24,MUTED,True,w=W)
 elif sid=='ruler':
  centered(d,145 if portrait else 110,'其他地方，先下班。',42 if portrait else 55,cn=True,w=W)
  x=margin;y=300 if portrait else 210;w=W-2*margin;h=490 if portrait else 265
  rr(d,(x,y,x+w,y+h),22,'#fffefb')
  d.text((x+22,y+15),'ILLUSTRATIVE DEMO  /  阅读带示意',font=font(13,True),fill=MUTED)
  bandtop=y+110;bandbottom=y+(250 if portrait else 200)
  scroll=max(0,min(40,(t-3.9)*20))
  for j in range(7):
   yy=y+62+j*(55 if portrait else 34)-scroll
   if yy>y+45 and yy<y+h-32: text(d,(x+28,yy),['One line. A little more room.','Keep the page. Quiet the rest.','Read at your own pace.'][j%3],24 if portrait else 22)
  if t>.75:
   overlay=Image.new('RGBA',(W,H)); od=ImageDraw.Draw(overlay)
   od.rectangle((x,y,x+w,bandtop),fill=(37,37,35,125))
   livebottom=bandtop+(bandbottom-bandtop)*ease((t-1.4)/1.6)
   od.rectangle((x,livebottom,x+w,y+h),fill=(37,37,35,125))
   im=Image.alpha_composite(im.convert('RGBA'),overlay).convert('RGB');d=ImageDraw.Draw(im)
   d.line((x,bandtop,x+w,bandtop),fill=DARKGREEN,width=3)
   d.line((x,livebottom,x+w,livebottom),fill=DARKGREEN,width=3)
   if t<3.8:cursor(d,x+w*.72,livebottom)
  centered(d,y+h+36,'① 固定上边界     ② 固定下边界',24,MUTED,True,w=W)
  if t>3.9: centered(d,y+h+82,'阅读带留在原位，照常滚动。',24,DARKGREEN,True,w=W)
 elif sid=='app':
  if portrait:
   centered(d,135,'小小一只。刚刚好。',42,cn=True,w=W)
   a=APP.resize((400,458),Image.Resampling.LANCZOS); im.paste(a,(160,255));d=ImageDraw.Draw(im)
   centered(d,765,'系统语音 / MiniMax / 兼容 API',27,cn=True,w=W)
   centered(d,820,'macOS 14+ · 原生 · 开源',24,MUTED,True,w=W)
   centered(d,870,'真实应用截图 · 界面为中文',16,MUTED,True,w=W)
  else:
   text(d,(margin,165),'小小一只。',57,cn=True);text(d,(margin,245),'刚刚好。',57,cn=True)
   text(d,(margin,355),'系统语音 / MiniMax / 兼容 API',28,cn=True)
   text(d,(margin,410),'macOS 14+ · 原生 · 开源',23,MUTED,True)
   a=APP.resize((385,440),Image.Resampling.LANCZOS);im.paste(a,(800,110));d=ImageDraw.Draw(im)
   text(d,(992,560),'真实应用截图 · 界面为中文',14,MUTED,True,'mt')
 elif sid=='star':
  if portrait:
   art(im,(55,375,610,405));d=ImageDraw.Draw(im);centered(d,160,'读起来，轻一点。',45,cn=True,w=W)
   mark(d,185,255,8);text(d,(265,248),'Reeeead',50)
   centered(d,835,'给阅读搭子，加个鸡腿。',28,cn=True,w=W)
   centered(d,900,'github.com/YFJack/reeeead',23,DARKGREEN,w=W)
  else:
   art(im,(680,140,550,370));d=ImageDraw.Draw(im)
   text(d,(margin,150),'读起来，轻一点。',56,cn=True)
   mark(d,margin,275,8);text(d,(margin+85,266),'Reeeead',56)
   text(d,(margin,385),'给阅读搭子，加个鸡腿。',28,cn=True)
   text(d,(margin,460),'github.com/YFJack/reeeead',26,DARKGREEN)
 # Always legible bilingual captions; no strobe transitions or flashing effects.
 rr(d,(margin-12,H-(190 if portrait else 106),W-margin+12,H-28),20,INK)
 lines=wrapped(d,scene['voice'],W-2*margin-22,25 if portrait else 25,True)
 yy=H-(178 if portrait else 95)
 for line in lines: centered(d,yy,line,25,'#faf9f3',True,w=W);yy+=34
 for line in wrapped(d,scene['en'],W-2*margin-22,19 if portrait else 18):
  centered(d,yy+4,line,19 if portrait else 18,'#cecec5',w=W);yy+=27
 # Quiet progress strip.
 d.rectangle((0,H-4,W*q,H),fill='#9bab90')
 return im

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--portrait',action='store_true');parser.add_argument('--stills-only',action='store_true');args=parser.parse_args()
 scenes,total=prepare_audio(json.loads((ROOT/'marketing/video/scenes.json').read_text()))
 suffix='portrait' if args.portrait else 'landscape'; W,H=(720,1280) if args.portrait else (1280,720)
 for s in scenes: frame(s,min(4,s['duration']*.72),args.portrait).save(OUT/(s['id']+'-'+suffix+'.jpg'),quality=90)
 if args.stills_only:return
 target=OUT/f'reeeead-launch-{suffix}.mp4'
 cmd=[FF,'-y','-loglevel','error','-threads','1','-f','rawvideo','-vcodec','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-i',str(OUT/'narration.wav'),'-c:v','libx264','-threads','1','-preset','fast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart','-shortest',str(target)]
 p=subprocess.Popen(cmd,stdin=subprocess.PIPE)
 try:
  for s in scenes:
   for n in range(round(s['duration']*FPS)): p.stdin.write(frame(s,n/FPS,args.portrait).tobytes())
   print('rendered',s['id'],suffix,flush=True)
 finally:p.stdin.close()
 if p.wait()!=0:raise SystemExit('FFmpeg encoding failed')
 print(json.dumps({'file':str(target),'seconds':total,'width':W,'height':H,'fps':FPS,'bytes':target.stat().st_size}),flush=True)
if __name__=='__main__':main()
