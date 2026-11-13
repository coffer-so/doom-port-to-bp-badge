#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["cairosvg>=2.8,<3", "Pillow>=12,<13"]
# ///
# SPDX-License-Identifier: GPL-2.0-or-later
"""Compile editable coin SVGs into the Lua sprite module. Requires system Cairo."""
import argparse
import io
import json
from pathlib import Path

import cairosvg
from PIL import Image


def compile_coins(root, output):
    entries = []
    symbols = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    for name in ('solana_coin', 'coffer_coin'):
        source = (root / 'assets' / (name + '.svg')).read_bytes()
        png = cairosvg.svg2png(bytestring=source, output_width=24, output_height=24)
        image = Image.open(io.BytesIO(png)).convert('RGBA')
        indexed = image.convert('RGB').quantize(colors=30)
        colors = indexed.getpalette()
        rows, palette = [], {}
        for y in range(24):
            row = ''
            for x in range(24):
                if image.getpixel((x, y))[3] < 128:
                    row += '.'
                    continue
                index = indexed.getpixel((x, y))
                symbol = symbols[index]
                row += symbol
                r, g, b = colors[index * 3:index * 3 + 3]
                palette[symbol] = (r << 16) | (g << 8) | b
            rows.append(row)
        entries.append(name + '={rows={' + ','.join(json.dumps(row) for row in rows)
                       + '},palette={' + ','.join('[' + json.dumps(k) + ']=' + str(v)
                                                 for k, v in palette.items()) + '}}')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('-- SPDX-License-Identifier: GPL-2.0-or-later\n'
                      '-- Generated from project SVG brand coin artwork.\n'
                      'return {' + ','.join(entries) + '}\n')
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    compile_coins(args.root, args.out or args.root / 'app/coins.lua')
