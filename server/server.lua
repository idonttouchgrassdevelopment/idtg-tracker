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

local function GetJobConfig(configJobName)
    if configJobName == '__default' then
        return Config.DefaultJob or {}
    end

    return Config.Jobs[configJobName] or {}
end

local function IsJobConfigured(jobName)
    if not jobName then return false, nil end

    if type(Config.Jobs) ~= 'table' then
        if Config.AllowAllJobs then
            return true, '__default'
        end

        return false, nil
    end

    if Config.Jobs[jobName] and Config.Jobs[jobName].enabled then
        return true, jobName
    end

    for configJob, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled and string.match(jobName, configJob) then
            return true, configJob
        end
    end

    if Config.AllowAllJobs then
        return true, '__default'
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

local function IsPlayerCuffed(playerId)
    if not playerId then
        return false
    end

    local playerState = Player(playerId) and Player(playerId).state
    if playerState and Config.CuffChecks and Config.CuffChecks.stateKeys then
        for _, key in ipairs(Config.CuffChecks.stateKeys) do
            if playerState[key] then
                return true
            end
        end
    end

    if Config.CuffChecks and Config.CuffChecks.exports then
        for _, exportData in ipairs(Config.CuffChecks.exports) do
            local resource = exportData.resource
            local exportName = exportData.exportName

            if resource and exportName and GetResourceState(resource) == 'started' then
                local ok, result = pcall(function()
                    return exports[resource][exportName](playerId)
                end)

                if not ok then
                    ok, result = pcall(function()
                        return exports[resource][exportName]()
                    end)
                end

                if ok and result then
                    return true
                end
            end
        end
    end

    return false
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
        callsign = '',
        rank = (job and job.grade_name) or '',
        department = (job and (job.label or job.name)) or '',
        coords = nil,
        lastUpdate = 0,
        isOnline = true,
        trackerEnabled = false,
        panicEnabled = true,
        panicLastAt = 0,
        lightsOn = false
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

    local previousDepartment = Players[playerId].department

    Players[playerId].job = {
        name = job.name,
        grade = job.grade,
        grade_name = job.grade_name,
        label = job.label,
        onDuty = job.onduty
    }

    if not previousDepartment or previousDepartment == '' or previousDepartment == Players[playerId].job.name or previousDepartment == Players[playerId].job.label then
        Players[playerId].department = job.label or job.name or ''
    end

    if not Players[playerId].rank or Players[playerId].rank == '' then
        Players[playerId].rank = job.grade_name or tostring(job.grade or '')
    end
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

local function IsOfficerJob(jobName)
    local panicConfig = Config.Panic or {}
    local officerJobs = panicConfig.officerJobs or {}

    if not jobName then
        return false
    end

    for _, officerJob in ipairs(officerJobs) do
        if officerJob == jobName then
            return true
        end
    end

    return false
end


local function CanManuallyDisableTracker(playerId)
    local disableConfig = Config.TrackerDisable or {}

    if disableConfig.restricted ~= true then
        return true
    end

    if disableConfig.allowWhenCuffed and IsPlayerCuffed(playerId) then
        return true
    end

    local playerData = Players[playerId]
    local playerJobName = playerData and playerData.job and playerData.job.name
    if not playerJobName then
        return false
    end

    for _, officerJob in ipairs(disableConfig.officerJobs or {}) do
        if officerJob == playerJobName then
            return true
        end
    end

    local isConfiguredJob = IsJobConfigured(playerJobName)
    if isConfiguredJob then
        return true
    end

    return false
end
local function GetPlayersInRadius(centerCoords, radius)
    local targets = {}

    if not centerCoords or not radius or radius <= 0 then
        return targets
    end

    for playerId, playerData in pairs(Players) do
        if playerData.isOnline and playerData.coords then
            local dx = (playerData.coords.x or 0.0) - centerCoords.x
            local dy = (playerData.coords.y or 0.0) - centerCoords.y
            local dz = (playerData.coords.z or 0.0) - centerCoords.z
            local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))

            if distance <= radius then
                targets[playerId] = true
            end
        end
    end

    return targets
end

local function GetNearbyPlayers(requesterId)
    if not Players[requesterId] then
        return {}
    end

    if not Players[requesterId].trackerEnabled then
        return {}
    end

    local requesterJob = Players[requesterId].job
    local nearbyPlayers = {}
    local isRequesterJobConfigured, requesterConfigJobName = IsJobConfigured(requesterJob and requesterJob.name)

    if not isRequesterJobConfigured then
        return {}
    end

    local requesterJobConfig = GetJobConfig(requesterConfigJobName)

    for playerId, playerData in pairs(Players) do
        if playerData.isOnline and playerData.coords and playerData.trackerEnabled then
            local isTargetJobConfigured, targetConfigJobName = IsJobConfigured(playerData.job and playerData.job.name)

            if isTargetJobConfigured and CanSeePlayer(requesterJobConfig, targetConfigJobName) then
                table.insert(nearbyPlayers, {
                    serverId = playerId,
                    playerName = playerData.name,
                    callsign = playerData.callsign,
                    rank = playerData.rank,
                    department = playerData.department,
                    job = playerData.job,
                    blip = GetJobConfig(targetConfigJobName).blip or {},
                    coords = playerData.coords,
                    lightsOn = playerData.lightsOn == true
                })
            end
        end
    end

    return nearbyPlayers
