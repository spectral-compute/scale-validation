#!/usr/bin/env python3
"""Generate a combined SCALE text + logo dot starting layout with purple ellipses.

Outputs:
- SVG preview
- PNG preview (if ImageMagick `magick` is available)
- JSON particle/layout data for later conversion into a LAMMPS data file

The white structures are:
  * the word SCALE built from densely packed small white dots
  * the SCALE logo built from densely packed small white dots

The background particles are larger purple ellipses placed without overlap
against the white particles or each other (using a conservative circular
exclusion radius around each ellipse).
"""
from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path
import argparse
import json
import random
import shutil
import subprocess
import tempfile

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("This script requires Pillow: pip install pillow")

# The user supplied the path data directly in chat.
LOGO_PATH = """M1905.9,796.37C1815.65,273.82,1319.26-76.07,796.71,14.18c-1.31,0-2.62,0-4.58.65-266.83,47.09-447.99,302.8-403.52,570.29,3.92,24.85,9.16,49.05,15.04,73.25,19.62,82.4,42.51,144.53,68.02,203.39,1.31,3.27-3.27,5.89-5.23,3.27-149.77-170.04-200.78-355.12-196.85-534.32,0-13.73-16.35-20.27-25.51-10.46C75.35,509.26-17.52,763.67,2.75,1030.5c0,3.92,1.96,7.19,4.58,9.81,115.76,108.56,188.35,262.26,188.35,433.6,0,12.41-.65,25.95-1.32,38.22-1.11,20.55-.39,24.57,8.51,26.53,181.16,33.35,334.2,149.11,417.91,306.73,3.92,7.19,13.73,7.19,17.66,0,65.4-121.64,104.64-259.64,111.83-406.14v-7.85c0-13.08.65-25.51.65-38.59v-18.31c-1.96-85.67-15.04-171.35-39.24-253.75-17.66-60.17-44.47-115.76-59.51-175.27-7.19-26.81-11.77-54.94-11.77-84.37h0c0-117.07,54.94-221.05,139.3-287.76,5.23-4.58,11.12-8.5,17-12.43h0c10.46-7.19,18.31-18.97,21.58-32.7,0-1.96.65-4.58,1.31-6.54,4.58-30.08,7.19-61.48,7.19-92.87s0-19.62-.65-28.78c0-7.19,5.89-12.43,12.43-12.43s4.58,0,6.54,1.96h1.31c41.2,26.16,79.13,57.55,112.49,93.52.65.65,1.31,1.96,1.96,2.62h0c5.23,5.89,12.43,9.16,20.93,9.81h7.85c15.7-2.62,26.81-16.35,26.81-32.7s0-4.58,0-6.54v-1.31c0-.65,0-1.96-.65-2.62-5.23-21.58-11.77-41.86-18.97-62.13,0-1.31-1.31-3.27-1.31-5.23,0-7.19,5.89-12.43,12.43-12.43s4.58.65,6.54,1.96c.65,0,1.31,1.31,1.96,1.96,24.2,18.31,47.09,39.24,68.02,61.48h.65c0,.65,162.85,148.46,162.85,148.46l8.5,7.85,19.62,19.62s21.58,21.58,21.58,22.24l10.46,11.12,9.81,9.81,16.35,16.35c5.23,5.23,9.16,11.12,11.77,17.66,2.62,6.54,3.92,13.73,3.92,20.93s0,7.19-1.31,10.46h0v1.96c0,1.31,0,3.27-.65,4.58-.65,1.31,0,3.27,0,5.23v1.31c0,9.16,1.96,17.66,5.89,24.85,1.31,1.96,1.96,3.92,3.27,5.89,1.31,1.96,3.27,4.58,4.58,7.19,3.27,5.23,7.19,10.46,11.12,15.7,17.66,24.2,37.93,45.78,61.48,64.75,5.23,4.58,11.12,8.5,16.35,13.08,1.96,1.31,3.27,2.62,5.23,3.92,2.62,1.96,4.58,3.27,7.19,5.23,0,0,1.31.65,1.31,1.31,3.27,2.62,4.58,5.89,4.58,9.81s-1.31,6.54-3.92,9.16l-30.74,30.08-17,17-22.24,21.58-2.62,2.62c-3.27,3.27-6.54,5.89-9.81,8.5-10.46,8.5-22.24,15.04-34.66,20.27-16.35,6.54-34.01,10.46-52.97,10.46s-39.89-4.58-57.55-12.43l-8.5-3.27-9.16-3.92-102.68-40.55-2.62-1.31-4.58-1.96-28.78-11.77c-3.92-1.31-7.85-3.27-11.77-5.23-3.92-1.96-7.85-4.58-11.12-7.19-3.92-3.27-7.85-7.19-11.77-11.12-11.12-12.43-18.31-27.47-20.93-45.13v-.65c-.65-5.89-1.31-11.77-.65-17.66v-7.19c-1.31-9.81-9.16-17-18.97-17h-4.58c-5.89.65-11.12,4.58-14.39,9.81h0c-2.62,4.58-5.23,9.81-7.85,14.39-11.12,24.2-15.7,51.01-11.12,79.13,9.81,64.75,67.36,108.56,113.14,149.11,17,15.04,34.66,28.78,52.97,42.51,11.77,8.5,23.54,17,35.32,25.51,182.47,137.99,313.92,340.08,361.66,572.91,1.31,7.19,9.81,10.46,15.7,5.89,270.1-210.59,421.83-562.44,359.05-923.45h0Z"""

