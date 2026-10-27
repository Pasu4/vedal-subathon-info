# Regex

## Link from timestamp

Replace YouTube comment style timestamp with a link to the video at that timestamp.

**Find:** `(?<!\[)(\d\d):(\d\d):(\d\d)`<br>
**Replace:** `[$0](https://youtu.be/PLaceHoLdeR?t=$1h$2m$3s)`

## Escape pipes

Escape pipe characters in timestamps so they aren't interpreted as tables by Jekyll.

**Find:** `(?<!\\)\|`<br>
**Replace:** `\\|`

## Non-italic song titles

**Find:** `(?<=(\)|\|) )[^*—\n|]+—( [^\\\(\n\| ]+)+`<br>
**Replace:** `*$&*`

## Find negative timestamps

**Find:** `:-\d+`

## Find overflowing timestamps

**Find:** `:[6-9]\d|:1[01]\d`

## Fix timestamps with 1 digit

**Find:** `:(\d)(?=\]|:)`<br>
**Replace:** `:0$1`
