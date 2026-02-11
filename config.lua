-- =============================================================================
-- GPS TRACKER CONFIGURATION
-- =============================================================================
-- This configuration file controls all aspects of the GPS tracker system
-- Edit this file to customize the tracker for your specific server needs
-- =============================================================================

Config = {}

-- =============================================================================
-- FRAMEWORK SELECTION
-- =============================================================================
-- Set to 'ESX' or 'QBCore' based on your server framework
-- The script will automatically detect and use the appropriate framework
-- =============================================================================
Config.Framework = 'QBCore' -- Options: 'ESX', 'QBCore', or 'Auto' for automatic detection

-- =============================================================================
-- GENERAL SETTINGS
-- =============================================================================

-- Enable/disable debug messages in the server console
Config.Debug = false

-- How often (in milliseconds) to update player positions
-- Lower values = more accurate but higher resource usage
-- Recommended: 2000-5000ms for 100+ players
Config.UpdateInterval = 3000

-- Maximum distance (in meters) before a player's blip disappears
-- Set to 0 for unlimited distance
Config.MaxDistance = 0

-- Automatically enable tracker when player goes on duty
Config.AutoEnableOnDuty = true

-- Automatically disable tracker when player goes off duty
Config.AutoDisableOffDuty = true


-- Allow all jobs to use the tracker/panic system, even if not explicitly listed in Config.Jobs
Config.AllowAllJobs = false

-- Fallback blip used when Config.AllowAllJobs is enabled and job is not configured
Config.DefaultJob = {
    blip = {
        sprite = 1,
        color = 0,
        scale = 1.0,
        label = 'Unit',
        showDistance = true,
    },
    visibleTo = {'all'},
    requireOnDuty = false,
}

-- Cuff checks used to block tracker and panic abuse while restrained
Config.CuffChecks = {
    -- local state bag keys checked first: LocalPlayer.state[key]
    stateKeys = {'isCuffed', 'cuffed', 'handcuffed', 'inCuffs'},
    -- fallback exported checks (resource/exportName)
    exports = {
        --{resource = 'qb-policejob', exportName = 'IsHandcuffed'}
        {resource = 'tk_policejob', exportName = 'isHandcuffed'}
    }
}

-- =============================================================================
-- ITEM REQUIREMENT (OPTIONAL)
-- =============================================================================
-- Set to true if you want players to need a specific item to use the tracker
-- Useful for roleplay servers that want item-based GPS systems
-- =============================================================================
Config.RequireItem = false

-- The item name that players need in their inventory to use the tracker
-- This item should exist in your server's items database
Config.RequiredItem = 'gps_device'

-- Prefer ox_inventory item checks when available (works for both ESX/QBCore)
Config.UseOxInventory = true

-- Register usable ox_inventory items (toggle tracker/panic)
Config.OxInventoryItems = {
    tracker = {
        enabled = false,
        name = 'gps_tracker'
    },
    panic = {
        enabled = false,
        name = 'panic_button'
    }
}

-- Panic system settings
Config.Panic = {
    enabled = true,
    cooldownMs = 45000,
    blipDurationMs = 15000,
    nearbyAudibleRadius = 80.0,
    officerJobs = {'police', 'sasp', 'bcso', 'fib'},
    sound = {
        enabled = true,
        audioName = '5_SEC_WARNING',
        audioRef = 'HUD_MINI_GAME_SOUNDSET',
        repeatIntervalMs = 850,
        layeredPlays = 2,
        layeredDelayMs = 80
    },
    blip = {
        sprite = 161,
        color = 1,
        scale = 1.9,
        label = 'PANIC',
        -- Optional icon layered in the center of the panic blip
        centerIcon = {
            enabled = true,
            -- radar_bounty_hit style icon
            sprite = 303,
            color = 1,
            scale = 0.85
        },
        showRadius = false,
        radius = 90.0,
        radiusColor = 1,
        radiusAlpha = 120
    }
}