# Simple 5x7 glyph masks. These are filled by dense dots rather than outline dots.
BASE_FONT = {
    "S": [
        "11111",
        "10000",
        "10000",
        "11111",
        "00001",
        "00001",
        "11111",
    ],
    "C": [
        "11111",
        "10000",
        "10000",
        "10000",
        "10000",
        "10000",
        "11111",
    ],
    "A": [
        "01110",
        "10001",
        "10001",
        "11111",
        "10001",
        "10001",
        "10001",
    ],
    "L": [
        "10000",
        "10000",
        "10000",
        "10000",
        "10000",
        "10000",
        "11111",
    ],
    "E": [
        "11111",
        "10000",
        "10000",
        "11110",
        "10000",
        "10000",
        "11111",
    ],
}


@dataclass
class Config:
    canvas_width: int = 1600
    canvas_height: int = 900
    box_left: int = 70
    box_top: int = 120
    box_right: int = 1530
    box_bottom: int = 780

    text: str = "SCALE"
    dot_radius: float = 3.0
    cell_pitch: float = 12.0
    letter_gap_cells: float = 1.3

    text_left_x: float = 260.0
    logo_left_x: float = 650.0
    logo_height_multiplier: float = 4.0

    purple_count: int = 85
    purple_major_to_dot_diameter: float = 7.0
    purple_minor_aspect: float = 1.0
    purple_margin: float = 10.0

    background_color: str = "#000000"
    box_stroke_color: str = "#3a3a3a"
    white_color: str = "#ffffff"
    purple_color: str = "#4e2d73"

    random_seed: int = 8


@dataclass
class Circle:
    x: float
    y: float
    r: float


@dataclass
class Ellipse:
    x: float
    y: float
    major: float
    minor: float
    angle_deg: float


def build_text_mask(cfg: Config) -> tuple[Image.Image, dict]:
    glyph_w_cells = 5
    glyph_h_cells = 7
    letter_gap = cfg.letter_gap_cells * cfg.cell_pitch
    text_w = len(cfg.text) * glyph_w_cells * cfg.cell_pitch + (len(cfg.text) - 1) * letter_gap
    text_h = glyph_h_cells * cfg.cell_pitch
    box_cy = (cfg.box_top + cfg.box_bottom) / 2.0
    text_top_y = box_cy - text_h / 2.0

    img = Image.new('L', (cfg.canvas_width, cfg.canvas_height), 0)
    draw = ImageDraw.Draw(img)
    for idx, ch in enumerate(cfg.text):
        glyph = BASE_FONT[ch]
        x0 = cfg.text_left_x + idx * (glyph_w_cells * cfg.cell_pitch + letter_gap)
        for row_idx, row in enumerate(glyph):
            for col_idx, active in enumerate(row):
                if active == '1':
                    left = x0 + col_idx * cfg.cell_pitch
                    top = text_top_y + row_idx * cfg.cell_pitch
                    right = left + cfg.cell_pitch
                    bottom = top + cfg.cell_pitch
                    draw.rectangle([left, top, right, bottom], fill=255)

    meta = {
        'text_width': text_w,
        'text_height': text_h,
        'text_top_y': text_top_y,
        'glyph_width_cells': glyph_w_cells,
        'glyph_height_cells': glyph_h_cells,
    }
    return img, meta


