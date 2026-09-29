"""Tiny numpy DSP kit for the game's procedural sound (feature 016).

Everything is mono float32 at RATE. Building blocks: oscillators,
envelopes, noise, one-pole / biquad filters, a convolution reverb from a
synthetic impulse response, instruments (pluck, bell, pad, owl) and
writers for one-shots and seamless loops.
"""
import os

import numpy as np
import soundfile as sf

RATE = 44100
AUDIO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "game", "assets", "audio"))


def rng(seed):
    return np.random.default_rng(seed)


def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


# ---------------------------------------------------------------- oscillators

def sine(freq, seconds, phase=0.0):
    """Sine with a constant or per-sample frequency (array)."""
    n = int(seconds * RATE)
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.sin(2 * np.pi * np.cumsum(f) / RATE + phase)


def sweep(f0, f1, seconds, curve=2.0):
    """Exponential-ish frequency glide from f0 to f1 (per-sample array)."""
    x = np.linspace(0.0, 1.0, int(seconds * RATE)) ** curve
    return f0 * (f1 / f0) ** x


def noise(seconds, seed=0):
    return rng(seed).uniform(-1.0, 1.0, int(seconds * RATE))


def brown(seconds, seed=0):
    x = np.cumsum(rng(seed).normal(0, 1, int(seconds * RATE)))
    x = x - lowpass(x, 5.0)
    return x / (np.abs(x).max() + 1e-9)


# ---------------------------------------------------------------- envelopes

def env_perc(seconds, attack=0.002, decay=None):
    """Fast attack, exponential decay to about -60 dB at the end."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    decay = decay if decay is not None else seconds / 6.9
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay)


def env_adsr(seconds, attack, release, sustain=1.0, decay=0.0):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    e = np.ones(n) * sustain
    if decay > 0:
        e = sustain + (1 - sustain) * np.exp(-np.maximum(t - attack, 0) / decay)
    e *= np.clip(t / max(attack, 1e-5), 0, 1)
    e *= np.clip((seconds - t) / max(release, 1e-5), 0, 1)
    return e


def fade(x, fade_in=0.005, fade_out=0.02):
    n = len(x)
    e = np.ones(n)
    i, o = int(fade_in * RATE), int(fade_out * RATE)
    if i:
        e[:i] = np.linspace(0, 1, i)
    if o:
        e[-o:] *= np.linspace(1, 0, o)
    return x * e


# ---------------------------------------------------------------- filters

def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a per-sample array."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * c / RATE)
    y = np.empty_like(x, dtype=np.float64)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, center, q=4.0):
    """RBJ biquad band-pass with a constant center frequency."""
    w = 2 * np.pi * center / RATE
    alpha = np.sin(w) / (2 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * np.cos(w), 1 - alpha
    b0, b2, a1, a2 = b0 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros(len(x))
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def fft_filter(x, lo=0.0, hi=None):
    """Brick-ish band limit in the frequency domain (fast for long beds)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    hi = hi if hi is not None else RATE / 2
    mask = np.clip((freqs - lo) / max(lo * 0.3, 1.0) + 1, 0, 1) * np.clip((hi - freqs) / (hi * 0.3) + 1, 0, 1)
    return np.fft.irfft(spec * mask, len(x))


# ---------------------------------------------------------------- reverb

_IR_CACHE = {}


def reverb(x, wet=0.25, seconds=1.6, damp=3500.0, seed=7, loop=False):
    """Convolution with a decaying, darkening noise tail. `loop=True`
    wraps the tail around so seamless loops stay seamless."""
    key = (seconds, damp, seed)
    if key not in _IR_CACHE:
        n = int(seconds * RATE)
        t = np.arange(n) / RATE
        ir = rng(seed).normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        ir = fft_filter(ir, 80.0, damp)
        ir[: int(0.012 * RATE)] = 0.0  # pre-delay
        _IR_CACHE[key] = ir / np.sqrt(np.sum(ir ** 2))
    ir = _IR_CACHE[key]
    size = len(x) + len(ir)
    wet_sig = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)
    if loop:
        tail = wet_sig[len(x):]
        head = wet_sig[: len(x)].copy()
        for k in range(0, len(tail), len(x)):
            chunk = tail[k: k + len(x)]
            head[: len(chunk)] += chunk
        wet_sig = head
    else:
        x = np.concatenate([x, np.zeros(len(ir))])
    return x * (1 - wet) + wet_sig[: len(x)] * wet * 2.5


# ---------------------------------------------------------------- instruments

