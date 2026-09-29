"""The standard dragon animation set, built procedurally onto a rig made by rerig.py (bone names from template.py).

    blender -b <rig.blend> --python tools/dragon_rig/animate.py -- [--save <out.blend>] [--only Dragon_Idle,...]
        [--library <DragonAnimations.blend>] [--fbx-dir <dir>]

--library writes a .blend holding only the actions (apply_actions.py copies them onto other rigs unchanged);
--fbx-dir exports each action as its own FBX (armature + that animation) for Roblox's animation import.

Every action is generic (Dragon_<Name>, not per species) and uses only the template's bone names and axis
conventions, so the same actions play on every re-rigged dragon. 30 fps, in place (no root motion: the game moves
the dragon; the Root bone only rotates, plus a small vertical crouch/heave/hop). Loops are seamless (the last frame
equals the first). Timeline markers (action pose markers) name where Roblox fires effects: FX_Flap (each downbeat),
FX_TakeOff, FX_Land, FX_Roar, FX_Burst, FX_Sneeze, FX_LevelUp, FX_Attack, FX_Hit. The same data is written to
tools/dragon_rig/animations.json.

How the motion is made: each action is a function of time giving the "driver" pose (key poses eased into each other,
or periodic waves for loops); follow-through comes from delaying bones further down a chain (neck -> head, wing
Upper -> Tip, tail base -> tip) and, for one-shots, a soft spring on every bone (tips springier) that adds a slight
overshoot and settle. Angles are degrees in the template conventions (template.py):
  body bones: X + = nose-down sense (head/neck down, tail tip up, legs swing back), Z + = tip toward the dragon's right
  wings: flap (+ = tip up), sweep (+ = tip back), twist (+ = leading edge up); the right wing is mirrored here.
Element personality (fire punchy, ice slow...) is meant to come from playback speed/weight in the game's config.
"""

import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import template as T  # noqa: E402

FPS = 30
REFERENCE_HEIGHT = 8.0  # studs; Root crouch/heave distances are shares of this (an Elder's height), the same on every rig
SIDES = (("L", 1), ("R", -1))

# ---------------------------------------------------------------------------------------------------------------
# Pose helpers. A pose is {bone: [x, y, z]} in degrees; poses add.


def P(**kw):
    return {k: list(v) for k, v in kw.items()}


def add(*poses, scale=1.0):
    out = {}
    for pose in poses:
        for bone, v in pose.items():
            cur = out.setdefault(bone, [0.0, 0.0, 0.0])
            for i in range(3):
                cur[i] += v[i] * scale
    return out


def mul(pose, k):
    return {b: [c * k for c in v] for b, v in pose.items()}


def lerp_pose(a, b, t):
    bones = set(a) | set(b)
    z = [0.0, 0.0, 0.0]
    return {x: [a.get(x, z)[i] + (b.get(x, z)[i] - a.get(x, z)[i]) * t for i in range(3)] for x in bones}


def wing(seg, flap=0.0, sweep=0.0, twist=0.0, sides=("L", "R")):
    """Both wings (mirrored) for one segment: Upper, Fore, Hand, Tip."""
    out = {}
    for side, s in SIDES:
        if side in sides:
            out[f"Wing_{side}_{seg}"] = [flap, twist * s, sweep * s]
    return out


def wings(**segs):
    """wings(Upper=(flap, sweep, twist), Fore=...)"""
    out = {}
    for seg, v in segs.items():
        flap, sweep, twist = (list(v) + [0, 0, 0])[:3]
        out.update(wing(seg, flap, sweep, twist))
    return out


def legs(which, upper=0.0, lower=0.0, foot=0.0, splay=0.0):
    """which = "F" (front pair) or "B" (back pair). X + = swing back. splay + = foot outward."""
    out = {}
    for side, s in SIDES:
        leg = f"{which}{side}"
        out[f"Leg_{leg}_Upper"] = [upper, 0.0, -splay * s]
        out[f"Leg_{leg}_Lower"] = [lower, 0.0, 0.0]
        out[f"Leg_{leg}_Foot"] = [foot, 0.0, 0.0]
    return out


def chain(bones_, x=0.0, y=0.0, z=0.0, grow=0.0):
    """Spreads a rotation over a chain: each bone gets (x, y, z) * (1 + grow * index)."""
    out = {}
    for i, b in enumerate(bones_):
        k = 1 + grow * i
        out[b] = [x * k, y * k, z * k]
    return out


NECK = ["Neck1", "Neck2", "Neck3"]
TAIL = [f"Tail{i}" for i in range(1, 7)]
SPINE = ["Spine1", "Spine2", "Spine3"]

# Depth of each bone in its chain (for follow-through delays and springs).
DEPTH = {"Root": 0, "Spine1": 0, "Spine2": 1, "Spine3": 2, "Neck1": 2, "Neck2": 3, "Neck3": 4, "Head": 5, "Jaw": 6}
for i in range(6):
    DEPTH[f"Tail{i + 1}"] = 1 + i
for side, _ in SIDES:
    for i, seg in enumerate(("Upper", "Fore", "Hand", "Tip")):
        DEPTH[f"Wing_{side}_{seg}"] = i
for leg in ("FL", "FR", "BL", "BR"):
    for i, seg in enumerate(("Upper", "Lower", "Foot")):
        DEPTH[f"Leg_{leg}_{seg}"] = i

# ---------------------------------------------------------------------------------------------------------------
# Key poses (from the canonical rest pose: wings spread, legs as modeled)

