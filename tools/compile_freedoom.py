#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Offline deterministic Freedoom -> badge artwork. Requires Pillow==13.0.0."""
import argparse
from collections import Counter
import hashlib
from io import BytesIO
import itertools
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'app' if (ROOT / 'app').is_dir() else ROOT
ASSETS = ROOT / 'assets' / 'freedoom'
COMMIT = '21d783c481af9233fa72305b40eb247fa966b49a'
SYMBOLS = 'abcdefghijklmnopqrstuvwxyz0123456789'
SHADE = (256, 220, 188, 156, 124)
MAX_COLUMN_RUNS = 3
MAX_MATERIAL_RUNS = 36


def source_files():
    manifest = json.loads((ASSETS / 'SOURCES.json').read_text())
    assert manifest['commit'] == COMMIT and manifest['license'] == 'BSD-3-Clause'
    out = {}
    for entry in manifest['files']:
        data = (ASSETS / entry['local_path']).read_bytes()
        assert len(data) == entry['size'], entry['upstream_path']
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['upstream_path']
        blob = b'blob ' + str(len(data)).encode() + b'\0' + data
        assert hashlib.sha1(blob).hexdigest() == entry['git_sha'], entry['upstream_path']
        out[entry['upstream_path']] = data
    return out


def load_image(files, name):
    return Image.open(BytesIO(files[name])).convert('RGBA')


