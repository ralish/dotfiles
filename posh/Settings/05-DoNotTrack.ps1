# Do Not Track (DNT)
# https://donottrack.sh/

$null = Start-DotFilesSection -Type 'Settings' -Name 'Do Not Track'

# Opt out of tracking (ads, crash reporting, telemetry, usage data, etc ...)
$Env:DO_NOT_TRACK = '1'

Complete-DotFilesSection