-- Police departments can share a custom blip style without repeating settings
-- Set enabled = false to keep each configured job sprite/color exactly as-is.
Config.PoliceBlip = {
    enabled = false,
    jobs = {'police', 'sasp', 'bcso', 'fib'},
    sprite = 60,
    color = 38,
    scale = 1.0,
    labelPrefix = 'LEO',
    flashWhenLightsOn = true,
    flashIntervalMs = 250
}

-- Restrict manual tracker disabling so only officers can disable it,
-- unless the player is currently cuffed.
Config.TrackerDisable = {
    restricted = true,
    allowWhenCuffed = false,
    officerJobs = {'police', 'sasp', 'bcso', 'fib', 'ems', 'ambulance', 'fire'},
}

-- Animation settings used when toggling the tracker and sending panic alerts
Config.Animations = {
    trackerToggle = {
        dict = 'cellphone@',
        clip = 'cellphone_text_read_base',
        duration = 1700,
        flag = 49
    },
    panic = {
        dict = 'random@arrests',
        clip = 'generic_radio_chatter',
        duration = 2200,
        flag = 49
    }
}

-- Display notification when player doesn't have the required item
Config.ShowItemNotification = true

-- =============================================================================
-- BLIP COLOR CONFIGURATION
-- =============================================================================
-- Configure custom colors for your server's needs
-- You can use either predefined color IDs or RGB values
-- =============================================================================

-- Custom RGB colors (if your framework supports it)
-- Format: {R, G, B} where each value is 0-255
Config.CustomColors = {
    ['custom_blue'] = {0, 102, 204},      -- Custom blue
    ['custom_red'] = {204, 0, 0},          -- Custom red
    ['custom_green'] = {0, 153, 51},       -- Custom green
    ['custom_purple'] = {153, 51, 204},    -- Custom purple
    ['custom_orange'] = {255, 128, 0},     -- Custom orange
    ['custom_cyan'] = {0, 153, 204},       -- Custom cyan
    ['custom_pink'] = {255, 51, 153},      -- Custom pink
    ['custom_yellow'] = {255, 204, 0},     -- Custom yellow
}

-- Standard FiveM Blip Colors (ID 0-85)
-- These are the built-in GTA V/FiveM blip colors
Config.StandardColors = {
    white = 1,
    red = 2,
    green = 3,
    blue = 4,
    orange = 5,
    yellow = 47,
    purple = 59,
    pink = 60,
    cyan = 61,
    light_blue = 62,
    dark_blue = 63,
    teal = 64,
    lime_green = 65,
    olive = 66,
    brown = 67,
    tan = 68,
    gray = 69,
    light_gray = 70,
    dark_gray = 71,
    black = 72,
    police_blue = 38,        -- Classic police blue
    sheriff_blue = 38,       -- Same as police
    ems_white = 1,           -- Medical white
    fire_orange = 5,         -- Fire department orange
    security_orange = 5,     -- Security orange
}

-- =============================================================================
-- BLIP SIZE CONFIGURATION
-- =============================================================================
-- Configure default blip sizes for different scenarios
-- Scale values range from 0.1 (tiny) to 5.0 (huge)
-- =============================================================================

Config.BlipSizes = {
    tiny = 0.5,       -- Very small, subtle
    small = 0.8,      -- Small, visible but not obtrusive
    medium = 1.0,     -- Medium size, good visibility (DEFAULT)
    large = 1.8,      -- Large, very visible
    huge = 2.5,       -- Very large, hard to miss
}

-- =============================================================================
-- JOB CONFIGURATION
-- =============================================================================
-- Configure which jobs have access to the GPS tracker and their settings
-- Each job can have custom blip appearance and visibility rules
-- =============================================================================

