-- =============================================================================
-- GPS TRACKER CLIENT SCRIPT
-- =============================================================================

local PlayerData = {}
local TrackerEnabled = false
local PlayerBlips = {}
local Framework = nil
local ESX = nil
local QBCore = nil

local function ShowNotification(type)
    local message = (Config.Notifications and Config.Notifications[type]) or type

    if Framework == 'ESX' and ESX then
        ESX.ShowNotification(message)
    elseif Framework == 'QBCore' and QBCore then
        QBCore.Functions.Notify(message, 'info', 3000)
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end

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

local function InitializeESX()
    Framework = 'ESX'
    ESX = exports['es_extended']:getSharedObject()

    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        if Config.AutoEnableOnDuty and PlayerData.job then
            CheckJobAndEnableTracker()
        end
    end)

    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
        if Config.AutoEnableOnDuty then
            CheckJobAndEnableTracker()
        end
    end)
end

local function InitializeQBCore()
    Framework = 'QBCore'
    QBCore = exports['qb-core']:GetCoreObject()

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = QBCore.Functions.GetPlayerData()
        if Config.AutoEnableOnDuty and PlayerData.job then
            CheckJobAndEnableTracker()
        end
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job
        if Config.AutoEnableOnDuty then
            CheckJobAndEnableTracker()
        end
    end)
end

local function IsJobConfigured(jobName)
    if not jobName then return false end

    if Config.Jobs[jobName] and Config.Jobs[jobName].enabled then
        return true, jobName
    end

    for configJob, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled and string.match(jobName, configJob) then
            return true, configJob
        end
    end

    return false
end

local function CanUseTracker()
    if not PlayerData.job then return false end

    local jobName = PlayerData.job.name
    local isConfigured, configJobName = IsJobConfigured(jobName)

    if not isConfigured then
        return false, 'not_authorized'
    end

    local jobConfig = Config.Jobs[configJobName]

    if jobConfig.requireOnDuty then
        local onDuty = false

        if Framework == 'ESX' then
            onDuty = PlayerData.job.grade and PlayerData.job.grade > 0
        elseif Framework == 'QBCore' then
            onDuty = PlayerData.job.onduty or false
        end

        if not onDuty then
            return false, 'not_on_duty'
        end
    end

    if Config.RequireItem then
        local hasItem = false

        if Framework == 'ESX' and exports.ox_inventory then
            local count = exports.ox_inventory:Search('count', Config.RequiredItem)
            hasItem = count and count > 0
        elseif Framework == 'QBCore' and QBCore then
            local item = QBCore.Functions.GetItemByName(Config.RequiredItem)
            hasItem = item ~= nil and item.amount > 0
        end

        if not hasItem then
            if Config.ShowItemNotification then
                ShowNotification('no_item')
            end
            return false, 'no_item'
        end
    end

    return true
end

function CheckJobAndEnableTracker()
    if not PlayerData.job then return end

    local canUse = CanUseTracker()

    if canUse and not TrackerEnabled then
        EnableTracker()
    elseif not canUse and TrackerEnabled then
        DisableTracker()
    end
end

local function ResolveBlipColor(color)
    if type(color) == 'number' then
        return color
    end

    if type(color) == 'string' and Config.StandardColors and Config.StandardColors[color] then
        return Config.StandardColors[color]
    end

    return 1
end

local function BuildBlipLabel(data)
    local name = data.playerName or 'Unknown'
    return name
end

local function CreateOrUpdateBlip(data)
    if not data or not data.coords then return end

    local coords = data.coords
    local jobBlip = data.blip or {}
    local color = ResolveBlipColor(jobBlip.color)
    local scale = tonumber(jobBlip.scale) or 1.0
    local sprite = tonumber(jobBlip.sprite) or 1

    local blip = PlayerBlips[data.serverId]

    if not blip or not DoesBlipExist(blip) then
        blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        PlayerBlips[data.serverId] = blip
        SetBlipAsShortRange(blip, false)
    else
        SetBlipCoords(blip, coords.x, coords.y, coords.z)
    end

    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(BuildBlipLabel(data))
    EndTextCommandSetBlipName(blip)
end

function ClearAllBlips()
    for serverId, blip in pairs(PlayerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
        PlayerBlips[serverId] = nil
    end
end

local function RemoveBlipByServerId(serverId)
    local blip = PlayerBlips[serverId]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    PlayerBlips[serverId] = nil
end

function EnableTracker()
    local canUse, reason = CanUseTracker()

    if not canUse then
        ShowNotification(reason)
        return false
    end

    if TrackerEnabled then return true end

    TrackerEnabled = true
    ShowNotification('tracker_enabled')

    TriggerServerEvent('gps_tracker:requestPlayerData')
    StartUpdateLoop()

    return true
end

function DisableTracker()
    if not TrackerEnabled then return true end

    TrackerEnabled = false
    TriggerServerEvent('gps_tracker:disableTracker')
    ClearAllBlips()
    ShowNotification('tracker_disabled')

    return true
end

function GetTrackerStatus()
    return TrackerEnabled
end

function StartUpdateLoop()
    Citizen.CreateThread(function()
        while TrackerEnabled do
            local coords = GetEntityCoords(PlayerPedId())

            TriggerServerEvent('gps_tracker:updatePosition', {
                coords = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }
            })

            TriggerServerEvent('gps_tracker:getNearbyPlayers')

            Wait(Config.UpdateInterval or 3000)
        end
    end)
end

RegisterNetEvent('gps_tracker:updateBlips', function(players)
    if not TrackerEnabled then return end

    local active = {}
    for _, playerData in ipairs(players or {}) do
        if playerData.serverId ~= GetPlayerServerId(PlayerId()) then
            active[playerData.serverId] = true
            CreateOrUpdateBlip(playerData)
        end
    end

    for serverId, _ in pairs(PlayerBlips) do
        if not active[serverId] then
            RemoveBlipByServerId(serverId)
        end
    end
end)

RegisterNetEvent('gps_tracker:playerDisconnected', function(serverId)
    if serverId == -1 then
        ClearAllBlips()
        return
    end

    RemoveBlipByServerId(serverId)
end)

local function RegisterTrackerCommands()
    if Config.Commands and Config.Commands.enable and Config.Commands.enable ~= '' then
        RegisterCommand(Config.Commands.enable, function()
            EnableTracker()
        end, false)
    end

    if Config.Commands and Config.Commands.disable and Config.Commands.disable ~= '' then
        RegisterCommand(Config.Commands.disable, function()
            DisableTracker()
        end, false)
    end

    if Config.Commands and Config.Commands.status and Config.Commands.status ~= '' then
        RegisterCommand(Config.Commands.status, function()
            ShowNotification(TrackerEnabled and 'status_enabled' or 'status_disabled')
        end, false)
    end

end

Citizen.CreateThread(function()
    Wait(1000)

    local detected = DetectFramework()

    if detected == 'ESX' then
        InitializeESX()
        PlayerData = ESX.GetPlayerData() or {}
    elseif detected == 'QBCore' then
        InitializeQBCore()
        PlayerData = QBCore.Functions.GetPlayerData() or {}
    end

    if Config.AutoEnableOnDuty and PlayerData.job then
        CheckJobAndEnableTracker()
    end

    RegisterTrackerCommands()
    exports('GetTrackerStatus', GetTrackerStatus)

    print('[GPS Tracker] Client initialized')
end)
