#!/usr/bin/env python3
"""Kilitli Kapı: voice.mp3 -> RMS envelope (env.json, 100 Hz) and a mixed wav (voice + synthesized SFX).
usage: python3 story_audio.py <ep-dir> <total-seconds> [cfg.json]   (needs numpy; afconvert on macOS)
With cfg (story_eps/epN.json) the voice is built from per-line files placed at their "at" times, and knocks/riser come from the cfg."""
import sys, json, subprocess, wave, os
import numpy as np

ep, total = sys.argv[1], float(sys.argv[2])
cfg = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else None
SR = 44100
def load(name):
    tmp = os.path.join(ep, "voice44.wav")
    subprocess.check_call(["afconvert", "-f", "WAVE", "-d", f"LEI16@{SR}", "-c", "1", os.path.join(ep, name), tmp])
    w = wave.open(tmp); return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float32) / 32768
if cfg:
    v = np.zeros(int(total * SR), np.float32)
    for ln in cfg["voice"]:
        x = load(ln["file"]); x = x / max(1e-6, np.abs(x).max())   # each line peak-normalised so voices match
        i = int(ln["at"] * SR); j = min(len(v), i + len(x)); v[i:j] += x[:j - i]
else:
    v = load("voice.mp3")
hop = SR // 100
env = [float(np.sqrt(np.mean(v[i:i + hop] ** 2))) for i in range(0, len(v) - hop, hop)]
json.dump(env, open(os.path.join(ep, "env.json"), "w"))

n = int(total * SR); t = np.arange(n) / SR
rng = np.random.default_rng(7)
def at(sig, start, gain=1.0):
    i = int(start * SR); j = min(n, i + len(sig))
    if i < n: out[i:j] += gain * sig[:j - i]

out = np.zeros(n, np.float32)
# ambience: dark hum, slow breathing swell, a little brown noise
hum = 0.6 * np.sin(2 * np.pi * 55 * t) + 0.35 * np.sin(2 * np.pi * 82.5 * t + 1) + 0.18 * np.sin(2 * np.pi * 110.4 * t)
hum *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t)
brown = np.cumsum(rng.standard_normal(n)).astype(np.float32); brown -= np.convolve(brown, np.ones(4000) / 4000, "same"); brown /= np.abs(brown).max()
out += 0.5 * hum + 0.35 * brown
# knocks: low thump (sine drop) + wood click
def knock(a=1.0):
    k = np.arange(int(.5 * SR)) / SR
    f = 62 + 70 * np.exp(-k * 38)
    th = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-k * 14)
    cl = rng.standard_normal(len(k)) * np.exp(-k * 90); cl = np.convolve(cl, np.ones(20) / 20, "same")
    return a * (th + 0.5 * cl)
KN = cfg["knocks"] if cfg else [(0.12, 1.0), (0.57, 0.85), (1.52, 1.0), (10.55, 1.0), (11.05, 0.9), (11.4, 0.8), (12.58, 0.7)]
for kt, ka in KN:
    at(knock(ka), kt, 1.6)
# suspense: riser r0 -> hit, long low tail
r0, h0 = cfg["riser"] if cfg else (14.6, 15.97)
rl = h0 - 0.02 - r0; k = np.arange(int(rl * SR)) / SR
rise = np.sin(2 * np.pi * np.cumsum(70 + 180 * (k / rl) ** 2) / SR) * (k / rl) ** 2 + 0.4 * rng.standard_normal(len(k)) * (k / rl) ** 3
at(rise.astype(np.float32), r0, 0.55)
k = np.arange(int(2.6 * SR)) / SR
hit = np.sin(2 * np.pi * np.cumsum(38 + 60 * np.exp(-k * 9)) / SR) * np.exp(-k * 1.6) + 0.25 * np.sin(2 * np.pi * 93 * k) * np.exp(-k * 2.5)
at(hit.astype(np.float32), h0, 1.9)
# end-card tail: fade ambience slightly
out *= np.clip((total - t) / 0.6, 0, 1)
out /= np.abs(out).max(); out *= 0.5   # sfx bed peaks at 0.5; mixed at ~ -14 dB under the voice
vp = np.zeros(n, np.float32); m = min(n, len(v)); vp[:m] = v[:m]
vp *= 0.9 / max(1e-6, np.abs(vp).max())
mix = vp + 0.2 * out * 1.0
mix = np.tanh(mix * 1.1) / np.tanh(1.1) * 0.95
pcm = (mix * 32767).astype("<i2")
o = wave.open(os.path.join(ep, "mix.wav"), "wb"); o.setnchannels(1); o.setsampwidth(2); o.setframerate(SR); o.writeframes(pcm.tobytes()); o.close()
print("mix.wav", total, "s")
