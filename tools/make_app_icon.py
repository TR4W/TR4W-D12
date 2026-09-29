"""Draw the TR4W application icon at 1024 and render the macOS iconset sizes.

The source art in the tree is 32x32, which is why Finder shows a generic
icon: there is nothing worth putting in a bundle.  This redraws the same
mark -- deep blue field, opposed light wedges meeting at the centre, TR4W
wordmark -- at a size macOS can actually use.

The wedges are kept because they are not decoration: they are a bowtie,
which is an antenna.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 1024
OUT = os.path.dirname(os.path.abspath(__file__))

DEEP   = (10, 24, 74)
MID    = (26, 58, 158)
BRIGHT = (52, 104, 226)
SILVER = (232, 236, 244)
GREY   = (150, 160, 178)


def vgrad(size, top, bottom):
   """A vertical gradient, drawn a row at a time."""
   g = Image.new('RGB', (1, size))
   d = ImageDraw.Draw(g)
   for y in range(size):
      t = y / max(1, size - 1)
      d.point((0, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
   return g.resize((size, size))


def squircle(size, radius):
   """The Big Sur rounded square, as a mask."""
   m = Image.new('L', (size * 4, size * 4), 0)
   ImageDraw.Draw(m).rounded_rectangle(
      [0, 0, size * 4 - 1, size * 4 - 1], radius=radius * 4, fill=255)
   return m.resize((size, size), Image.LANCZOS)


def pick_font(px):
   for name in ('arialbd.ttf', 'segoeuib.ttf', 'calibrib.ttf', 'Arial Bold.ttf'):
      for root in (r'C:\Windows\Fonts', '/Library/Fonts', '/usr/share/fonts'):
         p = os.path.join(root, name)
         if os.path.exists(p):
            return ImageFont.truetype(p, px)
   return ImageFont.load_default()


# --- the field -------------------------------------------------------------
art = vgrad(S, MID, DEEP).convert('RGBA')
d = ImageDraw.Draw(art)

# --- the bowtie: two opposed wedges meeting at the centre ------------------
cx = S // 2
cy = int(S * 0.435)          # lifted, so the wordmark gets clear air
half_h = int(S * 0.255)      # vertical half-height at the outer edge
inset  = int(S * 0.12)      # how far the tips sit from the edge
gap    = int(S * 0.012)     # the pinch at the centre

left = [(inset, cy - half_h), (cx - gap, cy - gap), (cx - gap, cy + gap), (inset, cy + half_h)]
right = [(S - inset, cy - half_h), (cx + gap, cy - gap), (cx + gap, cy + gap), (S - inset, cy + half_h)]

shade = Image.new('RGBA', (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shade)
sd.polygon(left, fill=SILVER + (255,))
sd.polygon(right, fill=GREY + (255,))
art = Image.alpha_composite(art, shade)

# a highlight along the top edge of each wedge, so it reads as a solid form
hl = Image.new('RGBA', (S, S), (0, 0, 0, 0))
hd = ImageDraw.Draw(hl)
hd.line([left[0], left[1]], fill=(255, 255, 255, 220), width=int(S * 0.012))
hd.line([right[0], right[1]], fill=(255, 255, 255, 150), width=int(S * 0.012))
art = Image.alpha_composite(art, hl)

# --- the wordmark ----------------------------------------------------------
d = ImageDraw.Draw(art)
f = pick_font(int(S * 0.215))
txt = 'TR4W'
bb = d.textbbox((0, 0), txt, font=f)
tw, th = bb[2] - bb[0], bb[3] - bb[1]
tx, ty = (S - tw) // 2 - bb[0], int(S * 0.700) - bb[1]
d.text((tx + int(S * 0.006), ty + int(S * 0.006)), txt, font=f, fill=(0, 0, 0, 110))
d.text((tx, ty), txt, font=f, fill=(255, 255, 255, 255))

# --- a soft inner rim, then the squircle mask ------------------------------
rim = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(rim).rounded_rectangle(
   [2, 2, S - 3, S - 3], radius=int(S * 0.2237),
   outline=(255, 255, 255, 46), width=int(S * 0.006))
art = Image.alpha_composite(art, rim)

art.putalpha(squircle(S, int(S * 0.2237)))
master = os.path.join(OUT, 'tr4w_icon_1024.png')
art.save(master)
print('master ->', master)

for px in (512, 256, 128, 64, 32, 16):
   art.resize((px, px), Image.LANCZOS).save(os.path.join(OUT, 'tr4w_icon_%d.png' % px))
print('sizes  -> 512 256 128 64 32 16')

# a side-by-side preview against the original, for review
orig = Image.open('tr4w/res/tr4w.ico').convert('RGBA').resize((256, 256), Image.NEAREST)
sheet = Image.new('RGBA', (256 * 2 + 48, 300), (245, 245, 247, 255))
sheet.paste(orig, (16, 22), orig)
new256 = art.resize((256, 256), Image.LANCZOS)
sheet.paste(new256, (256 + 32, 22), new256)
sd = ImageDraw.Draw(sheet)
sf = pick_font(20)
sd.text((16, 286 - 14), 'existing 32x32', font=sf, fill=(60, 60, 70, 255))
sd.text((256 + 32, 286 - 14), 'redrawn 1024', font=sf, fill=(60, 60, 70, 255))
prev = os.path.join(OUT, 'icon_compare.png')
sheet.convert('RGB').save(prev)
print('compare->', prev)
