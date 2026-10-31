"""Draws SurvivorsLite's own textures into SurvivorsLite/media as BLP files.

The Azeroth Survivors client loads interface textures, an addon's too, as BLP: it adds
".blp" to the path a texture is set to. TGA and PNG files in the AddOns folder show nothing
there (tried in the web client, 2026-10-31). So these are BLP2 files like the game's own
interface art, a 256 color palette with 8 bits of alpha, which keeps the icons transparent:

    lair   a dragon's head in light grey with a dark outline; the addon tints it with each
           lair's color, so one image serves all five
    chest  a chest in its own colors
    bar    the damage meter's bar fill, grey so the addon can color it

Each is drawn eight times larger and scaled down for smooth edges. The output is the same
on every run.

Usage: python tools/make_media.py   (needs: pip install pillow)
"""
import os
import struct

from PIL import Image, ImageChops, ImageDraw, ImageFilter

here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "..", "SurvivorsLite", "media")

SS = 8          # drawn this many times larger
SIZE = 32       # icon size in pixels
BIG = SIZE * SS


def mip_chain(img):
    """The image and its halvings down to 1 x 1, each scaled with its alpha as weight."""
    out = [img]
    while img.size[0] > 1 or img.size[1] > 1:
        w, h = max(1, img.size[0] // 2), max(1, img.size[1] // 2)
        r, g, b, a = img.split()
        pre = Image.merge("RGB", [ImageChops.multiply(c, a) for c in (r, g, b)]).resize((w, h), Image.BOX)
        a = a.resize((w, h), Image.BOX)
        px, ap = pre.load(), a.load()
        nxt = Image.new("RGBA", (w, h))
        np_ = nxt.load()
        for y in range(h):
            for x in range(w):
                al = ap[x, y]
                if al == 0:
                    np_[x, y] = (0, 0, 0, 0)
                else:
                    c = px[x, y]
                    np_[x, y] = tuple(min(255, int(v * 255 / al + 0.5)) for v in c) + (al,)
        out.append(nxt)
        img = nxt
    return out


def write_blp(img, path):
    """A BLP2 file as the 1.12 client's own interface art: a 256 color palette, 8 bits of
    alpha and every mip level."""
    img = img.convert("RGBA")
    mips = mip_chain(img)
    # One palette for all levels, from the colors of the first.
    pal_img = img.convert("RGB").quantize(256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = pal_img.getpalette()[:768]
    pal += [0] * (768 - len(pal))
    blobs = []
    for m in mips:
        idx = m.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE)
        blobs.append(idx.tobytes() + m.split()[3].tobytes())
    w, h = img.size
    header = b"BLP2" + struct.pack("<IBBBBII", 1, 1, 8, 8, 1, w, h)
    offsets, sizes = [], []
    pos = len(header) + 16 * 4 * 2 + 256 * 4
    for b in blobs:
        offsets.append(pos)
        sizes.append(len(b))
        pos += len(b)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))
    palette = b"".join(struct.pack("<BBBB", pal[i * 3 + 2], pal[i * 3 + 1], pal[i * 3], 0) for i in range(256))
    with open(path, "wb") as f:
        f.write(header + struct.pack("<16I", *offsets) + struct.pack("<16I", *sizes) + palette + b"".join(blobs))


def pts(points):
    return [(x * SS, y * SS) for x, y in points]


def mirror(points):
    return [(SIZE - x, y) for x, y in points]


def mask_of(draw_fn):
    m = Image.new("L", (BIG, BIG), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def outlined(fill_rgb, mask, width):
    """The shape in `fill_rgb` (an RGB image) with a dark edge `width` units wide around it."""
    k = int(width * SS) * 2 + 1
    edge = mask.filter(ImageFilter.MaxFilter(k))
    out = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    out.paste((8, 6, 4, 255), (0, 0), edge)
    body = fill_rgb.convert("RGBA")
    out.paste(body, (0, 0), mask)
    return out


def shrink(img):
    # Scale with alpha weighting so the edge does not pick up the transparent pixels' color.
    r, g, b, a = img.split()
    pre = Image.merge("RGB", [ImageChops.multiply(c, a) for c in (r, g, b)])
    pre = pre.resize((SIZE, SIZE), Image.LANCZOS)
    a = a.resize((SIZE, SIZE), Image.LANCZOS)
    pr, pg, pb = pre.split()
    ap = a.load()
    chans = [pr.load(), pg.load(), pb.load()]
    out = Image.new("RGBA", (SIZE, SIZE))
    op = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            al = ap[x, y]
            if al == 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            c = [min(255, int(ch[x, y] * 255 / al + 0.5)) for ch in chans]
            op[x, y] = (c[0], c[1], c[2], al)
    return out


def vertical(top, bottom, size=BIG):
    """A grey (or RGB) gradient from top to bottom."""
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t + 0.5) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


# ---------------------------------------------------------------- the lair's dragon head

HEAD = [(16, 7.2), (19.8, 7.8), (22.6, 9.4), (24.2, 12.6), (23.8, 16), (21.8, 20), (20.4, 24),
        (18.8, 27.8), (16, 29.6), (13.2, 27.8), (11.6, 24), (10.2, 20), (8.2, 16), (7.8, 12.6),
        (9.4, 9.4), (12.2, 7.8)]
HORN = [(10, 10.6), (7.4, 7.6), (5.2, 4.4), (3.6, 1.4), (7.4, 3.8), (10.6, 6.6), (13.4, 8.6)]
CREST = [(14.2, 8), (16, 3.6), (17.8, 8)]
FRILL_UP = [(8.4, 12.4), (2.6, 12.2), (8.2, 16.6)]
FRILL_DOWN = [(9.8, 17.6), (4.6, 19.8), (10.8, 21.4)]
EYE = [(10.2, 13), (14.8, 15.4), (14.2, 17.2), (10.8, 15)]


