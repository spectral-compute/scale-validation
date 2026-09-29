#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

PYTHON_BIN=${PYTHON_BIN:-python3}
LAMMPS_BIN=${LAMMPS_BIN:-lmp}
FFMPEG_BIN=${FFMPEG_BIN:-ffmpeg}

OUT_ROOT=${OUT_ROOT:-"$SCRIPT_DIR/runs"}
RUN_NAME=${RUN_NAME:-"run_$(date +%Y%m%d_%H%M%S)"}
RUN_DIR="$OUT_ROOT/$RUN_NAME"
FRAMES_DIR="$RUN_DIR/frames"

# tidy up old stuff
rm -rf "$FRAMES_DIR"
mkdir -p "$FRAMES_DIR"

# Layout-generation parameters
FONT_SIZE=${FONT_SIZE:-24}
TEXT_LEFT_X=${TEXT_LEFT_X:-230}
LOGO_LEFT_X=${LOGO_LEFT_X:-1050}
LOGO_SCALE_MULTIPLIER=${LOGO_SCALE_MULTIPLIER:-2}
PURPLE_COUNT=${PURPLE_COUNT:-133}
LAYOUT_SEED=${LAYOUT_SEED:-8}

# JSON -> LAMMPS conversion parameters
UNITS_PER_PIXEL=${UNITS_PER_PIXEL:-0.1}
WHITE_DENSITY=${WHITE_DENSITY:-0.5}
PURPLE_DENSITY=${PURPLE_DENSITY:-0.01}
PAD_BOX=${PAD_BOX:-0.0}

# Simulation / rendering parameters
NSTEPS=${NSTEPS:-12000}
DUMP_EVERY=${DUMP_EVERY:-20}
TIMESTEP=${TIMESTEP:-0.002}
TEMPERATURE=${TEMPERATURE:-0.70}
VELOCITY_SEED=${VELOCITY_SEED:-492845}
IMG_WIDTH=${IMG_WIDTH:-1920}
IMG_HEIGHT=${IMG_HEIGHT:-1080}
ZOOM=${ZOOM:-3.4}
FRAMERATE=${FRAMERATE:-30}
VIDEO_NAME=${VIDEO_NAME:-combined_scale.mp4}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}


# The layout JSON, LAMMPS data file and derived pair-style parameters are
# cached under CACHE_DIR because generating them needs Python plus Pillow and ImageMagick
# Which there is no other reason to install. Delete cache file to force it to regenerate
CACHE_DIR="$SCRIPT_DIR/output"
LAYOUT_JSON="$CACHE_DIR/layout_particles.json"
DATA_FILE="$CACHE_DIR/data.combined"
PAIR_PARAMS_CACHE="$CACHE_DIR/pair_params.env"
mkdir -p "$CACHE_DIR"

PREVIEW_SVG="$CACHE_DIR/combined_preview.svg"
PREVIEW_PNG="$CACHE_DIR/combined_preview.png"
LOG_FILE="$RUN_DIR/lammps.log"
MOVIE_FILE="$RUN_DIR/$VIDEO_NAME"

printf 'Run directory: %s\n' "$RUN_DIR"

# generate the layout JSON + preview, unless already cached
if [ ! -f "$LAYOUT_JSON" ]; then
  require_cmd "$PYTHON_BIN"
  "$PYTHON_BIN" "$SCRIPT_DIR/generate_combined_layout.py" \
    --outdir "$CACHE_DIR" \
    --font-size "$FONT_SIZE" \
    --logo-scale-multiplier "$LOGO_SCALE_MULTIPLIER" \
    --text-left-x "$TEXT_LEFT_X" \
    --logo-left-x "$LOGO_LEFT_X" \
    --purple-count "$PURPLE_COUNT" \
    --seed "$LAYOUT_SEED"
else
  printf 'Reusing cached layout: %s\n' "$LAYOUT_JSON"
fi

