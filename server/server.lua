-- =============================================================================
-- GPS TRACKER SERVER SCRIPT
-- =============================================================================
-- Handles all server-side functionality including:
-- - Player position tracking and storage
-- - Job-based visibility management
-- - Player data synchronization
-- - Performance optimization for 100+ players
-- =============================================================================

-- Initialize variables
local Players = {}
local Framework = nil
local ESX = nil
local QBCore = nil

-- =============================================================================
-- FRAMEWORK INITIALIZATION
-- =============================================================================

-- Auto-detect framework
local function DetectFramework()
    if Config.Framework ~= 'Auto' then
        return Config.Framework
    end
    
    if GetResourceState('es_extended') == 'started' then
        return 'ESX'
    end
    
    if GetResourceState('qb-core') == 'started' then
        return 'QBCore'
    end
    
    return 'ESX'
end

-- Initialize ESX server
local function InitializeESX()
    Framework = 'ESX'
    ESX = exports["es_extended"]:getSharedObject()
    
    -- Register player joined event
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        InitializePlayer(playerId, xPlayer)
    end)
    
    -- Register player dropped event
    RegisterNetEvent('esx:playerDropped', function(playerId)
        CleanupPlayer(playerId)
    end)
    
    -- Register job update event
    RegisterNetEvent('esx:setJob', function(playerId, job)
        UpdatePlayerJob(playerId, job)
    end)
    
    print('[GPS Tracker Server] ESX initialized successfully')
end

-- Initialize QBCore server
local function InitializeQBCore()
    Framework = 'QBCore'
    QBCore = exports['qb-core']:GetCoreObject()
    
    -- Register player joined event
    RegisterNetEvent('QBCore:Server:PlayerLoaded', function(player)
        InitializePlayer(player.PlayerData.source, player.PlayerData)
    end)
    
    -- Register player dropped event
    RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(playerId)
        CleanupPlayer(playerId)
    end)
    
    -- Register job update event
    RegisterNetEvent('QBCore:Server:OnJobUpdate', function(playerId, job)
        UpdatePlayerJob(playerId, job)
    end)
    
    print('[GPS Tracker Server] QBCore initialized successfully')
end

-- =============================================================================
-- PLAYER MANAGEMENT
-- =============================================================================

-- Initialize player data
function InitializePlayer(playerId, playerData)
    if not playerData or not playerId then
        return
    end
    
    local job = nil
    
    if Framework == 'ESX' then
        job = {
            name = playerData.job.name,
            grade = playerData.job.grade,
            grade_name = playerData.job.grade_name,
            label = playerData.job.label
        }
    elseif Framework == 'QBCore' then
        job = {
            name = playerData.job.name,
            grade = playerData.job.grade.level,
            grade_name = playerData.job.grade.name,
            label = playerData.job.label,
            onDuty = playerData.job.onduty
        }
    end
    
    Players[playerId] = {
        serverId = playerId,
        job = job,
        coords = nil,
        lastUpdate = 0,
        isOnline = true,
        trackerEnabled = false
    }
    
    print('[GPS Tracker Server] Initialized player ' .. playerId .. ' with job: ' .. (job and job.name or 'nil'))
end

-- Cleanup player data
function CleanupPlayer(playerId)
    if Players[playerId] then
        Players[playerId].isOnline = false
        Players[playerId].trackerEnabled = false
        
        -- Notify all players to remove this player's blip
        TriggerClientEvent('gps_tracker:playerDisconnected', -1, playerId)
        
        -- Remove from storage after delay
        SetTimeout(30000, function()
            if Players[playerId] and not Players[playerId].isOnline then
                Players[playerId] = nil
            end
        end)
        
        print('[GPS Tracker Server] Cleaned up player ' .. playerId)
    end
end

-- Update player job
function UpdatePlayerJob(playerId, job)
    if not Players[playerId] then
        return
    end
    
    Players[playerId].job = {
        name = job.name,
        grade = job.grade,
        grade_name = job.grade_name,
        label = job.label,
        onDuty = job.onduty
    }
    
    print('[GPS Tracker Server] Updated job for player ' .. playerId .. ' to: ' .. job.name)
end

-- =============================================================================
-- POSITION TRACKING
-- =============================================================================

