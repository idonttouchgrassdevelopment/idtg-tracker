-- =============================================================================
-- GPS TRACKER SERVER SCRIPT
-- =============================================================================

local Players = {}
local Framework = nil
local ESX = nil
local QBCore = nil

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

local function IsJobConfigured(jobName)
    if not jobName then return false, nil end

    if Config.Jobs[jobName] and Config.Jobs[jobName].enabled then
        return true, jobName
    end

    for configJob, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled and string.match(jobName, configJob) then
            return true, configJob
        end
    end

    return false, nil
end

local function CanSeePlayer(requesterJobConfig, targetConfigJobName)
    if not requesterJobConfig.visibleTo then
        return false
    end

    for _, visibleJob in ipairs(requesterJobConfig.visibleTo) do
        if visibleJob == 'all' or visibleJob == targetConfigJobName then
            return true
        end
    end

    return false
end

local function GetPlayerNameByFramework(playerId)
    if Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            return xPlayer.getName()
        end
    elseif Framework == 'QBCore' and QBCore then
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData and player.PlayerData.charinfo then
            local charinfo = player.PlayerData.charinfo
            if charinfo.firstname and charinfo.lastname then
                return (charinfo.firstname .. ' ' .. charinfo.lastname)
            end
        end
    end

    return GetPlayerName(playerId) or ('Player ' .. tostring(playerId))
end

local function InitializePlayer(playerId, playerData)
    if not playerData or not playerId then
        return
    end

    local job

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
            grade = (playerData.job.grade and playerData.job.grade.level) or 0,
            grade_name = (playerData.job.grade and playerData.job.grade.name) or '',
            label = playerData.job.label,
            onDuty = playerData.job.onduty
        }
    end

    Players[playerId] = {
        serverId = playerId,
        name = GetPlayerNameByFramework(playerId),
        job = job,
        coords = nil,
        lastUpdate = 0,
        isOnline = true,
        trackerEnabled = false
    }
end

local function CleanupPlayer(playerId)
    if not Players[playerId] then return end

    Players[playerId].isOnline = false
    Players[playerId].trackerEnabled = false
    TriggerClientEvent('gps_tracker:playerDisconnected', -1, playerId)

    SetTimeout(30000, function()
        if Players[playerId] and not Players[playerId].isOnline then
            Players[playerId] = nil
        end
    end)
end

local function UpdatePlayerJob(playerId, job)
    if not Players[playerId] then return end

    Players[playerId].job = {
        name = job.name,
        grade = job.grade,
        grade_name = job.grade_name,
        label = job.label,
        onDuty = job.onduty
    }
end

local function EnsurePlayerInitialized(playerId)
    if Players[playerId] then
        return true
    end

    if Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            InitializePlayer(playerId, xPlayer)
        end
    elseif Framework == 'QBCore' and QBCore then
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData then
            InitializePlayer(playerId, player.PlayerData)
        end
    end

    return Players[playerId] ~= nil
end

local function InitializeESX()
    Framework = 'ESX'
    ESX = exports['es_extended']:getSharedObject()

    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        InitializePlayer(playerId, xPlayer)
    end)

    RegisterNetEvent('esx:setJob', function(playerId, job)
        UpdatePlayerJob(playerId, job)
    end)
end

local function InitializeQBCore()
    Framework = 'QBCore'
    QBCore = exports['qb-core']:GetCoreObject()

    RegisterNetEvent('QBCore:Server:PlayerLoaded', function(player)
        InitializePlayer(player.PlayerData.source, player.PlayerData)
    end)

    RegisterNetEvent('QBCore:Server:OnJobUpdate', function(playerId, job)
        UpdatePlayerJob(playerId, job)
    end)
end

local function GetNearbyPlayers(requesterId)
    if not Players[requesterId] then
        return {}
    end

    local requesterJob = Players[requesterId].job
    local nearbyPlayers = {}
    local isRequesterJobConfigured, requesterConfigJobName = IsJobConfigured(requesterJob and requesterJob.name)

    if not isRequesterJobConfigured then
        return {}
    end

    local requesterJobConfig = Config.Jobs[requesterConfigJobName]

    for playerId, playerData in pairs(Players) do
        if playerId ~= requesterId and playerData.isOnline and playerData.coords and playerData.trackerEnabled then
            local isTargetJobConfigured, targetConfigJobName = IsJobConfigured(playerData.job and playerData.job.name)

            if isTargetJobConfigured and CanSeePlayer(requesterJobConfig, targetConfigJobName) then
                table.insert(nearbyPlayers, {
                    serverId = playerId,
                    playerName = playerData.name,
                    job = playerData.job,
                    blip = (Config.Jobs[targetConfigJobName] and Config.Jobs[targetConfigJobName].blip) or {},
                    coords = playerData.coords
                })
            end
        end
    end

    return nearbyPlayers
end

RegisterNetEvent('gps_tracker:updatePosition', function(positionData)
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end

    local coords = positionData and positionData.coords
    if not coords then
        return
    end

    Players[playerId].coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
    Players[playerId].lastUpdate = GetGameTimer()
    Players[playerId].trackerEnabled = true
end)

RegisterNetEvent('gps_tracker:disableTracker', function()
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end

    Players[playerId].trackerEnabled = false
    TriggerClientEvent('gps_tracker:playerDisconnected', -1, playerId)
end)

RegisterNetEvent('gps_tracker:getNearbyPlayers', function()
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end
    TriggerClientEvent('gps_tracker:updateBlips', playerId, GetNearbyPlayers(playerId))
end)

RegisterNetEvent('gps_tracker:requestPlayerData', function()
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end
    TriggerClientEvent('gps_tracker:updateBlips', playerId, GetNearbyPlayers(playerId))
end)

Citizen.CreateThread(function()
    while true do
        Wait(Config.Performance.cleanupInterval)

        local currentTime = GetGameTimer()
        local stalePlayers = {}

        for playerId, playerData in pairs(Players) do
            if playerData.trackerEnabled and playerData.lastUpdate > 0 then
                if currentTime - playerData.lastUpdate > Config.Performance.staleBlipTimeout then
                    playerData.trackerEnabled = false
                    table.insert(stalePlayers, playerId)
                end
            end
        end

        for _, stalePlayerId in ipairs(stalePlayers) do
            TriggerClientEvent('gps_tracker:playerDisconnected', -1, stalePlayerId)
        end
    end
end)

AddEventHandler('playerDropped', function()
    CleanupPlayer(source)
end)

Citizen.CreateThread(function()
    Citizen.Wait(1000)

    local detectedFramework = DetectFramework()

    if detectedFramework == 'ESX' then
        InitializeESX()
    elseif detectedFramework == 'QBCore' then
        InitializeQBCore()
    else
        print('[GPS Tracker Server] Error: Could not detect supported framework')
    end

    if Framework == 'QBCore' then
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local player = QBCore.Functions.GetPlayer(playerId)
            if player then
                InitializePlayer(playerId, player.PlayerData)
            end
        end
    end

    print('[GPS Tracker Server] Server initialized successfully')
end)
