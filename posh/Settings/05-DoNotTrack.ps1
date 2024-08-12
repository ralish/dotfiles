Start-DotFilesSection -Type 'Settings' -Name 'DoNotTrack'

# Console Do Not Track (DNT)
# https://consoledonottrack.com/
$env:DO_NOT_TRACK = '1'

Complete-DotFilesSection