def pluck(freq, seconds, bright=0.5, seed=0):
    """Karplus-Strong string: a campfire guitar / ukulele pluck."""
    n = int(seconds * RATE)
    period = max(2, int(RATE / freq))
    buf = rng(seed).uniform(-1, 1, period)
    buf = lowpass(buf, 1500 + 6000 * bright)
    out = np.empty(n)
    decay = 0.996
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = decay * 0.5 * (v + buf[(i + 1) % period])
    return out * env_adsr(seconds, 0.001, 0.05)


def bell(freq, seconds, bright=1.0):
    """Inharmonic struck bell / chime."""
    t = t_axis(seconds)
    ratios = [(1.0, 1.0, 1.0), (2.0, 0.5, 0.6), (2.76, 0.35 * bright, 0.4), (5.4, 0.18 * bright, 0.25), (8.9, 0.08 * bright, 0.15)]
    out = np.zeros(len(t))
    for r, amp, life in ratios:
        out += amp * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (seconds * life / 3.0))
    return out * env_adsr(seconds, 0.001, 0.02) / 1.6


def soft_tone(freq, seconds, attack=0.02, release=0.2, harmonics=(1.0, 0.25, 0.08)):
    t = t_axis(seconds)
    out = sum(a * np.sin(2 * np.pi * freq * (k + 1) * t) for k, a in enumerate(harmonics))
    return out * env_adsr(seconds, attack, release)


def pad(freqs, seconds, attack=1.0, release=1.2, detune=0.35, seed=0):
    """Warm chord pad: detuned saw-ish stacks, gently low-passed."""
    t = t_axis(seconds)
    out = np.zeros(len(t))
    r = rng(seed)
    for f in freqs:
        for d in (-detune, 0.0, detune):
            ff = f * 2 ** (d / 12.0)
            ph = r.uniform(0, 2 * np.pi)
            for k, amp in enumerate((1.0, 0.45, 0.22, 0.1)):
                out += amp * np.sin(2 * np.pi * ff * (k + 1) * t + ph * (k + 1))
    out /= (len(freqs) * 3 * 1.8)
    return out * env_adsr(seconds, attack, release)


def knock(freq, seconds=0.18, seed=0, q=6.0):
    """Wood knock: a resonant band of noise with a tiny click."""
    x = noise(seconds, seed) * env_perc(seconds, 0.0005, seconds / 9)
    body = bandpass(x, freq, q) * 3.0
    thump = sine(sweep(freq * 0.45, freq * 0.25, seconds), seconds) * env_perc(seconds, 0.001, seconds / 8)
    return body + 0.6 * thump


def owl(seconds=0.55, pitch=390.0):
    """One soft 'hoo': breathy sine with vibrato and a slight droop."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    f = pitch * (1.04 - 0.06 * t / seconds) + 6.0 * np.sin(2 * np.pi * 5.5 * t)
    tone = sine(f, seconds) + 0.15 * sine(f * 2, seconds)
    breath = bandpass(noise(seconds, 11), pitch * 2, 3.0) * 0.25
    return (tone + breath) * env_adsr(seconds, 0.08, 0.2) ** 1.5


# ---------------------------------------------------------------- mixing

def place(dest, src, at_seconds, gain=1.0, wrap=False):
    """Mixes `src` into `dest` starting at a time; `wrap` folds overflow
    back to the start (for seamless loops)."""
    start = int(at_seconds * RATE) % len(dest) if wrap else int(at_seconds * RATE)
    if start >= len(dest):
        return dest
    end = start + len(src)
    if end <= len(dest):
        dest[start:end] += src * gain
        return dest
    fit = len(dest) - start
    dest[start:] += src[:fit] * gain
    rest = src[fit:]
    if wrap:
        while len(rest):
            k = min(len(rest), len(dest))
            dest[:k] += rest[:k] * gain
            rest = rest[k:]
    return dest


def normalize(x, peak_db=-1.0):
    peak = np.abs(x).max()
    if peak < 1e-9:
        return x
    return x / peak * 10 ** (peak_db / 20.0)


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def write(rel_path, x, peak_db=-1.0, trim=True):
    """Normalises and writes an .ogg under game/assets/audio/."""
    x = np.asarray(x, dtype=np.float64)
    if trim:
        loud = np.nonzero(np.abs(x) > np.abs(x).max() * 1e-3)[0]
        if len(loud):
            x = fade(x[: loud[-1] + int(0.02 * RATE)], 0.0, 0.015)
    x = normalize(x, peak_db)
    path = os.path.join(AUDIO_DIR, rel_path)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # libsndfile's Vorbis encoder can crash on one huge write; feed it blocks.
    with sf.SoundFile(path, "w", RATE, 1, format="OGG", subtype="VORBIS") as f:
        data = x.astype(np.float32)
        for i in range(0, len(data), 8192):
            f.write(data[i: i + 8192])
    print("wrote", os.path.relpath(path, AUDIO_DIR), "%.2fs" % (len(x) / RATE))
