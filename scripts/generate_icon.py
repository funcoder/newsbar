#!/usr/bin/env python3
"""Generate a NewsBar app icon."""

from PIL import Image, ImageDraw, ImageFont
import os
import subprocess
import math

SIZE = 1024

def create_icon():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Rounded rectangle background - dark blue gradient feel
    margin = 80
    radius = 180

    # Draw rounded rect background
    draw.rounded_rectangle(
        [margin, margin, SIZE - margin, SIZE - margin],
        radius=radius,
        fill=(20, 30, 60, 255),
    )

    # Inner glow / lighter layer
    inner_margin = margin + 8
    draw.rounded_rectangle(
        [inner_margin, inner_margin, SIZE - inner_margin, SIZE - inner_margin],
        radius=radius - 8,
        fill=(30, 45, 80, 255),
    )

    # Draw a newspaper/ticker icon
    # Stylized "N" made of bars (like a news ticker)
    cx, cy = SIZE // 2, SIZE // 2

    bar_color = (100, 180, 255, 255)
    accent_color = (255, 140, 50, 255)
    white = (240, 245, 255, 255)

    # Draw horizontal ticker lines (like scrolling news)
    bar_height = 28
    bar_gap = 52
    start_y = cy - 160

    # Top accent bar (orange - breaking news feel)
    draw.rounded_rectangle(
        [cx - 250, start_y - 80, cx + 250, start_y - 80 + 36],
        radius=18,
        fill=accent_color,
    )

    # News ticker lines
    widths = [500, 420, 460, 380, 440]
    for i, w in enumerate(widths):
        y = start_y + i * bar_gap
        x_start = cx - w // 2
        x_end = cx + w // 2
        color = white if i == 0 else bar_color
        draw.rounded_rectangle(
            [x_start, y, x_end, y + bar_height],
            radius=bar_height // 2,
            fill=color,
        )

    # Small dot indicator (like a live indicator)
    dot_r = 18
    dot_x = cx - 250 + dot_r + 8
    dot_y = start_y - 80 + 18
    draw.ellipse(
        [dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r],
        fill=(255, 60, 60, 255),
    )

    return img


def generate_iconset(img, output_dir):
    """Generate .iconset directory with all required sizes."""
    iconset_dir = os.path.join(output_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]

    for size, scale in sizes:
        actual = size * scale
        resized = img.resize((actual, actual), Image.LANCZOS)
        if scale == 1:
            name = f"icon_{size}x{size}.png"
        else:
            name = f"icon_{size}x{size}@{scale}x.png"
        resized.save(os.path.join(iconset_dir, name))

    return iconset_dir


if __name__ == "__main__":
    output_dir = os.path.join(os.path.dirname(__file__), "..")
    img = create_icon()
    iconset_dir = generate_iconset(img, output_dir)
    print(f"Generated iconset at: {iconset_dir}")

    # Convert to .icns
    icns_path = os.path.join(output_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"Generated .icns at: {icns_path}")

    # Cleanup iconset directory
    import shutil
    shutil.rmtree(iconset_dir)
    print("Cleaned up iconset directory")
