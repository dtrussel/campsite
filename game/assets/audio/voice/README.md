# Voice lines (feature 035)

One file per story line, named by the line id from
`res://resources/story/*.tres`:

    intro.c1.1.1.ogg      (narrator, Chapter 1 intro, page 1, line 1)
    dawn.c1.n1.leo.2.ogg  (Nela's reply on dawn 1 when Leo is played)
    loss.fire.1.ogg
    bark.thief.nela.2.ogg (a bark, feature 037: res://resources/barks/barks.tres)

## Generated placeholders

Every line here is currently **generated** with Kokoro TTS by
`art/audio/voice.py` (see the cast in `docs/design/story.md`, Voice).
After changing a line's text, regenerate it:

    tools/build_audio.sh voice dawn.c1.n1    # ids starting with this
    tools/build_audio.sh voice nela          # every line of one speaker
    tools/build_audio.sh voice               # everything (~2 min)

## Real recordings

Drop a recording in with the same name and it replaces the generated
one; don't regenerate that id afterwards. `.ogg` is preferred; `.wav`
and `.mp3` work too. No code changes are needed: a line with a file
plays its voice, a line without one is shown as text only (a bark
without one chirps instead). `tools/check.sh` prints how many lines are
voiced and fails on a file that matches no line id (a typo).
