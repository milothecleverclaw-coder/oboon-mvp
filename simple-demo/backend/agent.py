import sys, os, asyncio, logging, json
import modal
import numpy as np, cv2
import aiohttp
from livekit import agents, rtc

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("oboon-agent")

MODAL_APP = "oboon-web-detector"
DB_FILE = "/home/node/.openclaw/workspace/oboon-web/data/users.json"
SETTINGS_URL = "http://localhost:8010/api/settings"

# Cached settings (refreshed each analysis cycle)
_settings = {
    "nsfw_threshold": 0.5,
    "face_threshold": 0.85,
    "sample_rate": 1,
}

async def fetch_settings():
    """Pull latest settings from FastAPI (non-blocking, fallback to cache)."""
    global _settings
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(SETTINGS_URL, timeout=aiohttp.ClientTimeout(total=1)) as r:
                if r.status == 200:
                    _settings = await r.json()
    except Exception:
        pass  # use cached value
    return _settings

def get_user_embedding(user_id):
    if not os.path.exists(DB_FILE):
        return None
    with open(DB_FILE, "r") as f:
        db = json.load(f)
    user_data = db.get(user_id)
    return user_data.get("embedding") if user_data else None

async def process_video_track(ctx: agents.JobContext, track: rtc.RemoteVideoTrack, participant: rtc.RemoteParticipant):
    logger.info(f"Processing video from: {participant.identity}")
    
    worker_cls = modal.Cls.from_name(MODAL_APP, "OboonAIWorker")
    worker = worker_cls()
    
    target_embedding = get_user_embedding(participant.identity)
    if not target_embedding:
        logger.warning(f"No registered face found for user: {participant.identity}")
    
    stream = rtc.VideoStream(track)
    frame_count = 0
    last_analysis_time = 0.0
    
    async for event in stream:
        frame_count += 1
        now = asyncio.get_event_loop().time()
        
        # Fetch settings and compute sample interval
        settings = await fetch_settings()
        sample_interval = max(0.5, float(settings.get("sample_rate", 1)))
        
        if now - last_analysis_time < sample_interval:
            continue
        last_analysis_time = now
        
        nsfw_threshold = float(settings.get("nsfw_threshold", 0.5))
        face_threshold = float(settings.get("face_threshold", 0.85))
        
        try:
            frame = event.frame
            w, h = frame.width, frame.height
            
            try:
                yuv = np.frombuffer(frame.data, dtype=np.uint8).reshape((int(h * 1.5), w))
                rgb = cv2.cvtColor(yuv, cv2.COLOR_YUV2RGB_I420)
            except Exception:
                arr = np.frombuffer(frame.data, dtype=np.uint8).reshape((h, w, 4))
                rgb = cv2.cvtColor(arr, cv2.COLOR_RGBA2RGB)
                
            _, buf = cv2.imencode(".jpg", rgb, [cv2.IMWRITE_JPEG_QUALITY, 70])
            
            result = await worker.process_frame.remote.aio(
                buf.tobytes(),
                target_embedding,
                nsfw_threshold=nsfw_threshold,
                face_threshold=face_threshold,
            )
            
            alert_msg = None
            msg_type = "alert"
            
            if result.get("nsfw"):
                alert_msg = f"🚨 คำเตือน: พบเนื้อหาที่ไม่เหมาะสม (NSFW)!"
                logger.warning(f"[{participant.identity}] NSFW DETECTED")
            elif not result.get("face_match"):
                if result.get("face_detected"):
                    alert_msg = "⚠️ คำเตือน: ใบหน้าไม่ตรงกับที่ลงทะเบียนไว้!"
                    logger.warning(f"[{participant.identity}] IMPOSTER DETECTED")
                else:
                    alert_msg = "⚠️ คำเตือน: ไม่พบใบหน้าในกล้อง!"
                    logger.warning(f"[{participant.identity}] NO FACE")
            else:
                alert_msg = "✅ ยืนยันตัวตนสำเร็จ: ใบหน้าตรงกัน!"
                msg_type = "success"
                logger.info(f"[{participant.identity}] Frame clear - Face matches.")
                
            if alert_msg:
                payload = json.dumps({
                    "type": msg_type,
                    "target": participant.identity,
                    "message": alert_msg
                }).encode("utf-8")
                
                await ctx.room.local_participant.publish_data(
                    payload, 
                    reliable=True
                )
                
        except Exception as e:
            logger.error(f"Frame processing error: {e}")

async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()
    logger.info(f"Agent connected to room {ctx.room.name}")
    
    @ctx.room.on("track_subscribed")
    def on_track(track, pub, participant):
        if track.kind == rtc.TrackKind.KIND_VIDEO:
            asyncio.create_task(process_video_track(ctx, track, participant))

if __name__ == "__main__":
    from livekit.agents import cli
    cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
