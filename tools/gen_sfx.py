"""Synthesizes the few retro sound effects that were not taken from a CC0 pack.

Usage: python3 tools/gen_sfx.py   (needs numpy + ffmpeg on PATH)
Writes OGG files into assets/audio/sfx/.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")
rng = np.random.default_rng(7)


def env(n, attack, decay):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-t / decay)


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def crush(x, steps=24):
    return np.round(x * steps) / steps


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        path = f.name
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path,
                    "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(path)


def gunshot(length=0.35, thump=90.0, bright=0.55):
    n = int(SR * length)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    crack = lowpass(noise, bright) * env(n, 0.001, 0.045)
    body = np.sin(2 * np.pi * thump * t * np.exp(-t * 6)) * env(n, 0.002, 0.08)
    return crush(crack * 0.9 + body * 0.8, 20)


def boom(length=1.1):
    n = int(SR * length)
    t = np.arange(n) / SR
    noise = lowpass(rng.uniform(-1, 1, n), 0.08) * env(n, 0.002, 0.35) * 1.6
    body = np.sin(2 * np.pi * 55 * t * np.exp(-t * 2)) * env(n, 0.002, 0.3)
    squish = lowpass(rng.uniform(-1, 1, n), 0.3) * env(n, 0.001, 0.06)
    return crush(noise + body + squish * 0.6, 24)


def spit(length=0.3):
    n = int(SR * length)
    t = np.arange(n) / SR
    f = np.linspace(500, 180, n)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.4
    noise = lowpass(rng.uniform(-1, 1, n), 0.25)
    return (tone + noise) * env(n, 0.005, 0.07)


def splat(length=0.35):
    n = int(SR * length)
    noise = lowpass(rng.uniform(-1, 1, n), 0.12)
    return noise * env(n, 0.001, 0.06)


def loop_noise(length, alpha, drops=0):
    n = int(SR * length)
    x = lowpass(rng.uniform(-1, 1, n), alpha)
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.5
    for _ in range(drops):
        p = rng.integers(0, n - 600)
        x[p:p + 300] += rng.uniform(-1, 1, 300) * np.exp(-np.arange(300) / 40) * rng.uniform(0.1, 0.35)
    # crossfade the end into the start so it loops without a click
    fade = int(SR * 0.3)
    head = x[:fade].copy()
    x[-fade:] = x[-fade:] * np.linspace(1, 0, fade) + head * np.linspace(0, 1, fade)
    return x[fade:]


def wind(length=6.0):
    n = int(SR * length)
    base = loop_noise(length, 0.02)
    t = np.arange(base.size) / SR
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * t / length * 2)
    return base * swell


def thunder(length=2.6):
    n = int(SR * length)
    x = lowpass(rng.uniform(-1, 1, n), 0.03)
    t = np.arange(n) / SR
    e = np.exp(-t / 0.9) * (1 + 0.5 * np.sin(2 * np.pi * 3 * t))
    crack = lowpass(rng.uniform(-1, 1, n), 0.4) * env(n, 0.001, 0.05)
    return x * e + crack * 0.4


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("shot", gunshot())
    save("turret_shot", gunshot(0.22, 140.0, 0.8) * 0.7)
    save("boom", boom())
    save("spit", spit())
    save("splat", splat())
    save("rain", loop_noise(5.0, 0.35, drops=120))
    save("wind", wind())
    save("thunder", thunder())
    print("ok")