Config.Jobs = {
    -- Police Jobs
    ['police'] = {
        enabled = true,
        -- Optional identity defaults applied when a player switches into this job.
        -- Leave fields empty/nil to use framework defaults.
        -- identity = {
        --     callsign = 'LSPD',
        --     rank = 'Officer',
        --     department = 'Los Santos Police Department',
        -- },
        -- Blip configuration for this job
        blip = {
            sprite = 60,           -- Blip sprite (1 = standard police blip)
            color = 38,           -- Blip color (38 = blue)
            scale = 1.0,          -- Blip size (0.1 - 5.0) - Increased for better visibility
            label = 'LSPD Unit',-- Label shown on map
            showDistance = true,  -- Show distance in label
            flashWhenLightsOn = true,
            flashIntervalMs = 250,
        },
        -- Jobs that can see this job's players on the map
        -- Use 'all' to allow all configured jobs to see them
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        -- Require player to be on duty to use tracker
        requireOnDuty = true,
    },

    ['sasp'] = {
        enabled = true,  
        -- identity = {
        --     callsign = 'SASP',
        --     department = 'San Andreas State Police',
        -- },
        -- Blip configuration for this job
        blip = {
            sprite = 60,           -- Blip sprite (1 = standard police blip)
            color = 39,           -- Blip color (38 = blue)
            scale = 1.0,          -- Blip size (0.1 - 5.0) - Increased for better visibility
            label = 'SASP Unit',-- Label shown on map
            showDistance = true,  -- Show distance in label
            flashWhenLightsOn = true,
            flashIntervalMs = 250,
        },
        -- Jobs that can see this job's players on the map
        -- Use 'all' to allow all configured jobs to see them
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        -- Require player to be on duty to use tracker
        requireOnDuty = true,
    },

    ['fib'] = {
        enabled = true,
        -- identity = {
        --     callsign = 'FIB',
        --     department = 'Federal Investigation Bureau',
        -- },
        -- Blip configuration for this job
        blip = {
            sprite = 60,           -- Blip sprite (1 = standard police blip)
            color = 40,           -- Blip color (38 = blue)
            scale = 1.0,          -- Blip size (0.1 - 5.0) - Increased for better visibility
            label = 'FIB Unit',-- Label shown on map
            showDistance = true,  -- Show distance in label
            flashWhenLightsOn = true,
            flashIntervalMs = 250,
        },
        -- Jobs that can see this job's players on the map
        -- Use 'all' to allow all configured jobs to see them
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        -- Require player to be on duty to use tracker
        requireOnDuty = true,
    },
    
    -- Sheriff Department
    ['bcso'] = {
        enabled = true,
        -- identity = {
        --     callsign = 'BCSO',
        --     department = 'Blaine County Sheriff\'s Office',
        -- },
        blip = {
            sprite = 60,
            color = 52,
            scale = 1.0,          -- Increased for better visibility
            label = 'BCSO Unit',
            showDistance = true,
            flashWhenLightsOn = true,
            flashIntervalMs = 250,
        },
        -- Sheriff and police can see each other
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        requireOnDuty = true,
    },
    
    -- Emergency Medical Services
    ['ems'] = {
        enabled = true,
        -- identity = {
        --     callsign = 'EMS',
        --     department = 'Emergency Medical Services',
        -- },
        blip = {
            sprite = 61,          -- Medical cross sprite
            color = 49,            -- White color
            scale = 1.0,          -- Increased for better visibility
            label = 'EMS Unit',
            showDistance = true,
        },
        -- EMS can see all emergency services
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        requireOnDuty = true,
    },
    
    -- EMS alias for servers that use the ambulance job name
    ['ambulance'] = {
        enabled = true,
        -- identity = {
        --     callsign = 'EMS',
        --     department = 'Emergency Medical Services',
        -- },
        blip = {
            sprite = 61,          -- Medical cross sprite
            color = 49,            -- White color
            scale = 1.0,          -- Increased for better visibility
            label = 'EMS Unit',
            showDistance = true,
        },
        -- EMS can see all emergency services
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        requireOnDuty = true,
    },

    -- Fire Department
    ['fire'] = {
        enabled = true,
        -- identity = {
        --     callsign = 'FIRE',
        --     department = 'Fire Department',
        -- },
        blip = {
            sprite = 436,         -- Fire department sprite
            color = 5,            -- Orange color
            scale = 1.0,          -- Increased for better visibility
            label = 'Fire Unit',
            showDistance = true,
        },
        -- Fire can see all emergency services
        visibleTo = {'police', 'sheriff', 'ems', 'ambulance', 'fire', 'sasp', 'bcso', 'fib'},
        requireOnDuty = true,
    },
    
    -- Custom Job Example: Security
    ['security'] = {
        enabled = false,         -- Set to true to enable
        blip = {
            sprite = 50,          -- Security blip
            color = 5,            -- Orange color
            scale = 1.0,          -- Increased for better visibility
            label = 'Security',
            showDistance = true,
        },
        -- Security only sees other security
        visibleTo = {'security'},
        requireOnDuty = true,
    },
}

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================
-- Configure notification messages for various tracker events
-- Supports language localization if needed
-- =============================================================================

