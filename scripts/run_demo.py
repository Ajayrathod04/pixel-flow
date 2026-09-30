#!/usr/bin/env python3
"""
PixelFlow paper-aligned end-to-end demonstration.

Pipeline:
  PNG -> 8-bit grayscale MEM -> SystemVerilog RConv/CConv ->
  output MEM -> filtered PNG

The hardware path is configured for:
  M=N=32
  K=L=3
  ROWS_PER_CYCLE=2

The testbench drives consecutive row batches with no idle valid gap,
matching the paper's row-by-row / generalized multiple-rows-per-cycle idea.
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

IMAGE_NAME = "original.png"
WIDTH = 32
HEIGHT = 32
ROWS_PER_CYCLE = 2


def run_pipeline(image_filename, width, height, rows_per_cycle):
    root = Path(__file__).resolve().parents[1]
    examples = root / "examples"
    din = root / "data" / "input"
    dout = root / "data" / "output"
    modelsim = root / "modelsim"
    din.mkdir(parents=True, exist_ok=True)
    dout.mkdir(parents=True, exist_ok=True)

    src = examples / image_filename
    if not src.exists():
        src = Path(image_filename).resolve()
    if not src.exists():
        raise FileNotFoundError(f"Image not found: {src}")

    stem = src.stem
    in_mem = din / f"{stem}.mem"
    out_mem = dout / f"{stem}_output.mem"
    out_png = dout / f"{stem}_filtered.png"

    prep = [
        sys.executable, str(root / "scripts" / "prepare_image.py"),
        str(src), str(in_mem), "--width", str(width), "--height", str(height)
    ]
    r = subprocess.run(prep, text=True, capture_output=True)
    if r.returncode:
        print(r.stdout)
        print(r.stderr)
        raise RuntimeError("prepare_image.py failed")

    vsim = shutil.which("vsim")
    if not vsim:
        raise RuntimeError("vsim not found. Run from a ModelSim/Questa command prompt.")

    do_cmd = (
        f"do run_real_image.do {width} {height} {rows_per_cycle} "
        f"../data/input/{stem}.mem ../data/output/{stem}_output.mem"
    )
    r = subprocess.run([vsim, "-c", "-do", do_cmd],
                       cwd=str(modelsim), text=True, capture_output=True)
    print(r.stdout)
    if r.stderr:
        print(r.stderr)

    if r.returncode or "0 MISMATCHES" not in (r.stdout + r.stderr).upper():
        raise RuntimeError("Hardware simulation failed or did not report 0 mismatches")

    recon = [
        sys.executable, str(root / "scripts" / "reconstruct.py"),
        str(out_mem), str(out_png), "--width", str(width), "--height", str(height)
    ]
    r = subprocess.run(recon, text=True, capture_output=True)
    if r.returncode:
        print(r.stdout)
        print(r.stderr)
        raise RuntimeError("reconstruct.py failed")

    print("====================================================")
    print("PixelFlow PAPER-ALIGNED END-TO-END DEMO")
    print("====================================================")
    print(f"Image             : {src.name}")
    print(f"Image size        : {width} x {height}")
    print("Filter            : K=L=3, H=[1 2 1], V=[1 2 1]^T")
    print(f"Rows per clock    : {rows_per_cycle}")
    print("Paper latency     : K+L-1 = 5 cycles (architecture convention)")
    print("Simulation        : PASS - 0 mismatches")
    print(f"Output MEM        : {out_mem.relative_to(root)}")
    print(f"Filtered PNG      : {out_png.relative_to(root)}")
    print("====================================================")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", default=IMAGE_NAME)
    ap.add_argument("--width", type=int, default=WIDTH)
    ap.add_argument("--height", type=int, default=HEIGHT)
    ap.add_argument("--rows-per-cycle", type=int, default=ROWS_PER_CYCLE)
    a = ap.parse_args()
    run_pipeline(a.image, a.width, a.height, a.rows_per_cycle)


if __name__ == "__main__":
    main()
