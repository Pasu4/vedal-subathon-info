<#
.SYNOPSIS
    Tool for fetching and converting timestamps for Neuro Archiver's VOD archive.
#>
param (
    # Path to the file containing the timestamps.
    [Parameter(Mandatory=$true)][string]$TimestampsFile,
    # Path to the overview file to update.
    [Parameter(Mandatory=$true)][string]$OverviewFile,
    # Category for the stream.
    # If set to "<other>", a placeholder will be added to the overview file instead.
    [Parameter(Mandatory=$false)][string]$Category,
    # Source of timestamps.
    # - "youtube": Fetch timestamps from the comment by $CommentAuthor (default).
    # - "clipboard": Use the current clipboard content as timestamps, useful if someone else already posted incomplete or incompatibly formatted timestamps.
    [Parameter(Mandatory=$false)][string]$TimestampsSource = "youtube",
    # YouTube username to fetch timestamps comment from. Default is "@Pasu4".
    [Parameter(Mandatory=$false)][string]$CommentAuthor = "@Pasu4",
    # YouTube channel of the channel to fetch the comment from. Default is "@NArchiver".
    [Parameter(Mandatory=$false)][string]$ArchiverChannel = "@NArchiver",
    # Index of the video to fetch. Default is 1 (latest video).
    [Parameter(Mandatory=$false)][int]$Index = 1
)

# Set encoding for PowerShell 5.1
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Transform parameters
if ($Category -eq "<other>") {
    $Category = "<!-- TODO: Specify category -->"
}
if ($TimestampsSource -eq $null) {
    $TimestampsSource = "youtube"
}

# Constants
$MONTHS = @{
    "Jan" = "01";
    "Feb" = "02";
    "Mar" = "03";
    "Apr" = "04";
    "May" = "05";
    "Jun" = "06";
    "Jul" = "07";
    "Aug" = "08";
    "Sep" = "09";
    "Oct" = "10";
    "Nov" = "11";
    "Dec" = "12";
}

$PLAYING_RX = 'Playing (?:\*\*)?_(.+?)_'
$CONTENT_RX = '(?:[\s-[\n]])\*(?=\S)(.+?)(?<=\S)\*(?=\s|$)'
$PARTICIPANT_RX = '\w+(?=(?:(?:, | and )\w+)*(?: appears?| joins?| wakes? up))'
$RAIDING_RX = '(?m)Raiding (.+?)(?:$| \|)'
$PRESENTS_RX = '(\w+) presents _(.+?)_'
$DUET_RX = '\(duet\)'
$DUET_WITH_RX = '\(duet w/ ([^)\n,]+)\)'

$STREAMS_TABLE_HEADER = '| Date / Link                                 | Title                                                               | Type                  | Participants                          | Raid target'
$PARTICIPANTS_TABLE_HEADER = '| Participant                                                   | Streams'
$CONTENT_TABLE_HEADER = '| Content                                   | Type                  | Participants                  | Streams'
$EVENTS_TABLE_HEADER = '| Event                                     | Stream'

$NON_PARTICIPANTS = @(
    "Notepad",
    "Note"
)

# Variables
$knownRaidTargets = @{}

function Get-YouTubeCommentText {
    param (
        [Parameter(Mandatory=$true)][string]$VideoId,
        [Parameter(Mandatory=$true)][string]$AuthorDisplayName,
        [Parameter(Mandatory=$true)][string]$ApiKey
    )

    $baseUri = 'https://www.googleapis.com/youtube/v3/commentThreads'
    $pageToken = $null

    do {
        $query = @{
            part = 'snippet'
            videoId = $VideoId
            maxResults = 100
            order = 'time'
            key = $ApiKey
        }

        if ($pageToken) {
            $query.pageToken = $pageToken
        }

        $response = Invoke-RestMethod -Method Get -Uri $baseUri -Body $query
        $comment = $response.items | Where-Object {
            $_.snippet.topLevelComment.snippet.authorDisplayName -eq $AuthorDisplayName
        } | Select-Object -First 1

        if ($comment) {
            return $comment.snippet.topLevelComment.snippet.textOriginal
        }

        $pageToken = $response.nextPageToken
    } while ($pageToken)

    return $null
}

# Set encoding
[System.Console]::OutputEncoding=[System.Text.Encoding]::UTF8

# Additionally extract timestamps from the comment
$youtubeApiKey = $env:YOUTUBE_DATA_API_KEY
if (-not $youtubeApiKey) {
    Write-Error "YOUTUBE_DATA_API_KEY environment variable is required."
    exit 1
}

$fetched = yt-dlp.exe -s -O '{"title":%(title)j,"id":%(id)j}' -I $Index "https://www.youtube.com/$ArchiverChannel" |
    ConvertFrom-Json
$videoTitle = $fetched.title
$videoId = $fetched.id

