import asyncio
import logging
import os
import io
import json
from PIL import Image
from livekit import agents, rtc
import modal

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("nudity-agent")

# Modal setup
# We'll use Function.lookup to connect to the deployed app
MODAL_APP_NAME = "oboon-face-recognition"
MODAL_FUNCTION_NAME = "detect_nudity"

async def entrypoint(ctx: agents.JobContext):
    logger.info(f"Connecting to room {ctx.room.name}")
    await ctx.connect()
    logger.info(f"Connected to room {ctx.room.name}")

    # Listen for new participants and their tracks
    @ctx.room.on("track_subscribed")
    def on_track_subscribed(track: rtc.Track, publication: rtc.TrackPublication, participant: rtc.RemoteParticipant):
        if track.kind == rtc.TrackKind.KIND_VIDEO:
            logger.info(f"Subscribed to video track from {participant.identity}")
            asyncio.create_task(process_video_track(ctx, track, participant))

    @ctx.room.on("participant_connected")
    def on_participant_connected(participant: rtc.RemoteParticipant):
        logger.info(f"Participant connected: {participant.identity}")

async def process_video_track(ctx: agents.JobContext, track: rtc.VideoTrack, participant: rtc.RemoteParticipant):
    video_stream = rtc.VideoStream(track)
    frame_count = 0
    SAMPLE_RATE = 30  # Process one frame every 30 frames (~1 fps)

    # Look up the Modal function once
    try:
        detect_fn = modal.Function.lookup(MODAL_APP_NAME, MODAL_FUNCTION_NAME)
    except Exception as e:
        logger.error(f"Failed to lookup Modal function: {e}")
        return

    async for frame_event in video_stream:
        frame_count += 1
        if frame_count % SAMPLE_RATE != 0:
            continue

        frame = frame_event.frame
        logger.info(f"Processing frame {frame_count} from {participant.identity}")

        # Convert frame to JPEG for transmission to Modal
        # LiveKit frames are often in YUV format, PIL handles various modes
        try:
            # Note: In a real production environment, you'd handle YUV -> RGB conversion more robustly
            # For this MVP, we assume the frame can be converted to an image
            img = Image.frombytes("RGBA", (frame.width, frame.height), frame.data)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=70)
            jpeg_data = buf.getvalue()

            # Call Modal GPU worker
            # remote.aio allows async calling
            result = await detect_fn.remote.aio(jpeg_data)
            
            logger.info(f"Detection result for {participant.identity}: {result}")

            if result.get("potentially_inappropriate"):
                logger.warning(f"🚨 POTENTIAL NUDITY DETECTED for participant {participant.identity} (Ratio: {result.get('skin_ratio')})")
                # Example action: send data message to room
                await ctx.room.local_participant.publish_data(
                    json.dumps({
                        "type": "violation",
                        "participant": participant.identity,
                        "score": result.get("skin_ratio")
                    }).encode(),
                    reliable=True
                )

        except Exception as e:
            logger.error(f"Error processing frame: {e}")

if __name__ == "__main__":
    cli.run_app(agents.WorkerOptions(entrypoint_fnc=entrypoint))