def sample_dense_dots_from_mask(mask: Image.Image, cfg: Config, x_min: float, x_max: float, y_min: float, y_max: float) -> list[Circle]:
    px = mask.load()
    spacing = cfg.dot_radius * 2.15
    dots: list[Circle] = []
    row = 0
    y = y_min + cfg.dot_radius * 1.2
    while y <= y_max - cfg.dot_radius * 1.2:
        x = x_min + cfg.dot_radius * 1.2 + (spacing / 2.0 if row % 2 else 0.0)
        while x <= x_max - cfg.dot_radius * 1.2:
            xi = int(round(x))
            yi = int(round(y))
            if 0 <= xi < mask.width and 0 <= yi < mask.height and px[xi, yi] > 127:
                dots.append(Circle(x=x, y=y, r=cfg.dot_radius))
            x += spacing
        y += spacing * 0.88
        row += 1
    return dots


def build_text_dots(cfg: Config) -> tuple[list[Circle], dict]:
    mask, meta = build_text_mask(cfg)
    x_min = cfg.text_left_x
    x_max = cfg.text_left_x + meta['text_width']
    y_min = meta['text_top_y']
    y_max = meta['text_top_y'] + meta['text_height']
    dots = sample_dense_dots_from_mask(mask, cfg, x_min, x_max, y_min, y_max)
    return dots, meta


def render_logo_mask(cfg: Config, logo_left_x: float, logo_top_y: float, logo_scale: float, temp_dir: Path) -> Path:
    svg_path = temp_dir / 'logo_mask.svg'
    png_path = temp_dir / 'logo_mask.png'
    svg_path.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{cfg.canvas_width}" height="{cfg.canvas_height}" '
        f'viewBox="0 0 {cfg.canvas_width} {cfg.canvas_height}">'
        f'<rect width="100%" height="100%" fill="black"/>'
        f'<g transform="translate({logo_left_x} {logo_top_y}) scale({logo_scale})">'
        f'<path d="{LOGO_PATH}" fill="white"/></g></svg>',
        encoding='utf-8',
    )
    magick = shutil.which('magick')
    if magick is None:
        raise SystemExit('ImageMagick `magick` is required to rasterize the SVG logo path into a mask.')
    subprocess.run([magick, str(svg_path), str(png_path)], check=True)
    return png_path


def build_logo_dots(cfg: Config, text_meta: dict) -> tuple[list[Circle], dict]:
    text_h = text_meta['text_height']
    logo_h = cfg.logo_height_multiplier * text_h
    logo_scale = logo_h / 1905.9
    logo_left_x = cfg.logo_left_x
    logo_top_y = (cfg.box_top + cfg.box_bottom) / 2.0 - logo_h / 2.0

    with tempfile.TemporaryDirectory() as td:
        mask_png = render_logo_mask(cfg, logo_left_x, logo_top_y, logo_scale, Path(td))
        mask = Image.open(mask_png).convert('L')
        logo_w_est = 1905.9 * logo_scale
        dots = sample_dense_dots_from_mask(mask, cfg, logo_left_x, logo_left_x + logo_w_est, logo_top_y, logo_top_y + logo_h)

    meta = {
        'logo_height': logo_h,
        'logo_scale': logo_scale,
        'logo_top_y': logo_top_y,
    }
    return dots, meta


def distance_sq(x1: float, y1: float, x2: float, y2: float) -> float:
    dx = x1 - x2
    dy = y1 - y2
    return dx * dx + dy * dy


def build_purple_ellipses(cfg: Config, white_dots: list[Circle]) -> list[Ellipse]:
    rng = random.Random(cfg.random_seed)
    purple: list[Ellipse] = []
    major = cfg.purple_major_to_dot_diameter * (cfg.dot_radius * 2.0)
    minor = major * cfg.purple_minor_aspect
    ellipse_safe_r = major / 2.0

    obstacles = [(d.x, d.y, d.r + 5.0) for d in white_dots]

    attempts = 0
    max_attempts = 150000
    while len(purple) < cfg.purple_count and attempts < max_attempts:
        attempts += 1
        x = rng.uniform(cfg.box_left + ellipse_safe_r + cfg.purple_margin,
                        cfg.box_right - ellipse_safe_r - cfg.purple_margin)
        y = rng.uniform(cfg.box_top + ellipse_safe_r + cfg.purple_margin,
                        cfg.box_bottom - ellipse_safe_r - cfg.purple_margin)
        angle = rng.uniform(0.0, 180.0)

        ok = True
        for ox, oy, orr in obstacles:
            if distance_sq(x, y, ox, oy) < (ellipse_safe_r + orr) ** 2:
                ok = False
                break
        if not ok:
            continue
        for e in purple:
            if distance_sq(x, y, e.x, e.y) < (ellipse_safe_r + e.major / 2.0 + 8.0) ** 2:
                ok = False
                break
        if not ok:
            continue
        purple.append(Ellipse(x=x, y=y, major=major, minor=minor, angle_deg=angle))
        obstacles.append((x, y, ellipse_safe_r))

    return purple


