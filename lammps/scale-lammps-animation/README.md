# Combined SCALE Text + Logo Layout Generator

This directory contains Python scripts that generate the combined initial-state layout and convert it into a LAMMPS data file.

## Configurable parameters

The layout generator exposes these controls:

- **Font size**: `--font-size`
- **Logo scale multiplier** relative to text height: `--logo-scale-multiplier`
- **Horizontal text position**: `--text-left-x`
- **Horizontal logo position**: `--logo-left-x`
- **Number of purple ellipses**: `--purple-count`

Both the text and the logo remain **vertically centred in the box**.

## Usage

Generate a preview/layout JSON:
```bash
python3 generate_combined_layout.py --outdir output
```

Example with custom settings:
```bash
python3 generate_combined_layout.py     --outdir output     --font-size 24     --logo-scale-multiplier 2.0     --text-left-x 230     --logo-left-x 1050     --purple-count 100
```

## Then convert the JSON into a LAMMPS data file

All particles are written as finite-size ellipsoids:
- white dots become spherical ellipsoids
- purple particles become rotated ellipsoids

Example:

```bash
python3 generate_lammps_data_from_json.py     --input-json output/layout_particles.json     --output-data output/data.combined     --units-per-pixel 0.1
```

Useful options:
- `--units-per-pixel` — convert preview pixels into LAMMPS distance units
- `--white-density` — per-atom density for white dots
- `--purple-density` — per-atom density for purple ellipses
- `--no-flip-y` — keep SVG-style y direction instead of flipping into Cartesian orientation
- `--pad-box` — add margin around the generated box

## Dependencies

- Python 3
- Pillow
- optionally ImageMagick (`magick`) for automatic PNG rendering; otherwise the SVG is still produced

## Output directories included

- `output/` — default example output

## Caching (`run_animation.sh`)

`run_animation.sh` treats `output/layout_particles.json`, `output/data.combined`and `output/pair_params.env` as a cache, not per-run scratch: if they already exist it skips straight to the LAMMPS + ffmpeg steps and needs neither Python nor Pillow/ImageMagick. Delete one to force it to regenerate after changing a layout or conversion parameter. Caching done so it can be run with no Python dependency.