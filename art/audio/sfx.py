"""One-shot sound effects (feature 016). Run: tools/build_audio.sh

Each effect is written as game/assets/audio/sfx/<id>_<n>.ogg; the
AudioManager picks a random variant. The ids match Fx.burst kinds where
a burst already exists (hit, wood, stone, ...), so those play for free.
Tone: warm, toy-like and never harsh; the players are young kids.
"""
import numpy as np

from dsp import (RATE, bandpass, bell, env_adsr, env_perc, fade, highpass, knock, lowpass, midi_hz, noise, owl,
                 pad, place, pluck, reverb, rng, sine, soft_clip, soft_tone, sweep, t_axis, write)


def silence(seconds):
    return np.zeros(int(seconds * RATE))


def hit(v):
    """Leo's stick connecting: a padded thwack."""
    d = 0.22
    r = rng(100 + v)
    thump = sine(sweep(190 + 20 * v, 55, d), d) * env_perc(d, 0.001, 0.045)
    snap = bandpass(noise(d, 10 + v), 1800 + 300 * v, 1.5) * env_perc(d, 0.0005, 0.018)
    body = knock(420 + r.uniform(-40, 40), d, seed=20 + v, q=4.0)
    return soft_clip(thump * 1.2 + snap * 1.4 + body * 0.5, 1.5)


def wood(v):
    """Chop: axe-ish knock plus a splintery tick."""
    d = 0.35
    a = knock(520 + 60 * v, d, seed=30 + v, q=5.0)
    split = highpass(noise(d, 40 + v), 2500) * env_perc(d, 0.001, 0.03) * 0.5
    x = a + split
    x = place(x, knock(700 + 40 * v, 0.2, seed=50 + v) * 0.35, 0.07)
    return reverb(x, 0.12, 0.6)


def stone(v):
    """Pick on rock: a bright clink with inharmonic partials."""
    d = 0.45
    t = t_axis(d)
    base = 1900 + 230 * v
    x = np.zeros(len(t))
    for ratio, amp, life in ((1.0, 1.0, 0.09), (1.73, 0.6, 0.06), (2.61, 0.4, 0.04), (3.9, 0.25, 0.03)):
        x += amp * np.sin(2 * np.pi * base * ratio * t) * np.exp(-t / life)
    click = bandpass(noise(d, 60 + v), 4000, 1.0) * env_perc(d, 0.0003, 0.006)
    thud = sine(sweep(160, 70, d), d) * env_perc(d, 0.001, 0.03)
    return reverb(x * 0.5 + click + thud * 0.8, 0.15, 0.7)


def rustle(seconds, seed, center=3500.0):
    n = noise(seconds, seed)
    wobble = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * rng(seed).uniform(9, 14) * t_axis(seconds)))
    return bandpass(n, center, 1.2) * wobble * env_adsr(seconds, 0.03, seconds * 0.6)


def berries(v):
    """Leafy rustle and a juicy little pop."""
    x = rustle(0.3, 70 + v)
    pop = sine(sweep(500 + 80 * v, 1300, 0.07, 0.5), 0.07) * env_perc(0.07, 0.001, 0.02)
    return place(x * 0.7, pop, 0.12 + 0.03 * v)


def leaves(v):
    """A soft armful of leaves: two rustles, no pop."""
    out = rustle(0.35, 75 + v, 2800)
    return place(out, rustle(0.25, 77 + v, 4200) * 0.6, 0.1)


def resin(v):
    """Knock on a pine plus a sticky gloop."""
    d = 0.4
    x = knock(460 + 40 * v, 0.25, seed=80 + v) * 0.7
    f = sweep(420, 170, 0.22, 0.6) * (1 + 0.08 * np.sin(2 * np.pi * 28 * t_axis(0.22)))
    gloop = lowpass(sine(f, 0.22), 1200) * env_adsr(0.22, 0.01, 0.1)
    out = np.zeros(int(d * RATE))
    place(out, x, 0.0)
    place(out, gloop * 0.8, 0.09)
    return reverb(out, 0.12, 0.5)


def dust(v):
    """Torch pushed into the ground: soft earthy thud."""
    d = 0.35
    x = lowpass(noise(d, 90 + v), 600) * env_perc(d, 0.004, 0.06) * 2.5
    thump = sine(sweep(120, 50, d), d) * env_perc(d, 0.002, 0.05)
    return x + thump


