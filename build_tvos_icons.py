#!/usr/bin/env python3
"""Generate tvOS Brand Assets (App Icon + Top Shelf) from the macOS icon.

The macOS icon is a 1024x1024 PNG with three colors: dark navy background,
muted gray-green "0" character, and bright accent-green "1" character. We
color-key it into three parallax layers so on Apple TV the bright "1"
floats above the dim "0" floats above the navy background.
"""
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).parent
SOURCE = ROOT / "Octant/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
BRAND = ROOT / "Octant/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

BG_COLOR = (8, 10, 18, 255)
ZERO_COLOR_HINT = (120, 150, 140)
ONE_COLOR_HINT = (43, 255, 158)


def classify(rgb):
    """Return 'bg', 'zero', or 'one' for an (r,g,b) pixel."""
    r, g, b = rgb[0], rgb[1], rgb[2]
    if r + g + b < 60:
        return "bg"
    if (g - r) > 80 and g > 130:
        return "one"
    return "zero"


def split_layers(src):
    """Return three RGBA images (back/middle/front) at the source size."""
    w, h = src.size
    pixels = src.load()
    back = Image.new("RGBA", (w, h), BG_COLOR)
    middle = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    front = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    middle_pixels = middle.load()
    front_pixels = front.load()
    for y in range(h):
        for x in range(w):
            px = pixels[x, y]
            klass = classify(px)
            if klass == "zero":
                middle_pixels[x, y] = (px[0], px[1], px[2], 255)
            elif klass == "one":
                front_pixels[x, y] = (px[0], px[1], px[2], 255)
    return back, middle, front


def fit_square_into(canvas_w, canvas_h, layer):
    """Fit a square layer into a wider canvas, centered, with transparent padding.
    Background layer is special-cased to fill the entire canvas with BG_COLOR."""
    target = min(canvas_w, canvas_h)
    scaled = layer.resize((target, target), Image.LANCZOS)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    x = (canvas_w - target) // 2
    y = (canvas_h - target) // 2
    canvas.paste(scaled, (x, y), scaled)
    return canvas


def fit_back(canvas_w, canvas_h):
    return Image.new("RGBA", (canvas_w, canvas_h), BG_COLOR)


def write_imageset(dst_dir, png_filename, idiom, scale, size_str=None):
    dst_dir.mkdir(parents=True, exist_ok=True)
    img_entry = {
        "filename": png_filename,
        "idiom": idiom,
        "scale": scale,
    }
    contents = {"images": [img_entry], "info": {"author": "xcode", "version": 1}}
    (dst_dir / "Contents.json").write_text(json.dumps(contents, indent=2))


def write_imageset_topshelf(dst_dir, png_filename, idiom):
    dst_dir.mkdir(parents=True, exist_ok=True)
    contents = {
        "images": [{"filename": png_filename, "idiom": idiom, "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }
    (dst_dir / "Contents.json").write_text(json.dumps(contents, indent=2))


def build_imagestack(stack_dir, size, middle_layer, front_layer):
    """Create a 3-layer parallax imagestack at the given size (w, h).

    Order: Back (deepest) → Middle → Front (closest)."""
    w, h = size
    stack_dir.mkdir(parents=True, exist_ok=True)
    # actool treats the FIRST entry in layers[] as the topmost (closest to
    # the viewer, biggest parallax movement) and the LAST entry as the
    # bottommost background layer, which must be fully opaque.
    layers_meta = []
    layer_specs = [
        ("Front", fit_square_into(w, h, front_layer)),
        ("Middle", fit_square_into(w, h, middle_layer)),
        ("Back", fit_back(w, h)),
    ]
    for name, image in layer_specs:
        layer_dir = stack_dir / f"{name}.imagestacklayer"
        content_dir = layer_dir / "Content.imageset"
        content_dir.mkdir(parents=True, exist_ok=True)
        png_name = f"{name.lower()}.png"
        image.save(content_dir / png_name)
        # Content.imageset/Contents.json
        (content_dir / "Contents.json").write_text(json.dumps({
            "images": [{"filename": png_name, "idiom": "tv", "scale": "1x"}],
            "info": {"author": "xcode", "version": 1},
        }, indent=2))
        # imagestacklayer/Contents.json
        (layer_dir / "Contents.json").write_text(json.dumps({
            "info": {"author": "xcode", "version": 1},
            "properties": {},
        }, indent=2))
        layers_meta.append({"filename": f"{name}.imagestacklayer"})
    # imagestack/Contents.json
    (stack_dir / "Contents.json").write_text(json.dumps({
        "info": {"author": "xcode", "version": 1},
        "layers": layers_meta,
        "properties": {},
    }, indent=2))


def build_topshelf(imageset_dir, size, middle_layer, front_layer):
    """Composite a flat top-shelf image at the given size."""
    w, h = size
    composite = fit_back(w, h)
    composite.alpha_composite(fit_square_into(w, h, middle_layer))
    composite.alpha_composite(fit_square_into(w, h, front_layer))
    imageset_dir.mkdir(parents=True, exist_ok=True)
    png_name = "topshelf.png"
    composite.convert("RGB").save(imageset_dir / png_name, optimize=True)
    (imageset_dir / "Contents.json").write_text(json.dumps({
        "images": [{"filename": png_name, "idiom": "tv", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))


def main():
    src = Image.open(SOURCE).convert("RGBA")
    print(f"Loaded source {src.size}")
    _back, middle, front = split_layers(src)

    # Wipe brandassets contents (preserve directory)
    if BRAND.exists():
        for child in BRAND.iterdir():
            if child.is_dir():
                import shutil
                shutil.rmtree(child)
            else:
                child.unlink()
    BRAND.mkdir(parents=True, exist_ok=True)

    # Top-level brandassets Contents.json
    (BRAND / "Contents.json").write_text(json.dumps({
        "assets": [
            {"filename": "App Icon - Large.imagestack",
             "idiom": "tv",
             "role": "primary-app-icon",
             "size": "1280x768"},
            {"filename": "App Icon - Small.imagestack",
             "idiom": "tv",
             "role": "primary-app-icon",
             "size": "400x240"},
            {"filename": "Top Shelf Image.imageset",
             "idiom": "tv",
             "role": "top-shelf-image",
             "size": "1920x720"},
            {"filename": "Top Shelf Image Wide.imageset",
             "idiom": "tv",
             "role": "top-shelf-image-wide",
             "size": "2320x720"},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))

    print("Building Large App Icon (1280x768)…")
    build_imagestack(BRAND / "App Icon - Large.imagestack",
                     (1280, 768), middle, front)

    print("Building Small App Icon (400x240)…")
    build_imagestack(BRAND / "App Icon - Small.imagestack",
                     (400, 240), middle, front)

    print("Building Top Shelf Image (1920x720)…")
    build_topshelf(BRAND / "Top Shelf Image.imageset",
                   (1920, 720), middle, front)

    print("Building Top Shelf Image Wide (2320x720)…")
    build_topshelf(BRAND / "Top Shelf Image Wide.imageset",
                   (2320, 720), middle, front)

    print("Done.")


if __name__ == "__main__":
    main()
