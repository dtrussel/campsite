"""Generated voice lines for the story and barks. Run: tools/build_audio.sh voice

Each story line and bark (game/resources/story/*.tres,
game/resources/barks/barks.tres) is spoken with Kokoro TTS and written as
game/assets/audio/voice/<line id>.ogg, the name StoryLibrary.voice()
looks for. These are placeholders: a real recording with the same name
simply replaces one.

The model files (~350 MB, Apache-2.0) are downloaded on first run into
art/audio/.voice-cache/ (gitignored) from the kokoro-onnx GitHub release.

    tools/build_audio.sh voice                 # every line
    tools/build_audio.sh voice bark.thief nela # ids starting with, or a speaker
    tools/build_audio.sh voice --names         # just the lines with a name
    tools/build_audio.sh voice --audition      # cast candidates, to the cache
"""
import glob
import os
import re
import subprocess
import sys
import tempfile
import urllib.request

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CACHE = os.path.join(HERE, ".voice-cache")
OUT_DIR = os.path.join(ROOT, "game", "assets", "audio", "voice")
MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/"
MODEL_FILES = ("kokoro-v1.0.onnx", "voices-v1.0.bin")
CONTENT = ("game/resources/story/*.tres", "game/resources/barks/*.tres")
KEY = re.compile(r'"(id|speaker|text)":\s*"((?:[^"\\]|\\.)*)"')

# Who speaks how. `voice` is a Kokoro voice, or a blend {voice: weight}.
# `shift` is in semitones (formants move with it: a smaller vocal tract).
# Leo blends a young male and a female voice: a boy, not a woman.
# Leo (7): brave, impulsive, quick. Nela (3): the little sister, higher,
# slower and dry. Mum: calm, warm ranger. Narrator: a bedtime storyteller.
CAST = {
    "leo": {"voice": {"am_liam": 0.5, "af_aoede": 0.5}, "speed": 1.05, "shift": 4.0, "lang": "en-us"},
    "nela": {"voice": {"af_jessica": 0.6, "af_bella": 0.4}, "speed": 0.95, "shift": 2.5, "lang": "en-us"},
    "mum": {"voice": "af_heart", "speed": 0.92, "shift": 0.0, "lang": "en-us"},
    "narrator": {"voice": "bm_fable", "speed": 0.9, "shift": 0.0, "lang": "en-gb"},
}

# Spoken text where the card's spelling trips the TTS up (card text stays).
SAY = {}

# The kids' names are said the German way: Nela [ˈneːla], Leo [ˈleːo].
# Keys are the English phonemes Kokoro's tokenizer gives (en-us, en-gb).
NAME_WORDS = re.compile(r"\b(Nela|Leo)\b")
NAMES = {"nˈɛlə": "nˈeːla", "lˈiːoʊ": "lˈeːo", "lˈiːəʊ": "lˈeːo"}

AUDITION = {
    "leo": [{"am_liam": 0.5, "af_aoede": 0.5}, {"am_puck": 0.6, "af_river": 0.4}, {"am_echo": 0.5, "af_sky": 0.5}],
    "nela": ["af_bella", "af_jessica", "af_heart", {"af_jessica": 0.6, "af_bella": 0.4}],
    "mum": ["af_heart", "bf_emma", "af_sarah"],
    "narrator": ["bm_fable", "bm_george", "am_michael"],
}
AUDITION_LINE = {
    "leo": "Stay behind me, Nela! Okay, maybe next to me.",
    "nela": "Those imps only come where it's dark. Light means safe.",
    "mum": "Day three. The moss glows where the shards fell.",
    "narrator": "Leo and Nela were camping with Mum by the Hollow Wood.",
}
LUFS = -18.0
PAD = 0.06


def lines():
    """[(id, speaker, text)] from every story and bark resource."""
    found = []
    for pattern in CONTENT:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            with open(path, encoding="utf-8") as f:
                body = f.read()
            for block in re.findall(r"\{[^{}]*\}", body):
                fields = dict(KEY.findall(block))
                if {"id", "speaker", "text"} <= fields.keys():
                    text = fields["text"].replace('\\"', '"')
                    found.append((fields["id"], fields["speaker"], text))
    return found


def kokoro():
    from kokoro_onnx import Kokoro

    os.makedirs(CACHE, exist_ok=True)
    for name in MODEL_FILES:
        path = os.path.join(CACHE, name)
        if not os.path.exists(path):
            print("downloading", name)
            urllib.request.urlretrieve(MODEL_URL + name, path + ".part")
            os.replace(path + ".part", path)
    return Kokoro(*(os.path.join(CACHE, n) for n in MODEL_FILES))


