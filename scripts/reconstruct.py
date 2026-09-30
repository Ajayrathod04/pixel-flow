#!/usr/bin/env python3
"""
PixelFlow - Script 2: reconstruct.py
====================================
Purpose:
  Read the output .mem file produced by the ModelSim SystemVerilog simulation
  and reconstruct it back into a standard PNG image file.

IMPORTANT EDUCATIONAL NOTE FOR DEMONSTRATION:
  This Python script DOES NOT perform any image filtering or convolution!
  The filtering was performed by SystemVerilog hardware modules in ModelSim.
  This script's role is strictly output reconstruction: converting raw hexadecimal
  pixel data from output.mem into a viewable PNG format.

Usage:
  python scripts/reconstruct.py data/output/output.mem data/output/filtered.png --width 32 --height 32
"""

import argparse
import sys
from pathlib import Path
from PIL import Image


def reconstruct_image(input_mem_path: str, output_png_path: str, width: int, height: int) -> None:
    # -------------------------------------------------------------------------
    # STEP 1: Determine Input MEM and Output PNG Paths
    # -------------------------------------------------------------------------
    input_path = Path(input_mem_path).resolve()
    output_path = Path(output_png_path).resolve()

    if not input_path.exists():
        raise FileNotFoundError(f"Input MEM file not found: {input_path}")

    # Ensure output parent directory exists (e.g., data/output/ or examples/)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # -------------------------------------------------------------------------
    # STEP 2: Validate Target Image Dimensions
    # -------------------------------------------------------------------------
    if width <= 0 or height <= 0:
        raise ValueError(f"Width ({width}) and Height ({height}) must be positive integers > 0.")

    expected_pixels = width * height

    # -------------------------------------------------------------------------
    # STEP 3: Read MEM File, Ignore Blank Lines, & Parse Hexadecimal Values
    # -------------------------------------------------------------------------
    raw_content = input_path.read_text(encoding='utf-8')
    tokens = raw_content.split()  # Splits on whitespace, automatically ignoring blank lines

    pixel_values = []
    for token in tokens:
        # Parse hex string (e.g., '00', '7F', 'FF') to integer
        val = int(token, 16)
        # ---------------------------------------------------------------------
        # STEP 4: Convert and Clamp Values to 8-bit Grayscale Range (0..255)
        # ---------------------------------------------------------------------
        clamped_val = max(0, min(255, val))
        pixel_values.append(clamped_val)

    # -------------------------------------------------------------------------
    # STEP 5: Validate Pixel Count Matches width * height
    # -------------------------------------------------------------------------
    actual_pixels = len(pixel_values)
    if actual_pixels != expected_pixels:
        raise RuntimeError(
            f"MEM read mismatch in '{input_path.name}': "
            f"expected {expected_pixels} pixels ({width}x{height}), but found {actual_pixels} pixels."
        )

    # -------------------------------------------------------------------------
    # STEP 6 & 7: Reshape Pixels into Width x Height Image and Save as PNG
    # -------------------------------------------------------------------------
    img = Image.new('L', (width, height))
    pixel_map = img.load()

    idx = 0
    for y in range(height):
        for x in range(width):
            pixel_map[x, y] = pixel_values[idx]
            idx += 1

    img.save(output_path, format='PNG')

    # -------------------------------------------------------------------------
    # STEP 8: Print Summary Report for Live Demonstration
    # -------------------------------------------------------------------------
    print("========================================")
    print("PixelFlow MEM Reconstruction")
    print("========================================")
    print(f"Input MEM   : {input_path}")
    print(f"Output PNG  : {output_path}")
    print(f"Resolution  : {width} x {height}")
    print(f"Pixels read : {actual_pixels}")
    print(f"Format      : 8-bit grayscale")
    print("========================================")
    print("Filtered image reconstructed successfully.")
    print("========================================")


def main():
    parser = argparse.ArgumentParser(
        description="Reconstruct ModelSim output MEM file into a viewable PNG image."
    )
    parser.add_argument("input_mem", help="Path to input MEM file (e.g. data/output/output.mem)")
    parser.add_argument("output_png", help="Path to output PNG image (e.g. data/output/filtered.png)")
    parser.add_argument("--width", type=int, default=32, help="Target image width in pixels (default: 32)")
    parser.add_argument("--height", type=int, default=32, help="Target image height in pixels (default: 32)")

    args = parser.parse_args()

    try:
        reconstruct_image(args.input_mem, args.output_png, args.width, args.height)
    except Exception as err:
        print(f"ERROR: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