Config.Notifications = {
    ['tracker_enabled'] = 'GPS Tracker enabled',
    ['tracker_disabled'] = 'GPS Tracker disabled',
    ['status_enabled'] = 'GPS Tracker is enabled',
    ['status_disabled'] = 'GPS Tracker is disabled',
    ['no_item'] = 'You need a GPS device to use the tracker',
    ['not_on_duty'] = 'You must be on duty to use the tracker',
    ['not_authorized'] = 'You are not authorized to use the GPS tracker',
    ['item_removed'] = 'GPS device removed',
    ['cannot_use_cuffed'] = 'You cannot use this while cuffed',
    ['panic_sent'] = 'Panic signal sent',
    ['panic_received'] = 'PANIC: Officer needs immediate assistance',
    ['panic_cooldown'] = 'Panic button is on cooldown',
    ['panic_enabled'] = 'Panic button enabled',
    ['panic_disabled'] = 'Panic button disabled',
    ['panic_status_enabled'] = 'Panic button is enabled',
    ['panic_status_disabled'] = 'Panic button is disabled',
    ['panic_failed'] = 'Unable to send panic signal right now',
    ['ox_lib_required'] = 'ox_lib is required for the GPS tracker menu',
    ['tracker_disable_restricted'] = 'Tracker can only be disabled by officers, unless you are cuffed',
    ['identity_updated'] = 'Unit details updated',
}

-- =============================================================================
-- COMMANDS
-- =============================================================================
-- Configure custom commands for manual tracker control
-- Set to empty string to disable a command
-- =============================================================================

Config.Commands = {
    enabled = false,              -- Master toggle for all tracker commands
    tracker = {
        enabled = true,
        name = 'tracker',        -- Opens tracker/panic control menu
    },
    panic = {
        enabled = true,
        name = 'panic',          -- Command to trigger a panic alert
    },
    callsign = {
        enabled = true,
        name = 'setcallsign',    -- /setcallsign <value>
    },
    rank = {
        enabled = true,
        name = 'setrank',        -- /setrank <value>
    },
    department = {
        enabled = true,
        name = 'setdept',        -- /setdept <value>
    },
}

-- =============================================================================
-- KEYBINDS
-- =============================================================================
-- Register optional keybinds so users can control tracker/panic without commands.
-- Set enabled = false to disable all keybind registrations.
-- defaultMapper examples: keyboard, pad
-- defaultParameter examples: F6, F7, LMENU
-- =============================================================================

