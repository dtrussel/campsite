# Voice lines (feature 035)

Drop the team's recordings here, one file per story line, named by the
line id from `res://resources/story/*.tres`:

    intro.c1.1.1.ogg      (narrator, Chapter 1 intro, page 1, line 1)
    dawn.c1.n1.leo.2.ogg  (Nela's reply on dawn 1 when Leo is played)
    loss.fire.1.ogg
    bark.thief.nela.2.ogg (a bark, feature 037: res://resources/barks/barks.tres)

`.ogg` is preferred; `.wav` and `.mp3` work too. No code changes are
needed: a line with a file plays its voice, a line without one is shown
as text only (a bark without one chirps instead). `tools/check.sh` prints how many lines are voiced and
fails on a file that matches no line id (a typo).
