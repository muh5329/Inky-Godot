"""Local-only build endpoint used by audio_render.html; never exposes unrelated paths."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parent.parent
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT),**kw)
 def do_POST(self):
  name=self.path.removeprefix('/save/')
  if not self.path.startswith('/save/') or not re.fullmatch(r'(?:sfx_[a-z0-9_]+\.wav|music_[a-z0-9_]+\.wav|manifest\.json)',name):self.send_error(400);return
  size=int(self.headers.get('Content-Length','0'))
  if not 0<size<100_000_000:self.send_error(413);return
  dest=ROOT/'assets/audio'/name;dest.parent.mkdir(exist_ok=True);dest.write_bytes(self.rfile.read(size))
  self.send_response(200);self.end_headers();self.wfile.write(b'OK')
ThreadingHTTPServer(('127.0.0.1',8491),Handler).serve_forever()
