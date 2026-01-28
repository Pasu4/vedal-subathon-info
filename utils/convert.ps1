param (
    [Parameter(Mandatory=$true)][string]$Link,
    [Parameter(Mandatory=$true)][string]$File
)

# Extract video ID from the link
if ($Link -match 'v=([a-zA-Z0-9_-]{11})') {
    $videoId = $matches[1]
} elseif ($Link -match 'youtu\.be/([a-zA-Z0-9_-]{11})') {
    $videoId = $matches[1]
} else {
    Write-Error "Invalid YouTube link format."
    exit 1
}

$content=Get-Content $File

# Markdown links
$newContent = $content -replace '(?<!\[)(\d\d):(\d\d):(\d\d)', ('[$0](https://youtu.be/' + "$videoId" + '?t=$1h$2m$3s)')

# Escape pipes
$newContent = $newContent -replace '(?<!\\)\|', '\|'

Set-Content -Path $File -Value $newContent