Config.Keybinds = {
    enabled = false,
    toggleTracker = {
        enabled = true,
        command = 'tracker', -- Legacy field: only used if command starts with '+'
        description = 'Toggle GPS tracker',
        defaultMapper = 'keyboard',
        defaultParameter = 'F6',
    },
    panic = {
        enabled = true,
        command = 'panic', -- Legacy field: only used if command starts with '+'
        description = 'Send GPS panic alert',
        defaultMapper = 'keyboard',
        defaultParameter = 'F7',
    },
    togglePanic = {
        enabled = false,
        command = 'panic', -- Legacy field: only used if command starts with '+'
        description = 'Toggle GPS panic button',
        defaultMapper = 'keyboard',
        defaultParameter = 'F8',
    }
}

-- =============================================================================
-- MENU
-- =============================================================================
-- Uses ox_lib context menu for tracker and panic actions.
-- =============================================================================

Config.Menu = {
    enabled = true,
    command = '',
    description = 'Open GPS tracker menu',
    keybindEnabled = true,
    keybindCommand = '', -- Optional custom keybind command (must start with '+')
    defaultMapper = 'keyboard',
    defaultParameter = 'F11',
    branding = {
        enabled = true,
        -- Font Awesome icon name OR image URL supported by ox_lib (if your build supports URL icons)
        icon = 'shield-halved',
        -- Optional prefix in menu title (emoji/text)
        titlePrefix = '🚓',
        -- Main menu title text
        title = 'Emergency Services Tracker System',
        -- Optional label for the status card
        label = 'Emergency Dispatch',
    }
}

-- =============================================================================
-- PERFORMANCE SETTINGS
-- =============================================================================
-- Advanced settings for performance optimization
-- Only modify if you understand the impact
-- =============================================================================

Config.Performance = {
    -- Batch player updates instead of processing one by one
    batchUpdates = true,
    
    -- Number of players to process per batch
    batchSize = 10,
    
    -- Delay between batches (in milliseconds)
    batchDelay = 100,
    
    -- Remove blips for players who haven't updated in X milliseconds
    -- Helps cleanup disconnected players
    staleBlipTimeout = 10000,
    
    -- Clean up blips periodically (in milliseconds)
    cleanupInterval = 30000,
}

-- =============================================================================
-- FRAMEWORK-SPECIFIC SETTINGS
-- =============================================================================
-- These settings may vary depending on your framework configuration
-- =============================================================================