def heal(v):
    """Warm two-note rise."""
    notes = [(76, 0.0), (83, 0.09)] if v == 0 else [(74, 0.0), (81, 0.09)]
    out = silence(0.9)
    for n, at in notes:
        place(out, soft_tone(midi_hz(n), 0.6, 0.01, 0.4, (1.0, 0.3, 0.1)) * env_perc(0.6, 0.01, 0.25), at)
    return reverb(out, 0.3, 1.2)


def level_up(v):
    """Rising bell arpeggio with a shimmer on top."""
    out = silence(1.8)
    for i, n in enumerate((72, 76, 79, 84)):
        place(out, bell(midi_hz(n), 1.2) * (0.8 + 0.1 * i), i * 0.08)
    shimmer = highpass(noise(1.0, 120), 6000) * env_adsr(1.0, 0.25, 0.7) * 0.08
    place(out, shimmer, 0.25)
    place(out, bell(midi_hz(88), 1.0, 0.6) * 0.5, 0.34)
    return reverb(out, 0.35, 1.8)


def sparkle(v):
    """Tiny XP chime."""
    out = silence(0.6)
    base = (91, 88)[v % 2]
    place(out, bell(midi_hz(base), 0.4, 0.5) * 0.7, 0.0)
    place(out, bell(midi_hz(base + 5), 0.4, 0.5) * 0.5, 0.06)
    return reverb(out, 0.25, 0.9)


def shadow_spawn(v):
    """Dark whoosh rising out of the ground, with a low growl."""
    d = 1.1
    t = t_axis(d)
    n = noise(d, 130 + v)
    cutoff = 200 + 1400 * (t / d) ** 1.5
    whoosh = lowpass(n, cutoff) * np.sin(np.pi * t / d) ** 2 * 2.0
    growl = (sine(62 + 4 * v + 3 * np.sin(2 * np.pi * 7 * t), d) + 0.5 * sine(93 + 5 * v, d))
    growl = soft_clip(growl * 1.5, 2.0) * env_adsr(d, 0.4, 0.4) * 0.35
    return reverb(whoosh + growl, 0.3, 1.4, damp=2000)


def shadow_death(v):
    """Cartoon 'poof' and a falling squeak; silly more than scary."""
    d = 0.6
    poof = lowpass(noise(d, 140 + v), sweep(3000, 300, d)) * env_perc(d, 0.003, 0.09) * 2.2
    squeak = sine(sweep(950 + 90 * v, 180, 0.35, 0.8), 0.35) * env_adsr(0.35, 0.005, 0.15) * 0.45
    out = poof
    place(out, squeak, 0.03)
    return reverb(out, 0.2, 0.8)


def build(v):
    """A building breaking: splintering planks."""
    out = silence(0.9)
    r = rng(150 + v)
    for i in range(5):
        place(out, knock(r.uniform(300, 700), 0.25, seed=160 + 10 * v + i) * r.uniform(0.5, 1.0), i * r.uniform(0.04, 0.08))
    crunch = bandpass(noise(0.5, 170 + v), 1400, 0.8) * env_perc(0.5, 0.002, 0.1)
    place(out, crunch, 0.0)
    return reverb(out, 0.18, 0.8)


def place_sfx(v):
    """Building placed: two solid thunks and a little settle."""
    out = silence(0.6)
    place(out, knock(260 + 20 * v, 0.3, seed=180 + v, q=3.0) * 1.2, 0.0)
    place(out, knock(340 + 20 * v, 0.25, seed=190 + v, q=4.0) * 0.7, 0.11)
    place(out, dust(v) * 0.5, 0.0)
    return reverb(out, 0.15, 0.7)


def craft(v):
    """Whittle-whittle-ding: two quick knocks and a happy chime."""
    out = silence(1.2)
    place(out, knock(820, 0.12, seed=200) * 0.6, 0.0)
    place(out, knock(900, 0.12, seed=201) * 0.6, 0.11)
    place(out, bell(midi_hz(84 + (2 if v else 0)), 0.9, 0.7) * 0.9, 0.24)
    place(out, bell(midi_hz(91 + (2 if v else 0)), 0.7, 0.5) * 0.4, 0.3)
    return reverb(out, 0.25, 1.0)


def ui_click(v):
    """Soft wooden tick for buttons."""
    d = 0.08
    return knock(1200 + 150 * v, d, seed=210 + v, q=8.0) * 0.8 + sine(1800, d) * env_perc(d, 0.0005, 0.008) * 0.3


def player_hurt(v):
    """Leo gets bonked: a padded thump and a short 'oof'-ish dip."""
    d = 0.3
    thump = sine(sweep(140, 55, d), d) * env_perc(d, 0.001, 0.05) * 1.3
    f = sweep(330 + 25 * v, 210, 0.18, 0.7)
    voice = sine(f, 0.18) + 0.5 * sine(f * 2, 0.18) + 0.3 * sine(f * 3, 0.18)
    voice = lowpass(voice, 1100) * env_adsr(0.18, 0.01, 0.08) * 0.55
    out = thump
    place(out, voice, 0.02)
    return soft_clip(out, 1.3)


def sibling_hurt(v):
    """Nela gets bonked: lighter thump, a higher little 'eep'."""
    d = 0.28
    thump = sine(sweep(170, 70, d), d) * env_perc(d, 0.001, 0.04)
    f = sweep(520 + 30 * v, 360, 0.16, 0.7)
    voice = sine(f, 0.16) + 0.4 * sine(f * 2, 0.16) + 0.2 * sine(f * 3, 0.16)
    voice = lowpass(voice, 1600) * env_adsr(0.16, 0.01, 0.07) * 0.5
    out = thump
    place(out, voice, 0.02)
    return soft_clip(out, 1.3)


def structure_hit(v):
    """An imp clawing a fence or post: a dull knock and a scratch."""
    d = 0.3
    x = knock(300 + 40 * v, 0.22, seed=240 + v, q=3.0)
    scratch = bandpass(noise(0.12, 250 + v), 2600, 2.0) * env_adsr(0.12, 0.005, 0.08) * 0.5
    out = np.zeros(int(d * RATE))
    place(out, x, 0.0)
    place(out, scratch, 0.03)
    return out


def task(v):
    """Nela says 'OK!': a friendly two-note pluck."""
    out = silence(0.8)
    a, b = ((72, 79), (74, 79), (76, 81))[v % 3]
    place(out, pluck(midi_hz(a), 0.5, 0.6, 400 + v) * 0.8, 0.0)
    place(out, pluck(midi_hz(b), 0.6, 0.6, 410 + v) * 0.8, 0.09)
    return reverb(out, 0.2, 0.8)


def repair(v):
    """A hammer tap on wood: a bright knock with a short metal ring."""
    d = 0.5
    t = t_axis(d)
    ring = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((2300 + 120 * v, 0.5), (3900 + 150 * v, 0.25))) * np.exp(-t / 0.05)
    out = knock(620 + 40 * v, 0.25, seed=420 + v, q=5.0) * 0.9
    out = np.concatenate([out, np.zeros(len(t) - len(out))])
    return reverb(out + ring * 0.35, 0.15, 0.6)


def clay(v):
    """Digging clay: a wet squelch and a soft plop."""
    d = 0.4
    t = t_axis(d)
    squelch = lowpass(noise(d, 430 + v), 700 + 500 * np.sin(np.pi * t / d)) * env_adsr(d, 0.02, 0.2) * 1.8
    plop = sine(sweep(260 + 30 * v, 120, 0.12, 0.6), 0.12) * env_perc(0.12, 0.002, 0.03)
    out = squelch
    place(out, plop * 0.8, 0.18)
    return out


def mushrooms(v):
    """Picking a mushroom: a soft snap and a little pop."""
    out = rustle(0.25, 440 + v, 3000) * 0.5
    snap_ = bandpass(noise(0.05, 450 + v), 1800, 2.0) * env_perc(0.05, 0.0005, 0.008) * 1.5
    pop = sine(sweep(380 + 60 * v, 900, 0.08, 0.5), 0.08) * env_perc(0.08, 0.001, 0.025)
    place(out, snap_, 0.05)
    place(out, pop * 0.7, 0.08)
    return out


def scrap(v):
    """Rummaging junk: a tinny clank with a rattle."""
    d = 0.6
    t = t_axis(d)
    out = np.zeros(len(t))
    r = rng(460 + v)
    for k in range(3):
        base = r.uniform(900, 1600)
        tone = sum(a * np.sin(2 * np.pi * base * m * t) for m, a in ((1.0, 0.6), (2.3, 0.35), (3.7, 0.2))) * np.exp(-t / 0.06)
        place(out, tone[: int(0.3 * RATE)] * r.uniform(0.4, 0.8), k * r.uniform(0.05, 0.1))
    place(out, knock(400, 0.2, seed=470 + v) * 0.5, 0.0)
    return reverb(out, 0.15, 0.6)


