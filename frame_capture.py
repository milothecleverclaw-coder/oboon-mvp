"""
Frame Capture Pipeline for Oboon
Captures frames from LiveKit video streams for AI processing
Integrates face recognition (DeepFace ArcFace) and nudity detection
"""
import asyncio
import base64
import json
import time
from datetime import datetime
from typing import Optional, Dict, Any, List
import cv2
import numpy as np
from deepface import DeepFace

# Frame capture configuration
CAPTURE_INTERVAL = 3  # seconds between frame captures
FRAME_QUALITY = 85  # JPEG quality (1-100)
MAX_FRAME_SIZE = 640 * 480  # Max resolution for processing

# Face recognition settings
FACE_MODEL = "ArcFace"  # 97%+ accuracy
DETECTOR_BACKEND = "retinaface"  # Best accuracy


class FrameCapturePipeline:
    """Captures and processes frames from video streams"""
    
    def __init__(self, livekit_url: str, api_key: str, api_secret: str):
        self.livekit_url = livekit_url
        self.api_key = api_key
        self.api_secret = api_secret
        self.active_captures: Dict[str, Any] = {}
        self.known_faces: Dict[str, List[float]] = {}  # identity -> embedding
    
    def register_known_face(self, identity: str, image_path: str):
        """Register a known face for recognition"""
        try:
            embedding = DeepFace.represent(
                img_path=image_path,
                model_name=FACE_MODEL,
                enforce_detection=True,
                detector_backend=DETECTOR_BACKEND
            )[0]["embedding"]
            self.known_faces[identity] = embedding
            print(f"Registered face for: {identity}")
        except Exception as e:
            print(f"Failed to register face for {identity}: {e}")
    
    async def start_capture(self, room_name: str, participant_id: str):
        """Start capturing frames from a participant's video track"""
        capture_id = f"{room_name}:{participant_id}"
        
        if capture_id in self.active_captures:
            print(f"Capture already active for {capture_id}")
            return
        
        self.active_captures[capture_id] = {
            "room": room_name,
            "participant": participant_id,
            "started_at": datetime.utcnow().isoformat(),
            "frames_captured": 0,
            "faces_detected": 0,
            "alerts": 0
        }
        
        print(f"Started capture for {capture_id}")
    
    async def stop_capture(self, room_name: str, participant_id: str):
        """Stop capturing frames"""
        capture_id = f"{room_name}:{participant_id}"
        
        if capture_id in self.active_captures:
            stats = self.active_captures.pop(capture_id)
            print(f"Stopped capture for {capture_id}")
            print(f"  Frames: {stats['frames_captured']}, Faces: {stats['faces_detected']}, Alerts: {stats['alerts']}")
    
    async def capture_frame(self, room_name: str, participant_id: str) -> Optional[bytes]:
        """Capture a single frame from participant's video"""
        # Placeholder - in production this would get video track from LiveKit
        # For testing, create a test frame with timestamp
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        timestamp = datetime.utcnow().strftime("%H:%M:%S")
        cv2.putText(frame, timestamp, (200, 240), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        
        # Encode to JPEG
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, FRAME_QUALITY])
        return buffer.tobytes()
    
    def recognize_faces(self, frame_data: bytes) -> Dict[str, Any]:
        """Detect and recognize faces in frame"""
        try:
            # Decode frame
            nparr = np.frombuffer(frame_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            # Detect faces
            faces = DeepFace.represent(
                frame,
                model_name=FACE_MODEL,
                enforce_detection=False,
                detector_backend=DETECTOR_BACKEND
            )
            
            results = []
            for face in faces:
                result = {
                    "region": face["facial_area"],
                    "confidence": face.get("confidence", 0),
                    "identity": "unknown"
                }
                
                # Check against known faces
                if self.known_faces:
                    embedding = face["embedding"]
                    best_match = None
                    best_distance = float('inf')
                    
                    for identity, known_embedding in self.known_faces.items():
                        # Calculate cosine distance
                        distance = np.linalg.norm(
                            np.array(embedding) - np.array(known_embedding)
                        )
                        if distance < best_distance and distance < 0.4:  # threshold
                            best_distance = distance
                            best_match = identity
                    
                    if best_match:
                        result["identity"] = best_match
                        result["distance"] = best_distance
                
                results.append(result)
            
            return {
                "faces_detected": len(results),
                "faces": results
            }
        
        except Exception as e:
            return {"error": str(e), "faces_detected": 0, "faces": []}
    
    def detect_inappropriate_content(self, frame_data: bytes) -> Dict[str, Any]:
        """Detect nudity/inappropriate content using skin detection heuristic"""
        try:
            nparr = np.frombuffer(frame_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            # Convert to HSV for skin detection
            hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
            
            # Skin color range (approximate)
            lower_skin = np.array([0, 20, 70], dtype=np.uint8)
            upper_skin = np.array([20, 255, 255], dtype=np.uint8)
            
            # Create skin mask
            skin_mask = cv2.inRange(hsv, lower_skin, upper_skin)
            skin_ratio = np.sum(skin_mask > 0) / (frame.shape[0] * frame.shape[1])
            
            return {
                "skin_ratio": float(skin_ratio),
                "potentially_inappropriate": skin_ratio > 0.6,
                "confidence": min(skin_ratio * 1.5, 1.0)
            }
        
        except Exception as e:
            return {"error": str(e)}
    
    async def process_frame(self, frame_data: bytes, room_name: str) -> Dict[str, Any]:
        """Process captured frame through AI pipeline"""
        # Face recognition
        face_result = self.recognize_faces(frame_data)
        
        # Nudity detection
        content_result = self.detect_inappropriate_content(frame_data)
        
        return {
            "room": room_name,
            "timestamp": datetime.utcnow().isoformat(),
            "frame_size": len(frame_data),
            "faces_detected": face_result.get("faces_detected", 0),
            "faces": face_result.get("faces", []),
            "inappropriate_content": content_result.get("potentially_inappropriate", False),
            "content_confidence": content_result.get("confidence", 0),
            "processed": True
        }
    
    async def continuous_capture(self, room_name: str, participant_id: str, duration: int = 300):
        """Continuously capture frames for specified duration"""
        capture_id = f"{room_name}:{participant_id}"
        start_time = time.time()
        
        await self.start_capture(room_name, participant_id)
        
        try:
            while time.time() - start_time < duration:
                if capture_id not in self.active_captures:
                    break
                
                # Capture frame
                frame = await self.capture_frame(room_name, participant_id)
                
                if frame:
                    # Process frame
                    result = await self.process_frame(frame, room_name)
                    
                    # Update stats
                    self.active_captures[capture_id]["frames_captured"] += 1
                    self.active_captures[capture_id]["faces_detected"] += result.get("faces_detected", 0)
                    
                    # Log result
                    print(f"Frame: {result['timestamp']} | Faces: {result['faces_detected']} | Inappropriate: {result['inappropriate_content']}")
                    
                    # Check for alerts
                    if result.get("inappropriate_content"):
                        await self.send_alert(room_name, "inappropriate_content", result)
                        self.active_captures[capture_id]["alerts"] += 1
                    
                    # Check for unknown faces in a 1:1 call (should only have 2 known participants)
                    unknown_faces = [f for f in result.get("faces", []) if f.get("identity") == "unknown"]
                    if len(unknown_faces) > 0:
                        await self.send_alert(room_name, "unknown_face", {"unknown_count": len(unknown_faces)})
                        self.active_captures[capture_id]["alerts"] += 1
                
                # Wait for next capture interval
                await asyncio.sleep(CAPTURE_INTERVAL)
        
        finally:
            await self.stop_capture(room_name, participant_id)
    
    async def send_alert(self, room_name: str, alert_type: str, data: Dict[str, Any]):
        """Send alert to webhook"""
        alert = {
            "room": room_name,
            "type": alert_type,
            "timestamp": datetime.utcnow().isoformat(),
            "data": data
        }
        print(f"🚨 ALERT [{alert_type.upper()}]: {json.dumps(alert, indent=2)}")


async def main():
    """Test the frame capture pipeline with face recognition"""
    pipeline = FrameCapturePipeline(
        livekit_url="ws://49.12.97.212:7880",
        api_key="ff656dd287ce4aa63f60df2eeb7d5194",
        api_secret="e8c0200218351c3ec0eabf05ce1dba84f1d0e8118d4a9927687fb0165a2f7438"
    )
    
    print("=== Frame Capture Pipeline Test ===")
    print(f"Face Model: {FACE_MODEL}")
    print(f"Detector: {DETECTOR_BACKEND}")
    print(f"Capture Interval: {CAPTURE_INTERVAL}s")
    print()
    
    # Test face recognition (will download models on first run)
    print("Testing face recognition pipeline...")
    
    # Run for 15 seconds
    await pipeline.continuous_capture(
        room_name="test-room-001",
        participant_id="test-participant",
        duration=15
    )
    
    print("\nTest complete!")


if __name__ == "__main__":
    asyncio.run(main())
