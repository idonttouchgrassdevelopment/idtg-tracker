-- =============================================================================
-- GPS TRACKER CLIENT SCRIPT
-- =============================================================================

-- Initialize variables
local PlayerData = {}
local TrackerEnabled = false
local PlayerBlips = {}
local Framework = nil
local ESX = nil
local QBCore = nil

-- =============================================================================
-- NOTIFICATION FUNCTION (MOVED TO TOP - FIXES ERROR)
-- =============================================================================

local function ShowNotification(type)
    local message = (Config.Notifications and Config.Notifications[type]) or type

    if Framework == 'ESX' and ESX then
        ESX.ShowNotification(message)
    elseif Framework == 'QBCore' and QBCore then
        QBCore.Functions.Notify(message, 'info', 3000)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end

-- =============================================================================
-- FRAMEWORK DETECTION
-- =============================================================================

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

-- =============================================================================
-- ESX INITIALIZATION
-- =============================================================================

local function InitializeESX()
    Framework = 'ESX'
    ESX = exports["es_extended"]:getSharedObject()

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

    print('[GPS Tracker] ESX initialized')
end

-- =============================================================================
-- QBCORE INITIALIZATION
-- =============================================================================

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

    print('[GPS Tracker] QBCore initialized')
end

-- =============================================================================
-- JOB CHECKING
-- =============================================================================

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

        if Framework == 'ESX' and ESX then
            -- Modern ESX method
            local count = exports.ox_inventory and exports.ox_inventory:Search('count', Config.RequiredItem)
            if count and count > 0 then
                hasItem = true
            end
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

-- =============================================================================
-- TRACKER CONTROL
-- =============================================================================

function EnableTracker()
    local canUse, reason = CanUseTracker()

    if not canUse then
        if reason ~= 'no_item' then
            ShowNotification(reason)
        end
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
    ClearAllBlips()
    ShowNotification('tracker_disabled')

    return true
end

function GetTrackerStatus()
    return TrackerEnabled
end

-- =============================================================================
-- BLIP MANAGEMENT
-- =============================================================================

function ClearAllBlips()
    for serverId, blip in pairs(PlayerBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    PlayerBlips = {}
end

-- =============================================================================
-- UPDATE LOOP
-- =============================================================================

function StartUpdateLoop()
    Citizen.CreateThread(function()
        while TrackerEnabled do
            local coords = GetEntityCoords(PlayerPedId())

            TriggerServerEvent('gps_tracker:updatePosition', {
                x = coords.x,
                y = coords.y,
                z = coords.z
            })

            Wait(Config.UpdateInterval or 3000)
        end
    end)
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

Citizen.CreateThread(function()
    Wait(1000)

    local detected = DetectFramework()

    if detected == 'ESX' then
        InitializeESX()
    elseif detected == 'QBCore' then
        InitializeQBCore()
    end

    exports('GetTrackerStatus', GetTrackerStatus)

    print('[GPS Tracker] Client initialized')
end)
