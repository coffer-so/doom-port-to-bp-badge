#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Create the exact App Store upload; never include vendor, tests, or photos."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FILES = ('main.lua', 'app.json', 'game.lua', 'art.lua', 'art_detail.lua', 'textures.lua', 'surfaces.lua', 'sprites.lua', 'coins.lua', 'rgb.lua', 'art/doom.png', 'art/coffer.png', 'credits.txt', 'license.txt')


def package(root: Path, output: Path) -> None:
    manifest = json.loads((root / 'app.json').read_text())
    if not re.fullmatch(r'[a-z0-9-]{3,24}', manifest['id']):
        raise ValueError('Invalid app id')
    if manifest['permissions'] != ['led'] or manifest.get('hosts'):
        raise ValueError('This game only needs the led permission and no network hosts')
    data = {name: (root / name).read_bytes() for name in FILES}
    if len(data['main.lua']) > 65536:
        raise ValueError('main.lua exceeds 64 KiB')
    bundled = [b for n, b in data.items() if n not in ('main.lua', 'app.json')]
    if any(len(b) > 262144 for b in bundled) or sum(map(len, bundled)) > 1048576:
        raise ValueError('Bundled files exceed App Store limits')
    output.parent.mkdir(parents=True, exist_ok=True)
    # Fixed timestamps and order make rebuilds byte-for-byte reproducible.
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in FILES:
            info = zipfile.ZipInfo(name, date_time=(2026, 11, 13, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data[name])
    print(f'{output}: {output.stat().st_size} bytes; source+data {sum(map(len, data.values()))} bytes')
    print('sha256 ' + hashlib.sha256(output.read_bytes()).hexdigest())


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=ROOT / 'app')
    p.add_argument('--out', type=Path, default=ROOT / 'dist' / 'doom-by-coffer-1.0.0.zip')
    args = p.parse_args()
    package(args.root, args.out)
