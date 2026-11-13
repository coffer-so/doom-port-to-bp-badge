#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Prepare the supplied vector mark and downscale the original title wordmark.
Requires cairosvg, system cairo, and ffmpeg. Runtime uses only the resulting PNGs.
"""
from pathlib import Path
import subprocess
import cairosvg
root=Path(__file__).resolve().parents[1]
(root/'app/art').mkdir(parents=True, exist_ok=True)
s=(root/'assets/coffer-export.svg').read_text()
cairosvg.svg2png(bytestring=s.encode(),write_to=str(root/'app/art/coffer.png'),output_width=13,output_height=16)
subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'assets/doom-classic.png'),'-vf','colorkey=0xff00ff:0.05:0.0,scale=180:116',str(root/'app/art/doom.png')],check=True)
