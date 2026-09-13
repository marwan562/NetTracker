#!/usr/bin/env python3
"""
generate_assets.py - Generates all NetTracker visual assets from the v3 WiFi identity:
- assets/logo.png: transparent full-color WiFi mark for README, docs & Settings About view
- assets/app-icon.png: 1024x1024 macOS squircle App Icon (transparent canvas + shadow)
- macos/NetTracker/Resources/logo.png + AppIcon.icns: bundled runtime assets
- assets/dmg-background.png & @2x: installer background (Apple-blue accents)

Source of truth: assets/identity/original/nettracker-wifi-v3-raw-2048.png
"""

import os
import shutil
import subprocess
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(ROOT, "assets")
RESOURCES_DIR = os.path.join(ROOT, "macos", "NetTracker", "Resources")
SRC_MASTER = os.path.join(ASSETS_DIR, "identity", "original", "nettracker-wifi-v3-raw-2048.png")
CLEAN_MASTER = os.path.join(ASSETS_DIR, "identity", "appicon", "AppIcon-1024.png")

APPLE_BLUE = (10, 132, 255)
APPLE_BLUE_LIGHT = (100, 180, 255)

os.makedirs(ASSETS_DIR, exist_ok=True)
os.makedirs(RESOURCES_DIR, exist_ok=True)

# Prefer the cleaned white-square master; fall back to the raw render.
src_path = CLEAN_MASTER if os.path.exists(CLEAN_MASTER) else SRC_MASTER
if not os.path.exists(src_path):
    raise FileNotFoundError(f"Source logo not found at {src_path}")

# 1. Extract the blue WiFi mark as a transparent PNG.
master = Image.open(src_path).convert("RGB")
arr = np.array(master, dtype=float)
r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
blue_strength = b - r
alpha = np.clip((blue_strength - 25.0) * 4.0, 0, 255).astype(np.uint8)
# Drop the AI-baked glow/shadow: keep only saturated blue core pixels.
core = (b > 130) & (r < 205) & (alpha > 60)
alpha = np.where(core, alpha, 0).astype(np.uint8)

rgb = np.array(master)
rgba = np.dstack((rgb, alpha))
full_transparent = Image.fromarray(rgba, "RGBA")
# Senior finish: ignore AI-baked shading/shadow, refill the silhouette with a
# clean flat Apple-blue gradient (vector-like, scales to menu-bar sizes).
_sil = full_transparent.getchannel("A").filter(ImageFilter.MaxFilter(3))
_sil = _sil.filter(ImageFilter.GaussianBlur(radius=1.2))
sil_arr = np.array(_sil)
ys, xs = np.where(sil_arr > 10)
h = ys.max() - ys.min() + 1
grad = np.zeros((arr.shape[0], arr.shape[1], 4), dtype=np.uint8)
TOP = np.array([74, 175, 255])     # bright cyan-blue
BOT = np.array([8, 110, 240])      # deep Apple blue
for yy in range(ys.min(), ys.max() + 1):
    t = (yy - ys.min()) / max(h - 1, 1)
    col = (TOP * (1 - t) + BOT * t).astype(np.uint8)
    grad[yy, xs.min():xs.max() + 1, :3] = col
grad[..., 3] = sil_arr
full_transparent = Image.fromarray(grad, "RGBA")
alpha = sil_arr

coords = np.argwhere(alpha > 60)
y0, x0 = coords.min(axis=0)
y1, x1 = coords.max(axis=0)
logo_cropped = full_transparent.crop((max(0, x0 - 20), max(0, y0 - 20), x1 + 20, y1 + 20))

logo_path = os.path.join(ASSETS_DIR, "logo.png")
logo_cropped.save(logo_path)
print(f"Generated {logo_path} ({logo_cropped.size[0]}x{logo_cropped.size[1]})")

# Runtime copy used by Settings > About (Bundle resource "logo.png").
shutil.copyfile(logo_path, os.path.join(RESOURCES_DIR, "logo.png"))
print("Updated macos/NetTracker/Resources/logo.png")

# Tight symbol mark for the app-icon body.
symbol_tight = logo_cropped

# 2. Build 1024x1024 macOS App Icon (squircle body + shadow, transparent canvas).
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
    rr = int(255 - 14 * ratio)
    gg = int(255 - 11 * ratio)
    bb = int(255 - 7 * ratio)
    draw_body.line([(0, y), (ICON_BODY_SIZE, y)], fill=(rr, gg, bb, 255))

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

# 3. Build DMG background images (Apple-blue accents to match identity).
W, H = 1320, 800
dmg_bg = Image.new("RGBA", (W, H), (255, 255, 255, 255))
draw = ImageDraw.Draw(dmg_bg)

for y in range(H):
    rr = int(255 - 12 * (y / H))
    gg = int(255 - 10 * (y / H))
    bb = int(255 - 6 * (y / H))
    draw.line([(0, y), (W, y)], fill=(rr, gg, bb, 255))

for x in range(W):
    ratio = x / W
    rr = int(APPLE_BLUE[0] * (1 - ratio) + APPLE_BLUE_LIGHT[0] * ratio)
    gg = int(APPLE_BLUE[1] * (1 - ratio) + APPLE_BLUE_LIGHT[1] * ratio)
    bb = int(APPLE_BLUE[2] * (1 - ratio) + APPLE_BLUE_LIGHT[2] * ratio)
    draw.line([(x, 0), (x, 6)], fill=(rr, gg, bb, 255))

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
adraw.line([(x_start, y_mid), (x_end - 16, y_mid)], fill=APPLE_BLUE + (80,), width=16)
arrow_img = arrow_img.filter(ImageFilter.GaussianBlur(radius=8))
dmg_bg = Image.alpha_composite(dmg_bg, arrow_img)

draw_arrow = ImageDraw.Draw(dmg_bg)
draw_arrow.line([(x_start, y_mid), (x_end - 18, y_mid)], fill=APPLE_BLUE + (235,), width=8)
arrow_head = [
    (x_end, y_mid),
    (x_end - 38, y_mid - 24),
    (x_end - 28, y_mid),
    (x_end - 38, y_mid + 24),
]
draw_arrow.polygon(arrow_head, fill=APPLE_BLUE + (255,))

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