# Wings folded along the back, a little raised: the ground pose (Idle, Roar start, Land end).
WINGS_FOLDED = wings(Upper=(38, 66, 0), Fore=(-45, 0, 0), Hand=(25, 0, 0), Tip=(8, 0, 0))
# Wings half open (Roar, proud stance)
WINGS_HALF = wings(Upper=(28, 22, 5), Fore=(-10, 20, 0), Hand=(0, -25, 0), Tip=(0, -8, 0))
# Wings wide ("star pose", Glide base): slight dihedral, tips spread
# (more dihedral, the Hand/Tip fanned forward and twisted up: the membrane is spread wide and reads from the front)
WINGS_WIDE = wings(Upper=(14, -8, 0), Fore=(2, -6, 3), Hand=(6, -24, 8), Tip=(12, -40, 10))
# Wings wrapped around the body (Reveal: curled in a ball)
WINGS_WRAPPED = wings(Upper=(-20, -55, 30), Fore=(-40, 40, 0), Hand=(-30, 70, 0), Tip=(-20, 30, 0))

# Legs tucked for flight
LEGS_TUCKED = add(legs("B", upper=60, lower=-20, foot=50), legs("F", upper=45, lower=70, foot=40))
# Legs reaching down/forward to land
LEGS_REACH = add(legs("B", upper=-20, lower=10, foot=-15), legs("F", upper=-25, lower=-10, foot=-10))
# Crouch before take off (knees bend; paired with a Root drop)
LEGS_CROUCH = add(legs("B", upper=-22, lower=35, foot=-18), legs("F", upper=-18, lower=30, foot=-14))
# Curled in a ball (Reveal)
LEGS_CURLED = add(legs("B", upper=-40, lower=60, foot=20), legs("F", upper=45, lower=-70, foot=30))

# Flight body: neck stretched forward/level, tail streaming back
FLIGHT_BODY = add(chain(NECK, x=-4), P(Head=(6, 0, 0)), chain(TAIL, x=-3, grow=0.1))

GROUND = add(WINGS_FOLDED)
FLIGHT = add(WINGS_WIDE, LEGS_TUCKED, FLIGHT_BODY)

# ---------------------------------------------------------------------------------------------------------------
# Timing helpers


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * t * (t * (t * 6 - 15) + 10)


