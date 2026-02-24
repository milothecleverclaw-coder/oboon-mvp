import sys
import os

# Ensure venv packages are on path (handles livekit-agents subprocess spawning)
_venv = os.path.join(os.path.dirname(os.path.abspath(__file__)), "venv/lib/python3.11/site-packages")
if os.path.exists(_venv) and _venv not in sys.path:
    sys.path.insert(0, _venv)

import asyncio
import logging
import io
import json
from PIL import Image
from livekit import agents, rtc
import modal

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("nsfw-agent")

MODAL_APP = "oboon-nsfw-detector"
MODAL_FN = "detect_nsfw"
SAMPLE_EVERY = 30       # 1 frame per second at 30fps
RESULTS_FILE = os.environ.get("RESULTS_FILE", "/tmp/nsfw_results.jsonl")


def write_result(data: dict):
    with open(RESULTS_FILE, "a") as f:
        f.write(json.dumps(data) + "\n")


async def process_video_track(ctx: agents.JobContext, track: rtc.VideoTrack, participant: rtc.RemoteParticipant):
    logger.info(f"Processing video from: {participant.identity}")

    # Look up Modal function
    try:
        detect_fn = modal.Function.lookup(MODAL_APP, MODAL_FN)
    except Exception as e:
        logger.error(f"Cannot find Modal function {MODAL_APP}/{MODAL_FN}: {e}")
        logger.error("Make sure to run: modal deploy modal_gpu_worker.py")
        return

    video_stream = rtc.VideoStream(track)
    frame_count = 0

    async for frame_event in video_stream:
        frame_count += 1
        if frame_count % SAMPLE_EVERY != 0:
            continue

        frame = frame_event.frame
        logger.info(f"Analyzing frame #{frame_count} from {participant.identity} ({frame.width}x{frame.height})")

        try:
            # Convert raw frame → JPEG
            img = Image.frombytes("RGBA", (frame.width, frame.height), frame.data)
            buf = io.BytesIO()
            img.convert("RGB").save(buf, format="JPEG", quality=70)
            jpeg_bytes = buf.getvalue()

            # Call Modal GPU
            result = await detect_fn.remote.aio(jpeg_bytes)
            result["frame_num"] = frame_count
            result["participant"] = participant.identity

            logger.info(f"  → NSFW: {result.get('is_nsfw')} | score: {result.get('score'):.3f}")
            write_result(result)

            # If NSFW — send data message to room
            if result.get("is_nsfw"):
                logger.warning(f"🚨 NSFW DETECTED from {participant.identity} (score={result.get('score'):.3f})")
                await ctx.room.local_participant.publish_data(
                    json.dumps({
                        "type": "violation",
                        "participant": participant.identity,
                        "score": result.get("score"),
                        "frame": frame_count,
                    }).encode(),
                    reliable=True,
                )

        except Exception as e:
            logger.error(f"Frame processing error: {e}")


async def entrypoint(ctx: agents.JobContext):
    logger.info(f"Agent joining room: {ctx.room.name}")
    await ctx.connect()
    logger.info(f"Connected to room: {ctx.room.name}")

    @ctx.room.on("track_subscribed")
    def on_track(track: rtc.Track, pub: rtc.TrackPublication, participant: rtc.RemoteParticipant):
        if track.kind == rtc.TrackKind.KIND_VIDEO:
            asyncio.create_task(process_video_track(ctx, track, participant))

    @ctx.room.on("participant_connected")
    def on_join(participant: rtc.RemoteParticipant):
        logger.info(f"Participant joined: {participant.identity}")

    @ctx.room.on("participant_disconnected")
    def on_leave(participant: rtc.RemoteParticipant):
        logger.info(f"Participant left: {participant.identity}")


if __name__ == "__main__":
    from livekit.agents import cli as lk_cli
    lk_cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
