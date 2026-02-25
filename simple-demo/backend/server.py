import os
import json
import base64
import time
from fastapi import FastAPI, HTTPException, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from livekit import api
import modal

app = FastAPI()

# ── Runtime AI settings (adjusted via /api/settings) ──────────────────────────
ai_settings = {
    "nsfw_threshold": 0.5,      # lower = more sensitive (flags more)
    "face_threshold": 0.85,     # higher = more lenient face match
    "sample_rate": 1,           # analyze every N seconds
}

@app.get("/api/settings")
async def get_settings():
    return ai_settings

@app.post("/api/settings")
async def update_settings(request: Request):
    data = await request.json()
    for key in ["nsfw_threshold", "face_threshold", "sample_rate"]:
        if key in data:
            ai_settings[key] = data[key]
    return {"success": True, "settings": ai_settings}
# ──────────────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

DB_FILE = "/home/node/.openclaw/workspace/oboon-web/data/users.json"

def load_db():
    if os.path.exists(DB_FILE):
        with open(DB_FILE, "r") as f:
            return json.load(f)
    return {}

def save_db(data):
    with open(DB_FILE, "w") as f:
        json.dump(data, f)

@app.post("/api/register")
async def register_face(request: Request):
    data = await request.json()
    user_id = data.get("user_id")
    image_b64 = data.get("image")
    
    if not user_id or not image_b64:
        raise HTTPException(status_code=400, detail="Missing user_id or image")
        
    if "," in image_b64:
        image_b64 = image_b64.split(",")[1]
        
    image_bytes = base64.b64decode(image_b64)
    
    try:
        worker_cls = modal.Cls.from_name("oboon-web-detector", "OboonAIWorker")
        worker = worker_cls()
        # Use remote.aio for async call
        result = await worker.get_embedding.remote.aio(image_bytes)
        
        if not result.get("success"):
            raise HTTPException(status_code=400, detail=result.get("error", "Failed to detect face"))
            
        db = load_db()
        db[user_id] = {
            "embedding": result["embedding"],
            "registered_at": time.time()
        }
        save_db(db)
        
        return {"success": True, "message": "Face registered successfully!"}
        
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/token")
async def get_token(user_id: str, room: str = "demo-room"):
    lk_api_key = os.environ.get("LIVEKIT_API_KEY")
    lk_api_secret = os.environ.get("LIVEKIT_API_SECRET")
    lk_url = os.environ.get("LIVEKIT_URL")
    
    if not lk_api_key or not lk_api_secret:
        raise HTTPException(status_code=500, detail="LiveKit credentials not configured")
        
    # Ensure token is valid for browser SDK
    token = api.AccessToken(lk_api_key, lk_api_secret) \
        .with_identity(user_id) \
        .with_name(user_id) \
        .with_grants(api.VideoGrants(
            room_join=True,
            room=room,
            can_publish=True,
            can_subscribe=True
        ))
        
    return {"token": token.to_jwt(), "url": lk_url}

# Mount React build files
frontend_dist = os.path.join(os.path.dirname(__file__), "../frontend/dist")
if os.path.exists(frontend_dist):
    app.mount("/", StaticFiles(directory=frontend_dist, html=True), name="static")
