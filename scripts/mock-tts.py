#!/usr/bin/env python3
"""Local, dependency-free API fixture. No real speech synthesis or API key required.

POST /speech returns a quiet 2-second test tone (WAV, decoded by AVAudioPlayer).
POST /slow waits 5 seconds; /unauthorized returns 401; /redirect redirects.
Only request field names and text length are logged, never text or credentials.
"""
import io
import json
import math
import struct
import time
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

buffer = io.BytesIO()
with wave.open(buffer, "wb") as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(16000)
    audio.writeframes(b"".join(struct.pack("<h", int(900 * math.sin(2 * math.pi * 440 * i / 16000))) for i in range(32000)))
AUDIO = buffer.getvalue()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        size = int(self.headers.get("Content-Length", "0"))
        if size > 100_000:
            self.send_error(413)
            return
        payload = json.loads(self.rfile.read(size))
        print(json.dumps({"path": self.path, "fields": sorted(payload), "characters": len(payload.get("input", "")), "speed": payload.get("speed")}), flush=True)
        if self.path == "/slow":
            time.sleep(5)
        if self.path == "/unauthorized":
            self.send_error(401)
            return
        if self.path == "/redirect":
            self.send_response(307)
            self.send_header("Location", "http://127.0.0.1:8642/speech")
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(AUDIO)))
        self.end_headers()
        try:
            self.wfile.write(AUDIO)
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == "__main__":
    print("Mock TTS ready: http://127.0.0.1:8642/speech", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 8642), Handler).serve_forever()
