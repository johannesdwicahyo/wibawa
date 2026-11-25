"""Builds the Wibawa logo files next to this script.

    pip install fonttools brotli
    python design/logo/outline.py

The word is set in Plus Jakarta Sans Bold from the font file that ships in the
gem, and written as outlines, so the SVGs need no font to display.
"""
import pathlib

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = pathlib.Path(__file__).parent
FONT = HERE / "../../app/assets/fonts/wibawa/plus-jakarta-sans-latin.woff2"

INDIGO, INK, WHITE, BLACK = "#21459d", "#161b24", "#fff", "#000"
PETALS = ("M12,12 H38 A74,74 0 0 1 112,86 V112 H86 A74,74 0 0 1 12,38 Z M244,12 V38 A74,74 0 0 1 170,112 H144 V86 A74,74 0 0 1 218,12 Z "
          "M112,144 V170 A74,74 0 0 1 38,244 H12 V218 A74,74 0 0 1 86,144 Z M144,144 H170 A74,74 0 0 1 244,218 V244 H218 A74,74 0 0 1 144,170 Z")
MARK = PETALS + " M128,104 L152,128 L128,152 L104,128 Z"  # the four cells and the point between them

TEXT, WEIGHT, TRACKING = "Wibawa", 700, -10  # tracking in thousandths of an em
GAP = 72  # between mark and word: the mark's central diamond (48) plus its margin, of 256


def word():
    """The word as one path with its baseline at y=0, with its width and cap height, in font units."""
    font = instantiateVariableFont(TTFont(FONT), {"wght": WEIGHT})
    glyphs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    pen, x = SVGPathPen(glyphs), 0
    for char in TEXT:
        name = cmap[ord(char)]
        glyphs[name].draw(TransformPen(pen, (1, 0, 0, -1, x, 0)))  # flip y: fonts draw upwards
        x += glyphs[name].width + TRACKING * upm / 1000
    return pen.getCommands(), x - TRACKING * upm / 1000, font["OS/2"].sCapHeight


WORD, WIDTH, CAP = word()


def svg(width, height, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.0f} {height:.0f}"><title>Wibawa</title>{body}</svg>\n'


def horizontal(mark, text):
    """Mark left, word right: capitals 5/8 of the mark's height, centred on it."""
    scale = 160 / CAP
    return svg(256 + GAP + WIDTH * scale, 256,
               f'<path fill="{mark}" d="{MARK}"/><path fill="{text}" transform="translate({256 + GAP} 208) scale({scale:.4f})" d="{WORD}"/>')


def stacked(mark, text):
    """Mark above, word below and centred: for square spaces."""
    scale = 112 / CAP
    width = max(WIDTH * scale, 256)
    return svg(width, 256 + 56 + 112,
               f'<path fill="{mark}" transform="translate({(width - 256) / 2:.1f} 0)" d="{MARK}"/>'
               f'<path fill="{text}" transform="translate({(width - WIDTH * scale) / 2:.1f} 424) scale({scale:.4f})" d="{WORD}"/>')


def wordmark(text):
    scale = 160 / CAP
    return svg(WIDTH * scale, 160, f'<path fill="{text}" transform="translate(0 160) scale({scale:.4f})" d="{WORD}"/>')


def symbol(colour, path=MARK):
    return svg(256, 256, f'<path fill="{colour}" d="{path}"/>')


def tile(path, scale):
    """White on an indigo tile, for app icons and the favicon."""
    return svg(256, 256, f'<rect width="256" height="256" rx="56" fill="{INDIGO}"/>'
                         f'<path fill="{WHITE}" transform="translate(128 128) scale({scale}) translate(-128 -128)" d="{path}"/>')


FILES = {
    "wibawa-logo.svg": horizontal(INDIGO, INK),
    "wibawa-logo-black.svg": horizontal(BLACK, BLACK),
    "wibawa-logo-white.svg": horizontal(WHITE, WHITE),
    "wibawa-logo-stacked.svg": stacked(INDIGO, INK),
    "wibawa-logo-stacked-white.svg": stacked(WHITE, WHITE),
    "wibawa-wordmark.svg": wordmark(INK),
    "wibawa-symbol.svg": symbol(BLACK),
    "wibawa-symbol-white.svg": symbol(WHITE),
    "wibawa-symbol-indigo.svg": symbol(INDIGO),
    "wibawa-symbol-small.svg": symbol(INDIGO, PETALS),  # under 24 px: no centre point, so the cells stay apart
    "wibawa-icon.svg": tile(MARK, 0.7),                  # app icon, avatar: 48 px and up
    "wibawa-favicon.svg": tile(PETALS, 0.78),            # 16 to 32 px; the same file ships in the gem
}

for name, content in FILES.items():
    (HERE / name).write_text(content)
    print("wrote", name)
