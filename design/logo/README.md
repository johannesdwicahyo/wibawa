# Wibawa logo

![The Wibawa logo](wibawa-logo.svg)

**The mark** is *kawung*, a batik motif once reserved for the Javanese courts, drawn as four table cells around one point. It stands for what the admin is about (tables of records) and for its name: *wibawa* means authority and dignity.

**The word** is set in Plus Jakarta Sans Bold, the admin's own typeface, drawn by Tokotype in Jakarta.

## Which file

| Use | File |
| --- | --- |
| Almost everywhere | `wibawa-logo.svg` (indigo mark, ink word) |
| On a dark ground | `wibawa-logo-white.svg` |
| One colour only (print, engraving, fax) | `wibawa-logo-black.svg` |
| Square spaces | `wibawa-logo-stacked.svg`, `wibawa-logo-stacked-white.svg` |
| The word alone, where the mark is already nearby | `wibawa-wordmark.svg` |
| The mark alone, 24 px and up | `wibawa-symbol-indigo.svg`, `wibawa-symbol.svg` (black), `wibawa-symbol-white.svg` |
| The mark alone, under 24 px | `wibawa-symbol-small.svg` (no centre point, so the four cells stay apart) |
| App icon, avatar | `wibawa-icon.svg` |
| Browser tab | `wibawa-favicon.svg` (the same file ships in the gem) |
| Where SVG is not accepted | `png/` (transparent background) |

The SVGs hold the word as outlines, so they need no font. `outline.py` rebuilds every SVG from the font file in the gem.

## Rules

**Lockup.** The mark sits left of the word. The word's capitals are 5/8 of the mark's height and centred on it. The gap between them is 72 units of the mark's 256: its central diamond plus the margin on each side. In the stacked version the mark sits above the word, centred. The parts are never rearranged or resized against each other.

**Clear space.** Keep an empty zone around the logo equal to the width of the mark's central diamond: about a fifth of the mark's height, on every side. It scales with the logo.

**Smallest size.** The logo: 18 px tall on screen. The mark with its centre point: 24 px. Below that, the small-size mark, down to 16 px.

**Colour.**

| Name | Hex | Use |
| --- | --- | --- |
| Indigo (*wedel*) | `#21459d` | The mark; the admin's action colour |
| Ink | `#161b24` | The word; text |
| Deep indigo | `#112252` | The sidebar; a dark ground for the white logo |
| Canvas | `#f8f6f4` | A light ground |

Use the colour logo or the black one on white or canvas, and the white one on indigo or deep indigo. On a photograph, put the white or black logo on a calm area.

**Typeface.** Plus Jakarta Sans is under the SIL Open Font License, which allows use in a logo.

**Don't.** Stretch or squash it. Recolour it outside the table above. Rotate it. Add a shadow, an outline or a gradient. Retype the word in another typeface. Put it on a busy background.

## History

`concepts.png` is the first concept sheet, from which the kawung mark was chosen. The wordmark (title case, bold), the two-colour treatment and the small-size favicon were chosen on 2026-11-25 from three options each.

## Not done

A trademark search on the name and the mark has not been made. There are no print files (CMYK or spot colour); the colours above are screen values.
