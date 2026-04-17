<#
.SYNOPSIS
    Tool for fetching and converting timestamps for Neuro Archiver's VOD archive.
#>
param (
    # YouTube video link to extract the ID from. Ignored in auto modes.
    [Parameter(Mandatory=$false)][string]$Link,
    # Path to the file containing the timestamps.
    [Parameter(Mandatory=$true)][string]$TimestampsFile,
    # Path to the overview file to update in full auto mode.
    [Parameter(Mandatory=$false)][string]$OverviewFile,
    # - "simple": Automatically fetch the latest video title and ID from the channel.
    # - "full": Additionally fetch timestamps from the comment and update the overview file.
    [Parameter(Mandatory=$false)][string]$Auto,
    # Category for the stream, used in full auto mode. Only for full auto mode.
    # If set to "<other>", a placeholder will be added to the overview file instead.
    [Parameter(Mandatory=$false)][string]$Category,
    # Source of timestamps for full auto mode.
    # - "youtube": Fetch timestamps from the comment by $CommentAuthor (default).
    # - "clipboard": Use the current clipboard content as timestamps, useful if someone else already posted incomplete or incompatibly formatted timestamps.
    [Parameter(Mandatory=$false)][string]$TimestampsSource = "youtube",
    # YouTube username to fetch timestamps comment from in full auto mode. Default is "@Pasu4".
    [Parameter(Mandatory=$false)][string]$CommentAuthor = "@Pasu4",
    # Index of the video to fetch in auto modes, default is 1 (latest video).
    [Parameter(Mandatory=$false)][int]$Index = 1
)

# Transform parameters
if ($Category -eq "<other>") {
    $Category = "<!-- TODO: Specify category -->"
}
if ($TimestampsSource -eq $null) {
    $TimestampsSource = "youtube"
}

# Constants
$COMMENT_AUTHOR = "@Pasu4"
$ARCHIVER_CHANNEL = "@NArchiver"
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
$PLAYING_RX = 'Playing _(.+?)_'
$CONTENT_RX = '(?:\s)\*(?=\S)(.+?)(?<=\S)\*(?=\s|$)'
$PARTICIPANT_RX = '\w+(?=(?:(?:, | and )\w+)* appears?| joins?)'
$RAIDING_RX = 'Raiding (.+?)(?:$| \|)'
$PRESENTS_RX = '(\w+) presents _(.+?)_'

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

