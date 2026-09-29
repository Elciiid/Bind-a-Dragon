"""Assemble preview GIFs from frames rendered by preview.py --all (run with normal Python + Pillow).

    python tools/dragon_rig/make_gifs.py <frames_dir> <out_dir> <DragonA> [<DragonB> ...] [--view persp] [--step 2]

Expects <frames_dir>/<Dragon>_<Action>_<view>_fNNN.png (preview.py with out prefix <frames_dir>/<Dragon>). Writes one
GIF per action to <out_dir>/<Action>.gif with the dragons side by side, playing at 30 / step fps (real time).
"""

import glob
import os
import re
import sys

from PIL import Image, ImageDraw

args = sys.argv[1:]
view = "persp"
step = 2
if "--view" in args:
    i = args.index("--view"); view = args[i + 1]; del args[i:i + 2]
if "--step" in args:
    i = args.index("--step"); step = int(args[i + 1]); del args[i:i + 2]
frames_dir, out_dir, dragons = args[0], args[1], args[2:]
os.makedirs(out_dir, exist_ok=True)

actions = sorted({re.match(rf"{dragons[0]}_(Dragon_\w+?)_{view}_f\d+\.png", os.path.basename(f)).group(1)
                  for f in glob.glob(os.path.join(frames_dir, f"{dragons[0]}_Dragon_*_{view}_f*.png"))})
for action in actions:
    per = [sorted(glob.glob(os.path.join(frames_dir, f"{d}_{action}_{view}_f*.png"))) for d in dragons]
    n = min(len(p) for p in per)
    out = []
    for k in range(n):
        ims = [Image.open(p[k]).convert("RGB") for p in per]
        w, h = ims[0].size
        frame = Image.new("RGB", (w * len(ims), h))
        for j, im in enumerate(ims):
            frame.paste(im, (j * w, 0))
            ImageDraw.Draw(frame).text((j * w + 8, 8), f"{dragons[j]}  {action}", fill=(255, 255, 255))
        out.append(frame.quantize(colors=160, method=Image.Quantize.MEDIANCUT))
    if len(out) > 2 and list(Image.open(per[0][0]).getdata()) == list(Image.open(per[0][-1]).getdata()):
        out = out[:-1]  # a loop: the last frame equals the first, drop it so the GIF doesn't hitch
    path = os.path.join(out_dir, f"{action}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=int(1000 * step / 30), loop=0, optimize=True)
    print("wrote", path, len(out), "frames")