# Fetch comment text based on the specified source
if ($TimestampsSource -eq "youtube") {
    $fetched | Add-Member -NotePropertyName comment -NotePropertyValue (
        Get-YouTubeCommentText -VideoId $videoId -AuthorDisplayName $CommentAuthor -ApiKey $youtubeApiKey
    )
} elseif ($TimestampsSource -eq "clipboard") {
    # In case someone else already posted incomplete or incompatibly formatted timestamps
    $fetched | Add-Member -NotePropertyName comment -NotePropertyValue (Get-Clipboard -Raw)
} else {
    Write-Error "Invalid timestamps source specified. Use 'youtube' or 'clipboard'."
    exit 1
}

# Extract date and title from video title (format: "Title - 1 Jan 2024" or "Title- 1 Jan 2024")

if (-not ($videoTitle -match '^(.*\S) *- *(\d+) (\w{3})\w* (\d+)$')) {
    Write-Error "Could not parse video title. `nExpected format: 'Video Title - 19 December 2022'`nProvided format: '$videoTitle'"
    exit 1
}
$videoTitle = $matches[1]
$day = $matches[2]
if ($day.Length -eq 1) {
    $day = "0$day"
}
$month = $MONTHS[$matches[3]]
$date = "$day $($matches[3]) $($matches[4])"

$overviewVideoLink = "[$month-$day](https://youtu.be/$videoId)"

$content=Get-Content -Raw $TimestampsFile

# Add content from comment

$addContent = $fetched.comment
if (-not $addContent) {
    Write-Error "No comment found by $CommentAuthor, cannot add timestamps."
    exit 1
}

# Initialize empty arrays
$contentEntries = @()
$participants = @()
$events = @()

# Parse games
if ($addContent -match $PLAYING_RX) {
    $contentEntries += (Select-String $PLAYING_RX -InputObject $addContent -AllMatches).Matches |
        ForEach-Object { $_.Groups[1].Value }
}
# Count VRChat also as a 3D stream
if ($contentEntries -contains "VRChat") {
    $contentEntries += "3D stream"
}

# Parse presentations
if ($addContent -match $PRESENTS_RX) {
    $events += (Select-String $PRESENTS_RX -input $addContent -AllMatches).Matches |
        ForEach-Object {"$($_.Groups[1].Value) presents *$($_.Groups[2].Value)*"}
    $contentEntries += "Presentation"
}

# Parse duets
if ($addContent -match $DUET_RX) {
    $participants += @("Neuro", "Evil")
}
if ($addContent -match $DUET_WITH_RX) {
    $participants += (Select-String $DUET_WITH_RX -input $addContent -AllMatches).Matches |
        ForEach-Object { $_.Groups[1].Value }
}

# Parse other content
if ($addContent -match $CONTENT_RX) {
    $contentEntries += (Select-String $CONTENT_RX -InputObject $addContent -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne "Just chatting" -and $_ -notmatch $PLAYING_RX -and $_ -notmatch $PRESENTS_RX }
}
# Transform compound entries
if ($contentEntries -contains "3D karaoke") {
    $contentEntries += @("3D stream", "Karaoke")
}

# Parse participants
if ($addContent -match $PARTICIPANT_RX) {
    $participants += (Select-String $PARTICIPANT_RX -InputObject $addContent -AllMatches).Matches.Value
}

# Make lists unique
# If the list only has one participant it is converted to a string for some reason,
# so the second assignment fixes that
$participants = $participants | Select-Object -Unique | Where-Object { $_ -notin $NON_PARTICIPANTS }
$participants = @() + $participants
$contentEntries = $contentEntries | Select-Object -Unique
$contentEntries = @() + $contentEntries

# Parse raid target
$addContent -match $RAIDING_RX
$raidTarget = $Matches[1]

# Escape non-formatting asterisks and underscores
$addContent = $addContent -replace '([^\s*_-])([*_])([^\s*_-])', '$1\\$2$3'
# Convert bold text (single asterisks -> double asterisks)
$addContent = $addContent -replace '(?<=^|[\s*_-])\*(.+?)\*(?=[\s*_-]|$)', '**$1**'
# Remove quadruple asterisks (YouTube API bug)
$addContent = $addContent -replace '\*\*\*\*', ''
# Convert italics (single underscores -> single asterisks)
$addContent = $addContent -replace '\b_(?=\S)(.+?)(?<=\S)_\b', '*$1*'
# Convert strikethrough (single dashes -> double tildes)
$addContent = $addContent -replace '(?<=^|\s|\*|_)-(?=\S)(.+?)(?<=\S)-(?=\s|\*|_|$)', '~~$1~~'
# Convert subheadings (double asterisks at start of line -> double hash)
$addContent = $addContent -replace '(?m)^\*\*(.+)\*\*\s*$', ('### $1' + "`n")

$content = $content + "`n## `n`n$addContent"

