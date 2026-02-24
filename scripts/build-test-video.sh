#!/bin/bash
# build-test-video.sh
# Generates a test video by downloading real datasets from Hugging Face & Kaggle
#
# Usage:
#   HF_TOKEN=xxx KAGGLE_USER=xxx KAGGLE_KEY=xxx ./build-test-video.sh
#
# Required environment variables:
#   HF_TOKEN     - Hugging Face API token
#   KAGGLE_USER  - Kaggle username
#   KAGGLE_KEY   - Kaggle API key
#
# This script creates:
#   1. A "safe" video segment (from Avengers Kaggle dataset)
#   2. An NSFW video segment (from Hugging Face NSFW dataset)
#   3. Stitches them together into test_video.mp4 and converts to .h264

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

# ── Defaults ──────────────────────────────────────────────────────────────────
OUTPUT_FILE="test_video.mp4"
FPS=1
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
    if [[ -z "${HF_TOKEN:-}" ]]; then
        error "HF_TOKEN environment variable not set"
        exit 1
    fi
    if [[ -z "${KAGGLE_USER:-}" || -z "${KAGGLE_KEY:-}" ]]; then
        error "KAGGLE_USER and KAGGLE_KEY environment variables not set"
        exit 1
    fi
}

# ── Setup Environment ─────────────────────────────────────────────────────────
setup_env() {
    # Source venv if available (for kaggle/hf CLIs)
    if [[ -f "/root/oboon-mvp/venv/bin/activate" ]]; then
        source /root/oboon-mvp/venv/bin/activate
    elif [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
    fi
    
    log "Installing dataset download tools..."
    pip install -q huggingface_hub kaggle 2>/dev/null || true
    
    # Configure Kaggle
    mkdir -p ~/.kaggle
    cat > ~/.kaggle/kaggle.json <<EOF
{"username":"${KAGGLE_USER}","key":"${KAGGLE_KEY}"}
EOF
    chmod 600 ~/.kaggle/kaggle.json
    success "Kaggle configured"
}

# ── Download Datasets ─────────────────────────────────────────────────────────
download_datasets() {
    local work_dir="$1"
    
    log "Downloading Avengers dataset from Kaggle (yasserh/avengers-faces-dataset)..."
    mkdir -p "${work_dir}/avengers"
    cd "${work_dir}/avengers"
    kaggle datasets download -d yasserh/avengers-faces-dataset --unzip > /dev/null 2>&1 || {
        warn "Kaggle download failed, using synthetic content"
        return 1
    }
    cd - >/dev/null
    success "Avengers dataset downloaded"
    
    log "Downloading NSFW dataset from Hugging Face (x1101/nsfw-full)..."
    mkdir -p "${work_dir}/nsfw"
    HF_TOKEN="${HF_TOKEN}" hf download x1101/nsfw-full \
        --repo-type dataset \
        --local-dir "${work_dir}/nsfw" > /dev/null 2>&1 || {
        warn "HF download failed, using synthetic content"
        return 1
    }
    
    # Unzip HF dataset if needed
    if ls "${work_dir}/nsfw"/*.zip 1> /dev/null 2>&1; then
        unzip -q "${work_dir}/nsfw"/*.zip -d "${work_dir}/nsfw_extracted" 2>/dev/null || true
    else
        mkdir -p "${work_dir}/nsfw_extracted"
        cp -r "${work_dir}/nsfw"/* "${work_dir}/nsfw_extracted/" 2>/dev/null || true
    fi
    success "NSFW dataset downloaded"
}

# ── Create Video from Images ──────────────────────────────────────────────────
create_segment() {
    local source_dir="$1"
    local output="$2"
    local label="$3"
    
    log "Creating ${label} video segment from ${source_dir}..."
    
    # Create temp dir for scaled images
    local tmp_frames="${source_dir}/frames"
    mkdir -p "$tmp_frames"
    
    # Find all images, take random ones, resize/pad to exactly 640x480
    local img_count
    img_count=$(find "$source_dir" -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg \) 2>/dev/null | wc -l)
    
    if [[ "$img_count" -lt 3 ]]; then
        warn "Not enough images in $source_dir, generating synthetic segment"
        ffmpeg -y -f lavfi -i "color=c=${label}:duration=${IMAGE_COUNT}:size=${WIDTH}x${HEIGHT}:rate=${FPS}" \
            -vf "drawtext=text='${label}':fontsize=48:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" \
            -c:v libx264 -preset fast -pix_fmt yuv420p "$output" 2>/dev/null
        return
    fi
    
    find "$source_dir" -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg \) 2>/dev/null | \
        shuf | head -n "$IMAGE_COUNT" > /tmp/img_list.txt
    
    local i=1
    while read -r img; do
        local out_frame=$(printf "%s/%03d.jpg" "$tmp_frames" "$i")
        ffmpeg -y -i "$img" -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" "$out_frame" 2>/dev/null || true
        i=$((i + 1))
    done < /tmp/img_list.txt
    
    # Create video from sequential images
    ffmpeg -y -framerate $FPS -i "$tmp_frames/%03d.jpg" -c:v libx264 -preset fast -pix_fmt yuv420p "$output" 2>/dev/null
    
    success "Segment created: $output ($(ls "$tmp_frames" | wc -l) frames)"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}=== Building Real Test Video ===${NC}"
    echo ""
    
    check_creds
    setup_env
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    download_datasets "$tmp_dir" || true
    
    local safe_seg="${tmp_dir}/safe.mp4"
    local nsfw_seg="${tmp_dir}/nsfw.mp4"
    
    # Create safe segment (Avengers)
    create_segment "${tmp_dir}/avengers" "$safe_seg" "SAFE"
    
    # Create NSFW segment
    create_segment "${tmp_dir}/nsfw_extracted" "$nsfw_seg" "NSFW"
    
    log "Stitching segments together..."
    cat > /tmp/concat_list.txt <<EOF
file '$safe_seg'
file '$nsfw_seg'
EOF
    
    ffmpeg -y -f concat -safe 0 -i /tmp/concat_list.txt -c copy "$OUTPUT_FILE" 2>/dev/null
    
    log "Converting to H264 bitstream for LiveKit CLI..."
    local h264_file="${OUTPUT_FILE%.mp4}.h264"
    ffmpeg -y -i "$OUTPUT_FILE" -vcodec copy -bsf:v h264_mp4toannexb "$h264_file" 2>/dev/null
    
    # Clean up
    rm -rf "$tmp_dir" /tmp/concat_list.txt /tmp/img_list.txt 2>/dev/null || true
    
    echo ""
    echo -e "${BOLD}${GREEN}=== Test Video Ready ===${NC}"
    echo -e "  MP4:  ${OUTPUT_FILE}"
    echo -e "  H264: ${h264_file}"
}

main
