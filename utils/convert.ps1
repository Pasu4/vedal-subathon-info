param (
    [Parameter(Mandatory=$false)][string]$Link,
    [Parameter(Mandatory=$true)][string]$File,
    [Parameter(Mandatory=$false)][switch]$Auto
)

if (-not $File -match '\.md$') {
    Write-Output "Not a Markdown file!"
    Write-Output "(Hint: Make sure your cursor is in the correct file)"
}

# TODO: yt-dlp.exe --skip-download --extractor-args "youtube:max_comments=1000,all,all,all,1" --write-comments --dump-json -o comments.json -I 1 "https://www.youtube.com/@NArchiver" | jq "{comment: [(.comments[] | select(.author == \"@Pasu4\") | .text)] | .[-1], title: .title, id: .id}"

if ($Auto) {
    $fetched = yt-dlp.exe -s -O "%(title)s::%(id)s" -I 1 "https://www.youtube.com/@NArchiver"
    $fetched = $fetched -split "::"
    $videoTitle = $fetched[0]
    $videoId = $fetched[1]
}
# Extract video ID from the link
elseif ($Link -match 'v=([a-zA-Z0-9_-]{11})') {
    $videoId = $matches[1]
} elseif ($Link -match 'youtu\.be/([a-zA-Z0-9_-]{11})') {
    $videoId = $matches[1]
} else {
    Write-Error "Invalid YouTube link format."
    exit 1
}

$content=Get-Content $File

# Title
if ($videoTitle) {
    $videoTitle, $date = $videoTitle -split ' - ', -2
    # TODO: Prefix day with 0 if it's a single digit
    $date = $date -replace '(\d+) (\w{3})\w* (\d+)', '$1 $2 $3'
    $content = $content -replace '^##\s*$', "## $videoTitle ([$date](https://youtu.be/$videoId))"
}

# Markdown links
$content = $content -replace '(?<!\[)(\d\d):(\d\d):(\d\d)', ('[$0](https://youtu.be/' + "$videoId" + '?t=$1h$2m$3s)')

# Escape pipes
$content = $content -replace '(?<!\\)\|', '\|'

# Make song titles italic
$content = $content -replace '(?<=(\)|\|) )[^*—\n|]+—( [^\\\(\n\| ]+)+', '*$0*'

# TODO: Auto-process raid targets + add line to table

Set-Content -Path $File -Value $content