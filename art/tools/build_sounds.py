"""Turns the raw clips in the "Sound files" folder (next to the repo
folder) into game-ready OGGs in godot/assets/audio, all evened out to
the same loudness, and synthesises the few sounds we have no clip for
(explosion, engine rumble, airlock hiss).

  blender -b --factory-startup --python art/tools/build_sounds.py

Uses Blender's bundled audio library (aud) and numpy, so nothing else
needs installing.
"""
import os

import aud
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "..", "..", "Sound files")
OUT = os.path.join(ROOT, "godot", "assets", "audio")
RATE = 44100

# out name: (source clip, target loudness dBFS RMS, mono, seconds to keep)
CLIPS = {
    "cannon_fire": ("Effects/Mass cannon fire sound.mp3", -16, True, 3.0),
    "laser_fire": ("Effects/Laser turret sound.mp3", -17, True, None),
    "sparks": ("Backround/Spark sounds.mp3", -20, True, None),
    "ship_hum": ("Backround/Close zoom in backround noise of the ship..mp3", -24, False, None),
}


def _level(x, target):
    """Scales x so its active part sits at `target` dBFS RMS, with a soft
    limiter keeping peaks under -1 dB."""
    env = np.abs(x).max(axis=1) if x.ndim > 1 else np.abs(x)
    loud = x[env > 10 ** (-50 / 20)]
    rms = np.sqrt((loud ** 2).mean()) if loud.size else 1e-6
    y = x * (10 ** (target / 20) / rms)
    lim = 10 ** (-1 / 20)
    return np.tanh(y / lim) * lim


def _fade(x, secs=0.03):
    n = min(int(RATE * secs), x.shape[0] // 4)
    ramp = np.linspace(0.0, 1.0, n)
    x[:n] *= ramp[:, None] if x.ndim > 1 else ramp
    x[-n:] *= ramp[::-1, None] if x.ndim > 1 else ramp[::-1]
    return x


def _save(name, x):
    x = np.ascontiguousarray(x if x.ndim > 1 else x[:, None], dtype=np.float32)
    path = os.path.join(OUT, name + ".ogg")
    aud.Sound.buffer(x, RATE).write(path, rate=RATE, channels=x.shape[1],
                                    container=aud.CONTAINER_OGG,
                                    codec=aud.CODEC_VORBIS, bitrate=128000)
    print("wrote", path, "%.2fs" % (x.shape[0] / RATE))


def _clip(src, target, mono, keep):
    s = aud.Sound(os.path.join(SRC, src)).resample(RATE, True)
    x = s.data().astype(np.float64)
    if keep:
        x = x[: int(RATE * keep)]
    if mono:
        x = x.mean(axis=1)
    return _fade(_level(x, target))


def _lowpass(x, a):
    """One-pole low-pass; a near 1 = darker."""
    y = np.empty_like(x)
    acc = 0.0
    for k in range(x.shape[0]):
        acc = acc * a + x[k] * (1 - a)
        y[k] = acc
    return y


def _explosion(rng):
    t = np.arange(int(RATE * 2.2)) / RATE
    rumble = _lowpass(rng.standard_normal(t.size), 0.985) * np.exp(-t * 2.2) * 6
    crack = rng.standard_normal(t.size) * np.exp(-t * 18)
    thump = np.sin(2 * np.pi * (55 - 25 * t) * t) * np.exp(-t * 4)
    return _fade(_level(rumble + crack * 0.5 + thump, -15), 0.005)


def _engine(rng):
    """Three-second seamless loop: low roar plus a throbbing hum."""
    n = RATE * 3
    t = np.arange(n) / RATE
    roar = _lowpass(rng.standard_normal(n + RATE), 0.97)[RATE:] * 5
    hum = np.sin(2 * np.pi * 46 * t) + 0.4 * np.sin(2 * np.pi * 92 * t)
    x = roar + hum * (0.6 + 0.15 * np.sin(2 * np.pi * 3 * t))
    k = int(RATE * 0.25)  # crossfade the end into the start so it loops
    x[:k] = x[:k] * np.linspace(0, 1, k) + x[-k:] * np.linspace(1, 0, k)
    return _level(x[:-k], -20)


def _hiss(rng):
    t = np.arange(int(RATE * 1.4)) / RATE
    env = np.minimum(t / 0.05, 1.0) * np.exp(-np.maximum(t - 0.3, 0) * 3)
    x = (rng.standard_normal(t.size) - _lowpass(rng.standard_normal(t.size), 0.9)) * env
    return _fade(_level(x, -22))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (src, target, mono, keep) in CLIPS.items():
        _save(name, _clip(src, target, mono, keep))
    rng = np.random.default_rng(7)
    _save("explosion", _explosion(rng))
    _save("engine_loop", _engine(rng))
    _save("airlock_hiss", _hiss(rng))


main()
