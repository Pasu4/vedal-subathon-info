# Vedal Subathon Info

## About

This repository contains information about the subathons (and possibly other streams) of the streamer [vedal987](https://twitch.tv/vedal987).
Timestamps are based on the unofficial VOD archive on YouTube by [Neuro Archiver](https://youtube.com/@NArchiver).
Information in this repository currently includes:

- Timestamps starting from the 2025 subathon
- Content overview (i.e. what happened on what day) starting from the 2025 subathon
- Subgoals from the 2025 subathon

I ([@Pasu4](https://github.com/Pasu4)) plan to add the following in the future once the subathon is finished, if I have the time:

- Content overview, sub goals and partial timestamps for the 2024 subathon
- Screen time for stream participants
- Graph showing timer value and subs over time
    - Probably one data point per hour, with higher resolution and/or separate graph for the Hype Train records
- Graphical timeline

Also thanks to [@KTrain5169](https://github.com/KTrain5169) for helping out with the repo.

## Links

- 2025 subathon
    - [Timestamps](/2025-subathon/timestamps.md)
    - [Overview](/2025-subathon/overview.md)
    - [Subgoals](/2025-subathon/subgoals.md)
- 2026
    - [Timestamps](/2026/timestamps.md)
    - [Overview](/2026/overview.md)

## How to read timestamps

Information about how I format timestamps, for better reading comprehension or for contributors.
Note that timestamps from early in the 2024 subathon (once I add them) may not use this exact format, since I wrote them before I started using this format consistently.

**Bold** entries are meant to be categories that span from one bold entry to the next.
They are not necessarily real stream categories from Twitch, just a way to loosely split the stream into thematic chunks ("chapters" if you will).

The parts of entries in *italics* are titles, used for songs, games, presentations, etc.
Songs with no official name (e.g. the subathon mixes) are not in italics.

Songs use the format "\<title\> — \<author\>".
That is an emdash (—), not a dash (-).

Intervals are used to reduce the number of timestamps when someone leaves, joins, mutes or unmutes.
Joining and unmuting use intervals for up to 15 minutes, after which two timestamps are used instead.
Leaving and muting use intervals up to 10 minutes, and below 1 minute are not timestamped at all.
For simplicity, an interval cannot contain intervals of the opposite type, in that case the start and end of the enclosing interval are timestamped separately instead.

## Deploy status (not important to visitors)

[![Deploy Jekyll with GitHub Pages dependencies preinstalled](https://github.com/Pasu4/vedal-subathon-info/actions/workflows/pages.yml/badge.svg)](https://github.com/Pasu4/vedal-subathon-info/actions/workflows/pages.yml)
