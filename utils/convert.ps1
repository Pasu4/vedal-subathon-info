param (
    [Parameter(Mandatory=$false)][string]$Link,
    [Parameter(Mandatory=$true)][string]$TimestampsFile,
    [Parameter(Mandatory=$false)][string]$OverviewFile,
    [Parameter(Mandatory=$false)][string]$Auto,
    [Parameter(Mandatory=$false)][string]$Category  # Category for full auto mode
)

# Constants
$CommentAuthor = "@Pasu4"
$Channel = "@NArchiver"
$date1Rx = '(\d) (\w{3})\w* (\d+)'
$date2Rx = '(\d\d) (\w{3})\w* (\d+)'
$knownRaidTargets = @{
    "Shylily" = "shylily";
    "Camila" = "camila";
    "BTMC" = "btmc";
    "Layna" = "laynalazar";
    "Mini" = "minikomew";
    "Cerber" = "cerbervt";
    "GX Aura" = "gx_aura";
    "Laimu" = "limealicious";
    "Chibi" = "chibidoki";
    "Asveeti" = "asveeti";
    "DougDoug" = "dougdoug";
    "GEEGA" = "geega";
    "Matara" = "matarakan";
    "Zentreya" = "zentreya";
    "NancyDearestArt" = "nancydearestart";
    "Trickywi" = "trickywi";
    "RosariaVTuber" = "rosariavtuber";
    "MOTHERv3" = "motherv3";
    "Uchuujin Ai" = "uchuujin_ai";
} # TODO: Automatically parse past raid targets from overview file

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
            "https://www.youtube.com/$Channel"
        | jq.exe "{comment: [(.comments[] | select(.author == `"$CommentAuthor`") | .text)] | .[-1], title: .title, id: .id}"
        | ConvertFrom-Json
    )
    $videoTitle = $fetched.title
    $videoId = $fetched.id

    $videoTitle, $date = $videoTitle -split ' - ', -2
    if ($date -match $date1Rx) {
        $date = "0$($matches[1]) $($matches[2]) $($matches[3])"
    } elseif ($date -match $date2Rx) {
        $date = "$($matches[1]) $($matches[2]) $($matches[3])"
    }
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
        Write-Error "No comment found by $CommentAuthor, cannot add timestamps."
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

    # Add content to overview file
    if (Test-Path $OverviewFile) {
        (Get-Content $OverviewFile) | ForEach-Object {
            # Add to streams table
            if ($_ -match '^<!-- marker_new_stream -->$') {
                $participantsList = $participants -join ", "
                if ($raidTarget -and $knownRaidTargets.ContainsKey($raidTarget)) {
                    $raidTargetLink = $knownRaidTargets[$raidTarget]
                } elseif ($raidTarget) {
                    $raidTargetLink = $raidTarget
                    Write-Warning "Unknown raid target '$raidTarget', add manually!"
                } else {
                    $raidTargetLink = "-"
                }
                $raidTargetLink = "[$raidTarget](https://twitch.tv/$raidTarget)"

                "| [$date](https://youtu.be/$videoId) " +
                "| " + $videoTitle.PadRight([math]::Max(0, 68 - $date.Length)) +
                "| " + $Category.PadRight([math]::Max(0, 22 - $Category.Length)) +
                "| " + $participantsList.PadRight([math]::Max(0, 38 - $participantsList.Length)) +
                "| " + $raidTargetLink
            }

            $_ # Output existing content
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