-- Update player position
RegisterNetEvent('gps_tracker:updatePosition', function(positionData)
    local playerId = source
    
    if not Players[playerId] then
        return
    end
    
    Players[playerId].coords = positionData.coords
    Players[playerId].lastUpdate = GetGameTimer()
    Players[playerId].trackerEnabled = true
end)

-- =============================================================================
-- PLAYER DATA RETRIEVAL
-- =============================================================================

-- Get nearby players based on job visibility
function GetNearbyPlayers(requesterId)
    if not Players[requesterId] then
        return {}
    end
    
    local requesterJob = Players[requesterId].job
    local nearbyPlayers = {}
    
    -- Check if requester's job is configured
    local isRequesterJobConfigured, requesterConfigJobName = IsJobConfigured(requesterJob and requesterJob.name)
    
    if not isRequesterJobConfigured then
        return {}
    end
    
    local requesterJobConfig = Config.Jobs[requesterConfigJobName]
    
    -- Iterate through all players
    for playerId, playerData in pairs(Players) do
        -- Skip if same player
        if playerId == requesterId then
            goto continue
        end
        
        -- Skip if player is not online or has no coordinates
        if not playerData.isOnline or not playerData.coords then
            goto continue
        end
        
        -- Skip if player's tracker is not enabled
        if not playerData.trackerEnabled then
            goto continue
        end
        
        -- Check if target job is configured
        local isTargetJobConfigured, targetConfigJobName = IsJobConfigured(playerData.job and playerData.job.name)
        
        if not isTargetJobConfigured then
            goto continue
        end
        
        -- Check if requester can see target based on job visibility
        if not CanSeePlayer(requesterJobConfig, targetConfigJobName) then
            goto continue
        end
        
        -- Add to nearby players
        table.insert(nearbyPlayers, {
            serverId = playerId,
            job = playerData.job,
            coords = playerData.coords
        })
        
        ::continue::
    end
    
    return nearbyPlayers
end

-- Check if job is configured
function IsJobConfigured(jobName)
    if not jobName then return false, nil end
    
    -- Check exact match
    if Config.Jobs[jobName] and Config.Jobs[jobName].enabled then
        return true, jobName
    end
    
    -- Check for partial matches
    for configJob, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled and string.match(jobName, configJob) then
            return true, configJob
        end
    end
    
    return false, nil
end

-- Check if requester can see target based on job configuration
function CanSeePlayer(requesterJobConfig, targetConfigJobName)
    if not requesterJobConfig.visibleTo then
        return false
    end
    
    -- Check if 'all' is in visibleTo
    for _, visibleJob in ipairs(requesterJobConfig.visibleTo) do
        if visibleJob == 'all' or visibleJob == targetConfigJobName then
            return true
        end
    end
    
    return false
end

-- Handle nearby players request
RegisterNetEvent('gps_tracker:getNearbyPlayers', function()
    local playerId = source
    
    if not Players[playerId] then
        return
    end
    
    local nearbyPlayers = GetNearbyPlayers(playerId)
    
    TriggerClientEvent('gps_tracker:updateBlips', playerId, nearbyPlayers)
end)

-- Handle player data request
RegisterNetEvent('gps_tracker:requestPlayerData', function()
    local playerId = source
    
    if not Players[playerId] then
        return
    end
    
    local nearbyPlayers = GetNearbyPlayers(playerId)
    
    TriggerClientEvent('gps_tracker:updateBlips', playerId, nearbyPlayers)
end)

-- =============================================================================
-- PERFORMANCE OPTIMIZATION
-- =============================================================================

-- Cleanup stale blips
Citizen.CreateThread(function()
    while true do
        Wait(Config.Performance.cleanupInterval)
        
        local currentTime = GetGameTimer()
        local stalePlayers = {}
        
        for playerId, playerData in pairs(Players) do
            -- Check if player data is stale
            if playerData.trackerEnabled and playerData.lastUpdate > 0 then
                if currentTime - playerData.lastUpdate > Config.Performance.staleBlipTimeout then
                    playerData.trackerEnabled = false
                    table.insert(stalePlayers, playerId)
                    
                    if Config.Debug then
                        print('[GPS Tracker Server] Player ' .. playerId .. ' marked as stale')
                    end
                end
            end
        end
        
        -- Notify all players to remove stale blips
        if #stalePlayers > 0 then
            for _, stalePlayerId in ipairs(stalePlayers) do
                TriggerClientEvent('gps_tracker:playerDisconnected', -1, stalePlayerId)
            end
        end
    end
end)

