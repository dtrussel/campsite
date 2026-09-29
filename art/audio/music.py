"""Seamless music and ambience loops (feature 016). Run: tools/build_audio.sh

- music/day.ogg:     campfire guitar (plucked) over a warm pad, G major,
                     I-vi-IV-V, 96 BPM, 16 bars.
- music/night.ogg:   D minor drone, heartbeat drum and sparse eerie
                     bells, 72 BPM, 16 bars. Tense but not scary.
- ambience/day.ogg:  wind in leaves and bird chirps.
- ambience/night.ogg: crickets and a soft wind.
- ambience/campfire.ogg: crackle and a low roar (played 3D at the fire).

Every loop wraps its note tails and reverb back to the start, so the
end runs straight into the beginning.
"""
import numpy as np

from dsp import (RATE, bandpass, bell, brown, env_adsr, env_perc, fft_filter, highpass, lowpass, midi_hz, noise, pad,
                 place, pluck, reverb, rng, sine, soft_clip, soft_tone, sweep, t_axis, write)


def day_music():
    bpm = 96
    beat = 60.0 / bpm
    bars = 16
    length = bars * 4 * beat
    out = np.zeros(int(length * RATE))
    r = rng(1)
    # I - vi - IV - V in G (midi roots), each one bar, looped 4 times.
    chords = [(55, [55, 59, 62]), (52, [52, 55, 59]), (48, [48, 52, 55]), (50, [50, 54, 57])]
    scale = [67, 69, 71, 74, 76, 79, 81]  # G major pentatonic, upper octave
    for bar in range(bars):
        root, triad = chords[bar % 4]
        t0 = bar * 4 * beat
        # pad
        place(out, pad([midi_hz(n) for n in triad], 4 * beat + 1.0, 0.6, 1.0, seed=bar) * 0.16, t0, wrap=True)
        # bass on beats 1 and 3
        for b in (0, 2):
            place(out, soft_tone(midi_hz(root - 12), beat * 1.8, 0.01, 0.4, (1.0, 0.35, 0.1)) * 0.3, t0 + b * beat, wrap=True)
        # strummed chord pluck pattern: down on 1, up on 2.5, down on 3, 4
        for at, gain in ((0.0, 0.5), (1.5, 0.3), (2.0, 0.42), (3.0, 0.3)):
            for k, n in enumerate(triad + [triad[0] + 12]):
                place(out, pluck(midi_hz(n), 1.4, 0.35, seed=bar * 100 + k) * gain * 0.35,
                      t0 + at * beat + k * 0.012, wrap=True)
        # melody: bars 5-8 and 13-16, a lazy random walk on chord-friendly tones
        if bar % 8 >= 4:
            idx = 2
            for step in range(8):
                if r.random() < 0.3:
                    continue
                idx = int(np.clip(idx + r.choice([-2, -1, 1, 2]), 0, len(scale) - 1))
                note = scale[idx]
                place(out, pluck(midi_hz(note), 1.0, 0.7, seed=bar * 10 + step) * 0.32, t0 + step * beat / 2, wrap=True)
                place(out, bell(midi_hz(note + 12), 0.5, 0.3) * 0.04, t0 + step * beat / 2, wrap=True)
    return reverb(out, 0.28, 2.0, loop=True)