def shard(v):
    """Picking up a Glow Shard: a sparkly rising chime."""
    out = silence(1.2)
    notes = (84, 88, 91, 96) if v == 0 else (86, 89, 93, 98)
    for i, n in enumerate(notes):
        place(out, bell(midi_hz(n), 0.7, 0.8) * (0.6 - 0.08 * i), i * 0.05)
    place(out, highpass(noise(0.6, 480 + v), 7000) * env_adsr(0.6, 0.05, 0.5) * 0.06, 0.05)
    return reverb(out, 0.35, 1.4)


def trap_snap(v):
    """The snap trap closing: a hard wooden clack and a spring twang."""
    d = 0.6
    clack = knock(900 + 80 * v, 0.15, seed=490 + v, q=3.0) * 1.3
    t = t_axis(0.5)
    twang = np.sin(2 * np.pi * (180 + 20 * v) * t + 3 * np.sin(2 * np.pi * 7 * t)) * np.exp(-t / 0.12) * 0.35
    out = np.zeros(int(d * RATE))
    place(out, clack, 0.0)
    place(out, twang, 0.01)
    place(out, sine(sweep(140, 60, 0.2), 0.2) * env_perc(0.2, 0.001, 0.04) * 0.8, 0.0)
    return out


def camp_hit(v):
    """Imp hitting the campfire: a thud and a spray of sparks."""
    d = 0.6
    thud = sine(sweep(110, 50, d), d) * env_perc(d, 0.002, 0.07)
    out = thud + lowpass(noise(d, 220 + v), 900) * env_perc(d, 0.002, 0.05)
    r = rng(230 + v)
    for _ in range(9):
        c = highpass(noise(0.02, int(r.integers(1e6))), 3000) * env_perc(0.02, 0.0002, 0.003)
        place(out, c * r.uniform(0.3, 0.8), r.uniform(0.02, 0.4))
    return out


def sunset(v):
    """The night warning: an owl calls twice over a low swell."""
    out = silence(3.2)
    place(out, owl(0.45, 395) * 0.9, 0.2)
    place(out, owl(0.8, 370), 0.85)
    swell = (sine(midi_hz(50), 3.0) + 0.5 * sine(midi_hz(57), 3.0)) * env_adsr(3.0, 1.2, 1.4) * 0.25
    place(out, swell, 0.0)
    return reverb(out, 0.4, 2.4, damp=2500)


def stinger(notes, chord, seconds, seed):
    out = silence(seconds + 2.0)
    step = 0.16
    for i, n in enumerate(notes):
        place(out, pluck(midi_hz(n), 1.2, 0.6, seed + i) * 0.8, i * step)
        place(out, bell(midi_hz(n + 12), 0.8, 0.4) * 0.25, i * step)
    at = len(notes) * step
    place(out, pad([midi_hz(n) for n in chord], seconds - at + 0.5, 0.05, 1.2), at)
    for n in chord:
        place(out, pluck(midi_hz(n), 2.0, 0.5, seed + n) * 0.5, at)
    return reverb(out, 0.3, 2.0)


def win(v):
    return stinger([67, 71, 74, 79], [55, 67, 71, 74, 79], 2.8, 300)


def lose(v):
    return stinger([69, 65, 62, 57], [50, 62, 65, 69], 2.8, 310)


SOUNDS = {
    "hit": (hit, 3),
    "wood": (wood, 3),
    "stone": (stone, 3),
    "berries": (berries, 3),
    "leaves": (leaves, 2),
    "resin": (resin, 2),
    "dust": (dust, 2),
    "heal": (heal, 2),
    "level_up": (level_up, 1),
    "sparkle": (sparkle, 2),
    "shadow_spawn": (shadow_spawn, 3),
    "shadow_death": (shadow_death, 3),
    "build": (build, 2),
    "place": (place_sfx, 2),
    "craft": (craft, 2),
    "ui_click": (ui_click, 2),
    "player_hurt": (player_hurt, 3),
    "camp_hit": (camp_hit, 2),
    "sibling_hurt": (sibling_hurt, 3),
    "structure_hit": (structure_hit, 3),
    "task": (task, 3),
    "repair": (repair, 3),
    "clay": (clay, 2),
    "mushrooms": (mushrooms, 2),
    "scrap": (scrap, 3),
    "shard": (shard, 2),
    "trap_snap": (trap_snap, 2),
    "sunset": (sunset, 1),
    "win": (win, 1),
    "lose": (lose, 1),
}


def main(only=None):
    for name, (fn, variants) in SOUNDS.items():
        if only and name not in only:
            continue
        for v in range(variants):
            write("sfx/%s_%d.ogg" % (name, v + 1), fade(fn(v), 0.0, 0.01), peak_db=-3.0)


if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
