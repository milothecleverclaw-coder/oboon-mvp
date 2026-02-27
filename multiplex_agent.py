import sys, os, asyncio, logging, json, time
import modal
import numpy as np, cv2
from livekit import rtc, api

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("nsfw-multiplex")

MODAL_APP, MODAL_FN = "oboon-nsfw-detector", "detect_nsfw"
SAMPLE_SECONDS = float(os.environ.get("SAMPLE_SECONDS", "2.0"))
RESULTS_FILE = os.environ.get("RESULTS_FILE", "/tmp/nsfw_results.jsonl")
MOCK_MODAL = os.environ.get("MOCK_MODAL", "false").lower() == "true"
LIVEKIT_URL = os.environ.get("LIVEKIT_URL", "")
START_ID = int(os.environ.get("START_ID", "1"))
END_ID = int(os.environ.get("END_ID", "50"))
NODE_ID = os.environ.get("NODE_ID", "1")

try:
    if not MOCK_MODAL:
        worker_cls = modal.Cls.from_name(MODAL_APP, "NudeNetWorker")
        global_worker = worker_cls()
    else:
        global_worker = None
except Exception as e:
    logger.error(f"Failed to initialize Modal worker globally: {e}")
    global_worker = None

def write_result(data: dict):
    with open(RESULTS_FILE, "a") as f:
        f.write(json.dumps(data) + "\n")
        f.flush()
        os.fsync(f.fileno())

async def process_video_track(room, track, participant):
    logger.info(f"[{room.name}] Processing video from: {participant.identity}")
    
    # CAPACITY=1 drops frames automatically when we're waiting
    stream = rtc.VideoStream(track, capacity=1)
    
    last_process_time = 0.0
    frame_count = 0
    
    try:
        async for event in stream:
            current_time = asyncio.get_event_loop().time()
            
            # Fast time-based skip
            if current_time - last_process_time < SAMPLE_SECONDS:
                continue
                
            last_process_time = current_time
            frame_count += 1
            frame = event.frame
            
            try:
                w, h = frame.width, frame.height
                try:
                    yuv = np.frombuffer(frame.data, dtype=np.uint8).reshape((int(h * 1.5), w))
                    rgb = cv2.cvtColor(yuv, cv2.COLOR_YUV2RGB_I420)
                except Exception as e:
                    arr = np.frombuffer(frame.data, dtype=np.uint8).reshape((h, w, 4))
                    rgb = cv2.cvtColor(arr, cv2.COLOR_RGBA2RGB)
                    
                _, buf = cv2.imencode(".jpg", rgb, [cv2.IMWRITE_JPEG_QUALITY, 70])
                start_t = time.time()
                
                if MOCK_MODAL:
                    await asyncio.sleep(0.5)
                    result = {"is_nsfw": False, "score": 0.0, "detections": [], "nsfw_count": 0}
                else:
                    result = await global_worker.detect_nsfw.remote.aio(buf.tobytes())
                    
                latency = time.time() - start_t
                result.update({"frame": frame_count, "user": participant.identity, "room_id": room.name, "latency_ms": round(latency * 1000)})
                
                write_result(result)
                
            except Exception as e:
                logger.error(f"Error processing frame in {room.name}: {e}")
                
    except asyncio.CancelledError:
        pass

async def join_room(room_id):
    room = rtc.Room()

    @room.on("track_subscribed")
    def on_track_subscribed(track, publication, participant):
        if track.kind == rtc.TrackKind.KIND_VIDEO:
            asyncio.create_task(process_video_track(room, track, participant))

    token = api.AccessToken(os.environ.get("LIVEKIT_API_KEY"), os.environ.get("LIVEKIT_API_SECRET")) \
        .with_identity(f"agent-{os.getpid()}-{room_id}") \
        .with_name("NSFW Agent") \
        .with_grants(api.VideoGrants(room_join=True, room=room_id)) \
        .to_jwt()

    try:
        await room.connect(LIVEKIT_URL, token)
        logger.info(f"Connected to room: {room_id}")
    except Exception as e:
        logger.error(f"Failed to connect to {room_id}: {e}")
    
    return room

async def main():
    if not LIVEKIT_URL:
        logger.error("LIVEKIT_URL environment variable required")
        sys.exit(1)

    logger.info(f"Starting multiplex agent for Node {NODE_ID}, Rooms {START_ID} to {END_ID}")
    
    rooms = []
    # Join rooms slightly staggered to avoid hammering LiveKit auth
    for i in range(START_ID, END_ID + 1):
        room_id = f"nsfw-loadtest-node{NODE_ID}-{i}"
        r = await join_room(room_id)
        rooms.append(r)
        await asyncio.sleep(0.1)

    logger.info(f"Successfully joined {len(rooms)} rooms. Waiting for publishers...")
    
    # Run forever until killed
    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        pass
    finally:
        for r in rooms:
            await r.disconnect()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass