fx_version 'cerulean'
game 'gta5'

name 'idtg-tracker'

author 'IDTG Development'
description 'Advanced GPS Tracker System for FiveM Roleplay Servers'
version '1.0.0'

client_script 'client/client.lua'
server_script 'server/server.lua'

shared_script 'config.lua'

ui_page 'ui/index.html'

dependencies {
}

files {
    'locales/en.lua',
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
}

exports {
    'GetTrackerStatus',
    'SetTrackerStatus',
    'SetPanicStatus',
    'GetPanicStatus',
    'UseTrackerItem',
    'UsePanicItem',
}
