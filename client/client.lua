-- =============================================================================
-- GPS TRACKER CLIENT SCRIPT
-- =============================================================================

local PlayerData = {}
local TrackerEnabled = false
local PlayerBlips = {}
local PanicBlips = {}
local Framework = nil
local ESX = nil
local QBCore = nil
local LastPanicAt = 0
local PanicEnabled = true

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

local function IsPlayerCuffed()
    if LocalPlayer and LocalPlayer.state and Config.CuffChecks and Config.CuffChecks.stateKeys then
        for _, key in ipairs(Config.CuffChecks.stateKeys) do
            if LocalPlayer.state[key] then
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
                    return exports[resource][exportName]()
                end)
                if ok and result then
                    return true
                end
            end
        end
    end

    return false
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

    if Config.AllowAllJobs then
        return true, '__default'
    end

    return false
end

local function GetJobConfig(configJobName)
    if configJobName == '__default' then
        return Config.DefaultJob or {}
    end

    return Config.Jobs[configJobName] or {}
end

local function HasRequiredItem()
    if not Config.RequireItem then
        return true
    end

    local requiredItem = Config.RequiredItem
    if not requiredItem or requiredItem == '' then
        return true
    end

    local hasItem = false

    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:Search('count', requiredItem)
        hasItem = count and count > 0
    elseif Framework == 'QBCore' and QBCore then
        local item = QBCore.Functions.GetItemByName(requiredItem)
        hasItem = item ~= nil and item.amount > 0
    end

    if not hasItem and Config.ShowItemNotification then
        ShowNotification('no_item')
    end

    return hasItem
end

local function CanUseTracker()
    if not PlayerData.job then return false end

    if IsPlayerCuffed() then
        return false, 'cannot_use_cuffed'
    end

    local jobName = PlayerData.job.name
    local isConfigured, configJobName = IsJobConfigured(jobName)

    if not isConfigured then
        return false, 'not_authorized'
    end

    local jobConfig = GetJobConfig(configJobName)

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

    if not HasRequiredItem() then
        return false, 'no_item'
    end

    return true
end

local function PlayConfigAnimation(animConfig)
    if not animConfig or not animConfig.dict or not animConfig.clip then
        return
    end

    local ped = PlayerPedId()
    RequestAnimDict(animConfig.dict)

    local timeoutAt = GetGameTimer() + 3000
    while not HasAnimDictLoaded(animConfig.dict) and GetGameTimer() < timeoutAt do
        Wait(10)
    end

    if not HasAnimDictLoaded(animConfig.dict) then
        return
    end

    TaskPlayAnim(ped, animConfig.dict, animConfig.clip, 3.0, 3.0, animConfig.duration or 1500, animConfig.flag or 49, 0.0, false, false, false)
    Wait(animConfig.duration or 1500)
    ClearPedTasks(ped)
end

function CheckJobAndEnableTracker()
    if not PlayerData.job then return end

    local canUse = CanUseTracker()

    if canUse and not TrackerEnabled then
        EnableTracker(false)
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

function EnableTracker(playAnimation)
    local canUse, reason = CanUseTracker()

    if not canUse then
        ShowNotification(reason)
        return false
    end

    if TrackerEnabled then return true end

    if playAnimation ~= false then
        PlayConfigAnimation(Config.Animations and Config.Animations.trackerToggle)
    end

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


function SetTrackerStatus(state)
    if state then
        return EnableTracker(true)
    end

    return DisableTracker()
end

function GetTrackerStatus()
    return TrackerEnabled
end

