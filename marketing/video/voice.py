"""Generate narration. MINIMAX_API_KEY is read from the environment, never logged."""
import json, os, pathlib, urllib.request
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=ROOT/'local/launch-output/audio'
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs): return None
def main():
 key=os.environ.get('MINIMAX_API_KEY')
 if not key: raise SystemExit('Set MINIMAX_API_KEY locally before generating narration.')
 OUT.mkdir(parents=True,exist_ok=True)
 scenes=json.loads((ROOT/'marketing/video/scenes.json').read_text())
 scenes += [{'id':'sample-en','voice':'A little less noise. A little more room to read. One line at a time.'}, {'id':'sample-zh','voice':'少一点干扰。多一点阅读的空间。一行一行，慢慢来。'}]
 for scene in scenes:
  target=OUT/(scene['id']+'.mp3')
  if target.exists(): continue
  body={'model':'speech-2.8-hd','text':scene['voice'],'stream':False,'language_boost':'auto','output_format':'hex','voice_setting':{'voice_id':'presenter_male','speed':1.15,'vol':1,'pitch':0,'emotion':'calm'},'audio_setting':{'sample_rate':32000,'bitrate':128000,'format':'mp3','channel':1}}
  request=urllib.request.Request('https://api.minimax.cn/v1/t2a_v2',data=json.dumps(body).encode(),headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
  with urllib.request.build_opener(NoRedirect).open(request,timeout=60) as response: data=json.loads(response.read(4_000_000))
  status=data.get('base_resp',{}).get('status_code')
  if status!=0 or data.get('data',{}).get('status')!=2: raise SystemExit(f'Voice generation failed: provider status {status}')
  target.write_bytes(bytes.fromhex(data['data']['audio']))
  print(scene['id'],data.get('extra_info',{}).get('audio_length'),'ms',flush=True)
if __name__=='__main__': main()
