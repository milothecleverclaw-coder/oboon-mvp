import sys, os, asyncio, logging, json
import modal
import numpy as np, cv2
from livekit import agents, rtc

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("nsfw-agent")

MODAL_APP, MODAL_FN = "oboon-nsfw-detector", "detect_nsfw"
SAMPLE_EVERY = int(os.environ.get("SAMPLE_EVERY", "30"))
RESULTS_FILE = os.environ.get("RESULTS_FILE", "/tmp/nsfw_results.jsonl")

def write_result(data: dict):
    with open(RESULTS_FILE, "a") as f: f.write(json.dumps(data) + "\n")

async def process_video_track(ctx, track, participant):
    logger.info(f"Processing video from: {participant.identity}")
    worker_cls = modal.Cls.from_name(MODAL_APP, "NudeNetWorker")
    worker = worker_cls()
    
    stream = rtc.VideoStream(track)
    frame_count = 0
    async for event in stream:
        frame_count += 1
        if frame_count % SAMPLE_EVERY != 0: continue
        
        frame = event.frame
        logger.info(f"Analyzing frame #{frame_count}")
        try:
            w, h = frame.width, frame.height
            # Try I420 -> RGB (LiveKit default)
            try:
                yuv = np.frombuffer(frame.data, dtype=np.uint8).reshape((int(h * 1.5), w))
                rgb = cv2.cvtColor(yuv, cv2.COLOR_YUV2RGB_I420)
            except Exception as e:
                logger.warning(f"I420 conversion failed, trying RGBA: {e}")
                arr = np.frombuffer(frame.data, dtype=np.uint8).reshape((h, w, 4))
                rgb = cv2.cvtColor(arr, cv2.COLOR_RGBA2RGB)
                
            _, buf = cv2.imencode(".jpg", rgb, [cv2.IMWRITE_JPEG_QUALITY, 70])
            import time
            start_t = time.time()
            result = await worker.detect_nsfw.remote.aio(buf.tobytes())
            latency = time.time() - start_t
            result.update({"frame": frame_count, "user": participant.identity, "room_id": ctx.room.name, "latency_ms": round(latency * 1000)})
            
            logger.info(f"  → [{ctx.room.name}] NSFW: {result.get('is_nsfw')} | score: {result.get('score'):.3f} | latency: {result.get('latency_ms')}ms")
            write_result(result)
        except Exception as e:
            logger.error(f"Error: {e}")

async def entrypoint(ctx: agents.JobContext):
    await ctx.connect()
    @ctx.room.on("track_subscribed")
    def on_track(track, pub, participant):
        if track.kind == rtc.TrackKind.KIND_VIDEO:
            asyncio.create_task(process_video_track(ctx, track, participant))

if __name__ == "__main__":
    from livekit.agents import cli
    port = int(os.environ.get("AGENT_PORT", "8081"))
    
    # Disable CPU-based load shedding for stress testing
    options = agents.WorkerOptions(
        entrypoint_fnc=entrypoint,
        port=port,
        load_fnc=lambda: 0.0, # Always pretend load is 0
        load_threshold=1.0    # Never mark as unavailable
    )
    cli.run_app(options)
