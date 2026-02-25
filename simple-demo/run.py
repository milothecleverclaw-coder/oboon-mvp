import os, subprocess, json, time

print("Fetching credentials...")
bw_session = subprocess.check_output(['bw', 'unlock', '--raw', 'y3&tHVAg0s%70']).decode('utf-8').strip()

lk_json = subprocess.check_output(['bw', 'get', 'item', 'livekit', '--session', bw_session]).decode('utf-8')
lk_notes = json.loads(lk_json)['notes']

for line in lk_notes.split('\n'):
    if '=' in line:
        k, v = line.split('=', 1)
        os.environ[k.strip()] = v.strip()

modal_json = subprocess.check_output(['bw', 'get', 'item', 'Modal API', '--session', bw_session]).decode('utf-8')
modal_data = json.loads(modal_json)
os.environ['MODAL_TOKEN_ID'] = modal_data['username']
os.environ['MODAL_TOKEN_SECRET'] = modal_data['password']

print("Starting FastApi Backend...")
fastapi_proc = subprocess.Popen([
    "uvicorn", "backend.server:app", "--host", "0.0.0.0", "--port", "8008"
])

time.sleep(2)

print("Starting LiveKit Python Agent...")
agent_proc = subprocess.Popen([
    "venv/bin/python", "backend/agent.py", "start"
], env=os.environ)

print("Starting Cloudflare Tunnel...")
cf_proc = subprocess.Popen([
    "cloudflared", "tunnel", "--url", "http://localhost:8008"
])

try:
    cf_proc.wait()
except KeyboardInterrupt:
    agent_proc.kill()
    fastapi_proc.kill()
    cf_proc.kill()
