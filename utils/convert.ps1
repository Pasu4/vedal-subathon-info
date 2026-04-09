param (
    [Parameter(Mandatory=$false)][string]$Link,
    [Parameter(Mandatory=$true)][string]$TimestampsFile,
    [Parameter(Mandatory=$false)][string]$OverviewFile,
    [Parameter(Mandatory=$false)][string]$Auto
)

# Constants
$TimestampsFile = "timestamps.md"
$OverviewFile = "overview.md"

if ($Auto -eq "simple") {
    # Only fetch the title and ID
    $fetched = yt-dlp.exe -s -O "%(title)s::%(id)s" -I 1 "https://www.youtube.com/@NArchiver"
    $fetched = $fetched -split "::"
    $videoTitle = $fetched[0]
    $videoId = $fetched[1]
}
elseif ($Auto -eq "full") {
    # Additionally extract timestamps from the comment by @Pasu4
    $fetched = (
        yt-dlp.exe `
            --skip-download `
            --extractor-args "youtube:max_comments=1000,all,all,all,1" `
            --write-comments `
            --dump-json `
            -I 1 `
            "https://www.youtube.com/@NArchiver"
        | jq.exe "{comment: [(.comments[] | select(.author == `"@Pasu4`") | .text)] | .[-1], title: .title, id: .id}"
        | ConvertFrom-Json
    )
    $videoTitle = $fetched.title
    $videoId = $fetched.id
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

$content=Get-Content $TimestampsFile

# Add content from @Pasu4's comment if in full auto mode
if ($Auto -eq "full") {
    $addContent = $fetched.comment
    if (-not $addContent) {
        Write-Error "No comment found by @Pasu4, cannot add timestamps."
        exit 1
    }

    # Parse games
    $addContent -match 'Playing _(.+?)_'
    $contentEntries = (
        (
            Select-String 'Playing _(.+?)_' -input $addContent -AllMatches
        ).Matches
        | ForEach-Object {$_.Groups[1]}
    ).Value
    # Parse other content
    $contentEntries = $contentEntries + (
        (
            Select-String '\*(Karaoke|Themed stream: .+?|3D stream)\*' -input $addContent -AllMatches
        ).Matches
        | ForEach-Object {$_.Groups[1]}
    ).Value
    # Parse participants
    $participants = (
        (
            Select-String '\w+(?=(?:(?:, | and )\w+)* appears?| joins?)' -input $addContent -AllMatches
        ).Matches.Value
    ).Value
    # Parse raid target
    $addContent -match 'Raiding (\w+)'
    $raidTarget = $Matches[1]

    # Escape non-formatting asterisks and underscores
    $addContent = $addContent -replace '(\S)([*_])(\S)', '$1\$2$3'
    # Convert bold text (single asterisks -> double asterisks)
    $addContent = $addContent -replace '(?<=^|\s)\*(?=\S)(.+?)(?<=\S)\*(?=\s|$)', '**$1**'
    # Convert italics (single underscores -> single asterisks)
    $addContent = $addContent -replace '\b_(?=\S)(.+?)(?<=\S)_\b', '*$1*'
    # Convert strikethrough (single dashes -> double tildes)
    $addContent = $addContent -replace '(?<=^|\s)-(?=\S)(.+?)(?<=\S)-(?=\s|$)', '~~$1~~'
    # Convert subheadings (double asterisks at start of line -> double hash)
    $addContent = $addContent -replace '(?m)^\*\*(.+?)\*\*\s*$', '## $1\n'

    $content = $content + "`n## `n`n$addContent`n"
}

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