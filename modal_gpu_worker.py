"""
Modal GPU Worker for Oboon NSFW Detection
Processes video frames from LiveKit streams using NudeNet
"""
import modal

app = modal.App("oboon-nsfw-detector")

# Standard debian image with proper deps
image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "nudenet==3.4.2",
        "opencv-python-headless",
        "pillow",
        "numpy",
    )
)


@app.function(
    image=image,
    gpu="T4",        # Cheapest GPU, enough for inference
    timeout=60,
    memory=4096,
    keep_warm=1,     # Keep 1 container warm to avoid cold starts
)
def detect_nsfw(jpeg_bytes: bytes) -> dict:
    """
    Detect NSFW content in a JPEG frame.
    Returns detections with labels and confidence scores.
    """
    import tempfile
    import os
    import numpy as np
    import cv2
    from nudenet import NudeDetector

    # Decode JPEG bytes → OpenCV frame
    nparr = np.frombuffer(jpeg_bytes, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if frame is None:
        return {"error": "Failed to decode frame", "is_nsfw": False, "score": 0.0}

    # Write to temp file (NudeDetector needs a file path)
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
        f.write(jpeg_bytes)
        tmp_path = f.name

    try:
        detector = NudeDetector()
        detections = detector.detect(tmp_path)
    finally:
        os.unlink(tmp_path)

    # NSFW labels from NudeNet
    NSFW_LABELS = {
        "FEMALE_BREAST_EXPOSED",
        "FEMALE_GENITALIA_EXPOSED",
        "MALE_GENITALIA_EXPOSED",
        "BUTTOCKS_EXPOSED",
        "ANUS_EXPOSED",
    }

    nsfw_hits = [d for d in detections if d["class"] in NSFW_LABELS]
    max_score = max((d["score"] for d in nsfw_hits), default=0.0)

    return {
        "is_nsfw": len(nsfw_hits) > 0,
        "score": round(max_score, 3),
        "detections": detections,
        "nsfw_count": len(nsfw_hits),
    }


@app.local_entrypoint()
def main():
    """Smoke test with a blank frame"""
    import numpy as np
    import cv2

    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    _, buf = cv2.imencode(".jpg", frame)

    print("Testing NSFW detector with blank frame...")
    result = detect_nsfw.remote(buf.tobytes())
    print(f"Result: {result}")