if ($Auto -eq "simple") {
    # Only fetch the title and ID
    $fetched = yt-dlp.exe -s -O "%(title)s::%(id)s" -I $Index "https://www.youtube.com/@NArchiver"
    $fetched = $fetched -split "::"
    $videoTitle = $fetched[0]
    $videoId = $fetched[1]
}
elseif ($Auto -eq "full") {
    # Additionally extract timestamps from the comment
    $youtubeApiKey = $env:YOUTUBE_DATA_API_KEY
    if (-not $youtubeApiKey) {
        Write-Error "YOUTUBE_DATA_API_KEY environment variable is required for full auto mode."
        exit 1
    }

    $fetched = yt-dlp.exe -s -O '{"title":%(title)j,"id":%(id)j}' -I $Index "https://www.youtube.com/$ARCHIVER_CHANNEL" |
        ConvertFrom-Json
    $videoTitle = $fetched.title
    $videoId = $fetched.id

    # Fetch comment text based on the specified source
    if ($TimestampsSource -eq "youtube") {
        $fetched | Add-Member -NotePropertyName comment -NotePropertyValue (
            Get-YouTubeCommentText -VideoId $videoId -AuthorDisplayName $COMMENT_AUTHOR -ApiKey $youtubeApiKey
        )
    } elseif ($TimestampsSource -eq "clipboard") {
        # In case someone else already posted incomplete or incompatibly formatted timestamps
        $fetched | Add-Member -NotePropertyName comment -NotePropertyValue (Get-Clipboard -Raw)
    } else {
        Write-Error "Invalid timestamps source specified. Use 'youtube' or 'clipboard'."
        exit 1
    }

    # Extract date and title from video title (format: "Title - 1 Jan 2024")
    $videoTitle, $date = $videoTitle -split ' - ', -2
    $date -match '(\d+) (\w{3})\w* (\d+)'
    $day = $matches[1]
    if ($day.Length -eq 1) {
        $day = "0$day"
    }
    $month = $MONTHS[$matches[2]]
    $date = "$day $($matches[2]) $($matches[3])"

    $overviewVideoLink = "[$month-$day](https://youtu.be/$videoId)"
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

$content=Get-Content -Raw $TimestampsFile

# Add content from comment if in full auto mode
if ($Auto -eq "full") {
    # Check arguments
    if (-not $OverviewFile) {
        Write-Error "Overview file path is required for full auto mode."
        exit 1
    }

    $addContent = $fetched.comment
    if (-not $addContent) {
        Write-Error "No comment found by $COMMENT_AUTHOR, cannot add timestamps."
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

    # Parse presentations
    if ($addContent -match $PRESENTS_RX) {
        $events += (Select-String $PRESENTS_RX -input $addContent -AllMatches).Matches |
            ForEach-Object {"$($_.Groups[1].Value) presents *$($_.Groups[2].Value)*"}
        $contentEntries += "Presentation"
    }

    # Parse other content
    if ($addContent -match $CONTENT_RX) {
        $contentEntries += (Select-String $CONTENT_RX -InputObject $addContent -AllMatches).Matches
            | ForEach-Object { $_.Groups[1].Value }
            | Where-Object { $_ -ne "Just chatting" -and $_ -notmatch $PLAYING_RX -and $_ -notmatch $PRESENTS_RX }
    }
    
    # Parse participants
    if ($addContent -match $PARTICIPANT_RX) {
        $participants += (Select-String $PARTICIPANT_RX -InputObject $addContent -AllMatches).Matches.Value
    }

    # Parse raid target
    $addContent -match $RAIDING_RX
    $raidTarget = $Matches[1]

    # Escape non-formatting asterisks and underscores
    $addContent = $addContent -replace '(\S)([*_])(\S)', '$1\\$2$3'
    # Convert bold text (single asterisks -> double asterisks)
    $addContent = $addContent -replace '(?<=^|\s)\*(?=\S)(.+?)(?<=\S)\*(?=\s|$)', '**$1**'
    # Convert italics (single underscores -> single asterisks)
    $addContent = $addContent -replace '\b_(?=\S)(.+?)(?<=\S)_\b', '*$1*'
    # Convert strikethrough (single dashes -> double tildes)
    $addContent = $addContent -replace '(?<=^|\s|\*|_)-(?=\S)(.+?)(?<=\S)-(?=\s|\*|_|$)', '~~$1~~'
    # Convert subheadings (double asterisks at start of line -> double hash)
    $addContent = $addContent -replace '(?m)^\*\*(.+)\*\*\s*$', '### $1\n'

    $content = $content + "`n## `n`n$addContent"

    # Add content to overview file
    if (Test-Path $OverviewFile) {
        $stage = "streamparsing"
        $foundContent = @()
        $foundParticipants = @()
        (Get-Content $OverviewFile) | ForEach-Object {
            $line = $_
            # Parse previous raid targets
            if ($stage -eq "streamparsing" -and $line -match '\[([^\]\n]+)\]\(https://twitch\.tv/(\w+)\)') {
                $knownRaidTargets[$matches[1]] = $matches[2]
                $line # Output existing content
            }
            # Add entry to streams table
            elseif ($line -match '^<!-- marker_new_stream -->$') {
                $participantsList = $participants -join ", "

                if ($raidTarget -and $knownRaidTargets.ContainsKey($raidTarget)) {
                    $raidTargetLink = "[$raidTarget](https://twitch.tv/$($knownRaidTargets[$raidTarget]))"
                } elseif ($raidTarget) {
                    $raidTargetLink = $raidTarget
                    Write-Warning "Unknown raid target '$raidTarget', add manually!"
                } else {
                    $raidTargetLink = "-"
                }

                "| [$date](https://youtu.be/$videoId) " +
                "| " + $videoTitle.PadRight(68) +
                "| " + $Category.PadRight(22) +
                "| " + $participantsList.PadRight(38) +
                "| " + $raidTargetLink

                $stage = "none"
                $line # Output existing content
            }
            # Detect participants section
            elseif ($line -match '^<!-- marker_participants -->$') {
                $stage = "participants"
                $line # Output existing content
            }
            # Detect end of participants section
            elseif ($line -eq '<!-- marker_participants_end -->') {
                $notFoundParticipants = $participants | Where-Object { $_ -notin $foundParticipants }
                if ($notFoundParticipants) {
                    Write-Warning "The following participants were not found in the overview file, add them manually:`n$($notFoundParticipants -join "`n")"
                    "<!-- TODO: Add missing participants: $($notFoundParticipants -join ', ') -->"
                }

                $stage = "none"
                $line # Output existing content
            }
            # Add stream links to participants section
            elseif ($stage -eq "participants") {
                foreach ($participant in $participants) {
                    if ($line.Contains($participant)) {
                        $line += ", " + $overviewVideoLink
                        $foundParticipants += $participant
                        break
                    }
                }
                $line # Output existing or updated content
            }
            # Detect content section
            elseif ($line -match '^<!-- marker_content -->$') {
                $stage = "content"
                $line # Output existing content
            }
            # Detect end of content section
            elseif ($line -match '^<!-- marker_content_end -->$') {
                $notFoundContent = $contentEntries | Where-Object { $_ -notin $foundContent }
                if ($notFoundContent) {
                    Write-Warning "The following content entries could not be classified, add them manually:`n$($notFoundContent -join "`n")"
                    "<!-- TODO: Add missing content entries: $($notFoundContent -join ', ') -->"
                }

                $stage = "none"
                $line # Output existing content
            }
            # Add stream links to content section
            elseif ($stage -eq "content") {
                foreach ($entry in $contentEntries) {
                    if ($line.Contains($entry)) {
                        $line += ", " + $overviewVideoLink
                        $foundContent += $entry
                        break
                    }
                }
                $line # Output existing or updated content
            }
            elseif ($line -match '^<!-- marker_new_event -->$') {
                foreach ($evt in $events) {
                    "| $($evt.PadRight(42))" +
                    "| " + $overviewVideoLink
                }
                $line # Output existing content
            }
            else {
                $line # Output existing content
            }
        } | Set-Content -Path $OverviewFile
    }
}

# Title
if ($videoTitle) {
    $content = $content -replace '(?m)^## *$', "## $videoTitle ([$date](https://youtu.be/$videoId))"
}

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