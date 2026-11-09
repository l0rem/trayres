# Draws the tray icon pixel-aligned at each size. Usage: uv run --with pillow python res/icon.py res/trayres.ico
import sys
from PIL import Image, ImageDraw
out = sys.argv[1]
GREY, BLUE, WHITE = (150, 160, 175, 255), (37, 120, 235, 255), (255, 255, 255, 255)
def draw(s):
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = max(1, s // 16)
    top, bottom = round(s * 0.12), round(s * 0.74)
    d.rounded_rectangle([0, top, s - 1, bottom], radius=u * 2, fill=GREY)
    d.rectangle([u, top + u, s - 1 - u, bottom - u], fill=BLUE)
    d.rectangle([s // 2 - u, bottom, s // 2 + u - 1, round(s * 0.86)], fill=GREY)
    d.rectangle([round(s * 0.28), round(s * 0.86), s - 1 - round(s * 0.28), round(s * 0.86) + u - 1 + (1 if u == 1 else 0)], fill=GREY)
    # four white corner brackets ("fit to screen")
    x0, y0, x1, y1 = u * 3, top + u * 3, s - 1 - u * 3, bottom - u * 3
    L = max(2, (x1 - x0) // 3)
    for cx, cy, dx, dy in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
        for k in range(u):
            d.line([cx, cy + dy * k, cx + dx * (L - 1), cy + dy * k], fill=WHITE)
            d.line([cx + dx * k, cy, cx + dx * k, cy + dy * (L - 1)], fill=WHITE)
    return im
sizes = [16, 20, 24, 32, 40, 48]
imgs = [draw(s) for s in sizes]
imgs[-1].save(out, format="ICO", sizes=[(s, s) for s in sizes], append_images=imgs[:-1])