def keyed(keys, t):
    """keys = [(time, pose), ...] eased (smootherstep) from key to key; holds outside the range."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            return lerp_pose(a, b, smooth((t - t0) / max(t1 - t0, 1e-6)))
    return keys[-1][1]


def wave(t, period, phase=0.0):
    return math.sin(2 * math.pi * t / period - phase)


def flap_wave(t, period, down_share=0.42, phase=0.0):
    """+1 at the top of the stroke, -1 at the bottom; the downstroke takes down_share of the cycle (power), the
    upstroke the rest (softer, floatier). Smooth everywhere."""
    u = ((t / period) - phase / (2 * math.pi)) % 1.0
    if u < down_share:
        return math.cos(math.pi * u / down_share)
    return -math.cos(math.pi * (u - down_share) / (1 - down_share))


# ---------------------------------------------------------------------------------------------------------------
# The actions. Each returns (frames, loop, driver(t) -> pose, markers {name: [frames]}, follow {delay per depth, spring})


def flight_wings(t, period, amp=1.0, base=0.0, phase=0.0):
    """One flap cycle for FlyLoop / TakeOff / Land: power downstroke, soft upstroke with the wing partly folding,
    the outer segments lagging (wingtips trail the beat)."""
    out = {}
    lag = {"Upper": 0.0, "Fore": 0.45, "Hand": 0.9, "Tip": 1.3}
    # the shoulder rises less than it falls (less membrane stretch at the top of the beat); the outer segments bend
    # more on the way up instead, so the stroke still reads big. The wing also sweeps back a little at the top.
    gain_up = {"Upper": 18, "Fore": 12, "Hand": 9, "Tip": 7}
    gain_down = {"Upper": 26, "Fore": 10, "Hand": 7, "Tip": 6}
    for seg in ("Upper", "Fore", "Hand", "Tip"):
        f = flap_wave(t, period, phase=phase + lag[seg])
        up = max(0.0, flap_wave(t, period, phase=phase + lag[seg] + 0.6))  # the upstroke half
        flap = (base + (5 if seg == "Upper" else 0)) + amp * (gain_up if f > 0 else gain_down)[seg] * f
        sweep = amp * {"Upper": 4 * max(f, 0.0) + 6 * min(f, 0.0), "Fore": 14 * up, "Hand": -18 * up,
                       "Tip": -10 * up}[seg]
        twist = amp * {"Upper": 4 * f, "Fore": 6 * f, "Hand": 8 * f, "Tip": 6 * f}[seg]
        out.update(wing(seg, flap, sweep, twist))
    return out


def flap_heave(t, period, amp=1.0, phase=0.0):
    """Body reaction to the beat: the chest lifts on the downstroke, the neck/head stay steady, the tail trails."""
    f = flap_wave(t, period, phase=phase + 0.4)
    out = add(P(Root=(2.5 * f * amp, 0, 0)), chain(SPINE, x=-1.0 * f * amp),
              chain(NECK, x=-1.2 * f * amp), P(Head=(-1.5 * f * amp, 0, 0)))
    for i, b in enumerate(TAIL):
        out[b] = [4 * amp * flap_wave(t, period, phase=phase + 1.0 + 0.45 * i), 0.0, 0.0]
    return out


def idle():
    T_ = 4.0

    def drive(t):
        breath = wave(t, T_ / 2)  # two breaths per loop
        look = wave(t, T_)
        look = math.copysign(abs(look) ** 0.55, look)  # linger when looking to a side
        nod = wave(t, T_ / 2, 1.2)
        # an occasional wing shuffle: the wings lift, flutter and settle once per loop (zero at the loop ends)
        u = (t - 2.35) / 0.8
        shuffle = math.sin(math.pi * u) if 0 < u < 1 else 0.0
        flutter = shuffle * math.sin(2 * math.pi * 6 * (t - 2.35))
        pose = add(GROUND,
                   chain(SPINE, x=-2.2 * breath), P(Root=(0, 1.8 * wave(t, T_, 0.8), 0)),
                   chain(NECK, x=-3.0 * breath + 3 * nod, z=14 * look), P(Head=(4 * nod, 0, 16 * look)),
                   P(Jaw=(2.0 * max(0.0, breath), 0, 0)),
                   wings(Upper=(4 * breath + 12 * shuffle, -6 * shuffle, 0), Fore=(-2 * breath, 0, 0),
                         Hand=(5 * flutter, 0, 0), Tip=(7 * flutter, 0, 0)),
                   legs("F", upper=1.2 * wave(t, T_, 0.8)), legs("B", upper=-1.2 * wave(t, T_, 0.8)))
        for i, b in enumerate(TAIL):  # a slow curl traveling down the tail
            pose = add(pose, {b: [2.5 * wave(t, T_, 0.6 + 0.5 * i), 0, 5 + 7 * wave(t, T_, 0.5 * i)]})
        return pose
    return 120, True, drive, {}, None


def fly_loop():
    period = 1.2

    def drive(t):
        return add(FLIGHT, flight_wings(t, period), flap_heave(t, period),
                   chain(TAIL, z=2.5 * wave(t, period, 0.3), grow=0.3))
    # downbeat = middle of the downstroke (the power moment)
    return 36, True, drive, {"FX_Flap": [int(round(0.21 * period * FPS))]}, None


def glide():
    T_ = 3.0

    def drive(t):
        bank = wave(t, T_)
        pose = add(FLIGHT,
                   P(Root=(1.5 * wave(t, T_ / 2), 0, 4 * bank)),
                   wings(Upper=(3 * wave(t, T_ / 2, 0.3), 2 * wave(t, T_, 1.0), 2 * wave(t, T_ / 2)),
                         Hand=(2.5 * wave(t, T_ / 2, 0.9), 0, 0), Tip=(3.5 * wave(t, T_ / 2, 1.3), 3 * wave(t, T_, 1.4), 0)),
                   chain(NECK, x=1.2 * wave(t, T_ / 2, 0.5), z=-3 * bank), P(Head=(0, 0, -4 * bank)))
        for i, b in enumerate(TAIL):
            pose = add(pose, {b: [1.5 * wave(t, T_ / 2, 0.4 + 0.4 * i), 0, 3.5 * wave(t, T_, 0.8 + 0.45 * i)]})
        return pose
    return 90, True, drive, {}, None


def take_off():
    # 0.00-0.33 crouch + wings rise (anticipation); 0.33-0.50 burst: wings slam down, legs push, neck up;
    # 0.50-1.50 two strong beats while the legs tuck, ending in the FlyLoop start pose.
    period = 0.5
    raised = add(GROUND, wings(Upper=(60, -10, 0), Fore=(10, -30, 0), Hand=(5, -20, 0), Tip=(0, -10, 0)))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.28, add(raised, LEGS_CROUCH, chain(NECK, x=6), P(Head=(5, 0, 0)),
                                                  P(Root=(4, 0, 0)))),
                      (0.45, add(WINGS_WIDE, wings(Upper=(-38, 12, 0)), legs("B", upper=18, lower=-10, foot=25),
                                 legs("F", upper=12, lower=-15, foot=10), chain(NECK, x=-9), P(Head=(-6, 0, 0)),
                                 P(Root=(-10, 0, 0)))),
                      (0.9, add(WINGS_WIDE, add(LEGS_TUCKED, scale=0.7), FLIGHT_BODY, P(Root=(-6, 0, 0)))),
                      (1.5, FLIGHT)], t)
        if t > 0.5:  # beats after the burst, ramping into the loop's own beat (same phase at the end)
            k = smooth((t - 0.5) / 0.25)
            k *= 1.25 - 0.25 * smooth((t - 1.0) / 0.5)  # extra strong beats, easing to the FlyLoop's strength
            beats = flight_wings(t - 0.5 + 0.0, period, amp=k)
            base = add(base, beats, flap_heave(t - 0.5, period, amp=min(k, 1.0)))
        return base
    fx = {"FX_TakeOff": [int(0.42 * FPS)], "FX_Flap": [int(0.42 * FPS), int((0.5 + 0.21 * period) * FPS),
                                                       int((1.0 + 0.21 * period) * FPS)]}
    return 45, False, drive, fx, {"delay": 1.3, "spring": True, "root_drop": [(0.0, 0.0), (0.28, -0.05), (0.42, 0.02),
                                                                                (0.6, 0.0)]}


def land():
    # 0.0-0.55 flare: nose up, wings forward/up to brake, two quick braking beats, legs reach down;
    # 0.9 touch down (FX_Land), absorb, 1.1-1.5 settle and fold the wings (ends in the Idle start pose)
    flare = add(wings(Upper=(18, -24, 18), Fore=(6, -18, 10), Hand=(8, -10, 6), Tip=(10, -6, 0)), LEGS_REACH,
                chain(NECK, x=-5), P(Head=(10, 0, 0)), P(Root=(-12, 0, 0)), chain(TAIL, x=7, grow=0.2))
    touch = add(WINGS_HALF, LEGS_CROUCH, chain(NECK, x=8), P(Head=(6, 0, 0)), P(Root=(5, 0, 0)))

    def drive(t):
        base = keyed([(0.0, FLIGHT), (0.45, flare), (0.8, add(flare, P(Root=(6, 0, 0)))),
                      (0.95, touch), (1.15, add(GROUND, mul(LEGS_CROUCH, 0.3))), (1.5, GROUND)], t)
        if t < 0.85:
            k = 1 - smooth((t - 0.55) / 0.3)
            base = add(base, flight_wings(t, 0.4, amp=0.9 * k, phase=0.0))
        return base
    fx = {"FX_Flap": [int(0.08 * FPS), int(0.48 * FPS)], "FX_Land": [int(0.93 * FPS)]}
    return 45, False, drive, fx, {"delay": 1.2, "spring": True, "root_drop": [(0.0, 0.0), (0.9, 0.0), (1.02, -0.05),
                                                                              (1.3, 0.0)]}


def roar():
    wind = add(GROUND, chain(NECK, x=7), P(Head=(10, 0, 0)), P(Root=(4, 0, 0)), wings(Upper=(-6, 8, 0)))
    rear = add(WINGS_HALF, chain(NECK, x=-12, grow=0.2), P(Head=(-16, 0, 0)), P(Jaw=(32, 0, 0)),
               chain(SPINE, x=-4), P(Root=(-9, 0, 0)), legs("F", upper=-6), chain(TAIL, x=6, grow=0.2))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.35, wind), (0.62, rear), (1.45, add(rear, chain(NECK, x=2), P(Jaw=(-4, 0, 0)))),
                      (2.0, GROUND)], t)
        if 0.62 < t < 1.45:  # a gentle roar tremble in the head and wingtips
            k = math.sin(math.pi * (t - 0.62) / 0.83)
            base = add(base, P(Head=(1.2 * k * math.sin(t * 40), 0, 0)), wings(Tip=(1.5 * k * math.sin(t * 34), 0, 0)))
        return base
    return 60, False, drive, {"FX_Roar": [int(0.62 * FPS)]}, {"delay": 1.2, "spring": True, "root_drop": None}


def reveal():
    # 0.0-1.0 curled in a ball (a slow, tense pulse); 1.0-1.25 bursts open into the star pose (FX_Burst) and roars;
    # 1.25-2.4 holds the star pose, floating; 2.4-3.0 settles into the Idle start pose.
    ball = add(WINGS_WRAPPED, LEGS_CURLED, chain(NECK, x=15, z=14), P(Head=(10, 0, 12)), P(Jaw=(0, 0, 0)),
               chain(SPINE, x=10), P(Root=(12, 0, 0)), chain(TAIL, z=-26, x=4))
    star = add(WINGS_WIDE, wings(Upper=(14, -6, 0), Tip=(8, -8, 0)), legs("F", upper=-18, lower=10, splay=10),
               legs("B", upper=-6, splay=8), chain(NECK, x=-10, grow=0.2), P(Head=(-18, 0, 0)), P(Jaw=(34, 0, 0)),
               chain(SPINE, x=-5), P(Root=(-10, 0, 0)), chain(TAIL, x=4, z=0))

    def drive(t):
        base = keyed([(0.0, ball), (0.95, add(ball, P(Root=(4, 0, 0)), chain(NECK, x=4))),
                      (1.2, star), (2.0, add(star, P(Jaw=(-26, 0, 0)))), (2.4, add(star, P(Jaw=(-34, 0, 0)))),
                      (3.0, GROUND)], t)
        if t < 1.0:  # the ball pulses, building tension
            k = smooth(t / 1.0)
            base = add(base, chain(SPINE, x=-2.0 * k * math.sin(t * 2 * math.pi * 2.2)),
                       wings(Upper=(0, 0, 1.5 * k * math.sin(t * 2 * math.pi * 2.2))))
        if 1.2 < t < 2.4:  # floating in the star pose
            k = math.sin(math.pi * (t - 1.2) / 1.2)
            base = add(base, wings(Upper=(3 * k * math.sin((t - 1.2) * 5), 0, 0), Tip=(4 * k * math.sin((t - 1.2) * 5 - 1), 0, 0)))
        return base
    return 90, False, drive, {"FX_Burst": [int(1.12 * FPS)], "FX_Roar": [int(1.25 * FPS)]}, \
        {"delay": 1.0, "spring": True, "root_drop": [(0.0, 0.0), (0.95, -0.015), (1.2, 0.03), (1.5, 0.0)]}


# ---------------------------------------------------------------------------------------------------------------
# Personality, roost and battle actions

# Lying down (Sleep): back legs folded under, front legs forward (sphinx), body on the ground (the Root drops)
LEGS_LYING = add(legs("B", upper=-35, lower=100, foot=-70), legs("F", upper=-70, lower=40, foot=20))
LYING_DROP = -0.2  # share of REFERENCE_HEIGHT


def leg_one(leg, upper=0.0, lower=0.0, foot=0.0):
    return {f"Leg_{leg}_Upper": [upper, 0, 0], f"Leg_{leg}_Lower": [lower, 0, 0], f"Leg_{leg}_Foot": [foot, 0, 0]}


def env(t, t0, t1, fade=0.15):
    """1 inside [t0, t1] with smooth fades at both ends, 0 outside."""
    return smooth((t - t0) / fade) * (1 - smooth((t - (t1 - fade)) / fade))


def sleep():
    # curled up on the ground: head curled round to the right, the tail wrapped round the same way over the nose;
    # two slow, deep breaths per loop
    T_ = 5.0
    # the tail turns hard at its base to run forward along the right flank, and its tip hooks in over the nose
    # (long tails reach past the head, so the tip curls back in)
    tail = {"Tail1": [-4, 0, 80], "Tail2": [0, 0, 70], "Tail3": [0, 0, 20], "Tail4": [0, 0, 6], "Tail5": [0, 0, 22],
            "Tail6": [4, 0, 40]}
    curled = add(GROUND, wings(Upper=(-12, 6, 0)), LEGS_LYING, P(Root=(4, 0, 0)),
                 chain(NECK, x=7, z=30), P(Head=(12, 0, 30)), tail)

    def drive(t):
        b = wave(t, T_ / 2)
        return add(curled, chain(SPINE, x=-2.8 * b), wings(Upper=(3.5 * b, 0, 0)), P(Head=(-1.2 * b, 0, 0)),
                   {"Tail6": [0, 0, 3 * wave(t, T_, 1.0)]})
    return 150, True, drive, {}, {"delay": 0.0, "spring": False,
                                  "root_drop": lambda t: LYING_DROP + 0.012 * wave(t, T_ / 2, 0.5)}


def happy_hop():
    # looks up toward the viewer with a head tilt, a little hop with a wing flick, tail wagging all through
    look = add(GROUND, chain(NECK, x=-6, z=-6), P(Head=(-8, 18, -8)))
    crouch = add(look, mul(LEGS_CROUCH, 0.9), wings(Upper=(8, 0, 0)))
    air = add(look, legs("B", upper=12, lower=-10, foot=20), legs("F", upper=10, lower=-15, foot=15),
              wings(Upper=(26, -10, 0), Fore=(-10, -10, 0)), chain(TAIL, x=6), P(Root=(-6, 0, 0)))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.3, look), (0.58, crouch), (0.8, air), (1.05, add(look, mul(LEGS_CROUCH, 0.5))),
                      (1.35, look), (2.0, GROUND)], t)
        wag = math.sin(math.pi * min(t / 2.0, 1.0))
        tail = {b: [0, 0, 11 * wag * math.sin(2 * math.pi * 3 * t - 0.6 * i)] for i, b in enumerate(TAIL)}
        wiggle = P(Root=(0, 0, 3 * env(t, 1.1, 1.7) * math.sin(2 * math.pi * 4 * t)))
        return add(base, tail, wiggle)
    return 60, False, drive, {}, {"delay": 1.0, "spring": True,
                                  "root_drop": [(0.0, 0.0), (0.5, 0.0), (0.62, -0.05), (0.82, 0.18), (1.02, -0.03),
                                                (1.3, 0.0)]}


def sneeze():
    # the breath builds (head up, jaw opening), a sharp jerk forward-down (FX_Sneeze), then a little head shake
    build = add(GROUND, chain(NECK, x=-5), P(Head=(-14, 0, 0), Jaw=(10, 0, 0)), P(Root=(-4, 0, 0)))
    peak = add(build, chain(NECK, x=-2), P(Head=(-6, 0, 0), Jaw=(4, 0, 0)))
    achoo = add(GROUND, chain(NECK, x=10), P(Head=(18, 0, 0), Jaw=(0, 0, 0)), P(Root=(7, 0, 0)),
                wings(Upper=(14, -8, 0)), chain(TAIL, x=8))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.35, build), (0.66, peak), (0.74, achoo), (0.95, add(GROUND, chain(NECK, x=3))),
                      (1.5, GROUND)], t)
        k = env(t, 0.85, 1.35, 0.1)
        return add(base, P(Head=(0, 0, 7 * k * math.sin(2 * math.pi * 7 * t))),
                   chain(NECK, z=3 * k * math.sin(2 * math.pi * 7 * t - 0.6)))
    return 45, False, drive, {"FX_Sneeze": [22]}, {"delay": 0.6, "spring": True, "root_drop": None}


def stretch():
    # a cat-like stretch (front legs forward, chest low, wings up and wide), a big yawn, then the wings shake out
    prep = add(GROUND, mul(LEGS_CROUCH, 0.4), chain(NECK, x=4))
    reach = add(WINGS_WIDE, wings(Upper=(24, -4, 0), Tip=(6, -6, 0)), legs("F", upper=-42, lower=-12, foot=-10),
                legs("B", upper=8, lower=-6), P(Root=(11, 0, 0)), chain(SPINE, x=4), chain(NECK, x=-6),
                P(Head=(-12, 0, 0), Jaw=(12, 0, 0)), chain(TAIL, x=-2))  # tail kept level against the Root pitch
    yawn = add(reach, P(Head=(-8, 0, 0), Jaw=(28, 0, 0)), wings(Upper=(6, -4, 0)))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.45, prep), (1.15, reach), (1.7, yawn),
                      (2.1, add(WINGS_HALF, P(Root=(2, 0, 0)))), (3.0, GROUND)], t)
        k = env(t, 1.95, 2.55, 0.12)
        return add(base, wings(Upper=(6 * k * math.sin(2 * math.pi * 9 * t), 0, 0),
                               Hand=(10 * k * math.sin(2 * math.pi * 9 * t - 1.0), 0, 0),
                               Tip=(12 * k * math.sin(2 * math.pi * 9 * t - 2.0), 0, 0)))
    return 90, False, drive, {}, {"delay": 1.0, "spring": True, "root_drop": [(0.0, 0.0), (0.45, -0.02), (1.15, -0.03),
                                                                              (2.1, 0.0)]}


def preen():
    # turns round to the left wing (lifted a little toward the head) and nibbles at it, then back
    left_wing_up = wing("Upper", flap=14, sweep=-22, sides=("L",))
    left_wing_up.update(wing("Fore", flap=10, sweep=-10, sides=("L",)))
    turn = add(GROUND, left_wing_up, chain(NECK, x=5, z=-26), P(Head=(22, 0, -26)), P(Root=(0, 6, 0)))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.65, turn), (2.3, turn), (3.0, GROUND)], t)
        k = env(t, 0.75, 2.25, 0.15)
        nib = math.sin(2 * math.pi * 4 * t)
        return add(base, P(Head=(5 * k * nib, 0, 0), Jaw=(6 * k * (0.5 + 0.5 * nib), 0, 0)),
                   chain(NECK, z=3 * k * math.sin(2 * math.pi * 1.5 * t)), wing("Hand", flap=3 * k * nib, sides=("L",)))
    return 90, False, drive, {}, {"delay": 1.0, "spring": True, "root_drop": None}


def shake():
    # a wet-dog shake: a roll wave running from the body to the head and down the tail, wings half open and ruffling
    half = lerp_pose(GROUND, WINGS_HALF, 0.6)

    def drive(t):
        base = keyed([(0.0, GROUND), (0.18, half), (1.15, half), (1.5, GROUND)], t)
        k = env(t, 0.05, 1.3, 0.22)
        w = 2 * math.pi * 5 * t
        r = 2 * math.pi * 7 * t
        pose = add(base, P(Root=(0, 3 * k * math.sin(w - 0.4), 12 * k * math.sin(w))),
                   chain(SPINE, z=5 * k * math.sin(w - 0.8)), chain(NECK, z=7 * k * math.sin(w - 1.5)),
                   P(Head=(0, 0, 10 * k * math.sin(w - 2.2))),
                   wings(Upper=(8 * k * math.sin(r), 0, 0), Hand=(10 * k * math.sin(r - 1), 0, 0),
                         Tip=(12 * k * math.sin(r - 2), 0, 0)))
        for i, b in enumerate(TAIL):
            pose = add(pose, {b: [0, 0, 9 * k * math.sin(w - 1.2 - 0.5 * i)]})
        return pose
    return 45, False, drive, {}, {"delay": 0.0, "spring": False, "root_drop": None}


def tail_flick():
    # a small wind-up to the left, then a whip to the right that travels to the tip (chain delay + springs)
    wind = add(GROUND, chain(TAIL, z=-16, x=3))
    flick = add(GROUND, chain(TAIL, z=24, x=9, grow=0.15), P(Head=(0, 0, 6)))

    def drive(t):
        return keyed([(0.0, GROUND), (0.25, wind), (0.42, flick), (0.68, add(GROUND, chain(TAIL, z=-4))),
                      (1.0, GROUND)], t)
    return 30, False, drive, {}, {"delay": 1.4, "spring": True, "root_drop": None}


def barrel_roll():
    # in flight: a small counter-roll, a full roll to the right with the wings swept back, a little overshoot, then
    # flapping back into the FlyLoop (it ends on the FlyLoop's first frame)
    period = 1.2
    tucked = add(FLIGHT, wings(Upper=(-4, 22, 0), Hand=(0, 10, 0)), chain(NECK, x=-3))

    def drive(t):
        base = keyed([(0.0, FLIGHT), (0.28, add(tucked, P(Root=(0, 0, -22)))), (1.25, add(tucked, P(Root=(0, 0, 360)))),
                      (1.55, add(FLIGHT, P(Root=(0, 0, 366)))), (2.0, add(FLIGHT, P(Root=(0, 0, 360))))], t)
        tail = {b: [0, 0, -8 * env(t, 0.3, 1.4, 0.3) * (1 + 0.2 * i)] for i, b in enumerate(TAIL)}
        k = smooth((t - 1.2) / 0.4)
        beats = add(flight_wings(t + 0.4, period, amp=k), flap_heave(t + 0.4, period, amp=k)) if k > 0 else {}
        return add(base, tail, beats)
    return 60, False, drive, {}, {"delay": 1.0, "spring": True, "root_drop": None}


def evolve():
    # gathers itself, rises while spinning once round, flings the wings wide at the peak with a roar (FX_Burst),
    # floats a moment, then settles back to the ground pose
    gather = add(GROUND, wings(Upper=(0, 10, 0)), LEGS_CROUCH, chain(NECK, x=6), P(Head=(6, 0, 0)), P(Root=(5, 0, 0)))
    spin_pose = add(lerp_pose(WINGS_FOLDED, WINGS_HALF, 0.5), mul(LEGS_TUCKED, 0.5), chain(TAIL, x=-3))
    star = add(WINGS_WIDE, wings(Upper=(20, -6, 0), Tip=(8, -8, 0)), legs("F", upper=-18, lower=10, splay=10),
               legs("B", upper=-6, splay=8), chain(NECK, x=-10, grow=0.2), P(Head=(-18, 0, 0), Jaw=(32, 0, 0)),
               chain(SPINE, x=-5), P(Root=(-8, 0, 0)))

    def drive(t):
        spin = keyed([(0.0, {"Root": [0, 0, 0]}), (0.4, {"Root": [0, 0, 0]}), (1.95, {"Root": [0, 360, 0]}),
                      (3.0, {"Root": [0, 360, 0]})], t)
        base = keyed([(0.0, GROUND), (0.4, gather), (1.0, spin_pose), (1.8, spin_pose), (2.05, star),
                      (2.5, add(star, P(Jaw=(-26, 0, 0)))), (3.0, GROUND)], t)
        k = env(t, 2.05, 2.55, 0.15)
        return add(base, spin, wings(Upper=(3 * k * math.sin((t - 2.05) * 9), 0, 0),
                                     Tip=(4 * k * math.sin((t - 2.05) * 9 - 1), 0, 0)))
    return 90, False, drive, {"FX_Burst": [60]}, {"delay": 1.0, "spring": True,
                                                  "root_drop": [(0.0, 0.0), (0.4, -0.04), (1.9, 0.15), (2.5, 0.13),
                                                                (3.0, 0.0)]}


def level_up():
    # a small dip, then chest out and head high (FX_LevelUp), a proud little shake of wings and tail, settle
    proud = add(lerp_pose(WINGS_FOLDED, WINGS_HALF, 0.5), P(Root=(-8, 0, 0)), chain(SPINE, x=-4), chain(NECK, x=-6),
                P(Head=(-10, 0, 0)), chain(TAIL, x=5))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.2, add(GROUND, mul(LEGS_CROUCH, 0.4), P(Head=(5, 0, 0)))), (0.45, proud),
                      (1.05, proud), (1.5, GROUND)], t)
        k = env(t, 0.5, 1.05, 0.12)
        return add(base, P(Root=(0, 0, 5 * k * math.sin(2 * math.pi * 6 * t))),
                   wings(Upper=(6 * k * math.sin(2 * math.pi * 8 * t), 0, 0),
                         Tip=(8 * k * math.sin(2 * math.pi * 8 * t - 1.2), 0, 0)),
                   {b: [0, 0, 8 * k * math.sin(2 * math.pi * 5 * t - 0.5 * i)] for i, b in enumerate(TAIL)})
    return 45, False, drive, {"FX_LevelUp": [12]}, {"delay": 1.0, "spring": True,
                                                    "root_drop": [(0.0, 0.0), (0.2, -0.02), (0.45, 0.02), (1.0, 0.01),
                                                                  (1.5, 0.0)]}


def attack():
    # rears back with the right front claw raised, lunges into a bite (jaw snaps shut, FX_Attack) with a swipe
    wind = add(WINGS_HALF, P(Root=(-10, 0, 0)), chain(NECK, x=-6), P(Head=(-10, 0, 0), Jaw=(10, 0, 0)),
               leg_one("FR", upper=-55, lower=45, foot=-10))
    bite = add(WINGS_HALF, P(Root=(12, 0, 0)), chain(NECK, x=4), P(Head=(8, 0, 0), Jaw=(36, 0, 0)),
               leg_one("FR", upper=38, lower=-10, foot=15))
    snap = add(bite, P(Jaw=(-36, 0, 0)))

    def drive(t):
        return keyed([(0.0, GROUND), (0.25, wind), (0.37, bite), (0.45, snap), (0.62, snap), (1.0, GROUND)], t)
    return 30, False, drive, {"FX_Attack": [13]}, {"delay": 0.7, "spring": True,
                                                   "root_drop": [(0.0, 0.0), (0.25, 0.02), (0.42, -0.02), (0.8, 0.0)]}


def hit():
    # flinches back and away (FX_Hit on the first frames), then springs back
    recoil = add(GROUND, P(Root=(-10, 0, 5)), chain(NECK, x=-8, z=6), P(Head=(-12, 0, 8)), wings(Upper=(12, -10, 0)),
                 chain(TAIL, x=6))

    def drive(t):
        return keyed([(0.0, GROUND), (0.07, recoil), (0.6, GROUND)], t)
    return 18, False, drive, {"FX_Hit": [1]}, {"delay": 0.6, "spring": True, "root_drop": None}


def victory():
    # a wind-up, then a proud roar with the wings raised high and spread (FX_Roar), hold, settle
    wind = add(GROUND, chain(NECK, x=7), P(Head=(10, 0, 0)), P(Root=(4, 0, 0)), wings(Upper=(-6, 8, 0)))
    up = add(wings(Upper=(55, -6, 0), Fore=(10, -10, 0), Hand=(4, -24, 6), Tip=(6, -30, 8)),
             chain(NECK, x=-12, grow=0.2), P(Head=(-16, 0, 0), Jaw=(34, 0, 0)), chain(SPINE, x=-4), P(Root=(-9, 0, 0)),
             legs("F", upper=-6), chain(TAIL, x=8, grow=0.2))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.32, wind), (0.6, up), (1.45, add(up, P(Jaw=(-8, 0, 0)))), (2.0, GROUND)], t)
        k = env(t, 0.6, 1.45, 0.12)
        return add(base, wings(Tip=(3 * k * math.sin(t * 30), 0, 0)))
    return 60, False, drive, {"FX_Roar": [18]}, {"delay": 1.0, "spring": True,
                                                 "root_drop": [(0.0, 0.0), (0.32, -0.02), (0.6, 0.02), (1.45, 0.02),
                                                               (2.0, 0.0)]}


def defeat():
    # head sinks, wings droop open and low, the body sags, one slow sigh; ends slumped (the game holds or fades out)
    slump = add(WINGS_FOLDED, wings(Upper=(-30, -18, 0), Fore=(-12, 0, 0), Hand=(-10, 0, 0)), mul(LEGS_CROUCH, 0.6),
                P(Root=(4, 0, 0)), chain(NECK, x=10), P(Head=(14, 0, 0)), chain(TAIL, x=-2))
    lower = add(slump, chain(NECK, x=3), P(Head=(5, 0, 0)))

    def drive(t):
        base = keyed([(0.0, GROUND), (0.65, slump), (2.0, lower)], t)
        sigh = env(t, 1.0, 1.8, 0.35)
        return add(base, chain(SPINE, x=-3.5 * sigh), wings(Upper=(4 * sigh, 0, 0)))
    return 60, False, drive, {}, {"delay": 1.2, "spring": True, "root_drop": [(0.0, 0.0), (0.65, -0.07), (2.0, -0.08)]}


ACTIONS = {
    "Dragon_Idle": idle,
    "Dragon_TakeOff": take_off,
    "Dragon_FlyLoop": fly_loop,
    "Dragon_Glide": glide,
    "Dragon_Land": land,
    "Dragon_Roar": roar,
    "Dragon_Reveal": reveal,
    "Dragon_Sleep": sleep,
    "Dragon_HappyHop": happy_hop,
    "Dragon_Sneeze": sneeze,
    "Dragon_Stretch": stretch,
    "Dragon_Preen": preen,
    "Dragon_Shake": shake,
    "Dragon_TailFlick": tail_flick,
    "Dragon_BarrelRoll": barrel_roll,
    "Dragon_Evolve": evolve,
    "Dragon_LevelUp": level_up,
    "Dragon_Attack": attack,
    "Dragon_Hit": hit,
    "Dragon_Victory": victory,
    "Dragon_Defeat": defeat,
}

# ---------------------------------------------------------------------------------------------------------------
# Baking


def spring_filter(values, depth, loop):
    """Second-order follow: a slight overshoot and settle; tips (deeper bones) are softer."""
    omega = 26.0 / (1 + 0.45 * depth)
    zeta = 0.62
    dt = 1.0 / FPS
    steps = 6
    out = []
    x = values[0]
    v = 0.0
    for target in values:
        for _ in range(steps):
            a = omega * omega * (target - x) - 2 * zeta * omega * v
            v += a * dt / steps
            x += v * dt / steps
        out.append(x)
    # keep the first and last frames exact so actions start/end on their key poses
    n = len(out)
    fix = min(4, n // 4)
    for i in range(fix):
        k = (i + 1) / (fix + 1)
        out[n - fix + i] = out[n - fix + i] * (1 - k) + values[n - fix + i] * k
    out[0], out[-1] = values[0], values[-1]
    return out


def sample(drive, frames, follow):
    """{bone: [[x, y, z] per frame]} with chain delays applied."""
    delay = follow["delay"] if follow else 0.0
    bones = [b for b, _, _ in T.BONES]
    tracks = {b: [] for b in bones}
    cache = {}
    for f in range(frames + 1):
        for b in bones:
            d = DEPTH.get(b, 0) * delay if not b.startswith("Leg_") else DEPTH.get(b, 0) * delay * 0.5
            t = max(0.0, (f - d) / FPS)
            key = round(t * 1000)
            if key not in cache:
                cache[key] = drive(t)
            tracks[b].append(cache[key].get(b, [0.0, 0.0, 0.0]))
    return tracks


def root_drop(follow, t, scale):
    keys = follow.get("root_drop") if follow else None
    if not keys:
        return 0.0
    if callable(keys):
        return keys(t) * scale
    if t <= keys[0][0]:
        return keys[0][1] * scale
    for (t0, a), (t1, b) in zip(keys, keys[1:]):
        if t <= t1:
            return (a + (b - a) * smooth((t - t0) / max(t1 - t0, 1e-6))) * scale
    return keys[-1][1] * scale


def bake(rig, name, builder, height):
    frames, loop, drive, markers, follow = builder()
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    tracks = sample(drive, frames, follow)
    for b, values in tracks.items():
        pb = rig.pose.bones.get(b)
        if pb is None:
            continue
        pb.rotation_mode = "XYZ"
        channels = list(zip(*values))
        if all(abs(c) < 1e-6 for ch in channels for c in ch):
            continue
        for axis in range(3):
            series = [math.radians(v) for v in channels[axis]]
            if follow and follow.get("spring"):
                series = spring_filter(series, DEPTH.get(b, 0), loop)
            if loop:
                series[-1] = series[0]
            fc = act.fcurve_ensure_for_datablock(rig, f'pose.bones["{b}"].rotation_euler', index=axis)
            fc.keyframe_points.add(len(series))
            co = []
            for f, v in enumerate(series):
                co += [f, v]
            fc.keyframe_points.foreach_set("co", co)
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
            fc.update()
    # Root crouch / heave (vertical only; a share of the dragon's height)
    if follow and follow.get("root_drop"):
        fc = act.fcurve_ensure_for_datablock(rig, 'pose.bones["Root"].location', index=1)  # bone Y = world up
        fc.keyframe_points.add(frames + 1)
        co = []
        for f in range(frames + 1):
            co += [f, root_drop(follow, f / FPS, height)]
        fc.keyframe_points.foreach_set("co", co)
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
        fc.update()
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, frames
    act.use_cyclic = loop
    for m in list(act.pose_markers):
        act.pose_markers.remove(m)
    for mname, frames_ in markers.items():
        for f in frames_:
            act.pose_markers.new(mname).frame = f
    return {"frames": frames, "seconds": frames / FPS, "loop": loop,
            "markers": {k: [f / FPS for f in v] for k, v in markers.items()}}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts = {"save": None, "only": None, "fbx-dir": None, "library": None}
    i = 0
    while i < len(argv):
        if argv[i] in ("--save", "--only", "--fbx-dir", "--library"):
            opts[argv[i][2:]] = argv[i + 1]; i += 2
        else:
            raise SystemExit(f"unknown option {argv[i]}")
    rig = bpy.data.objects["DragonRig"]
    height = REFERENCE_HEIGHT
    bpy.context.scene.render.fps = FPS
    info = {}
    names = opts["only"].split(",") if opts["only"] else list(ACTIONS)
    for name in names:
        info[name] = bake(rig, name, ACTIONS[name], height)
        print("baked", name, info[name])
    if not opts["only"]:
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "animations.json"), "w") as f:
            json.dump({"fps": FPS, "actions": info}, f, indent=1)
    rig.animation_data.action = bpy.data.actions[names[0]]
    if opts["save"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(opts["save"]))
    if opts["library"]:
        bpy.data.libraries.write(os.path.abspath(opts["library"]), {bpy.data.actions[n] for n in names}, fake_user=True)
    if opts["fbx-dir"]:
        os.makedirs(opts["fbx-dir"], exist_ok=True)
        for name in names:
            rig.animation_data.action = bpy.data.actions[name]
            bpy.ops.object.select_all(action="DESELECT")
            rig.select_set(True)
            bpy.context.view_layer.objects.active = rig
            bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, info[name]["frames"]
            bpy.ops.export_scene.fbx(filepath=os.path.join(os.path.abspath(opts["fbx-dir"]), name + ".fbx"),
                                     use_selection=True, object_types={"ARMATURE"}, apply_scale_options="FBX_SCALE_ALL",
                                     add_leaf_bones=False, bake_anim=True, bake_anim_use_all_actions=False,
                                     bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0.0,
                                     use_armature_deform_only=True)


if __name__ == "__main__":
    main()
