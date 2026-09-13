#!/usr/bin/env python3
"""
generate_assets.py - Generates all NetTracker visual assets:
- assets/logo.png: High-resolution transparent PNG logo for README & docs
- assets/app-icon.png: 1024x1024 macOS squircle App Icon
- macos/NetTracker/Resources/AppIcon.icns: Multi-res Apple ICNS file
- assets/dmg-background.png & @2x: Installer background image
"""

import os
import subprocess
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT, "assets")
RESOURCES_DIR = os.path.join(ROOT, "macos", "NetTracker", "Resources")
SRC_LOGO = os.path.join(ASSETS_DIR, "nettracker-logo.jpeg")

os.makedirs(ASSETS_DIR, exist_ok=True)
os.makedirs(RESOURCES_DIR, exist_ok=True)

if not os.path.exists(SRC_LOGO):
    raise FileNotFoundError(f"Source logo not found at {SRC_LOGO}")

# 1. Load original JPEG and generate transparent PNG
raw = Image.open(SRC_LOGO).convert("RGB")
arr = np.array(raw, dtype=float)

diff = 255.0 - arr
max_diff = np.max(diff, axis=-1)
alpha = np.clip((max_diff - 6.0) / 240.0 * 255.0 * 1.04, 0, 255).astype(np.uint8)

a_norm = alpha.astype(float) / 255.0
safe_a = np.maximum(a_norm[..., None], 1e-4)
rgb_clean = (arr - (1.0 - safe_a) * 255.0) / safe_a
rgb_clean = np.clip(rgb_clean, 0, 255).astype(np.uint8)

rgba = np.dstack((rgb_clean, alpha))
full_transparent = Image.fromarray(rgba, "RGBA")

content_mask = alpha > 40
coords = np.argwhere(content_mask)
y0, x0 = coords.min(axis=0)
y1, x1 = coords.max(axis=0)

logo_cropped = full_transparent.crop((x0 - 20, y0 - 20, x1 + 20, y1 + 20))
logo_path = os.path.join(ASSETS_DIR, "logo.png")
logo_cropped.save(logo_path)
print(f"Generated {logo_path} ({logo_cropped.size[0]}x{logo_cropped.size[1]})")

# Crop tight symbol mark (wifi + rising arrow)
sym_alpha = alpha.copy()
sym_alpha[480:, :] = 0
sym_coords = np.argwhere(sym_alpha > 35)
sy0, sx0 = sym_coords.min(axis=0)
sy1, sx1 = sym_coords.max(axis=0)
symbol_tight = full_transparent.crop((sx0, sy0, sx1 + 1, sy1 + 1))

# 2. Build 1024x1024 macOS App Icon
CANVAS_SIZE = 1024
ICON_BODY_SIZE = 824
RADIUS = 185
OFFSET = (CANVAS_SIZE - ICON_BODY_SIZE) // 2

mask = Image.new("L", (ICON_BODY_SIZE, ICON_BODY_SIZE), 0)
draw_mask = ImageDraw.Draw(mask)
draw_mask.rounded_rectangle([(0, 0), (ICON_BODY_SIZE - 1, ICON_BODY_SIZE - 1)], radius=RADIUS, fill=255)

body = Image.new("RGBA", (ICON_BODY_SIZE, ICON_BODY_SIZE), (255, 255, 255, 255))
draw_body = ImageDraw.Draw(body)
for y in range(ICON_BODY_SIZE):
    ratio = y / ICON_BODY_SIZE
    r = int(255 - 14 * ratio)
    g = int(255 - 11 * ratio)
    b = int(255 - 7 * ratio)
    draw_body.line([(0, y), (ICON_BODY_SIZE, y)], fill=(r, g, b, 255))

draw_body.rounded_rectangle(
    [(0, 0), (ICON_BODY_SIZE - 1, ICON_BODY_SIZE - 1)],
    radius=RADIUS,
    outline=(210, 218, 226, 255),
    width=3,
)
body.putalpha(mask)

sym_w = 530
sym_h = int(symbol_tight.size[1] * (sym_w / symbol_tight.size[0]))
sym_scaled = symbol_tight.resize((sym_w, sym_h), Image.Resampling.LANCZOS)
sym_pos = ((ICON_BODY_SIZE - sym_w) // 2, (ICON_BODY_SIZE - sym_h) // 2 - 8)
body.paste(sym_scaled, sym_pos, sym_scaled)

shadow = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
shadow_layer = Image.new("RGBA", (ICON_BODY_SIZE, ICON_BODY_SIZE), (0, 0, 0, 75))
shadow_layer.putalpha(mask)
shadow.paste(shadow_layer, (OFFSET, OFFSET + 22))
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=26))

canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
canvas = Image.alpha_composite(canvas, shadow)
canvas.paste(body, (OFFSET, OFFSET), body)

app_icon_path = os.path.join(ASSETS_DIR, "app-icon.png")
canvas.save(app_icon_path)
print(f"Generated {app_icon_path}")

# Build AppIcon.icns
iconset_dir = "/tmp/NetTracker_build.iconset"
os.makedirs(iconset_dir, exist_ok=True)
sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]
for sz, name in sizes:
    resized = canvas.resize((sz, sz), Image.Resampling.LANCZOS)
    resized.save(os.path.join(iconset_dir, name))

icns_path = os.path.join(RESOURCES_DIR, "AppIcon.icns")
subprocess.check_call(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path])
print(f"Generated {icns_path}")

# 3. Build DMG background images
W, H = 1320, 800
dmg_bg = Image.new("RGBA", (W, H), (255, 255, 255, 255))
draw = ImageDraw.Draw(dmg_bg)

for y in range(H):
    r = int(255 - 12 * (y / H))
    g = int(255 - 10 * (y / H))
    b = int(255 - 6 * (y / H))
    draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

for x in range(W):
    ratio = x / W
    r = int(46 * (1 - ratio) + 74 * ratio)
    g = int(140 * (1 - ratio) + 172 * ratio)
    b = int(165 * (1 - ratio) + 185 * ratio)
    draw.line([(x, 0), (x, 6)], fill=(r, g, b, 255))

logo_h = 165
logo_w = int(logo_cropped.size[0] * (logo_h / logo_cropped.size[1]))
logo_scaled = logo_cropped.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
logo_x = (W - logo_w) // 2
logo_y = 30
dmg_bg.paste(logo_scaled, (logo_x, logo_y), logo_scaled)

font_sub = None
font_tag = None
for fpath in ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/Supplemental/Arial.ttf"]:
    if os.path.exists(fpath):
        try:
            font_sub = ImageFont.truetype(fpath, 32)
            font_tag = ImageFont.truetype(fpath, 24)
            break
        except Exception:
            pass
if font_sub is None:
    font_sub = ImageFont.load_default()
    font_tag = ImageFont.load_default()

instruction_text = "Drag NetTracker into Applications to install"
bbox = draw.textbbox((0, 0), instruction_text, font=font_sub)
tw = bbox[2] - bbox[0]
draw.text(((W - tw) // 2, logo_y + logo_h + 16), instruction_text, fill=(75, 90, 108, 255), font=font_sub)

x_start = 520
x_end = 800
y_mid = 440

arrow_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
adraw = ImageDraw.Draw(arrow_img)
adraw.line([(x_start, y_mid), (x_end - 16, y_mid)], fill=(46, 140, 165, 80), width=16)
arrow_img = arrow_img.filter(ImageFilter.GaussianBlur(radius=8))
dmg_bg = Image.alpha_composite(dmg_bg, arrow_img)

draw_arrow = ImageDraw.Draw(dmg_bg)
draw_arrow.line([(x_start, y_mid), (x_end - 18, y_mid)], fill=(46, 140, 165, 235), width=8)
arrow_head = [
    (x_end, y_mid),
    (x_end - 38, y_mid - 24),
    (x_end - 28, y_mid),
    (x_end - 38, y_mid + 24),
]
draw_arrow.polygon(arrow_head, fill=(46, 140, 165, 255))

foot_text = "NetTracker • Native macOS Network Usage Tracker"
bbox_f = draw.textbbox((0, 0), foot_text, font=font_tag)
tw_f = bbox_f[2] - bbox_f[0]
draw.text(((W - tw_f) // 2, H - 46), foot_text, fill=(145, 158, 172, 255), font=font_tag)

dmg_bg_2x = os.path.join(ASSETS_DIR, "dmg-background@2x.png")
dmg_bg_1x = os.path.join(ASSETS_DIR, "dmg-background.png")
dmg_bg.save(dmg_bg_2x)
bg_res = dmg_bg.resize((660, 400), Image.Resampling.LANCZOS)
bg_res.save(dmg_bg_1x)
print(f"Generated {dmg_bg_1x} and {dmg_bg_2x}")