# convert JSON -> LAMMPS data file, unless already cached
if [ ! -f "$DATA_FILE" ]; then
  require_cmd "$PYTHON_BIN"
  "$PYTHON_BIN" "$SCRIPT_DIR/generate_lammps_data_from_json.py" \
    --input-json "$LAYOUT_JSON" \
    --output-data "$DATA_FILE" \
    --units-per-pixel "$UNITS_PER_PIXEL" \
    --white-density "$WHITE_DENSITY" \
    --purple-density "$PURPLE_DENSITY" \
    --pad-box "$PAD_BOX"
else
  printf 'Reusing cached LAMMPS data file: %s\n' "$DATA_FILE"
fi

# derive pair-style parameters from the generated json
if [ ! -f "$PAIR_PARAMS_CACHE" ]; then
  require_cmd "$PYTHON_BIN"
  "$PYTHON_BIN" - "$LAYOUT_JSON" "$UNITS_PER_PIXEL" "$PAIR_PARAMS_CACHE" <<'PY'
import json, math, sys
path, units_per_pixel, out_path = sys.argv[1], float(sys.argv[2]), sys.argv[3]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
white = data['white_dots']
purple = data['purple_ellipses']
if not white or not purple:
    raise SystemExit('layout JSON must contain at least one white dot and one purple ellipse')
white_diam = 2.0 * white[0]['r'] * units_per_pixel
purple_major = purple[0]['major'] * units_per_pixel
purple_minor = purple[0]['minor'] * units_per_pixel
sigma11 = white_diam
sigma22 = purple_minor
sigma12 = math.sqrt(sigma11 * sigma22)
cut11 = 2.5 * sigma11
cut22 = 1.35 * purple_major
cut12 = 0.5 * (cut11 + cut22)
gbcut = max(cut11, cut22, cut12)
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(f"SIGMA11={sigma11:.8f}\nSIGMA22={sigma22:.8f}\nSIGMA12={sigma12:.8f}\n")
    f.write(f"CUT11={cut11:.8f}\nCUT22={cut22:.8f}\nCUT12={cut12:.8f}\nGBCUTOFF={gbcut:.8f}\n")
PY
else
  printf 'Reusing cached pair-style parameters: %s\n' "$PAIR_PARAMS_CACHE"
fi
# shellcheck source=/dev/null
source "$PAIR_PARAMS_CACHE"

# Interaction strengths. Keeping them near 1.0 makes the run visually active
# without hard-coding shape-dependent values into the LAMMPS input.
EPS11=${EPS11:-1.00}
EPS22=${EPS22:-0.90}
EPS12=${EPS12:-0.95}

# run the simulation. "$@" lets a caller pass acceleration flags through (e.g. "-sf gpu -pk gpu 1")
require_cmd "$LAMMPS_BIN"
"$LAMMPS_BIN" "$@" \
  -log "$LOG_FILE" \
  -in "$SCRIPT_DIR/in.combined" \
  -var data_file "$DATA_FILE" \
  -var frame_dir "$FRAMES_DIR" \
  -var nsteps "$NSTEPS" \
  -var dump_every "$DUMP_EVERY" \
  -var timestep "$TIMESTEP" \
  -var temp "$TEMPERATURE" \
  -var velocity_seed "$VELOCITY_SEED" \
  -var img_width "$IMG_WIDTH" \
  -var img_height "$IMG_HEIGHT" \
  -var zoom "$ZOOM" \
  -var gb_cutoff "$GBCUTOFF" \
  -var sigma11 "$SIGMA11" \
  -var sigma22 "$SIGMA22" \
  -var sigma12 "$SIGMA12" \
  -var cut11 "$CUT11" \
  -var cut22 "$CUT22" \
  -var cut12 "$CUT12" \
  -var eps11 "$EPS11" \
  -var eps22 "$EPS22" \
  -var eps12 "$EPS12"

# Build mp4 from the rendered frames
require_cmd "$FFMPEG_BIN"
"$FFMPEG_BIN" -y \
  -framerate "$FRAMERATE" \
  -pattern_type glob -i "$FRAMES_DIR/frame.*.png" \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
  "$MOVIE_FILE"

cat <<EOF_SUMMARY

Completed successfully.

Preview files:
  $PREVIEW_SVG
  $PREVIEW_PNG

Simulation outputs:
  $DATA_FILE
  $LOG_FILE
  $FRAMES_DIR/
  $MOVIE_FILE
EOF_SUMMARY
