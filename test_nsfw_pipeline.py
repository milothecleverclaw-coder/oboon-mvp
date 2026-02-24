#!/usr/bin/env python3
"""
test_nsfw_pipeline.py
=====================
End-to-end NSFW detection pipeline test:
  1. Deploy Modal GPU worker
  2. Generate a synthetic test video (or use a real file)
  3. Start LiveKit Agent (subscribes to video, samples frames, calls Modal)
  4. Publish the video into a LiveKit room
  5. Print detection summary

Usage:
  python test_nsfw_pipeline.py
  python test_nsfw_pipeline.py --video path/to/video.mp4
  python test_nsfw_pipeline.py --skip-deploy   # if already deployed
"""

import argparse
import asyncio
import json
import logging
import os
import signal
import subprocess
import sys
import tempfile
import time

# ── Config ────────────────────────────────────────────────────────────────────
STATE_FILE = os.path.expanduser("~/.openclaw/workspace/oboon/.vm-state.json")
RESULTS_FILE = "/tmp/nsfw_results.jsonl"
ROOM_NAME = "nsfw-test-room"
TEST_DURATION = 20  # seconds of video to publish
MODAL_APP = "oboon-nsfw-detector"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger("test-pipeline")

# ── Step 0: Load LiveKit credentials ─────────────────────────────────────────
def load_credentials():
    if not os.path.exists(STATE_FILE):
        log.error(f"State file not found: {STATE_FILE}")
        log.error("Run: bash scripts/create-resources.sh --calls 50 --vm-only")
        sys.exit(1)

    with open(STATE_FILE) as f:
        state = json.load(f)

    required = ["livekit_url", "api_key", "api_secret"]
    for k in required:
        if k not in state:
            log.error(f"Missing {k} in state file")
            sys.exit(1)

    return state["livekit_url"], state["api_key"], state["api_secret"]


