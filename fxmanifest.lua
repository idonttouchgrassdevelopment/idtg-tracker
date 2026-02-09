fx_version 'cerulean'
game 'gta5'

name 'idtg-tracker'

author 'IDTG Development'
description 'Advanced GPS Tracker System for FiveM Roleplay Servers'
version '1.1.0'

client_script 'client/client.lua'
server_script 'server/server.lua'

shared_script 'config.lua'

dependencies {
    '/server:5181',
}

files {
    'locales/en.lua',
}

exports {
    'GetTrackerStatus',
    'SetTrackerStatus',
    'SetPanicStatus',
    'GetPanicStatus',
    'UseTrackerItem',
    'UsePanicItem',
}
