# Regex

## Link from timestamp

Replace YouTube comment style timestamp with a link to the video at that timestamp.

**Find:** `(?<!\[)(\d\d):(\d\d):(\d\d)`<br>
**Replace:** `[$0](https://youtu.be/PLaceHoLdeR?t=$1h$2m$3s)`

## Escape pipes

Escape pipe characters in timestamps so they aren't interpreted as tables by Jekyll.

**Find:** `(?<!\\)\|`<br>
**Replace:** `\\|`
