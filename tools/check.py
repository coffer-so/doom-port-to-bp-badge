#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Validate the Lua application and upload tools; no hardware required."""
import argparse,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--lua',default='lua5.5')
p.add_argument('--stress',action='store_true')
a=p.parse_args()
for name in ['core','app','surfaces','sprites','rgb']+(['stress'] if a.stress else []):
 subprocess.run([a.lua,str(root/'tests'/f'{name}_spec.lua'),str(root/'app')],check=True,cwd=root)
subprocess.run([sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py'],check=True,cwd=root)
