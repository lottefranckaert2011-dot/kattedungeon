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


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("shot", gunshot())
    save("turret_shot", gunshot(0.22, 140.0, 0.8) * 0.7)
    print("ok")
