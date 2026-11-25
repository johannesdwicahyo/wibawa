"""Draws the wordmark drafts as outlined SVG paths (no font needed to view them).

    pip install fonttools brotli
    python design/brand/outline.py

Reads the Plus Jakarta Sans file that ships in the gem and writes
design/brand/wordmark-*.svg (mark + word, black) next to this script.
"""
import pathlib

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = pathlib.Path(__file__).parent
FONT = HERE / "../../app/assets/fonts/wibawa/plus-jakarta-sans-latin.woff2"
MARK = ("M12,12 H38 A74,74 0 0 1 112,86 V112 H86 A74,74 0 0 1 12,38 Z M244,12 V38 A74,74 0 0 1 170,112 H144 V86 A74,74 0 0 1 218,12 Z "
        "M112,144 V170 A74,74 0 0 1 38,244 H12 V218 A74,74 0 0 1 86,144 Z M144,144 H170 A74,74 0 0 1 244,218 V244 H218 A74,74 0 0 1 144,170 Z "
        "M128,104 L152,128 L128,152 L104,128 Z")

# name: (text, weight, tracking in thousandths of an em)
DRAFTS = {
    "a-title": ("Wibawa", 700, -10),
    "b-lower": ("wibawa", 600, -5),
    "c-caps": ("WIBAWA", 600, 90),
}


def word(text, weight, tracking):
    """The word as one SVG path with its baseline at y=0, plus its width and cap height, in font units."""
    font = instantiateVariableFont(TTFont(FONT), {"wght": weight})
    glyphs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    pen, x = SVGPathPen(glyphs), 0
    for char in text:
        name = cmap[ord(char)]
        glyphs[name].draw(TransformPen(pen, (1, 0, 0, -1, x, 0)))  # flip y: fonts draw upwards
        x += glyphs[name].width + tracking * upm / 1000
    return pen.getCommands(), x - tracking * upm / 1000, font["OS/2"].sCapHeight, font["OS/2"].sxHeight


def lockup(text, weight, tracking):
    """Mark on the left, word on the right. The mark is 256 units tall; the word's
    capitals are 5/8 of that, centred on the mark; the gap is the mark's central
    diamond plus its margin (72 units), so the spacing scales with the mark."""
    path, width, cap, x_height = word(text, weight, tracking)
    tall = cap if text != text.lower() else x_height
    scale = 160 / cap
    baseline = 128 + tall * scale / 2
    total = 256 + 72 + width * scale
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total:.0f} 256" fill="#000"><title>Wibawa</title>'
            f'<path d="{MARK}"/><path transform="translate(328 {baseline:.1f}) scale({scale:.4f})" d="{path}"/></svg>\n')


for name, draft in DRAFTS.items():
    (HERE / f"wordmark-{name}.svg").write_text(lockup(*draft))
    print("wrote", f"wordmark-{name}.svg")
