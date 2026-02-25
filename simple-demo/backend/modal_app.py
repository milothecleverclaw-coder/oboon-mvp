import modal

app = modal.App("oboon-web-detector")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("libgl1", "libglib2.0-0")
    .pip_install(
        "nudenet==3.4.2",
        "deepface",
        "tf-keras",
        "opencv-python-headless",
        "pillow",
        "numpy"
    )
)

@app.cls(
    image=image,
    gpu="T4",
    timeout=60,
    min_containers=0,
    allow_concurrent_inputs=10,
)
class OboonAIWorker:
    @modal.enter()
    def load_models(self):
        import os
        from nudenet import NudeDetector
        from deepface import DeepFace
        os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
        self.nude_detector = NudeDetector()
        print("NudeNet loaded")
        DeepFace.build_model("ArcFace")
        print("DeepFace ArcFace loaded")

    @modal.method()
    def get_embedding(self, image_bytes: bytes) -> dict:
        import tempfile
        import os
        from deepface import DeepFace
        
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
            f.write(image_bytes)
            tmp_path = f.name
            
        try:
            results = DeepFace.represent(
                tmp_path,
                model_name="ArcFace",
                detector_backend="opencv",
                enforce_detection=False
            )
            if len(results) > 0 and results[0].get("face_confidence", 0) > 0.35:
                return {"success": True, "embedding": results[0]["embedding"]}
            return {"success": False, "error": "No clear face detected. Please ensure you are in a well-lit area."}
        except Exception as e:
            return {"success": False, "error": str(e)}
        finally:
            os.unlink(tmp_path)

    @modal.method()
    def process_frame(
        self,
        image_bytes: bytes,
        target_embedding: list = None,
        nsfw_threshold: float = 0.5,
        face_threshold: float = 0.85,
    ) -> dict:
        import tempfile
        import os
        from deepface import DeepFace
        
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
            f.write(image_bytes)
            tmp_path = f.name
            
        result = {
            "nsfw": False,
            "nsfw_score": 0.0,
            "face_match": True,
            "face_distance": 0.0,
            "face_detected": False
        }
            
        try:
            detections = self.nude_detector.detect(tmp_path)
            NSFW_LABELS = {
                "FEMALE_BREAST_EXPOSED", "FEMALE_GENITALIA_EXPOSED", 
                "MALE_GENITALIA_EXPOSED", "BUTTOCKS_EXPOSED", "ANUS_EXPOSED"
            }
            nsfw_hits = [d for d in detections if d["class"] in NSFW_LABELS and d["score"] >= nsfw_threshold]
            if nsfw_hits:
                result["nsfw"] = True
                result["nsfw_score"] = float(max(d["score"] for d in nsfw_hits))

            if target_embedding:
                current_faces = DeepFace.represent(
                    tmp_path,
                    model_name="ArcFace",
                    detector_backend="opencv",
                    enforce_detection=False
                )
                
                if current_faces and current_faces[0].get("face_confidence", 0) > 0.35:
                    result["face_detected"] = True
                    current_emb = current_faces[0]["embedding"]
                    import numpy as np
                    a = np.array(target_embedding)
                    b = np.array(current_emb)
                    # Cosine distance
                    distance = 1 - np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))
                    result["face_distance"] = float(distance)
                    
                    if distance > face_threshold:
                        result["face_match"] = False
                else:
                    result["face_match"] = False
                    
        except Exception as e:
            result["error"] = str(e)
        finally:
            os.unlink(tmp_path)
            
        return result
