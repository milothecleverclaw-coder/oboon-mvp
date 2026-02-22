# Test Video Files

Synthetic test videos for simulating video call participants.

## Files

| File | Description | Size | Duration |
|------|-------------|------|----------|
| `test_participant_1.mp4` | Test pattern with text overlay | ~120KB | 15s |
| `test_participant_2.mp4` | SMPTE bars with text overlay | ~22KB | 15s |
| `test_participant_3.mp4` | Test pattern with text overlay | ~120KB | 15s |
| `test_participant_4.mp4` | Test pattern with text overlay | ~120KB | 15s |
| `test_participant_5.mp4` | Test pattern with text overlay | ~124KB | 15s |
| `simulated_face.mp4` | Simulated face (head-shaped oval) | ~19KB | 15s |

## Specifications

- **Resolution:** 640x480
- **Frame Rate:** 30 fps
- **Duration:** 15 seconds
- **Codec:** H.264 (libx264)

## Usage

These videos are used for:
1. Load testing LiveKit rooms
2. Simulating multiple participants
3. Frame capture pipeline testing

## Regeneration

To regenerate all test videos:

```bash
cd oboon/test_videos

# Test pattern videos
for i in 1 3 4 5; do
  ffmpeg -y -f lavfi -i "testsrc=duration=15:size=640x480:rate=30" \
  -vf "drawtext=text='Test Participant $i':fontsize=24:fontcolor=white:x=(w-text_w)/2:y=h-50" \
  -c:v libx264 -preset fast -crf 23 test_participant_$i.mp4
done

# SMPTE bars
ffmpeg -y -f lavfi -i "smptebars=duration=15:size=640x480:rate=30" \
-vf "drawtext=text='Test Participant 2':fontsize=24:fontcolor=white:x=(w-text_w)/2:y=h-50" \
-c:v libx264 -preset fast -crf 23 test_participant_2.mp4

# Simulated face
ffmpeg -y -f lavfi -i "color=c=beige:s=640x480:d=15:r=30" \
-vf "drawbox=x=220:y=120:w=200:h=240:c=tan:t=fill, \
drawbox=x=260:y=180:w=30:h=20:c=white:t=fill, \
drawbox=x=350:y=180:w=30:h=20:c=white:t=fill, \
drawbox=x=290:y=280:w=60:h=30:c=indianred:t=fill, \
drawtext=text='Simulated Face':fontsize=20:fontcolor=white:x=(w-text_w)/2:y=h-40" \
-c:v libx264 -preset fast -crf 23 simulated_face.mp4
```