def write_svg(cfg: Config, white_dots: list[Circle], purple: list[Ellipse], out_svg: Path) -> None:
    lines: list[str] = []
    lines.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{cfg.canvas_width}" height="{cfg.canvas_height}" '
                 f'viewBox="0 0 {cfg.canvas_width} {cfg.canvas_height}">')
    lines.append(f'<rect width="100%" height="100%" fill="{cfg.background_color}"/>')
    lines.append(f'<rect x="{cfg.box_left}" y="{cfg.box_top}" width="{cfg.box_right-cfg.box_left}" '
                 f'height="{cfg.box_bottom-cfg.box_top}" fill="none" stroke="{cfg.box_stroke_color}" stroke-width="2"/>')
    for e in purple:
        lines.append(
            f'<ellipse cx="{e.x:.3f}" cy="{e.y:.3f}" rx="{e.major/2.0:.3f}" ry="{e.minor/2.0:.3f}" '
            f'transform="rotate({e.angle_deg:.3f} {e.x:.3f} {e.y:.3f})" fill="{cfg.purple_color}"/>'
        )
    for d in white_dots:
        lines.append(f'<circle cx="{d.x:.3f}" cy="{d.y:.3f}" r="{d.r:.3f}" fill="{cfg.white_color}"/>')
    lines.append('</svg>')
    out_svg.write_text('\n'.join(lines), encoding='utf-8')


def maybe_render_png(out_svg: Path, out_png: Path) -> bool:
    magick = shutil.which('magick')
    if magick is None:
        return False
    subprocess.run([magick, str(out_svg), str(out_png)], check=True)
    return True


def write_json(cfg: Config, text_meta: dict, logo_meta: dict, white_dots: list[Circle], purple: list[Ellipse], out_json: Path) -> None:
    payload = {
        'config': asdict(cfg),
        'text_meta': text_meta,
        'logo_meta': logo_meta,
        'white_dots': [asdict(d) for d in white_dots],
        'purple_ellipses': [asdict(e) for e in purple],
    }
    out_json.write_text(json.dumps(payload, indent=2), encoding='utf-8')


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--outdir', default='output', help='Output directory')
    p.add_argument('--text-left-x', type=float, default=None, help='Left x position of the text block')
    p.add_argument('--logo-left-x', type=float, default=None, help='Left x position of the logo block')
    p.add_argument('--font-size', type=float, default=None, help='Cell pitch in px; larger means a bigger dot-font')
    p.add_argument('--logo-scale-multiplier', type=float, default=None, help='Logo height multiplier relative to text height')
    p.add_argument('--purple-count', type=int, default=None, help='Number of purple ellipses')
    p.add_argument('--seed', type=int, default=None, help='Random seed for purple ellipse placement')
    return p.parse_args()


def main() -> int:
    args = parse_args()
    cfg = Config()
    if args.text_left_x is not None:
        cfg.text_left_x = args.text_left_x
    if args.logo_left_x is not None:
        cfg.logo_left_x = args.logo_left_x
    if args.font_size is not None:
        cfg.cell_pitch = args.font_size
    if args.logo_scale_multiplier is not None:
        cfg.logo_height_multiplier = args.logo_scale_multiplier
    if args.purple_count is not None:
        cfg.purple_count = args.purple_count
    if args.seed is not None:
        cfg.random_seed = args.seed

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    svg_path = outdir / 'combined_preview.svg'
    png_path = outdir / 'combined_preview.png'
    json_path = outdir / 'layout_particles.json'

    text_dots, text_meta = build_text_dots(cfg)
    logo_dots, logo_meta = build_logo_dots(cfg, text_meta)
    white_dots = text_dots + logo_dots
    purple = build_purple_ellipses(cfg, white_dots)

    write_svg(cfg, white_dots, purple, svg_path)
    rendered_png = maybe_render_png(svg_path, png_path)
    write_json(cfg, text_meta, logo_meta, white_dots, purple, json_path)

    print(f'Wrote {svg_path}')
    if rendered_png:
        print(f'Wrote {png_path}')
    else:
        print('PNG not rendered because ImageMagick `magick` was not found. SVG was still written.')
    print(f'Wrote {json_path}')
    print(f'white_dots={len(white_dots)} purple_ellipses={len(purple)}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