def style(tts, voice):
    if isinstance(voice, str):
        return voice
    total = sum(voice.values())
    return sum(tts.get_voice_style(v) * (w / total) for v, w in voice.items())


def mean_f0(x, rate):
    """Median pitch (Hz) of the voiced 40 ms frames, by autocorrelation."""
    n = int(0.04 * rate)
    lo, hi = int(rate / 600), int(rate / 70)
    peak = np.abs(x).max() or 1.0
    found = []
    for i in range(0, len(x) - n, n // 2):
        frame = x[i: i + n] - x[i: i + n].mean()
        if np.abs(frame).max() < peak * 0.2:
            continue
        ac = np.correlate(frame, frame, "full")[n - 1:]
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] > 0.5 * ac[0]:
            found.append(rate / lag)
    return float(np.median(found)) if found else 0.0


def trim(x, rate):
    loud = np.nonzero(np.abs(x) > np.abs(x).max() * 0.02)[0]
    if not len(loud):
        return x
    pad = int(PAD * rate)
    return x[max(0, loud[0] - pad): loud[-1] + pad]


def finish(x, rate, shift, path):
    """Pitch shift, loudness-normalise and encode to Vorbis with ffmpeg."""
    with tempfile.NamedTemporaryFile(suffix=".wav") as raw:
        sf.write(raw.name, trim(x, rate), rate)
        chain = ["loudnorm=I=%.0f:TP=-2:LRA=7" % LUFS, "aresample=%d" % rate]
        if shift:
            chain.insert(0, "rubberband=pitch=%.4f" % (2 ** (shift / 12)))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", raw.name, "-af", ",".join(chain),
                        "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    out, out_rate = sf.read(path)
    return len(out) / out_rate, mean_f0(out, out_rate)


def phonemes(tts, text, lang):
    """Kokoro's phonemes for `text`, with the names swapped for NAMES."""
    said = tts.tokenizer.phonemize(text, lang)
    for english, german in NAMES.items():
        said = re.sub(r"(?<!\w)%s" % re.escape(english), german, said)
    return said


def speak(tts, cast, text, path):
    style_ = style(tts, cast["voice"])
    if NAME_WORDS.search(text):
        samples, rate = tts.create(phonemes(tts, text, cast["lang"]), voice=style_, speed=cast["speed"],
                                   lang=cast["lang"], is_phonemes=True)
    else:
        samples, rate = tts.create(text, voice=style_, speed=cast["speed"], lang=cast["lang"])
    return finish(np.asarray(samples, dtype=np.float64), rate, cast["shift"], path)


def audition(tts):
    out = os.path.join(CACHE, "audition")
    os.makedirs(out, exist_ok=True)
    for speaker, voices in AUDITION.items():
        for voice in voices:
            cast = dict(CAST[speaker], voice=voice)
            name = voice if isinstance(voice, str) else "+".join(voice)
            path = os.path.join(out, "%s_%s.ogg" % (speaker, name))
            seconds, f0 = speak(tts, cast, AUDITION_LINE[speaker], path)
            print("%-9s %-20s %4.1fs  f0 %3.0f Hz" % (speaker, name, seconds, f0))


def main(args):
    tts = kokoro()
    if "--audition" in args:
        audition(tts)
        return
    os.makedirs(OUT_DIR, exist_ok=True)
    names_only = "--names" in args
    args = [a for a in args if a != "--names"]
    stats = {}
    for line_id, speaker, text in lines():
        if names_only and not NAME_WORDS.search(text):
            continue
        if args and speaker not in args and not any(line_id.startswith(a) for a in args):
            continue
        if speaker not in CAST:
            print("skip %s: no voice cast for %s" % (line_id, speaker))
            continue
        seconds, f0 = speak(tts, CAST[speaker], SAY.get(line_id, text), os.path.join(OUT_DIR, line_id + ".ogg"))
        stats.setdefault(speaker, []).append((seconds, f0))
        print("wrote %-28s %-8s %4.1fs %3.0f Hz  %s" % (line_id, speaker, seconds, f0, text))
    for speaker, rows in stats.items():
        seconds = [r[0] for r in rows]
        print("%-9s %3d lines  %.1f-%.1fs  f0 %3.0f Hz" % (
            speaker, len(rows), min(seconds), max(seconds), np.median([r[1] for r in rows])))


if __name__ == "__main__":
    main(sys.argv[1:])