# ── Step 1: Deploy Modal worker ───────────────────────────────────────────────
def deploy_modal():
    log.info("Deploying Modal GPU worker...")
    result = subprocess.run(
        [sys.executable, "-m", "modal", "deploy", "modal_gpu_worker.py"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        log.error(f"Modal deploy failed:\n{result.stderr}")
        sys.exit(1)
    log.info("✓ Modal worker deployed")


# ── Step 2: Generate synthetic test video ─────────────────────────────────────
def generate_test_video(path: str, duration: int = 20):
    """Generate a solid-color video using ffmpeg (no real NSFW content needed for pipeline test)"""
    log.info(f"Generating {duration}s synthetic test video: {path}")
    cmd = [
        "ffmpeg", "-y",
        "-f", "lavfi",
        "-i", f"color=c=blue:size=640x480:duration={duration}:rate=30",
        "-c:v", "libx264", "-preset", "fast", "-pix_fmt", "yuv420p",
        path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        log.error(f"ffmpeg failed:\n{result.stderr}")
        sys.exit(1)
    log.info(f"✓ Test video generated: {path}")


# ── Step 3: Start Agent ───────────────────────────────────────────────────────
def start_agent(lk_url: str, api_key: str, api_secret: str) -> subprocess.Popen:
    log.info("Starting LiveKit NSFW Agent...")

    venv_python = os.path.join(os.path.dirname(__file__), "venv/bin/python")
    if not os.path.exists(venv_python):
        venv_python = sys.executable

    env = os.environ.copy()
    env.update({
        "LIVEKIT_URL": lk_url,
        "LIVEKIT_API_KEY": api_key,
        "LIVEKIT_API_SECRET": api_secret,
        "RESULTS_FILE": RESULTS_FILE,
    })

    # Clear old results
    if os.path.exists(RESULTS_FILE):
        os.unlink(RESULTS_FILE)

    proc = subprocess.Popen(
        [venv_python, "agent_server.py", "start",
         "--url", lk_url,
         "--api-key", api_key,
         "--api-secret", api_secret],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    log.info(f"✓ Agent started (pid={proc.pid})")
    time.sleep(4)  # Give it time to connect to LiveKit
    return proc


# ── Step 4: Dispatch agent + Publish video ────────────────────────────────────
async def dispatch_and_wait(lk_url: str, api_key: str, api_secret: str):
    """Dispatch agent and wait until it appears in the room"""
    from livekit import api
    lk_api = api.LiveKitAPI(lk_url, api_key, api_secret)
    try:
        dispatch = await lk_api.agent_dispatch.create_dispatch(
            api.CreateAgentDispatchRequest(
                agent_name="nsfw-detector",
                room=ROOM_NAME,
            )
        )
        log.info(f"✓ Agent dispatched: {dispatch.agent_name}")

        # Wait until agent participant appears in room (max 15s)
        log.info("Waiting for agent to join room...")
        for _ in range(15):
            await asyncio.sleep(1)
            parts = await lk_api.room.list_participants(
                api.ListParticipantsRequest(room=ROOM_NAME)
            )
            agent_parts = [p for p in parts.participants if p.identity.startswith("agent-")]
            if agent_parts:
                log.info(f"✓ Agent in room: {agent_parts[0].identity}")
                break
        else:
            log.warning("Agent did not appear in room within 15s")

    except Exception as e:
        log.warning(f"Dispatch error: {e}")
    finally:
        await lk_api.aclose()


def publish_video(lk_url: str, api_key: str, api_secret: str, video_path: str):
    log.info(f"Publishing video to room '{ROOM_NAME}'...")

    # Dispatch agent and wait for it to be ready in room
    asyncio.run(dispatch_and_wait(lk_url, api_key, api_secret))
    time.sleep(1)

    # Use lk load-test with video
    cmd = [
        "lk", "load-test",
        "--url", lk_url,
        "--api-key", api_key,
        "--api-secret", api_secret,
        "--room", ROOM_NAME,
        "--video-publishers", "1",
        "--duration", f"{TEST_DURATION}s",
    ]

    log.info(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=TEST_DURATION + 30)

    if result.returncode != 0:
        log.warning(f"lk load-test stderr: {result.stderr}")
    else:
        log.info("✓ Video published successfully")

    return result.stdout


# ── Step 5: Print summary ─────────────────────────────────────────────────────
def print_summary(agent_proc: subprocess.Popen):
    log.info("Collecting results...")
    time.sleep(3)  # Give agent time to flush last detections

    # Stop agent
    agent_proc.send_signal(signal.SIGTERM)

    # Read agent output
    try:
        stdout, _ = agent_proc.communicate(timeout=5)
        agent_output = stdout.decode() if stdout else ""
    except subprocess.TimeoutExpired:
        agent_proc.kill()
        agent_output = ""

    # Parse results file
    results = []
    if os.path.exists(RESULTS_FILE):
        with open(RESULTS_FILE) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        results.append(json.loads(line))
                    except Exception:
                        pass

    print("\n" + "="*60)
    print("  NSFW DETECTION PIPELINE RESULTS")
    print("="*60)
    print(f"  Frames analyzed:   {len(results)}")

    if results:
        nsfw_frames = [r for r in results if r.get("is_nsfw")]
        scores = [r.get("score", 0) for r in results]
        print(f"  NSFW frames:       {len(nsfw_frames)} / {len(results)}")
        print(f"  Max score:         {max(scores):.3f}")
        print(f"  Avg score:         {sum(scores)/len(scores):.3f}")

        if nsfw_frames:
            print(f"\n  🚨 NSFW DETECTIONS:")
            for r in nsfw_frames[:5]:  # Show first 5
                print(f"    Frame {r.get('frame_num')}: score={r.get('score'):.3f} — {[d['class'] for d in r.get('detections', []) if d.get('score', 0) > 0.5]}")
        else:
            print("\n  ✅ No NSFW content detected")
    else:
        print("\n  ⚠️  No results captured — check agent logs")
        if agent_output:
            print("\nAgent output (last 20 lines):")
            for line in agent_output.strip().split("\n")[-20:]:
                print(f"  {line}")

    print("="*60 + "\n")


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="End-to-end NSFW detection pipeline test")
    parser.add_argument("--video", help="Path to video file (default: generate synthetic)", default=None)
    parser.add_argument("--skip-deploy", action="store_true", help="Skip Modal deploy step")
    args = parser.parse_args()

    print("\n🚀 NSFW Detection Pipeline Test")
    print("="*60)

    # Step 0: Credentials
    lk_url, api_key, api_secret = load_credentials()
    print(f"  LiveKit: {lk_url}")
    print(f"  Room:    {ROOM_NAME}")
    print("="*60 + "\n")

    # Step 1: Deploy Modal
    if not args.skip_deploy:
        deploy_modal()
    else:
        log.info("Skipping Modal deploy (--skip-deploy)")

    # Step 2: Video
    if args.video:
        video_path = args.video
        if not os.path.exists(video_path):
            log.error(f"Video file not found: {video_path}")
            sys.exit(1)
        log.info(f"Using provided video: {video_path}")
    else:
        video_path = "/tmp/test_video.mp4"
        generate_test_video(video_path, duration=TEST_DURATION)

    # Step 3: Agent
    agent_proc = start_agent(lk_url, api_key, api_secret)

    try:
        # Step 4: Publish
        publish_video(lk_url, api_key, api_secret, video_path)
    finally:
        # Step 5: Summary
        print_summary(agent_proc)


if __name__ == "__main__":
    main()
