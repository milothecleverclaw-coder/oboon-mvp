"""
Modal GPU Worker for Oboon Face Recognition
Processes video frames from LiveKit streams
"""
import modal

# Create Modal app
app = modal.App("oboon-face-recognition")

# Define GPU image with dependencies
# Using a pre-built image with OpenCV and Python 3.11
# Image: gigante/python-opencv:5.0.0-alpha
# This image should have numpy and opencv pre-installed
image = modal.Image.from_registry(
    "gigante/python-opencv:5.0.0-alpha",
    # Removed python_version as it's not compatible with from_registry
).pip_install(
    "deepface",
    "requests",
    # numpy and opencv should be pre-installed in the base image
)

# GPU-enabled function for face recognition
@app.function(
    image=image,
    gpu="A10G",  # Cost-effective GPU for inference
    timeout=60,
    memory=4096,
)
def process_frame(frame_data: bytes) -> dict:
    """
    Process a single video frame for face recognition.
    Returns detected faces with embeddings.
    """
    import cv2
    import numpy as np
    from deepface import DeepFace

    # Decode frame
    nparr = np.frombuffer(frame_data, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if frame is None:
        return {"error": "Failed to decode frame"}

    try:
        # Detect faces using ArcFace model (97%+ accuracy)
        result = DeepFace.represent(
            frame,
            model_name="ArcFace",
            enforce_detection=False,
            detector_backend="retinaface"
        )

        faces = []
        for face in result:
            faces.append({
                "embedding": face["embedding"],
                "region": face["facial_area"],
                "confidence": face.get("confidence", 0)
            })

        return {
            "faces_detected": len(faces),
            "faces": faces
        }
    except Exception as e:
        return {"error": str(e), "faces_detected": 0}


@app.function(
    image=image,
    gpu="A10G",
    timeout=120,
    memory=4096,
)
def detect_nudity(frame_data: bytes) -> dict:
    """
    Detect nudity/inappropriate content in frame.
    Returns detection result with confidence score.
    """
    import cv2
    import numpy as np
    from deepface import DeepFace

    nparr = np.frombuffer(frame_data, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if frame is None:
        return {"error": "Failed to decode frame"}

    try:
        # Analyze for inappropriate content
        # Note: DeepFace has limited nudity detection
        # Production should use specialized models
        analysis = DeepFace.analyze(
            frame,
            actions=["age", "gender"],
            enforce_detection=False
        )

        # Simple heuristic: if skin-like colors dominate large areas
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        lower_skin = np.array([0, 20, 70], dtype=np.uint8)
        upper_skin = np.array([20, 255, 255], dtype=np.uint8)
        skin_mask = cv2.inRange(hsv, lower_skin, upper_skin)
        skin_ratio = np.sum(skin_mask > 0) / (frame.shape[0] * frame.shape[1])

        return {
            "skin_ratio": float(skin_ratio),
            "potentially_inappropriate": skin_ratio > 0.6,
            "confidence": min(skin_ratio * 1.5, 1.0)
        }
    except Exception as e:
        return {"error": str(e)}


# Local entry point for testing
@app.local_entrypoint()
def main():
    """Test the GPU worker"""
    import numpy as np
    import cv2

    # Create a test frame (black image with white circle)
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    cv2.circle(frame, (320, 240), 100, (255, 255, 255), -1)

    # Encode to JPEG
    _, buffer = cv2.imencode('.jpg', frame)
    frame_data = buffer.tobytes()

    # Test face recognition
    print("Testing face recognition...")
    result = process_frame.remote(frame_data)
    print(f"Result: {result}")

    # Test nudity detection
    print("\nTesting nudity detection...")
    result = detect_nudity.remote(frame_data)
    print(f"Result: {result}")


if __name__ == "__main__":
    main()