def sprite(files, name, size):
    image = load_image(files, name)
    image = image.crop(image.getbbox())
    w, h = size
    scale = min(w / image.width, h / image.height)
    fitted = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))),
                          Image.Resampling.NEAREST)
    result = Image.new('RGBA', size)
    result.alpha_composite(fitted, ((w - fitted.width) // 2, h - fitted.height))
    return result


def palette_for(images, count):
    """Weighted median cut with explicit tie breaking; no randomized quantizer."""
    hist = Counter(tuple(pixel[:3]) for image in images for pixel in image.get_flattened_data() if pixel[3] >= 128)
    boxes = [sorted(hist)]
    while len(boxes) < count:
        choices = []
        for i, box in enumerate(boxes):
            if len(box) < 2:
                continue
            ranges = [max(c[k] for c in box) - min(c[k] for c in box) for k in range(3)]
            channel = max(range(3), key=lambda k: (ranges[k], -k))
            choices.append((ranges[channel], sum(hist[c] for c in box), -i, channel))
        if not choices:
            break
        _, _, neg_index, channel = max(choices)
        index = -neg_index
        box = sorted(boxes[index], key=lambda c: (c[channel], c))
        half = (sum(hist[c] for c in box) + 1) // 2
        acc, split = 0, 1
        for j, color in enumerate(box[:-1], 1):
            acc += hist[color]
            split = j
            if acc >= half:
                break
        boxes[index:index + 1] = [box[:split], box[split:]]
    palette = []
    for box in boxes:
        weight = sum(hist[c] for c in box)
        palette.append(tuple((sum(c[k] * hist[c] for c in box) + weight // 2) // weight for k in range(3)))
    return sorted(set(palette), key=lambda c: (c[0] * 3 + c[1] * 6 + c[2], c))


def distance(a, b):
    return sum((a[k] - b[k]) ** 2 for k in range(3))


def closest(color, palette):
    return min(range(len(palette)), key=lambda i: (distance(color, palette[i]), i))


def indexed_sprite(image, palette):
    rows = []
    output = Image.new('RGBA', image.size)
    for y in range(image.height):
        row = ''
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if pixel[3] < 128:
                row += '.'
            else:
                index = closest(pixel[:3], palette)
                row += SYMBOLS[index]
                output.putpixel((x, y), (*palette[index], 255))
        rows.append(row)
    return rows, output


def texture(files, patches):
    image = Image.new('RGBA', (128, 128), (20, 21, 22, 255))
    for name, x, y in patches:
        image.alpha_composite(load_image(files, name), (x, y))
    return image, image.convert('RGB').resize((16, 8), Image.Resampling.BOX)


def limited_texture(image):
    """Globally allocate <=36 runs/material, <=3/column to bound Lua fallback cost."""
    palette = palette_for([image.convert('RGBA')], 8)
    choices = []
    for x in range(16):
        colors = [image.getpixel((x, y)) for y in range(8)]
        options = {}
        for count in range(1, MAX_COLUMN_RUNS + 1):
            best = None
            for cuts in itertools.combinations(range(1, 8), count - 1):
                ends = (0, *cuts, 8)
                runs, cost = [], 0
                for start, end in zip(ends, ends[1:]):
                    segment = colors[start:end]
                    color = min(palette, key=lambda p: (sum(distance(c, p) for c in segment), p))
                    cost += sum(distance(c, color) for c in segment)
                    if runs and runs[-1][2] == color:
                        runs[-1] = (runs[-1][0], end, color)
                    else:
                        runs.append((start, end, color))
                candidate = (cost, runs)
                used = len(runs)
                if used not in options or candidate < options[used]:
                    options[used] = candidate
        choices.append(options)
    states = {0: (0, [])}
    for options in choices:
        next_states = {}
        for used, (cost, columns) in states.items():
            for extra, (added_cost, runs) in options.items():
                if used + extra > MAX_MATERIAL_RUNS:
                    continue
                candidate = (cost + added_cost, columns + [runs])
                if used + extra not in next_states or candidate < next_states[used + extra]:
                    next_states[used + extra] = candidate
        states = next_states
    _, (_, columns) = min(states.items(), key=lambda item: (item[1][0], item[0], item[1][1]))
    output = Image.new('RGBA', (16, 8))
    for x, runs in enumerate(columns):
        assert runs[0][0] == 0 and runs[-1][1] == 8
        assert len(runs) <= MAX_COLUMN_RUNS
        for start, end, color in runs:
            for y in range(start, end):
                output.putpixel((x, y), (*color, 255))
    assert sum(map(len, columns)) <= MAX_MATERIAL_RUNS
    return columns, output


def rgb(color):
    return color[0] * 65536 + color[1] * 256 + color[2]


def png_bytes(image):
    buffer = BytesIO()
    image.save(buffer, 'PNG', compress_level=9)
    return buffer.getvalue()


def lua_sprites(palette, sprites, overlay):
    lines = ['-- SPDX-License-Identifier: BSD-3-Clause AND GPL-2.0-or-later',
             '-- Generated by tools/compile_freedoom.py; do not hand edit.',
             '-- Enemy/pistol: Freedoom contributors, BSD-3-Clause; see credits.txt.',
             '-- Original Coffer chest: GPL-2.0-or-later. Dot is transparent.',
             'return {', '  palette_additions = {']
    for symbol, color in overlay['palette'].items():
        lines.append(f'    {symbol}=0x{color:06X},')
    for symbol, color in zip(SYMBOLS, palette):
        lines.append(f"    ['{symbol}']=0x{rgb(color):06X},")
    lines.append('  },')
    for name, rows in {**sprites, 'chest': overlay['chest']}.items():
        lines.append(f'  {name} = {{')
        lines.extend(f"    '{row}'," for row in rows)
        lines.append('  },')
    lines.append('}')
    return ('\n'.join(lines) + '\n').encode()


def lua_textures(materials):
    lines = ['-- SPDX-License-Identifier: BSD-3-Clause',
             '-- Generated Freedoom derivatives; see credits.txt and docs/assets.md.',
             '-- 16x8, five light levels; <=3 runs/column and <=36/material.',
             'local base={']
    for columns in materials:
        lines.append('  {')
        for runs in columns:
            values = ','.join(f'{start},{end},0x{rgb(color):06X}' for start, end, color in runs)
            lines.append(f'    {{{values}}},')
        lines.append('  },')
    lines.extend(['}', 'local factors={256,220,188,156,124}', 'local out={}',
                  'for material=1,3 do', '  out[material]={}', '  for shade=1,5 do',
                  '    local columns={};out[material][shade]=columns',
                  '    local factor=factors[shade]', '    for x=1,16 do',
                  '      local source=base[material][x];local runs={}',
                  '      for i=1,#source,3 do', '        local c=source[i+2]',
                  '        local r=((c>>16)*factor)//256',
                  '        local g=(((c>>8)&255)*factor)//256',
                  '        local b=((c&255)*factor)//256',
                  '        runs[i],runs[i+1],runs[i+2]=source[i],source[i+1],(r<<16)|(g<<8)|b',
                  '      end', '      columns[x]=runs', '    end', '  end', 'end', 'return out'])
    return ('\n'.join(lines) + '\n').encode()


def contact_sheet(images, labels, zoom, columns=3, tile=(256, 336)):
    sheet = Image.new('RGBA', (columns * tile[0], ((len(images) + columns - 1) // columns) * tile[1]),
                      (25, 26, 27, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (image, label) in enumerate(zip(images, labels)):
        resized = image.resize((image.width * zoom, image.height * zoom), Image.Resampling.NEAREST)
        x = (i % columns) * tile[0] + (tile[0] - resized.width) // 2
        y = (i // columns) * tile[1] + 24
        sheet.alpha_composite(resized, (x, y))
        draw.text(((i % columns) * tile[0] + 12, (i // columns) * tile[1] + tile[1] - 32),
                  label, fill=(226, 219, 196, 255))
    return sheet


def build():
    files = source_files()
    overlay = json.loads((ASSETS / 'project-overlay.json').read_text())
    assert len(overlay['chest']) == 28 and all(len(row) == 32 for row in overlay['chest'])
    enemy = sprite(files, 'sprites/possa1.png', (24, 36))
    weapon = sprite(files, 'sprites/pisga0.png', (32, 24))
    palette = palette_for([enemy, weapon], 24)
    enemy_rows, enemy = indexed_sprite(enemy, palette)
    weapon_rows, weapon = indexed_sprite(weapon, palette)
    assert len(palette) <= len(SYMBOLS)
    specs = [
        [('patches/sw19_2.png', 0, 0), ('patches/sw19_1.png', 64, 0)],
        [('patches/sw19_4.png', 0, 0), ('patches/sw19_3.png', 64, 0)],
        [('patches/door2_4.png', 0, 0)],
    ]
    materials, texture_images, source_images = [], [], []
    for spec in specs:
        source, reduced = texture(files, spec)
        columns, reduced = limited_texture(reduced)
        materials.append(columns)
        texture_images.append(reduced)
        source_images.append(source)
    output = {
        APP / 'art_detail.lua': lua_sprites(palette, {'enemy': enemy_rows, 'weapon': weapon_rows}, overlay),
        APP / 'textures.lua': lua_textures(materials),
        ASSETS / 'previews' / 'enemy.png': png_bytes(enemy),
        ASSETS / 'previews' / 'weapon.png': png_bytes(weapon),
        ASSETS / 'previews' / 'badge-assets.png': png_bytes(contact_sheet(
            [enemy, weapon, *texture_images],
            ['Freedoom zombie / 24x36', 'Freedoom pistol / 32x24', 'STARTAN3 / 16x8',
             'STARG3 / 16x8', 'BIGDOOR2 / 16x8'], 8)),
        ASSETS / 'previews' / 'texture-sources.png': png_bytes(contact_sheet(
            source_images, ['Freedoom STARTAN3', 'Freedoom STARG3', 'Freedoom BIGDOOR2'],
            2, tile=(280, 312))),
    }
    for i, image in enumerate(texture_images, 1):
        output[ASSETS / 'previews' / f'texture-{i}.png'] = png_bytes(image)
    sprite_runs = {}
    for name, rows in [('enemy', enemy_rows), ('weapon', weapon_rows)]:
        sprite_runs[name] = sum(sum(b != '.' and a != b for a, b in zip('.' + column, column + '.'))
                                for column in [''.join(row[x] for row in rows) for x in range(len(rows[0]))])
    stats = {'upstream_commit': COMMIT, 'sprite_colors': len(palette), 'sprite_runs': sprite_runs,
             'texture_runs_per_material': [sum(map(len, columns)) for columns in materials],
             'texture_runs_all_shades': sum(sum(map(len, columns)) for columns in materials) * 5,
             'maximum_texture_column_runs': max(len(runs) for columns in materials for runs in columns),
             'sha256': {(f'app/{path.name}' if path.parent == APP else str(path.relative_to(ROOT))): hashlib.sha256(data).hexdigest()
                        for path, data in output.items()}}
    output[ASSETS / 'BUILD.json'] = (json.dumps(stats, indent=2) + '\n').encode()
    return output, stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify byte-identical generated outputs')
    args = parser.parse_args()
    output, stats = build()
    for path, data in output.items():
        if args.check:
            assert path.is_file() and path.read_bytes() == data, f'Generated asset differs: {path}'
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(('Verified' if args.check else 'Generated') + f' {len(output)} Freedoom asset outputs; '
          f'{stats["texture_runs_all_shades"]} texture runs, '
          f'{stats["sprite_runs"]["enemy"]} enemy runs; commit {COMMIT}')


if __name__ == '__main__':
    main()
