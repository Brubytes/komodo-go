"""Render the source logo with Inkscape (no Python dependencies).

Run from the repo root: python tool/generate_logo_assets.py
Then run the launcher icon and native splash generators; see assets/README.md.
"""

import copy
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SVG = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG)
INKSCAPE = shutil.which('inkscape') or str(
    Path(os.environ.get('ProgramFiles', 'C:/Program Files'))
    / 'Inkscape/bin/inkscape.com'
)
source = ET.parse(ROOT / 'assets/Komodo-GO-Painted.svg').getroot()


def render(path, size, scale, background, shape='square', dark=False):
    svg = ET.Element(f'{{{SVG}}}svg', viewBox='0 0 1024 1024')
    if background:
        if shape == 'circle':
            ET.SubElement(svg, f'{{{SVG}}}circle', cx='512', cy='512',
                          r='512', fill=background)
        else:
            ET.SubElement(svg, f'{{{SVG}}}rect', width='1024', height='1024',
                          rx='123' if shape == 'rounded' else '0', fill=background)
    art = copy.deepcopy(source)
    art.set('x', str(512 * (1 - scale)))
    art.set('y', str(512 * (1 - scale)))
    art.set('width', str(1024 * scale))
    art.set('height', str(1024 * scale))
    if dark:
        for element in art.iter():
            fill = element.get('fill')
            if fill in ('#231F20', '#2E8555'):
                element.set('fill', '#F1F5F0' if fill == '#231F20' else '#69C78F')
    svg.append(art)
    # Android 12 keeps the entire badge within the system's circular mask.
    if size == 1152:
        outer = ET.Element(f'{{{SVG}}}svg', viewBox='0 0 1152 1152')
        svg.attrib.update(x='316', y='316', width='520', height='520')
        outer.append(svg)
        svg = outer
    with tempfile.TemporaryDirectory() as directory:
        temporary = Path(directory) / 'logo.svg'
        ET.ElementTree(svg).write(temporary, encoding='utf-8', xml_declaration=True)
        subprocess.run([INKSCAPE, str(temporary), '--export-type=png',
                        f'--export-width={size}', f'--export-filename={ROOT / path}'],
                       check=True)
    png = (ROOT / path).read_bytes()
    assert png[:8] == b'\x89PNG\r\n\x1a\n', path
    assert struct.unpack('>II', png[16:24]) == (size, size), path


if __name__ == '__main__':
    for dark in (False, True):
        suffix = '_dark' if dark else ''
        background = '#141C18' if dark else '#FFFFFF'
        for shape, size, scale in [('square', 1024, 0.94),
                                   ('rounded', 775, 0.94), ('circle', 512, 0.80)]:
            name = '' if shape == 'square' else f'_{shape}'
            render(f'assets/komodo-go-logo{name}{suffix}.png', size, scale,
                   background, shape, dark)
        render(f'assets/komodo-go-logo_rounded_android12{suffix}.png',
               1152, 0.94, background, 'rounded', dark)
    render('assets/komodo-go-logo_dark_transparent.png', 1024, 0.94, None, dark=True)
    for size in (192, 512):
        render(f'web/icons/Icon-maskable-{size}.png', size, 0.65, '#FFFFFF')
    shutil.copyfile(ROOT / 'assets/komodo-go-logo.png',
                    ROOT / 'storepix/assets/komodo-go-logo.png')
