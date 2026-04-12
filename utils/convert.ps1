param (
    [Parameter(Mandatory=$false)][string]$Link,
    [Parameter(Mandatory=$true)][string]$TimestampsFile,
    [Parameter(Mandatory=$false)][string]$OverviewFile,
    [Parameter(Mandatory=$false)][string]$Auto,
    [Parameter(Mandatory=$false)][string]$Category  # Category for full auto mode
)

# Transform parameters
if ($Category -eq "<other>") {
    $Category = "<!-- TODO: Specify category -->"
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

# Variables
$knownRaidTargets = @{}

if ($Auto -eq "simple") {
    # Only fetch the title and ID
    $fetched = yt-dlp.exe -s -O "%(title)s::%(id)s" -I 1 "https://www.youtube.com/@NArchiver"
    $fetched = $fetched -split "::"
    $videoTitle = $fetched[0]
    $videoId = $fetched[1]
}
elseif ($Auto -eq "full") {
    # Additionally extract timestamps from the comment
    $fetched = (
        yt-dlp.exe `
            --skip-download `
            --extractor-args "youtube:max_comments=1000,all,all,all,1" `
            --write-comments `
            --dump-json `
            -I 1 `
            "https://www.youtube.com/$ARCHIVER_CHANNEL"
        | jq.exe "{comment: [(.comments[] | select(.author == `"$COMMENT_AUTHOR`") | .text)] | .[-1], title: .title, id: .id}"
        | ConvertFrom-Json
    )
    $videoTitle = $fetched.title
    $videoId = $fetched.id

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

$content=Get-Content $TimestampsFile

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
    $addContent -match 'Raiding (.+?)(?:$| \|)'
    $raidTarget = $Matches[1]
    if ($raidTarget -and $knownRaidTargets.ContainsKey($raidTarget)) {
        $raidTargetLink = $knownRaidTargets[$raidTarget]
    } elseif ($raidTarget) {
        $raidTargetLink = $raidTarget
        Write-Warning "Unknown raid target '$raidTarget', add manually!"
    } else {
        $raidTargetLink = "-"
    }
    $raidTargetLink = "[$raidTarget](https://twitch.tv/$raidTarget)"

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
    # Add link to raid target
    $addContent = $addContent -replace '(?m)^Raiding \w+$', "Raiding $raidTargetLink"

    $content = $content + "`n## `n`n$addContent`n"

    # Add content to overview file
    if (Test-Path $OverviewFile) {
        $stage = "streamparsing"
        $foundContent = @()
        $foundParticipants = @()
        (Get-Content $OverviewFile) | ForEach-Object {
            $line = $_
            # Parse previous raid targets
            if ($stage -eq "streamparsing" -and $line -match '\[(.+)\]\(https://twitch\.tv/(\w+)\)') {
                $knownRaidTargets[$matches[1]] = $matches[2]
            }
            # Add entry to streams table
            elseif ($line -match '^<!-- marker_new_stream -->$') {
                $participantsList = $participants -join ", "

                "| [$date](https://youtu.be/$videoId) " +
                "| " + $videoTitle.PadRight([math]::Max(0, 68 - $date.Length)) +
                "| " + $Category.PadRight([math]::Max(0, 22 - $Category.Length)) +
                "| " + $participantsList.PadRight([math]::Max(0, 38 - $participantsList.Length)) +
                "| " + $raidTargetLink

                $stage = "none"
                $line # Output existing content
            }
            # Detect participants section
            elseif ($line -match '^<!-- marker_participants -->$') {
                $stage = "participants"
                $line # Output existing content
            }
            # Add stream links to participants section
            elseif ($stage -eq "participants") {
                foreach ($participant in $participants) {
                    if ($line -contains $participant) {
                        $line += ", " + $overviewVideoLink
                        $foundParticipants += $participant
                        break
                    }
                }
                $line
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
            # Detect content section
            elseif ($line -match '^<!-- marker_content -->$') {
                $stage = "content"
                $line # Output existing content
            }
            # Add stream links to content section
            elseif ($stage -eq "content") {
                foreach ($entry in $contentEntries) {
                    if ($line -contains $entry) {
                        $line += ", " + $overviewVideoLink
                        $foundContent += $entry
                        break
                    }
                }
                $line
            }
            # Detect end of content section
            elseif ($line -match '^<!-- marker_content_end -->$') {
                $notFoundContent = $contentEntries | Where-Object { $_ -notin $foundContent }
                if ($notFoundContent) {
                    Write-Warning "The following content entries were not found in the overview file, add them manually:`n$($notFoundContent -join "`n")"
                    "<!-- TODO: Add missing content entries: $($notFoundContent -join ', ') -->"
                }

                $stage = "none"
                $line # Output existing content
            }
            else {
                $line # Output existing content
            }
        }
    }
}

# Title
if ($videoTitle) {
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