-- =============================================================================
-- PLAYER CONNECTION EVENTS
-- =============================================================================

-- Handle player joining
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.update('Loading GPS Tracker...')
    
    Citizen.Wait(100)
    deferrals.done()
end)

-- Handle player dropping
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    
    if Players[playerId] then
        CleanupPlayer(playerId)
    end
end)

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

Citizen.CreateThread(function()
    -- Wait for framework to load
    Citizen.Wait(1000)
    
    -- Detect and initialize framework
    local detectedFramework = DetectFramework()
    
    if detectedFramework == 'ESX' then
        InitializeESX()
    elseif detectedFramework == 'QBCore' then
        InitializeQBCore()
    else
        print('[GPS Tracker Server] Error: Could not detect supported framework')
    end
    
    -- Sync with existing players
    if Framework == 'ESX' then
        ESX.GetPlayersFromJob(nil, function(players)
            for _, xPlayer in ipairs(players) do
                InitializePlayer(xPlayer.source, xPlayer)
            end
        end)
    elseif Framework == 'QBCore' then
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local player = QBCore.Functions.GetPlayer(playerId)
            if player then
                InitializePlayer(playerId, player.PlayerData)
            end
        end
    end
    
    print('[GPS Tracker Server] Server initialized successfully')
    print('[GPS Tracker Server] Tracking ' .. #GetPlayers() .. ' players')
end)

-- =============================================================================
-- DEBUG COMMANDS
-- =============================================================================

if Config.Debug then
    -- Debug command to see all tracked players
    RegisterCommand('gps_debug_players', function(source, args, rawCommand)
        local playerId = source
        
        if playerId ~= 0 then
            print('[GPS Tracker Debug] This command can only be used from the server console')
            return
        end
        
        print('[GPS Tracker Debug] === CURRENT TRACKED PLAYERS ===')
        for playerId, playerData in pairs(Players) do
            print('[GPS Tracker Debug] Player: ' .. playerId .. 
                  ' | Job: ' .. (playerData.job and playerData.job.name or 'nil') ..
                  ' | Online: ' .. tostring(playerData.isOnline) ..
                  ' | Tracker: ' .. tostring(playerData.trackerEnabled) ..
                  ' | Last Update: ' .. (playerData.lastUpdate or 0))
        end
        print('[GPS Tracker Debug] ===================================')
    end, true)
    
    -- Debug command to force update all players
    RegisterCommand('gps_debug_update', function(source, args, rawCommand)
        if source ~= 0 then
            return
        end
        
        print('[GPS Tracker Debug] Forcing player update...')
        
        for playerId, playerData in pairs(Players) do
            if playerData.isOnline then
                TriggerClientEvent('gps_tracker:getNearbyPlayers', playerId)
            end
        end
        
        print('[GPS Tracker Debug] Update sent to all players')
    end, true)
    
    -- Debug command to reset all blips
    RegisterCommand('gps_debug_reset', function(source, args, rawCommand)
        if source ~= 0 then
            return
        end
        
        print('[GPS Tracker Debug] Resetting all blips...')
        
        for playerId, playerData in pairs(Players) do
            playerData.trackerEnabled = false
        end
        
        TriggerClientEvent('gps_tracker:playerDisconnected', -1, -1)
        
        print('[GPS Tracker Debug] All blips reset')
    end, true)
end

-- =============================================================================
-- EXPORTS
-- =============================================================================

-- Get player tracker status
exports('GetPlayerTrackerStatus', function(playerId)
    if not Players[playerId] then
        return false
    end
    
    return Players[playerId].trackerEnabled
end)

-- Set player tracker status
exports('SetPlayerTrackerStatus', function(playerId, status)
    if not Players[playerId] then
        return false
    end
    
    Players[playerId].trackerEnabled = status
    
    if not status then
        TriggerClientEvent('gps_tracker:playerDisconnected', -1, playerId)
    end
    
    return true
end)

-- Get all tracked players
exports('GetTrackedPlayers', function()
    local trackedPlayers = {}
    
    for playerId, playerData in pairs(Players) do
        if playerData.trackerEnabled then
            table.insert(trackedPlayers, {
                serverId = playerId,
                job = playerData.job,
                coords = playerData.coords
            })
        end
    end
    
    return trackedPlayers
end)