fx_version 'cerulean'
game 'gta5'

name 'idtg-tracker'

author 'IDTG Development'
description 'Advanced GPS Tracker System for FiveM Roleplay Servers'
version '1.0.0'

client_script 'client/client.lua'
server_script 'server/server.lua'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

dependencies {
    'ox_lib',
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
