#!/usr/bin/env python3
"""
PixelFlow - Script 1: prepare_image.py
======================================
Purpose:
  Convert a standard image file (PNG/JPEG/BMP/etc.) into an 8-bit grayscale
  hexadecimal memory initialization (.mem) file for the SystemVerilog testbench.

IMPORTANT EDUCATIONAL NOTE FOR DEMONSTRATION:
  This Python script DOES NOT perform any image filtering or convolution!
  Python is solely responsible for image acquisition, grayscale conversion,
  resizing, and format serialization into a .mem file.
  The actual 2D separable [1 2 1] x [1 2 1] image convolution filtering is
  performed strictly by SystemVerilog hardware modules (row_convolver & column_convolver)
  inside ModelSim.

Usage:
  python scripts/prepare_image.py data/input/original.png data/input/input.mem --width 32 --height 32
"""

import argparse
import sys
from pathlib import Path
from PIL import Image


def prepare_image(input_image_path: str, output_mem_path: str, width: int, height: int) -> None:
    # -------------------------------------------------------------------------
    # STEP 1: Determine Input and Output Paths
    # -------------------------------------------------------------------------
    input_path = Path(input_image_path).resolve()
    output_path = Path(output_mem_path).resolve()

    if not input_path.exists():
        raise FileNotFoundError(f"Input image file not found: {input_path}")

    # Ensure output parent directory exists (e.g., data/input/)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # -------------------------------------------------------------------------
    # STEP 2: Validate Input Resolution Parameters
    # -------------------------------------------------------------------------
    if width <= 0 or height <= 0:
        raise ValueError(f"Width ({width}) and Height ({height}) must be positive integers > 0.")

    expected_pixels = width * height

    # -------------------------------------------------------------------------
    # STEP 3: Open the Input Image using Pillow (PIL)
    # -------------------------------------------------------------------------
    with Image.open(input_path) as img:
        # ---------------------------------------------------------------------
        # STEP 4: Convert Image to 8-bit Grayscale ('L' mode: 0=black, 255=white)
        # ---------------------------------------------------------------------
        grayscale_img = img.convert('L')

        # ---------------------------------------------------------------------
        # STEP 5: Resize Image to Target Width and Height (32x32 default)
        # ---------------------------------------------------------------------
        resized_img = grayscale_img.resize((width, height), Image.Resampling.LANCZOS)

        # ---------------------------------------------------------------------
        # STEP 6 & 7: Convert Pixels to 8-bit Hex and Write to .mem File
        # ---------------------------------------------------------------------
        # Each line in the MEM file represents one 8-bit pixel in hexadecimal (00 to FF).
        lines = []
        for y in range(height):
            for x in range(width):
                pixel_val = resized_img.getpixel((x, y))
                # Ensure 8-bit clamping (0..255) and format as 2-digit uppercase HEX
                pixel_hex = f"{max(0, min(255, pixel_val)):02X}"
                lines.append(pixel_hex + '\n')

        # Write all lines to the target .mem file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.writelines(lines)

    # -------------------------------------------------------------------------
    # STEP 8: Validate the Generated MEM File Pixel Count
    # -------------------------------------------------------------------------
    actual_lines = len(lines)
    if actual_lines != expected_pixels:
        raise RuntimeError(
            f"MEM generation mismatch: expected {expected_pixels} pixels, but wrote {actual_lines}."
        )

    # -------------------------------------------------------------------------
    # Print Clear Summary for Live Demonstration
    # -------------------------------------------------------------------------
    print("========================================")
    print("PixelFlow Image Preparation")
    print("========================================")
    print(f"Input image : {input_path}")
    print(f"Output MEM  : {output_path}")
    print(f"Resolution  : {width} x {height}")
    print(f"Format      : 8-bit grayscale")
    print(f"Pixels      : {actual_lines}")
    print("========================================")
    print("MEM file generated successfully.")
    print("========================================")


def main():
    parser = argparse.ArgumentParser(
        description="Convert input image into 8-bit grayscale MEM format for SystemVerilog ModelSim filter."
    )
    parser.add_argument("input_image", help="Path to input image file (e.g. data/input/original.png)")
    parser.add_argument("output_mem", help="Path to output MEM file (e.g. data/input/input.mem)")
    parser.add_argument("--width", type=int, default=32, help="Target image width in pixels (default: 32)")
    parser.add_argument("--height", type=int, default=32, help="Target image height in pixels (default: 32)")

    args = parser.parse_args()

    try:
        prepare_image(args.input_image, args.output_mem, args.width, args.height)
    except Exception as err:
        print(f"ERROR: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