function StartUpdateLoop()
    Citizen.CreateThread(function()
        while TrackerEnabled do
            if IsPlayerCuffed() then
                DisableTracker()
                ShowNotification('cannot_use_cuffed')
                break
            end

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

local function RemovePanicBlip(key)
    local blip = PanicBlips[key]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    PanicBlips[key] = nil
end

local function CreatePanicBlip(data)
    if not data or not data.coords then
        return
    end

    local blipConfig = (Config.Panic and Config.Panic.blip) or {}
    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    local key = string.format('%s:%s', tostring(data.serverId or 'x'), tostring(GetGameTimer()))

    SetBlipSprite(blip, blipConfig.sprite or 161)
    SetBlipColour(blip, ResolveBlipColor(blipConfig.color or 1))
    SetBlipScale(blip, blipConfig.scale or 1.4)
    SetBlipFlashes(blip, true)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString((blipConfig.label or 'PANIC') .. ' - ' .. (data.playerName or 'Unit'))
    EndTextCommandSetBlipName(blip)

    PanicBlips[key] = blip

    SetTimeout((Config.Panic and Config.Panic.blipDurationMs) or 30000, function()
        RemovePanicBlip(key)
    end)
end

local function SetPanicEnabled(state)
    PanicEnabled = state == true
    ShowNotification(PanicEnabled and 'panic_enabled' or 'panic_disabled')
    return PanicEnabled
end

local function TogglePanicEnabled()
    return SetPanicEnabled(not PanicEnabled)
end

local function GetPanicEnabled()
    return PanicEnabled
end

local function UsePanic()
    if not Config.Panic or not Config.Panic.enabled then
        return
    end

    if not PanicEnabled then
        ShowNotification('panic_disabled')
        return
    end

    if IsPlayerCuffed() then
        ShowNotification('cannot_use_cuffed')
        return
    end

    local canUse, reason = CanUseTracker()
    if not canUse then
        ShowNotification(reason)
        return
    end

    local now = GetGameTimer()
    if now - LastPanicAt < ((Config.Panic and Config.Panic.cooldownMs) or 15000) then
        ShowNotification('panic_cooldown')
        return
    end

    LastPanicAt = now
    PlayConfigAnimation(Config.Animations and Config.Animations.panic)

    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('gps_tracker:panic', {
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })

    ShowNotification('panic_sent')
end


exports('UseTrackerItem', function()
    if TrackerEnabled then
        DisableTracker()
    else
        EnableTracker(true)
    end
end)

exports('UsePanicItem', function()
    UsePanic()
end)

exports('SetTrackerStatus', SetTrackerStatus)
exports('SetPanicStatus', SetPanicEnabled)
exports('GetPanicStatus', GetPanicEnabled)

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

RegisterNetEvent('gps_tracker:receivePanic', function(data)
    CreatePanicBlip(data)
    ShowNotification('panic_received')
end)

RegisterNetEvent('gps_tracker:useTrackerItem', function()
    if TrackerEnabled then
        DisableTracker()
    else
        EnableTracker(true)
    end
end)

RegisterNetEvent('gps_tracker:usePanicItem', function()
    UsePanic()
end)

local function GetCommandName(commandConfig)
    if type(commandConfig) == 'table' then
        return commandConfig.name
    end

    if type(commandConfig) == 'string' then
        return commandConfig
    end

    return nil
end

local function IsCommandEnabled(commandConfig)
    if type(commandConfig) == 'table' then
        if commandConfig.enabled == false then
            return false
        end

        return commandConfig.name and commandConfig.name ~= ''
    end

    return type(commandConfig) == 'string' and commandConfig ~= ''
end

local function RegisterTrackerCommands()
    if not Config.Commands or Config.Commands.enabled == false then
        return
    end

    if IsCommandEnabled(Config.Commands.enable) then
        RegisterCommand(GetCommandName(Config.Commands.enable), function()
            EnableTracker(true)
        end, false)
    end

    if IsCommandEnabled(Config.Commands.disable) then
        RegisterCommand(GetCommandName(Config.Commands.disable), function()
            DisableTracker()
        end, false)
    end

    if IsCommandEnabled(Config.Commands.status) then
        RegisterCommand(GetCommandName(Config.Commands.status), function()
            ShowNotification(TrackerEnabled and 'status_enabled' or 'status_disabled')
        end, false)
    end

    if IsCommandEnabled(Config.Commands.panic) then
        RegisterCommand(GetCommandName(Config.Commands.panic), function()
            UsePanic()
        end, false)
    end

    if IsCommandEnabled(Config.Commands.panicEnable) then
        RegisterCommand(GetCommandName(Config.Commands.panicEnable), function()
            SetPanicEnabled(true)
        end, false)
    end

    if IsCommandEnabled(Config.Commands.panicDisable) then
        RegisterCommand(GetCommandName(Config.Commands.panicDisable), function()
            SetPanicEnabled(false)
        end, false)
    end

    if IsCommandEnabled(Config.Commands.panicStatus) then
        RegisterCommand(GetCommandName(Config.Commands.panicStatus), function()
            ShowNotification(PanicEnabled and 'panic_status_enabled' or 'panic_status_disabled')
        end, false)
    end
end

local function RegisterTrackerKeybinds()
    if not Config.Keybinds or Config.Keybinds.enabled == false then
        return
    end

    local toggleConfig = Config.Keybinds.toggleTracker
    if toggleConfig and toggleConfig.enabled ~= false and toggleConfig.command and toggleConfig.command ~= '' then
        RegisterCommand(toggleConfig.command, function()
            if TrackerEnabled then
                DisableTracker()
            else
                EnableTracker(true)
            end
        end, false)

        RegisterKeyMapping(
            toggleConfig.command,
            toggleConfig.description or 'Toggle GPS tracker',
            toggleConfig.defaultMapper or 'keyboard',
            toggleConfig.defaultParameter or 'F6'
        )
    end

    local panicConfig = Config.Keybinds.panic
    if panicConfig and panicConfig.enabled ~= false and panicConfig.command and panicConfig.command ~= '' then
        RegisterCommand(panicConfig.command, function()
            UsePanic()
        end, false)

        RegisterKeyMapping(
            panicConfig.command,
            panicConfig.description or 'Send GPS panic alert',
            panicConfig.defaultMapper or 'keyboard',
            panicConfig.defaultParameter or 'F7'
        )
    end

    local panicToggleConfig = Config.Keybinds.togglePanic
    if panicToggleConfig and panicToggleConfig.enabled ~= false and panicToggleConfig.command and panicToggleConfig.command ~= '' then
        RegisterCommand(panicToggleConfig.command, function()
            TogglePanicEnabled()
        end, false)

        RegisterKeyMapping(
            panicToggleConfig.command,
            panicToggleConfig.description or 'Toggle GPS panic button',
            panicToggleConfig.defaultMapper or 'keyboard',
            panicToggleConfig.defaultParameter or 'F8'
        )
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
    RegisterTrackerKeybinds()
    exports('GetTrackerStatus', GetTrackerStatus)


    print('[GPS Tracker] Client initialized')
end)
