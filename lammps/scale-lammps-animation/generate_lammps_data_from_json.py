#!/usr/bin/env python3
"""Convert the combined layout JSON into a LAMMPS data file.

This script reads the layout JSON produced by generate_combined_layout.py and
writes a LAMMPS `data.*` file suitable for `atom_style ellipsoid`.

Conventions used:
- Type 1 = white text/logo dots
- Type 2 = purple background ellipses
- All particles are written as finite-size ellipsoids.
  * White dots are represented as spheres (equal x/y/z diameters)
  * Purple particles are represented as ellipsoids with their in-plane angle
    converted to a quaternion representing a rotation about the z axis.
  * ellipses don't render :( But maybe they will in next version! no harm in leaving it
- Coordinates are converted from preview pixels to LAMMPS distance units via a
  configurable scale factor.
- By default the preview's screen-space y axis is flipped so the LAMMPS system
  renders with the same visual orientation in a Cartesian frame.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

DEFAULT_UNITS_PER_PIXEL = 0.1
DEFAULT_ZLO = -0.5
DEFAULT_ZHI = 0.5
DEFAULT_WHITE_DENSITY = 1.0
DEFAULT_PURPLE_DENSITY = 1.0


def q_from_z_rotation(theta_deg: float) -> tuple[float, float, float, float]:
    half = math.radians(theta_deg) / 2.0
    return (math.cos(half), 0.0, 0.0, math.sin(half))


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input-json', required=True, help='Path to layout_particles.json')
    p.add_argument('--output-data', required=True, help='Path to output LAMMPS data file')
    p.add_argument('--units-per-pixel', type=float, default=DEFAULT_UNITS_PER_PIXEL,
                   help='LAMMPS distance units per preview pixel (default: %(default)s)')
    p.add_argument('--zlo', type=float, default=DEFAULT_ZLO, help='z lower bound for 2D box')
    p.add_argument('--zhi', type=float, default=DEFAULT_ZHI, help='z upper bound for 2D box')
    p.add_argument('--white-density', type=float, default=DEFAULT_WHITE_DENSITY,
                   help='Density used for white dot particles')
    p.add_argument('--purple-density', type=float, default=DEFAULT_PURPLE_DENSITY,
                   help='Density used for purple ellipse particles')
    p.add_argument('--no-flip-y', action='store_true',
                   help='Do not flip the preview y-axis into Cartesian orientation')
    p.add_argument('--pad-box', type=float, default=0.0,
                   help='Extra padding (LAMMPS units) added around the scaled x/y box bounds')
    return p.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def main() -> int:
    args = parse_args()
    data = load_json(Path(args.input_json))
    cfg = data['config']
    white_dots = data['white_dots']
    purple = data['purple_ellipses']

    units = args.units_per_pixel
    flip_y = not args.no_flip_y

    box_left_px = cfg['box_left']
    box_right_px = cfg['box_right']
    box_top_px = cfg['box_top']
    box_bottom_px = cfg['box_bottom']

    # Put the lower-left of the LAMMPS box at (0,0) after scaling.
    xlo = 0.0 - args.pad_box
    xhi = (box_right_px - box_left_px) * units + args.pad_box
    ylo = 0.0 - args.pad_box
    yhi = (box_bottom_px - box_top_px) * units + args.pad_box

    atoms = []
    ellipsoids = []

    def transform_xy(x_px: float, y_px: float) -> tuple[float, float]:
        x = (x_px - box_left_px) * units
        if flip_y:
            y = (box_bottom_px - y_px) * units
        else:
            y = (y_px - box_top_px) * units
        return x, y

    atom_id = 1

    # White particles become type 1 spherical ellipsoids.
    for d in white_dots:
        x, y = transform_xy(d['x'], d['y'])
        diameter = 2.0 * d['r'] * units
        atoms.append((atom_id, 1, 1, args.white_density, x, y, 0.0))
        ellipsoids.append((atom_id, diameter, diameter, diameter, 1.0, 0.0, 0.0, 0.0))
        atom_id += 1

    # Purple particles become type 2 ellipsoids.
    for e in purple:
        x, y = transform_xy(e['x'], e['y'])
        major = e['major'] * units
        minor = e['minor'] * units
        quatw, quati, quatj, quatk = q_from_z_rotation(e['angle_deg'])
        atoms.append((atom_id, 2, 1, args.purple_density, x, y, 0.0))
        ellipsoids.append((atom_id, major, minor, minor, quatw, quati, quatj, quatk))
        atom_id += 1

    natoms = len(atoms)
    nellipsoids = len(ellipsoids)

    out_path = Path(args.output_data)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open('w', encoding='utf-8') as f:
        f.write('Combined SCALE text+logo layout generated from JSON\n\n')
        f.write(f'{natoms} atoms\n')
        f.write(f'{nellipsoids} ellipsoids\n')
        f.write('2 atom types\n\n')
        f.write(f'{xlo:.8f} {xhi:.8f} xlo xhi\n')
        f.write(f'{ylo:.8f} {yhi:.8f} ylo yhi\n')
        f.write(f'{args.zlo:.8f} {args.zhi:.8f} zlo zhi\n\n')

        # No Masses section: atom_style ellipsoid rejects one outright
        # ("Cannot set mass for atom style ellipsoid") -- mass comes from
        # each atom's density x ellipsoid volume instead, both already
        # written below.
        f.write('Atoms # ellipsoid\n\n')
        for rec in atoms:
            atom_id, atom_type, ellipsoidflag, density, x, y, z = rec
            f.write(f'{atom_id} {atom_type} {ellipsoidflag} {density:.8f} {x:.8f} {y:.8f} {z:.8f}\n')
        f.write('\n')

        f.write('Ellipsoids\n\n')
        for rec in ellipsoids:
            atom_id, sx, sy, sz, qw, qi, qj, qk = rec
            f.write(f'{atom_id} {sx:.8f} {sy:.8f} {sz:.8f} {qw:.10f} {qi:.10f} {qj:.10f} {qk:.10f}\n')

    print(f'Wrote {out_path}')
    print(f'atoms={natoms} ellipsoids={nellipsoids}')
    print('Suggested LAMMPS settings: atom_style ellipsoid ; dimension 2')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