# Add content to overview file
if (Test-Path $OverviewFile) {
    $stage = "none"
    $foundContent = @()
    $foundParticipants = @()
    (Get-Content $OverviewFile) | ForEach-Object {
        $line = $_
        if ($line -eq $STREAMS_TABLE_HEADER) {
            $stage = "streamparsing"
        }
        # Parse previous raid targets
        elseif ($stage -eq "streamparsing" -and $line -match '\[([^\]\n]+)\]\(https://twitch\.tv/(\w+)\)') {
            $knownRaidTargets[$matches[1]] = $matches[2]
        }
        # Detect end of table
        elseif ($stage -eq "streamparsing" -and -not $line) {
            # Add entry to streams table
            $participantsList = $participants -join ", "

            if ($raidTarget -and $knownRaidTargets.ContainsKey($raidTarget)) {
                $raidTargetLink = "[$raidTarget](https://twitch.tv/$($knownRaidTargets[$raidTarget]))"
            } elseif ($raidTarget) {
                $raidTargetLink = $raidTarget
                Write-Warning "Unknown raid target '$raidTarget', add manually!"
            } else {
                $raidTargetLink = "-"
            }

            "| [$date](https://youtu.be/$videoId)" +
            " | " + $videoTitle.PadRight(67) +
            " | " + $Category.PadRight(21) +
            " | " + $participantsList.PadRight(37) +
            " | " + $raidTargetLink

            $stage = "none"
        }
        # Detect participants section
        elseif ($line -eq $PARTICIPANTS_TABLE_HEADER) {
            $stage = "participants"
        }
        # Detect end of participants section
        elseif ($stage -eq "participants" -and -not $line) {
            $notFoundParticipants = $participants | Where-Object { $_ -notin $foundParticipants }
            $notFoundParticipants = @() + $notFoundParticipants
            if ($notFoundParticipants) {
                Write-Warning "The following participants were added to the overview file, you need to link their twitch:`n$($notFoundParticipants -join "`n")"
                # "<!-- TODO: Add missing participants: $($notFoundParticipants -join ', ') -->"
            }
            foreach ($newParticipant in $notFoundParticipants) {
                "| " + $newParticipant.PadRight(61) +
                " | " + $overviewVideoLink
            }

            $stage = "none"
        }
        # Add stream links to participants section
        elseif ($stage -eq "participants") {
            foreach ($participant in $participants) {
                if ($line -match "^\| \[$([Regex]::Escape($participant))\]\([^)]+?\) +\|") {
                    $line += ", " + $overviewVideoLink
                    $foundParticipants += $participant
                    break
                }
            }
        }
        # Detect content section
        elseif ($line -eq $CONTENT_TABLE_HEADER) {
            $stage = "content"
        }
        # Detect end of content section
        elseif ($stage -eq "content" -and -not $line) {
            $notFoundContent = $contentEntries | Where-Object { $_ -notin $foundContent }
            $notFoundContent = @() + $notFoundContent
            $guessParticipant = $participants[0]
            if ($notFoundContent) {
                Write-Warning "The following content entries were added, you need to configure the type and participants (guessing $guessParticipant):`n$($notFoundContent -join "`n")"
                # "<!-- TODO: Add missing content entries: $($notFoundContent -join ', ') -->"
            }
            foreach ($newContent in $notFoundContent) {
                $guessType = "TODO"
                if ($newContent.StartsWith("Themed stream: ")) {
                    $guessType = "Themed stream"
                }
                # Not guessing game since there is no distinction whether it is integrated
                "| " + $newContent.PadRight(41) +
                " | " + $guessType.PadRight(21) +
                " | " + $guessParticipant.PadRight(29) +
                " | " + $overviewVideoLink
            }

            $stage = "none"
        }
        # Add stream links to content section
        elseif ($stage -eq "content") {
            foreach ($entry in $contentEntries) {
                if ($line -match "^\| $([Regex]::Escape($entry)) +\|") {
                    $line += ", " + $overviewVideoLink
                    $foundContent += $entry
                    break
                }
            }
        }
        elseif ($line -eq $EVENTS_TABLE_HEADER) {
            $stage = "events"
        }
        elseif ($stage -eq "events" -and -not $line) {
            foreach ($evt in $events) {
                "| $($evt.PadRight(41))" +
                " | " + $overviewVideoLink
            }
        }

        $line # Output existing content
    } | Set-Content -Path $OverviewFile
}

# Title
$content = $content -replace '(?m)^## *$', "## $videoTitle ([$date](https://youtu.be/$videoId))"

# Markdown links
$content = $content -replace '(?m)^(\d\d):(\d\d):(\d\d)', ('- [$0](https://youtu.be/' + "$videoId" + '?t=$1h$2m$3s)')

# Escape pipes
$content = $content -replace '(?m)(?<!\\)\|', '\|'

# Make song titles italic
$content = $content -replace '(?m)(?<=(\)|\|) )[^*—\n|]+—( [^\\\(\n\| ]+)+', '*$0*'

# Add link to raid target
$content = $content -replace '(?m)Raiding (\w.*?)(?:$| \|)', "Raiding $raidTargetLink"

# TODO: Auto-process raid targets + add line to table

Set-Content -Path $TimestampsFile -Value $content