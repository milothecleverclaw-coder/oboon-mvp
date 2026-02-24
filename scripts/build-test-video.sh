#!/bin/bash
# build-test-video.sh
# Generates a test video by downloading real datasets from Hugging Face & Kaggle

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
OUTPUT_FILE="test_video.mp4"
WIDTH=640
HEIGHT=480
IMAGE_COUNT=20

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)   OUTPUT_FILE="$2"; shift 2 ;;
        --count)    IMAGE_COUNT="$2"; shift 2 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${BLUE}▶ $*${NC}"; }
success() { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠ $*${NC}"; }
error()   { echo -e "${RED}✗ $*${NC}"; }

# ── Check credentials ─────────────────────────────────────────────────────────
check_creds() {
    if [[ -z "${HF_TOKEN:-}" ]]; then error "HF_TOKEN not set"; exit 1; fi
    if [[ -z "${KAGGLE_USER:-}" || -z "${KAGGLE_KEY:-}" ]]; then error "KAGGLE creds not set"; exit 1; fi
}

# ── Setup Environment ─────────────────────────────────────────────────────────
setup_env() {
    if [[ -f "/root/oboon-mvp/venv/bin/activate" ]]; then source /root/oboon-mvp/venv/bin/activate; fi
    pip install -q huggingface_hub kaggle 2>/dev/null || true
    mkdir -p ~/.kaggle
    echo "{\"username\":\"${KAGGLE_USER}\",\"key\":\"${KAGGLE_KEY}\"}" > ~/.kaggle/kaggle.json
    chmod 600 ~/.kaggle/kaggle.json
}

# ── Download Datasets ─────────────────────────────────────────────────────────
download_datasets() {
    local work_dir="$1"
    log "Downloading datasets..."
    
    mkdir -p "${work_dir}/kaggle" "${work_dir}/hf"
    
    # Kaggle: Avengers
    log "  - Kaggle: yasserh/avengers-faces-dataset"
    cd "${work_dir}/kaggle"
    kaggle datasets download -d yasserh/avengers-faces-dataset --unzip > /dev/null 2>&1 || warn "Kaggle failed"
    cd - >/dev/null
    
    # HF: NSFW
    log "  - HF: x1101/nsfw-full"
    HF_TOKEN="${HF_TOKEN}" hf download x1101/nsfw-full --repo-type dataset --local-dir "${work_dir}/hf" > /dev/null 2>&1 || warn "HF failed"
    
    # Extract images to flat folders
    mkdir -p "${work_dir}/safe" "${work_dir}/nsfw"
    
    log "Extracting images..."
    # Avengers images
    find "${work_dir}/kaggle" -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg \) | head -n "$IMAGE_COUNT" | \
        while read -r img; do cp "$img" "${work_dir}/safe/$(basename "$img")" 2>/dev/null || true; done
    
    # NSFW images (extract zip first)
    if ls "${work_dir}/hf"/*.zip 1> /dev/null 2>&1; then
        unzip -q "${work_dir}/hf"/*.zip -d "${work_dir}/hf_tmp" 2>/dev/null || true
        find "${work_dir}/hf_tmp" -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg \) | head -n "$IMAGE_COUNT" | \
            while read -r img; do cp "$img" "${work_dir}/nsfw/$(basename "$img")" 2>/dev/null || true; done
    fi
    
    local s_cnt=$(ls "${work_dir}/safe" | wc -l)
    local n_cnt=$(ls "${work_dir}/nsfw" | wc -l)
    log "Found $s_cnt safe images and $n_cnt NSFW images"
}

# ── Create Video ──────────────────────────────────────────────────────────────
create_video() {
    local work_dir="$1"
    local output="$2"
    
    log "Building frame sequences..."
    mkdir -p "${work_dir}/frames"
    local i=1
    
    # Add safe frames
    for img in "${work_dir}/safe"/*; do
        ffmpeg -y -i "$img" -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" "${work_dir}/frames/$(printf "%03d.jpg" $i)" 2>/dev/null
        i=$((i+1))
    done
    
    # Add nsfw frames
    for img in "${work_dir}/nsfw"/*; do
        ffmpeg -y -i "$img" -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" "${work_dir}/frames/$(printf "%03d.jpg" $i)" 2>/dev/null
        i=$((i+1))
    done
    
    local total_frames=$((i-1))
    if [[ "$total_frames" -lt 2 ]]; then
        warn "Using synthetic fallback"
        ffmpeg -y -f lavfi -i testsrc=duration=20:size=640x480:rate=30 -c:v libx264 -pix_fmt yuv420p "$output" 2>/dev/null
    else
        log "Stitching $total_frames frames into real-time video..."
        ffmpeg -y -framerate 1 -i "${work_dir}/frames/%03d.jpg" -c:v libx264 -preset fast -vf "fps=30" -pix_fmt yuv420p "$output" 2>/dev/null
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}=== Building Real Test Video ===${NC}"
    check_creds
    setup_env
    local tmp_dir=$(mktemp -d)
    download_datasets "$tmp_dir"
    create_video "$tmp_dir" "$OUTPUT_FILE"
    
    local h264_file="${OUTPUT_FILE%.mp4}.h264"
    ffmpeg -y -i "$OUTPUT_FILE" -vcodec copy -bsf:v h264_mp4toannexb "$h264_file" 2>/dev/null
    
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTPUT_FILE")
    echo -e "${BOLD}${GREEN}=== Test Video Ready ===${NC}"
    echo -e "  Duration: ${duration}s"
    echo -e "  MP4:      ${OUTPUT_FILE}"
    echo -e "  H264:     ${h264_file}"
    rm -rf "$tmp_dir" 2>/dev/null
}

main