def night_music():
    bpm = 72
    beat = 60.0 / bpm
    bars = 16
    length = bars * 4 * beat
    n = int(length * RATE)
    out = np.zeros(n)
    t = np.arange(n) / RATE
    # drone: D2 + A2, slowly breathing, with a filtered-noise wind.
    breathe = 0.7 + 0.3 * np.sin(2 * np.pi * t / length * 4)
    def cyc(f):  # a whole number of cycles per loop, so the drone wraps cleanly
        return round(f * length) / length
    drone = (np.sin(2 * np.pi * cyc(midi_hz(38)) * t) + 0.6 * np.sin(2 * np.pi * cyc(midi_hz(45)) * t)
             + 0.25 * np.sin(2 * np.pi * cyc(midi_hz(50) * 1.003) * t))
    out += drone * breathe * 0.22
    chords = [[62, 65, 69], [58, 62, 65], [60, 64, 67], [57, 61, 64]]  # Dm Bb C A
    for bar in range(0, bars, 2):
        place(out, pad([midi_hz(x - 12) for x in chords[(bar // 2) % 4]], 8 * beat + 1.5, 2.0, 2.0, 0.2, seed=bar) * 0.12,
              bar * 4 * beat, wrap=True)
    # heartbeat drum: lub-dub on beat 1, softer on beat 3
    for bar in range(bars):
        for b, g in ((0, 1.0), (2, 0.6)):
            at = (bar * 4 + b) * beat
            for dt, gg in ((0.0, 1.0), (0.18, 0.7)):
                kick = sine(sweep(85, 42, 0.35), 0.35) * env_perc(0.35, 0.002, 0.08)
                place(out, kick * 0.55 * g * gg, at + dt, wrap=True)
    # eerie bells, minor pentatonic, sparse
    r = rng(5)
    bells = [74, 77, 79, 81, 84, 86]
    for bar in range(bars):
        if bar % 2 == 1 and r.random() < 0.8:
            note = bells[int(r.integers(len(bells)))]
            at = bar * 4 * beat + float(r.choice([0.5, 1.5, 2.5])) * beat
            place(out, bell(midi_hz(note), 2.5, 0.6) * 0.14, at, wrap=True)
    # distant low wind
    wind = fft_filter(noise(length, 9), 60, 450)  # circular, so it loops seamlessly
    out += wind * (0.6 + 0.4 * np.sin(2 * np.pi * t / length * 3)) * 0.35
    return reverb(out, 0.35, 3.0, damp=2500, loop=True)


def chirp(seed):
    r = rng(seed)
    out = np.zeros(int(0.5 * RATE))
    base = r.uniform(2800, 4200)
    for k in range(int(r.integers(2, 5))):
        d = r.uniform(0.04, 0.09)
        f = sweep(base * r.uniform(0.9, 1.1), base * r.uniform(1.2, 1.6), d, 0.7)
        place(out, sine(f, d) * np.sin(np.pi * np.linspace(0, 1, int(d * RATE))) ** 2, k * r.uniform(0.07, 0.12))
    return out


def day_ambience():
    length = 24.0
    n = int(length * RATE)
    t = np.arange(n) / RATE
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / length * 2) * np.sin(2 * np.pi * t / length * 5 + 1)
    wind = fft_filter(noise(length, 21), 300, 2200) * gust * 0.35
    out = wind
    r = rng(22)
    for i in range(14):
        place(out, chirp(100 + i) * r.uniform(0.08, 0.2), r.uniform(0, length), wrap=True)
    return reverb(out, 0.25, 1.5, loop=True)


def night_ambience():
    length = 24.0
    n = int(length * RATE)
    t = np.arange(n) / RATE
    out = fft_filter(noise(length, 31), 150, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * t / length * 2)) * 0.25
    r = rng(32)
    # Crickets: trains of 4.5 kHz pulses, several voices at different rates.
    for voice in range(4):
        freq = r.uniform(4200, 5200)
        rate = r.uniform(26, 34)
        phrase = r.uniform(0.6, 1.2)
        gap = r.uniform(0.4, 1.4)
        gate = (np.sin(2 * np.pi * rate * t) > 0.3).astype(float)
        cycle = phrase + gap
        on = ((t + voice * 0.37) % cycle) < phrase
        env = lowpass(gate * on, 400.0)
        out += np.sin(2 * np.pi * freq * t) * env * r.uniform(0.05, 0.09)
    return reverb(out, 0.3, 1.8, loop=True)


def campfire():
    length = 8.0
    n = int(length * RATE)
    roar = lowpass(brown(length, 41), 500) * 0.5
    hiss = fft_filter(noise(length, 42), 2000, 7000) * 0.04
    out = roar + hiss
    r = rng(43)
    for i in range(70):
        d = r.uniform(0.004, 0.02)
        c = bandpass(noise(d + 0.03, int(r.integers(1e6))), r.uniform(1500, 5000), 2.0) * env_perc(d + 0.03, 0.0002, d / 3)
        place(out, c * r.uniform(0.3, 1.2), r.uniform(0, length), wrap=True)
    for i in range(6):  # a few bigger pops
        place(out, bandpass(noise(0.08, 500 + i), 900, 1.5) * env_perc(0.08, 0.0005, 0.01) * 1.5,
              r.uniform(0, length), wrap=True)
    return soft_clip(out, 1.2)


LOOPS = {
    "music/day.ogg": (day_music, -3.0),
    "music/night.ogg": (night_music, -3.0),
    "ambience/day.ogg": (day_ambience, -6.0),
    "ambience/night.ogg": (night_ambience, -6.0),
    "ambience/campfire.ogg": (campfire, -4.0),
}


def crossfade_loop(x, seconds=0.75):
    """Folds the last `seconds` over the start with an equal-power fade,
    so any loop (even plain noise) wraps without a click."""
    k = int(seconds * RATE)
    ramp = np.linspace(0, np.pi / 2, k)
    y = x[:-k].copy()
    y[:k] = x[:k] * np.sin(ramp) + x[-k:] * np.cos(ramp)
    return y


def main(only=None):
    for path, (fn, peak) in LOOPS.items():
        if only and not any(o in path for o in only):
            continue
        x = fn()
        if path.startswith("ambience/"):
            x = crossfade_loop(x)
        write(path, x, peak_db=peak, trim=False)


if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
