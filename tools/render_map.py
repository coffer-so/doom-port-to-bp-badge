#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["Pillow==13.0.0"]
# ///
# SPDX-License-Identifier: GPL-2.0-or-later
"""Render the actual Lua level and its initial entities as a deterministic PNG."""
import argparse
import math
from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
EXPORT = r'''
local s=dofile(arg[1]).new()
io.write('SIZE\t',s.width,'\t',s.height,'\n')
for _,row in ipairs(s.map) do io.write('ROW\t',row,'\n') end
local function point(kind,x,y,angle)
  io.write(string.format('%s\t%.9g\t%.9g\t%.9g\n',kind,x,y,angle or 0))
end
point('spawn',s.x,s.y,s.angle)
point('chest',s.chest.x,s.chest.y)
for _,p in ipairs(s.pickups) do point(p.kind,p.x,p.y) end
for _,e in ipairs(s.enemies) do point('enemy',e.x,e.y) end
for _,d in ipairs(s.doors) do point('door',d.x+0.5,d.y+0.5) end
'''
COLORS = {'spawn': '#52a7e8', 'chest': '#edbc52', 'solana_coin': '#41d8c2',
          'coffer_coin': '#bca0f4', 'enemy': '#d6544c', 'door': '#ed8b3c'}
SYMBOLS = {'chest': 'H', 'solana_coin': '1', 'coffer_coin': '2', 'enemy': 'Z', 'door': 'D'}
TILES = {'0': '#ded7c0', '1': '#3b484a', '2': '#53624f', '3': '#ed8b3c'}


def load_level(lua, app):
    result = subprocess.run([lua, '-', str((app / 'game.lua').resolve())],
                            input=EXPORT, text=True, capture_output=True, timeout=15, check=True)
    rows, points = [], []
    width = height = 0
    for line in result.stdout.splitlines():
        parts = line.split('\t')
        if parts[0] == 'SIZE':
            width, height = map(int, parts[1:])
        elif parts[0] == 'ROW':
            rows.append(parts[1])
        elif parts[0] in COLORS:
            x, y, angle = map(float, parts[1:])
            points.append((parts[0], x, y, angle))
        else:
            raise ValueError('Unexpected Lua map export record')
    if not (1 <= width <= 256 and 1 <= height <= 256 and len(rows) == height
            and all(len(row) == width and set(row) <= TILES.keys() for row in rows)):
        raise ValueError('Invalid exported map dimensions or tiles')
    if any(not (0 <= x < width and 0 <= y < height and math.isfinite(angle))
           for _, x, y, angle in points):
        raise ValueError('Entity outside the exported map')
    return width, height, rows, points


def render_map(level, output):
    width, height, rows, points = level
    cell, margin, top = 22, 32, 94
    image_width = max(720, width * cell) + 2 * margin
    left = (image_width - width * cell) // 2
    legend_y = top + height * cell + 30
    image = Image.new('RGB', (image_width, legend_y + 132), '#171d1f')
    draw = ImageDraw.Draw(image)
    title = ImageFont.load_default(size=28)
    font = ImageFont.load_default(size=17)
    small = ImageFont.load_default(size=11)
    draw.text((margin, 18), 'DOOM - level map', font=title, fill='#f5ead0')
    zombies = sum(kind == 'enemy' for kind, *_ in points)
    draw.text((margin, 56), f'{width} x {height} cells | {zombies} zombies | 2 coins | North = up',
              font=font, fill='#b8c2bc')
    for y, row in enumerate(rows):
        for x, tile in enumerate(row):
            a, b = left + x * cell, top + y * cell
            draw.rectangle((a, b, a + cell - 1, b + cell - 1), fill=TILES[tile], outline='#65716a')
    for x in range(0, width, 5):
        draw.text((left + x * cell + cell // 2, top - 12), str(x), anchor='mm', font=small, fill='#b8c2bc')
    for y in range(0, height, 5):
        draw.text((left - 12, top + y * cell + cell // 2), str(y), anchor='mm', font=small, fill='#b8c2bc')

    def marker(kind, x, y, angle=0):
        radius = 8
        color = COLORS[kind]
        if kind == 'spawn':
            vertices = [(x + math.cos(angle + offset) * radius,
                         y + math.sin(angle + offset) * radius) for offset in (0, 2.4, -2.4)]
            draw.polygon(vertices, fill=color, outline='#ffffff')
        else:
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color, outline='#ffffff')
            draw.text((x, y), SYMBOLS[kind], anchor='mm', font=small, fill='#171d1f')

    # Draw the full initial state, including both closed shortcut doors.
    for kind, x, y, angle in points:
        marker(kind, left + x * cell, top + y * cell, angle)
    legend = [('spawn', 'Spawn / facing direction'), ('chest', 'Return chest'),
              ('solana_coin', 'Solana coin'), ('coffer_coin', 'Coffer coin'),
              ('enemy', f'Zombie ({zombies})'), ('door', 'Door'),
              ('floor', 'Walkable floor'), ('wall', 'Wall')]
    for i, (kind, text) in enumerate(legend):
        x = margin + (i % 2) * ((image_width - 2 * margin) // 2)
        y = legend_y + (i // 2) * 28
        if kind in COLORS:
            marker(kind, x + 8, y + 10)
        else:
            draw.rectangle((x, y + 2, x + 16, y + 18),
                           fill=TILES['0' if kind == 'floor' else '1'], outline='#b8c2bc')
        draw.text((x + 28, y), text, font=font, fill='#f5ead0')
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output, format='PNG', optimize=False, compress_level=9)
    print(f'{output}: {width}x{height} level, {len(points)} entity markers')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default='lua5.5', help='Lua CLI matching the application')
    parser.add_argument('--app', type=Path, default=ROOT / 'app' if (ROOT / 'app').is_dir() else ROOT)
    parser.add_argument('--out', type=Path, default=ROOT / 'docs' / 'images' / 'map.png')
    args = parser.parse_args()
    render_map(load_level(args.lua, args.app), args.out)
