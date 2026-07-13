# Timestamping guidelines

- TOC
{:toc}

The following are the guidelines I use for timestamping.
If you want to help timestamp streams, you should refer to this document if you're unsure about something.
I won't fault you if you don't follow these guidelines exactly since they're quite extensive, but I may change some of your timestamps to be consistent with the others.
Note though that some of the guidelines are required for the script to work correctly.

## What to timestamp

## Timestamp syntax

For consistency and so the [script](#using-the-script) can parse them correctly, timestamps should follow the following syntax.
Examples and counterexamples are provided.

Note that the syntax is different for the `timestamps.md` file.
The reason for that is that this syntax uses YouTube comment formatting, while the file uses Markdown.
The YouTube format is automatically converted to Markdown by the script, so you don't have to do that manually.

### Timestamp

A timestamp should always have exactly two digits each for hours, minutes, and seconds, even if they are zeros.
This is so that all timestamps are aligned.

If the time of an event cannot be determined, use `‒‒:‒‒:‒‒` for the timestamp.
Important: Use figure dashes, not normal ones.
Normal dashes don't align properly with numbers, but figure dashes are designed for exactly that.

Correct examples:

```
‒‒:‒‒:‒‒ *Titanium — Stage Kids* (before start of VOD)
00:00:00 _Circles — KIRA & Rachie_
00:04:00 Neuro appears | *Just chatting*
01:35:01 *Art review*
```

Incorrect examples:

```
--:--:-- *Titanium — Stage Kids* (before start of VOD)
0:00 _Circles — KIRA & Rachie_
04:00 Neuro appears | *Just chatting*
1:35:01 *Art review*
```

### Entries

Each timestamp can have one or more entries.
Multiple entries are delimited by the pipe character (`|`).
There should never be a timestamp without entries.

Timestamps with multiple entries should be used if two or more events occur simultaneously (within ~10s of each other).
The timestamp used should correspond to the earliest of these events, and the events should be listed in the order they occur.

Correct examples:

```
00:00:00 _Circles — KIRA & Rachie_
00:04:00 Neuro appears | *Just chatting*
00:10:06 Evil appears | *Karaoke* | _Bewitching Eyes — Hades II_
```

Incorrect examples:

```
00:00:00 _Circles — KIRA & Rachie_ |
00:04:00 Neuro appears, *Just chatting*
00:10:06 Evil appears
00:10:06 *Karaoke*
00:10:07 _Bewitching Eyes — Hades II_
```

### Song

Songs should be *italic* (surround them with underscores (`_`)).
They should always list the title of the song *first* and the author *second*.
Title and author should be separated by an em dash (`—`), not a normal dash.
Capitalization of the title and author should match what is displayed on stream.
If they are not displayed, the spelling intended by the author should be used (i.e. google it).

Additional information can be added in parentheses, *outside* the italics.
Duets are a special form of this:
Specifying `(duet)` makes the script automatically add both Neuro and Evil as participants to the overview.
If `(duet w/ <name>)` is used, the named person will be added as a participant (prefer using just `(duet)` if it's with the other twin).

Correct examples:

```
00:00:00 _Circles — KIRA & Rachie_
00:04:02 _What Is Love — Haddaway_
00:05:34 _LEMON MELON COOKIE — TAK_
00:06:42 _Through the Fire and Flames — DragonForce_ (instrumental)
00:35:23 _Happier — YUNGBLUD_ (duet)
01:23:45 _Chinatown Blues — ODDEEO & Karma Wears White Tears_ (duet w/ Vedal)
```

Incorrect examples:

```
00:00:00 Circles — KIRA & Rachie
00:04:02 _What Is Love - Haddaway_
00:05:34 _Lemon Melon Cookie — Tak_
00:06:42 _Through the Fire and Flames — DragonForce (instrumental)_
00:35:23 _Happier — YUNGBLUD_ (duet w/ Evil)
01:23:45 _Chinatown Blues — ODDEEO & Karma Wears White Tears_ (duet with Vedal)
```

### Participants

A participant is someone who appears on stream, for example by joining the voice call or the current stream game.
For the script to detect this, you need to use one of the following verbs:

- **"appear(s)":** Should be used if nobody was on stream immediately prior. Usually that is only the start of the stream, but may also be used for example if there are technical difficulties and Neuro disappears.
- **"join(s)":** Used if there is someone else on screen already.
- **"wake(s) up":** Used when Neuro/Evil exits "sleeping state". Usually only used for subathons.

There are also inverse verbs to the above, which don't have a meaning to the script, but are listed here for consistency:

- **"disappear(s)":** May be used if the disappearance is unplanned or unexpected.
- **"leave(s)":** Used in most cases where a participant ceases to be on stream.
- **"go(es) to sleep":** Used when Neuro/Evil enters "sleeping state". Usually only used for subathons.

TODO: time joined

TODO: not log if leave not long enough

TODO: order of participants

If there is possible confusion in what way they joined, you can specify this after the verb, e.g. "Camila joins VC" or "Vedal joins the game".

### Content entry

TODO

### Miscellaneous

TODO

### Subheading

TODO

## When does stuff happen

game: audible or visible
art review: no source visible

## Using the script

The script `utils/convert.ps1` used to automatically fetch timestamps from a YouTube comment, parse them, and automatically add the correct entries to the content file.

- YouTube API key