def lair():
    def shape(d):
        for part in (HEAD, HORN, mirror(HORN), CREST, FRILL_UP, mirror(FRILL_UP),
                     FRILL_DOWN, mirror(FRILL_DOWN)):
            d.polygon(pts(part), fill=255)
    mask = mask_of(shape)
    # Light at the brow, darker at the jaw; the horns and frills a little darker than the face.
    fill = vertical((255, 255, 255), (178, 178, 178))
    horns = mask_of(lambda d: [d.polygon(pts(p), fill=255) for p in
                               (HORN, mirror(HORN), FRILL_UP, mirror(FRILL_UP), FRILL_DOWN, mirror(FRILL_DOWN))])
    dim = vertical((206, 206, 206), (150, 150, 150))
    fill.paste(dim, (0, 0), horns)
    # A lighter ridge down the snout.
    ridge = mask_of(lambda d: d.polygon(pts([(15.2, 9), (16.8, 9), (17.4, 25), (14.6, 25)]), fill=255))
    ridge = ridge.filter(ImageFilter.GaussianBlur(SS * 0.8))
    fill.paste((255, 255, 255), (0, 0), ridge)
    img = outlined(fill, mask, 1.5)
    # Eyes and nostrils cut dark, so the face reads at minimap size.
    d = ImageDraw.Draw(img)
    for eye in (EYE, mirror(EYE)):
        d.polygon(pts(eye), fill=(8, 6, 4, 255))
    for cx in (14.4, 17.6):
        d.ellipse([((cx - 0.8) * SS, 25.6 * SS), ((cx + 0.8) * SS, 27.2 * SS)], fill=(8, 6, 4, 255))
    return shrink(img)


# ---------------------------------------------------------------- the chest

WOOD_TOP, WOOD_BOTTOM = (176, 112, 58), (104, 60, 28)
GOLD_TOP, GOLD_BOTTOM = (255, 226, 120), (196, 140, 38)


def chest():
    lid = [(4, 14)] + [(4 + 24 * i / 20.0, 14 - 9 * (1 - (2 * i / 20.0 - 1) ** 2) ** 0.5 * 0.92 - 0.6)
                       for i in range(21)] + [(28, 14)]
    body = [(4, 14), (28, 14), (27.4, 27.6), (4.6, 27.6)]

    def shape(d):
        d.polygon(pts(lid), fill=255)
        d.polygon(pts(body), fill=255)
    mask = mask_of(shape)
    fill = vertical(WOOD_TOP, WOOD_BOTTOM)
    # The lid a little lighter than the box.
    lid_mask = mask_of(lambda d: d.polygon(pts(lid), fill=255))
    fill.paste(vertical((198, 130, 70), (150, 92, 44)), (0, 0), lid_mask)
    d = ImageDraw.Draw(fill)
    # Plank seams.
    for y in (19.6, 23.8):
        d.line([(5 * SS, y * SS), (27 * SS, y * SS)], fill=(70, 38, 16), width=int(0.7 * SS))
    gold = vertical(GOLD_TOP, GOLD_BOTTOM)
    bands = mask_of(lambda d2: [
        d2.rectangle([(x0 * SS, 3 * SS), (x1 * SS, 28 * SS)], fill=255) for x0, x1 in ((7.6, 10.4), (21.6, 24.4))
    ] + [d2.rectangle([(3.6 * SS, 13.1 * SS), (28.4 * SS, 15.3 * SS)], fill=255)])
    bands = ImageChops.multiply(bands, mask)
    fill.paste(gold, (0, 0), bands)
    # The lock plate with its keyhole.
    lock = mask_of(lambda d2: d2.rounded_rectangle([(13.4 * SS, 12.4 * SS), (18.6 * SS, 19.6 * SS)],
                                                   radius=int(1.2 * SS), fill=255))
    fill.paste(gold, (0, 0), lock)
    img = outlined(fill, mask, 1.5)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(13.4 * SS, 12.4 * SS), (18.6 * SS, 19.6 * SS)], radius=int(1.2 * SS),
                        outline=(8, 6, 4, 255), width=int(0.6 * SS))
    d.ellipse([(15.1 * SS, 14.2 * SS), (16.9 * SS, 16 * SS)], fill=(8, 6, 4, 255))
    d.polygon(pts([(15.5, 15.4), (16.5, 15.4), (16.8, 18), (15.2, 18)]), fill=(8, 6, 4, 255))
    return shrink(img)


# ---------------------------------------------------------------- the meter's bar

def bar():
    """64 x 16: a soft top light, a gloss over the upper half and a darker bottom edge."""
    w, h = 64, 16
    img = Image.new("RGBA", (w, h))
    p = img.load()
    for y in range(h):
        t = y / (h - 1)
        v = 0.95 - 0.33 * t
        if y < h / 2:
            v += 0.06
        if y == 0:
            v = 1.0
        if y == h - 1:
            v = 0.5
        c = int(max(0, min(1, v)) * 255 + 0.5)
        for x in range(w):
            p[x, y] = (c, c, c, 255)
    return img


def main():
    os.makedirs(out_dir, exist_ok=True)
    for name, img in (("lair", lair()), ("chest", chest()), ("bar", bar())):
        path = os.path.join(out_dir, name + ".blp")
        write_blp(img, path)
        print(os.path.relpath(path, os.path.join(here, "..")), img.size)


if __name__ == "__main__":
    main()