-- ESX-specific settings
Config.ESX = {
    -- Event name for player loaded (usually 'esx:playerLoaded')
    playerLoadedEvent = 'esx:playerLoaded',
    
    -- Event name for job update (usually 'esx:setJob')
    jobUpdateEvent = 'esx:setJob',
    
    -- Event name for going on duty (customize based on your server's job system)
    onDutyEvent = 'esx:onJob',
    
    -- Event name for going off duty
    offDutyEvent = 'esx:offJob',
}

-- QBCore-specific settings
Config.QBCore = {
    -- Event name for player loaded (usually 'QBCore:Client:OnPlayerLoaded')
    playerLoadedEvent = 'QBCore:Client:OnPlayerLoaded',
    
    -- Event name for job update (usually 'QBCore:Client:OnJobUpdate')
    jobUpdateEvent = 'QBCore:Client:OnJobUpdate',
    
    -- Event name for duty change (usually 'QBCore:Server:OnDutyUpdate')
    dutyUpdateEvent = 'QBCore:Server:OnDutyUpdate',
}

-- =============================================================================
-- HOW TO ADD NEW JOBS
-- =============================================================================
-- Follow this template to add new jobs to the Config.Jobs table:
--
-- ['your_job_name'] = {
--     enabled = true,           -- Set to false to disable
--     blip = {
--         sprite = 1,           -- Sprite ID (https://docs.fivem.net/docs/game-references/blips/)
--         color = 1,            -- Color ID or RGB array (see color reference below)
--         scale = Config.BlipSizes.medium,  -- Use predefined sizes or enter number directly
--         label = 'Unit Name',  -- Text shown on map
--         showDistance = true,  -- Show distance in label
--     },
--     visibleTo = {'job1', 'job2', 'your_job_name'}, -- Who can see them
--     requireOnDuty = true,     -- Must be on duty to use tracker
-- },
--
-- COLOR CONFIGURATION OPTIONS:
-- 1. Use predefined FiveM colors by ID (0-85):
--    color = 38  -- Police blue
--
-- 2. Use standard color references:
--    color = Config.StandardColors.police_blue
--    color = Config.StandardColors.red
--
-- 3. Use custom RGB colors (if supported by your framework):
--    color = Config.CustomColors.custom_blue
--    color = {255, 0, 0}  -- Direct RGB (Red)
--
-- SIZE CONFIGURATION OPTIONS:
-- 1. Use predefined sizes:
--    scale = Config.BlipSizes.tiny       -- 0.5
--    scale = Config.BlipSizes.small      -- 0.8
--    scale = Config.BlipSizes.medium     -- 1.0 (RECOMMENDED)
--    scale = Config.BlipSizes.large      -- 1.8
--    scale = Config.BlipSizes.huge       -- 2.5
--
-- 2. Use custom size directly:
--    scale = 1.5  -- Any value between 0.1 and 5.0
--
-- COMMON BLIP SPRITES:
-- 1 - Standard Police Blip
-- 4 - Central white circle
-- 42 - First responder
-- 56 - Police car
-- 61 - Medical cross
-- 84 - Sheriff blip
-- 436 - Fire department
-- 487 - Ambulance
-- 50 - Security blip
-- 77 - Police car alternative
-- 280 - Police star
-- 356 - Fire truck
-- 423 - Ambulance alternative
--
-- COMPLETE FIVEM BLIP COLOR REFERENCE (IDs 0-85):
-- 0  - White/Default
-- 1  - White
-- 2  - Red
-- 3  - Green
-- 4  - Blue
-- 5  - Orange
-- 6  - Brown
-- 7  - Gray
-- 8  - Light Gray
-- 9  - Dark Gray
-- 10 - Black
-- 11 - Dark Red
-- 12 - Light Green
-- 13 - Dark Blue
-- 14 - Yellow
-- 15 - Light Orange
-- 16 - Light Blue
-- 17 - Purple
-- 18 - Pink
-- 19 - Cyan
-- 20 - Dark Purple
-- 21 - Dark Pink
-- 22 - Dark Cyan
-- 23 - Dark Brown
-- 24 - Light Brown
-- 25 - Dark Yellow
-- 26 - Dark Orange
-- 27 - Dark Blue (lighter)
-- 28 - Dark Blue (darker)
-- 29 - Dark Purple (lighter)
-- 30 - Dark Purple (darker)
-- 31 - Dark Pink (lighter)
-- 32 - Dark Pink (darker)
-- 33 - Dark Cyan (lighter)
-- 34 - Dark Cyan (darker)
-- 35 - Dark Brown (lighter)
-- 36 - Dark Brown (darker)
-- 37 - Light Yellow
-- 38 - Police Blue (classic)
-- 39 - Army Green
-- 40 - Navy Blue
-- 41 - Maroon
-- 42 - Gold
-- 43 - Olive Green
-- 44 - Tan
-- 45 - Coral
-- 46 - Salmon
-- 47 - Yellow
-- 48 - Light Yellow
-- 49 - Light Orange
-- 50 - Orange
-- 51 - Red Orange
-- 52 - Dark Orange
-- 53 - Light Red
-- 54 - Red
-- 55 - Dark Red
-- 56 - Light Green
-- 57 - Green
-- 58 - Dark Green
-- 59 - Purple
-- 60 - Pink
-- 61 - Cyan
-- 62 - Light Blue
-- 63 - Blue
-- 64 - Dark Blue
-- 65 - Light Purple
-- 66 - Purple
-- 67 - Dark Purple
-- 68 - Light Pink
-- 69 - Pink
-- 70 - Dark Pink
-- 71 - Light Cyan
-- 72 - Cyan
-- 73 - Dark Cyan
-- 74 - Light Gray
-- 75 - Gray
-- 76 - Dark Gray
-- 77 - Light Black
-- 78 - Black
-- 79 - Very Light Gray
-- 80 - Very Dark Gray
-- 81 - Lime Green
-- 82 - Teal
-- 83 - Navy
-- 84 - Dark Navy
-- 85 - Dark Teal
--
-- RECOMMENDED COLOR COMBINATIONS BY DEPARTMENT:
--
-- POLICE DEPARTMENTS:
-- - Police: 38 (Blue), 4 (Blue), 63 (Blue), 40 (Navy Blue)
-- - Sheriff: 38 (Blue), 4 (Blue), 63 (Blue), 40 (Navy Blue)
-- - SWAT: 1 (White), 2 (Red), 10 (Black)
-- - Highway Patrol: 38 (Blue), 63 (Blue)
--
-- EMERGENCY SERVICES:
-- - EMS/Paramedics: 1 (White), 60 (Pink), 69 (Pink)
-- - Fire Department: 5 (Orange), 26 (Dark Orange), 42 (Gold)
-- - Search & Rescue: 3 (Green), 56 (Light Green), 81 (Lime Green)
--
-- SECURITY:
-- - Private Security: 5 (Orange), 50 (Orange), 52 (Dark Orange)
-- - Mall Security: 6 (Brown), 23 (Dark Brown)
-- - Nightclub Security: 18 (Pink), 69 (Pink)
--
-- GOVERNMENT:
-- - FBI/Detectives: 10 (Black), 78 (Black)
-- - Court Security: 1 (White), 7 (Gray)
-- - Prison Guards: 40 (Navy Blue), 83 (Navy)
--
-- RP SPECIFIC COLORS:
-- - Gang Colors: Use matching gang colors (2, 54, 55 for red gangs, etc.)
-- - Custom Factions: Use Config.CustomColors to create unique colors
--
-- SIZE RECOMMENDATIONS:
-- - Small squads (5-10 players): scale = Config.BlipSizes.medium (1.0)
-- - Medium departments (10-30 players): scale = Config.BlipSizes.large (1.8)
-- - Large departments (30+ players): scale = Config.BlipSizes.huge (2.5)
-- - Covert operations: scale = Config.BlipSizes.small (0.8)
-- - Maximum visibility: scale = Config.BlipSizes.huge (2.5)
--
-- EXAMPLE CONFIGURATIONS:
--
-- High Visibility Police (Large, Bright Blue):
-- ['police'] = {
--     blip = {
--         sprite = 1,
--         color = Config.StandardColors.police_blue,
--         scale = Config.BlipSizes.large,  -- 1.8
--         label = 'Police Unit',
--         showDistance = true,
--     },
-- }
--
-- Stealth Operations (Small, Dark Blue):
-- ['swat'] = {
--     blip = {
--         sprite = 84,
--         color = Config.StandardColors.dark_blue,
--         scale = Config.BlipSizes.small,  -- 0.8
--         label = 'SWAT Unit',
--         showDistance = false,
--     },
-- }
--
-- Medical Response (Large, White):
-- ['ems'] = {
--     blip = {
--         sprite = 61,
--         color = Config.StandardColors.ems_white,
--         scale = Config.BlipSizes.huge,  -- 2.5
--         label = 'EMS Unit',
--         showDistance = true,
--     },
-- }
--
-- Custom RGB Color (Advanced):
-- ['custom_job'] = {
--     blip = {
--         sprite = 1,
--         color = {255, 100, 50},  -- Custom orange-red
--         scale = 1.5,
--         label = 'Custom Unit',
--         showDistance = true,
--     },
-- }
-- =============================================================================
