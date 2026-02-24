#!/bin/bash
# build-test-video.sh
# Generates a test video with safe + NSFW content for pipeline testing
#
# Usage:
#   ./build-test-video.sh [--output <path>] [--duration <seconds>]
#
# This script creates:
#   1. A "safe" video segment (synthetic color pattern)
#   2. An NSFW video segment (from public test images)
#   3. Stitches them together into test_stream.mp4
#
# The resulting video is suitable for testing the NSFW detection pipeline
# without needing any local files.

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
OUTPUT_DIR="${OUTPUT_DIR:-.}"
OUTPUT_FILE="${OUTPUT_DIR}/test_video.mp4"
SAFE_DURATION=10
NSFW_DURATION=10
FPS=30
WIDTH=640
HEIGHT=480

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)   OUTPUT_FILE="$2"; shift 2 ;;
        --duration) SAFE_DURATION="$2"; NSFW_DURATION="$2"; shift 2 ;;
        --safe-duration) SAFE_DURATION="$2"; shift 2 ;;
        --nsfw-duration) NSFW_DURATION="$2"; shift 2 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${BLUE}▶ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✗ $*${NC}"; }

# ── Check dependencies ────────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in ffmpeg; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

# ── Generate safe video segment ───────────────────────────────────────────────
generate_safe_segment() {
    local output="$1"
    log "Generating safe video segment (${SAFE_DURATION}s)..."
    
    # Create a test pattern with text overlay (simulates "normal" video call)
    ffmpeg -y -f lavfi -i "testsrc=duration=${SAFE_DURATION}:size=${WIDTH}x${HEIGHT}:rate=${FPS}" \
        -vf "drawtext=text='SAFE CONTENT - Frame %{frame_num}':fontsize=24:fontcolor=white:x=(w-text_w)/2:y=h-50" \
        -c:v libx264 -preset fast -pix_fmt yuv420p \
        "$output" 2>/dev/null
    
    success "Safe segment: $output"
}

# ── Generate NSFW video segment ───────────────────────────────────────────────
generate_nsfw_segment() {
    local output="$1"
    log "Generating NSFW video segment (${NSFW_DURATION}s)..."
    
    # Create a test pattern with red tint and NSFW label
    # (In production, this would be actual NSFW content)
    # Using synthetic content to avoid hosting actual NSFW material
    ffmpeg -y -f lavfi -i "color=c=pink:duration=${NSFW_DURATION}:size=${WIDTH}x${HEIGHT}:rate=${FPS}" \
        -vf "drawtext=text='NSFW TEST CONTENT':fontsize=32:fontcolor=red:x=(w-text_w)/2:y=(h-text_h)/2" \
        -c:v libx264 -preset fast -pix_fmt yuv420p \
        "$output" 2>/dev/null
    
    success "NSFW segment: $output"
}

# ── Stitch segments together ──────────────────────────────────────────────────
stitch_video() {
    local safe_seg="$1"
    local nsfw_seg="$2"
    local output="$3"
    
    log "Stitching segments together..."
    
    # Create concat file
    cat > /tmp/concat_list.txt <<EOF
file '$safe_seg'
file '$nsfw_seg'
EOF
    
    ffmpeg -y -f concat -safe 0 -i /tmp/concat_list.txt \
        -c copy "$output" 2>/dev/null
    
    rm -f /tmp/concat_list.txt "$safe_seg" "$nsfw_seg"
    
    success "Final video: $output"
}

# ── Convert to H264 bitstream for LiveKit ─────────────────────────────────────
convert_to_h264() {
    local input="$1"
    local output="${input%.mp4}.h264"
    
    log "Converting to H264 bitstream for LiveKit CLI..."
    
    ffmpeg -y -i "$input" -vcodec copy -bsf:v h264_mp4toannexb "$output" 2>/dev/null
    
    success "H264 bitstream: $output"
    echo "$output"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}=== Building Test Video ===${NC}"
    echo -e "  Safe duration: ${SAFE_DURATION}s"
    echo -e "  NSFW duration: ${NSFW_DURATION}s"
    echo -e "  Output: ${OUTPUT_FILE}"
    echo ""
    
    check_deps
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local safe_seg="${tmp_dir}/safe.mp4"
    local nsfw_seg="${tmp_dir}/nsfw.mp4"
    
    generate_safe_segment "$safe_seg"
    generate_nsfw_segment "$nsfw_seg"
    stitch_video "$safe_seg" "$nsfw_seg" "$OUTPUT_FILE"
    
    local h264_file
    h264_file=$(convert_to_h264 "$OUTPUT_FILE")
    
    echo ""
    echo -e "${BOLD}${GREEN}=== Test Video Ready ===${NC}"
    echo -e "  MP4:  ${OUTPUT_FILE}"
    echo -e "  H264: ${h264_file}"
    echo ""
    echo -e "Use with run-pipeline.sh:"
    echo -e "  ${BLUE}./scripts/run-pipeline.sh --video ${OUTPUT_FILE}${NC}"
}

main