end

RegisterNetEvent('gps_tracker:updatePosition', function(positionData)
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end
    if IsPlayerCuffed(playerId) then return end

    local coords = positionData and positionData.coords
    if not coords then
        return
    end

    Players[playerId].coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
    Players[playerId].lightsOn = positionData and positionData.lightsOn == true
    Players[playerId].lastUpdate = GetGameTimer()
    Players[playerId].trackerEnabled = true
end)

RegisterNetEvent('gps_tracker:disableTracker', function()
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end
    if not CanManuallyDisableTracker(playerId) then
        TriggerClientEvent('gps_tracker:panicDenied', playerId, 'tracker_disable_restricted')
        return
    end

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

RegisterNetEvent('gps_tracker:updateIdentity', function(payload)
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end

    payload = payload or {}
    local function sanitize(value, fallback)
        if type(value) ~= 'string' then
            return fallback
        end

        local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed == '' then
            return fallback
        end

        if #trimmed > 48 then
            trimmed = trimmed:sub(1, 48)
        end

        return trimmed
    end

    local player = Players[playerId]
    local job = player and player.job or {}

    player.callsign = sanitize(payload.callsign, player.callsign or '')
    player.rank = sanitize(payload.rank, player.rank or (job.grade_name or ''))
    player.department = sanitize(payload.department, player.department or (job.label or job.name or ''))

    TriggerClientEvent('gps_tracker:identityUpdated', playerId, {
        callsign = player.callsign,
        rank = player.rank,
        department = player.department
    })
end)


RegisterNetEvent('gps_tracker:setPanicState', function(state)
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end

    Players[playerId].panicEnabled = state == true
end)

RegisterNetEvent('gps_tracker:panic', function(payload)
    local playerId = source
    if not EnsurePlayerInitialized(playerId) then return end
    if IsPlayerCuffed(playerId) then
        TriggerClientEvent('gps_tracker:panicDenied', playerId, 'cannot_use_cuffed')
        return
    end
    if not (Config.Panic and Config.Panic.enabled) then return end

    local sender = Players[playerId]
    if sender and sender.panicEnabled == false then
        TriggerClientEvent('gps_tracker:panicDenied', playerId, 'panic_disabled')
        return
    end

    local senderJob = sender and sender.job
    local senderConfigured, senderConfigJobName = IsJobConfigured(senderJob and senderJob.name)
    if not senderConfigured then
        TriggerClientEvent('gps_tracker:panicDenied', playerId, 'not_authorized')
        return
    end

    local cooldownMs = (Config.Panic and Config.Panic.cooldownMs) or 45000
    local now = GetGameTimer()
    if (sender.panicLastAt or 0) > 0 and (now - (sender.panicLastAt or 0)) < cooldownMs then
        TriggerClientEvent('gps_tracker:panicDenied', playerId, 'panic_cooldown')
        return
    end
    sender.panicLastAt = now

    local coords = payload and payload.coords or sender.coords
    if not coords then
        TriggerClientEvent('gps_tracker:panicDenied', playerId, 'panic_failed')
        return
    end

    local panicData = {
        serverId = playerId,
        playerName = sender.name,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    }

    local panicConfig = Config.Panic or {}
    local nearbyAudibleRadius = tonumber(panicConfig.nearbyAudibleRadius) or 80.0
    local nearbyTargets = GetPlayersInRadius(panicData.coords, nearbyAudibleRadius)

    TriggerClientEvent('gps_tracker:panicSent', playerId, panicData)

    for targetId, targetData in pairs(Players) do
        if targetData.isOnline and targetId ~= playerId then
            local targetJobName = targetData.job and targetData.job.name
            local targetConfigured, targetConfigJobName = IsJobConfigured(targetJobName)
            local shouldReceive = false

            if IsOfficerJob(targetJobName) then
                shouldReceive = true
            elseif targetConfigured and CanSeePlayer(GetJobConfig(targetConfigJobName), senderConfigJobName) then
                shouldReceive = true
            elseif nearbyTargets[targetId] and not IsOfficerJob(targetJobName) then
                shouldReceive = true
            end

            if shouldReceive then
                TriggerClientEvent('gps_tracker:receivePanic', targetId, panicData)
            end
        end
    end
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
