# Generating Video from Images using FFmpeg

This guide explains how to robustly generate a video from a sequence of images using FFmpeg. This is particularly useful for generating synthetic test data for video streaming and computer vision pipelines (like LiveKit WebRTC testing).

## The Core Problem

A common mistake when creating videos from images is using commands that result in the wrong video duration or playback speed:

```bash
# ❌ BAD: Creates a 1 FPS video that plays instantly in WebRTC streams
ffmpeg -framerate 1 -i frames/%03d.jpg -c:v libx264 out.mp4

# ❌ BAD: Squeezes 10 frames into 0.33 seconds of video
ffmpeg -framerate 30 -i frames/%03d.jpg -c:v libx264 out.mp4
```

When streaming over WebRTC (e.g., via the LiveKit CLI `lk room join --publish out.h264 --fps 30`), the server expects a true 30 FPS stream. If you provide a 1 FPS video, the publisher will stream all the frames instantly, and your processing agents will miss the content.

## The Solution: Duplicating Frames

To create a video where **each image is held for a specific amount of time** (e.g., 1 second) while maintaining a **standard output framerate** (e.g., 30 FPS), you must instruct FFmpeg to duplicate frames.

### Step 1: Format Your Images

Ensure all images are named sequentially (e.g., `001.jpg`, `002.jpg`, etc.) and have the exact same resolution.

You can scale and pad them to a standard 640x480 resolution using this filter:
```bash
ffmpeg -i input.jpg -vf "scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:color=black" 001.jpg
```

### Step 2: The Perfect FFmpeg Command

To hold each image for exactly 1 second, resulting in a true 30 FPS video:

```bash
ffmpeg -y -framerate 1/1 -i "frames/%03d.jpg" -c:v libx264 -r 30 -pix_fmt yuv420p output.mp4
```

**Why this works:**
* `-framerate 1/1` (input option): Tells FFmpeg to read exactly 1 input image per second.
* `-r 30` (output option): Forces the output video to be exactly 30 frames per second. FFmpeg automatically achieves this by duplicating each input image 30 times.
* `-pix_fmt yuv420p`: Ensures maximum compatibility across web players and WebRTC.

### Step 3: WebRTC / LiveKit Prep (Optional)

If you are publishing directly via the LiveKit CLI (`lk room join`), you need to convert the `.mp4` container into a raw `.h264` bitstream:

```bash
ffmpeg -y -i output.mp4 -vcodec copy -bsf:v h264_mp4toannexb raw_stream.h264
```

When publishing, remember to explicitly tell the CLI the framerate of your file:
```bash
lk room join <URL> --publish raw_stream.h264 --fps 30
```

## Advanced: Concatenating Videos

If you have two separate MP4 files (e.g., `safe.mp4` and `nsfw.mp4`) and want to stitch them together flawlessly without timestamp (PTS/DTS) corruption, use the `filter_complex` method rather than the `concat` demuxer:

```bash
ffmpeg -y -i safe.mp4 -i nsfw.mp4 -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[v]" -map "[v]" final.mp4
```
*Note: Both videos must have the exact same resolution and framerate for the filter to work.*
