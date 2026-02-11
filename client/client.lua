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
local AutoEnableSuppressed = false
local UsePanic

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

local function IsOxLibMenuAvailable()
    return GetResourceState('ox_lib') == 'started' and lib and type(lib.registerContext) == 'function' and type(lib.showContext) == 'function'
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

local function IsTrackerDisableRestricted()
    return Config.TrackerDisable and Config.TrackerDisable.restricted == true
end

local function IsTrackerDisableOfficer()
    if not PlayerData.job or not PlayerData.job.name then
        return false
    end

    local allowedJobs = (Config.TrackerDisable and Config.TrackerDisable.officerJobs) or {}
    for _, jobName in ipairs(allowedJobs) do
        if jobName == PlayerData.job.name then
            return true
        end
    end

    return false
end

local function IsTrackerDisableConfiguredJob()
    if not PlayerData.job or not PlayerData.job.name then
        return false
    end

    local jobName = PlayerData.job.name

    if type(Config.Jobs) ~= 'table' then
        return Config.AllowAllJobs == true
    end

    if Config.Jobs[jobName] and Config.Jobs[jobName].enabled then
        return true
    end

    for configJob, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled and string.match(jobName, configJob) then
            return true
        end
    end

    return Config.AllowAllJobs == true
end

local function CanManuallyDisableTracker()
    if not IsTrackerDisableRestricted() then
        return true
    end

    if Config.TrackerDisable and Config.TrackerDisable.allowWhenCuffed and IsPlayerCuffed() then
        return true
    end

    if IsTrackerDisableOfficer() then
        return true
    end

    return IsTrackerDisableConfiguredJob()
end

local function IsJobConfigured(jobName)
    if not jobName then return false end

    if type(Config.Jobs) ~= 'table' then
        if Config.AllowAllJobs == true then
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

local function IsMenuJobAuthorized(jobName)
    if not jobName or type(Config.Jobs) ~= 'table' then
        return false
    end

    if Config.Jobs[jobName] and Config.Jobs[jobName].enabled then
        return true
    end

    for configJob, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled and string.match(jobName, configJob) then
            return true
        end
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

    local canUse, reason = CanUseTracker()

    if not canUse then
        AutoEnableSuppressed = false
        if TrackerEnabled and reason ~= 'cannot_use_cuffed' then
            DisableTracker(false)
        end
        return
    end

    if AutoEnableSuppressed then
        return
    end

    if not TrackerEnabled then
        EnableTracker(false, false)
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
    local parts = {}

    if data.callsign and data.callsign ~= '' then
        parts[#parts + 1] = data.callsign
    end

    if data.rank and data.rank ~= '' then
        parts[#parts + 1] = data.rank
    end

    parts[#parts + 1] = name

    if data.department and data.department ~= '' then
        parts[#parts + 1] = ('(%s)'):format(data.department)
    end

    return table.concat(parts, ' | ')
end

local function UpdateIdentityMetadata(payload)
    TriggerServerEvent('gps_tracker:updateIdentity', payload or {})
end

local function ShowIdentityUpdateDialog()
    if not IsOxLibMenuAvailable() or type(lib.inputDialog) ~= 'function' then
        ShowNotification('ox_lib_required')
        return
    end

    local response = lib.inputDialog('Update Unit Details', {
        { type = 'input', label = 'Callsign', description = 'Your active unit callsign for map legend', required = false, max = 48 },
        { type = 'input', label = 'Rank', description = 'Displayed rank/title in the map legend', required = false, max = 48 },
        { type = 'input', label = 'Department', description = 'Department currently clocked onto', required = false, max = 48 }
    })

    if not response then
        return
    end

    UpdateIdentityMetadata({
        callsign = response[1],
        rank = response[2],
        department = response[3]
    })
end

local function IsJobInList(jobName, jobs)
    if not jobName or type(jobs) ~= 'table' then
        return false
    end

    for _, configuredJob in ipairs(jobs) do
        if configuredJob == jobName then
            return true
        end
    end

    return false
end

local function ResolvePoliceBlipOverride(data, jobBlip)
    local policeConfig = Config.PoliceBlip or {}

    if policeConfig.enabled ~= true then
        return jobBlip
    end

    local jobName = data and data.job and data.job.name
    if not IsJobInList(jobName, policeConfig.jobs) then
        return jobBlip
    end

    local merged = {
        sprite = tonumber(policeConfig.sprite) or jobBlip.sprite,
        color = policeConfig.color or jobBlip.color,
        scale = tonumber(policeConfig.scale) or jobBlip.scale,
        label = ((policeConfig.labelPrefix and policeConfig.labelPrefix ~= '') and (policeConfig.labelPrefix .. ' Unit')) or jobBlip.label,
        showDistance = jobBlip.showDistance,
        flashWhenLightsOn = policeConfig.flashWhenLightsOn,
        flashIntervalMs = policeConfig.flashIntervalMs
    }

    if merged.sprite == nil then
        merged.sprite = jobBlip.sprite
    end

    if merged.color == nil then
        merged.color = jobBlip.color
    end

    if merged.scale == nil then
        merged.scale = jobBlip.scale
    end

    return merged
end

local function ShouldBlipFlash(jobBlip, lightsOn)
    if not jobBlip then
        return false
    end

    if jobBlip.flashWhenLightsOn == true then
        return lightsOn == true
    end

    return false
end

local function CreateOrUpdateBlip(data)
    if not data or not data.coords then return end

    local coords = data.coords
    local jobBlip = ResolvePoliceBlipOverride(data, data.blip or {})
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

    if ShouldBlipFlash(jobBlip, data.lightsOn) then
        SetBlipFlashes(blip, true)
        SetBlipFlashInterval(blip, tonumber(jobBlip.flashIntervalMs) or 250)
    else
        SetBlipFlashes(blip, false)
    end

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

function EnableTracker(playAnimation, isManualAction)
    local canUse, reason = CanUseTracker()

    if not canUse then
        ShowNotification(reason)
        return false
    end

    if TrackerEnabled then return true end

    if isManualAction == true then
        AutoEnableSuppressed = false
    end

    if playAnimation ~= false then
        PlayConfigAnimation(Config.Animations and Config.Animations.trackerToggle)
    end

    TrackerEnabled = true
    ShowNotification('tracker_enabled')

    TriggerServerEvent('gps_tracker:requestPlayerData')
    StartUpdateLoop()

    return true
end

function DisableTracker(isManualAction)
    if IsPlayerCuffed() then
        ShowNotification('cannot_use_cuffed')
        return false
    end

    if isManualAction == true then
        if not CanManuallyDisableTracker() then
            ShowNotification('tracker_disable_restricted')
            return false
        end

        AutoEnableSuppressed = true
    end

    if not TrackerEnabled then return true end

    TrackerEnabled = false
    TriggerServerEvent('gps_tracker:disableTracker')
    ClearAllBlips()
    ShowNotification('tracker_disabled')

    return true
end


function SetTrackerStatus(state)
    if state then
        return EnableTracker(true, true)
    end

    return DisableTracker(true)
end

function GetTrackerStatus()
    return TrackerEnabled
end

function StartUpdateLoop()
    Citizen.CreateThread(function()
        while TrackerEnabled do
            local coords = GetEntityCoords(PlayerPedId())

            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            local lightsOn = false

            if vehicle and vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                local alarmOn = false

                if type(IsVehicleAlarmActivated) == 'function' then
                    alarmOn = IsVehicleAlarmActivated(vehicle)
                elseif type(IsVehicleAlarmOn) == 'function' then
                    alarmOn = IsVehicleAlarmOn(vehicle)
                end

                lightsOn = IsVehicleSirenOn(vehicle) or alarmOn
            end

            TriggerServerEvent('gps_tracker:updatePosition', {
                coords = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                },
                lightsOn = lightsOn
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
    local key = string.format('%s:%s', tostring(data.serverId or 'x'), tostring(GetGameTimer()))

    local panicBlip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipSprite(panicBlip, blipConfig.sprite or 161)
    SetBlipColour(panicBlip, ResolveBlipColor(blipConfig.color or 1))
    SetBlipScale(panicBlip, blipConfig.scale or 1.9)
    SetBlipFlashes(panicBlip, true)
    SetBlipAsShortRange(panicBlip, false)
    SetBlipFlashInterval(panicBlip, 250)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString((blipConfig.label or 'PANIC') .. ' - ' .. (data.playerName or 'Unit'))
    EndTextCommandSetBlipName(panicBlip)

    PanicBlips[key] = panicBlip

    local centerIconConfig = blipConfig.centerIcon or {}
    if centerIconConfig.enabled ~= false then
        local centerBlip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(centerBlip, tonumber(centerIconConfig.sprite) or 303)
        SetBlipColour(centerBlip, ResolveBlipColor(centerIconConfig.color or blipConfig.color or 1))
        SetBlipScale(centerBlip, tonumber(centerIconConfig.scale) or 0.85)
        SetBlipAsShortRange(centerBlip, false)
        SetBlipFlashes(centerBlip, true)
        SetBlipFlashInterval(centerBlip, 250)
        PanicBlips[key .. ':center'] = centerBlip
    end

    if blipConfig.showRadius ~= false then
        local radius = tonumber(blipConfig.radius) or 90.0
        local radiusBlip = AddBlipForRadius(data.coords.x, data.coords.y, data.coords.z, radius)
        SetBlipColour(radiusBlip, ResolveBlipColor(blipConfig.radiusColor or blipConfig.color or 1))
        SetBlipAlpha(radiusBlip, tonumber(blipConfig.radiusAlpha) or 120)
        PanicBlips[key .. ':radius'] = radiusBlip
    end

    SetTimeout((Config.Panic and Config.Panic.blipDurationMs) or 15000, function()
        RemovePanicBlip(key)
        RemovePanicBlip(key .. ':center')
        RemovePanicBlip(key .. ':radius')
    end)
end

local function PlayPanicSoundForDuration(durationMs)
    local panicConfig = Config.Panic or {}
    local soundConfig = panicConfig.sound or {}

    if soundConfig.enabled == false then
        return
    end

    local audioName = soundConfig.audioName or '5_SEC_WARNING'
    local audioRef = soundConfig.audioRef or 'HUD_MINI_GAME_SOUNDSET'
    local totalDuration = tonumber(durationMs) or (panicConfig.blipDurationMs or 15000)
    local repeatIntervalMs = tonumber(soundConfig.repeatIntervalMs) or 850
    local layeredPlays = tonumber(soundConfig.layeredPlays) or 2
    local layeredDelayMs = tonumber(soundConfig.layeredDelayMs) or 80

    if repeatIntervalMs < 250 then
        repeatIntervalMs = 250
    end

    if layeredPlays < 1 then
        layeredPlays = 1
    end

    if layeredDelayMs < 0 then
        layeredDelayMs = 0
    end

    CreateThread(function()
        local startedAt = GetGameTimer()

        while (GetGameTimer() - startedAt) < totalDuration do
            for _ = 1, layeredPlays do
                PlaySoundFrontend(-1, audioName, audioRef, true)
                if layeredDelayMs > 0 then
                    Wait(layeredDelayMs)
                end
            end
            Wait(repeatIntervalMs)
        end
    end)
end

local function SetPanicEnabled(state, showNotification)
    PanicEnabled = state == true
    TriggerServerEvent('gps_tracker:setPanicState', PanicEnabled)

    if showNotification == true then
        ShowNotification(PanicEnabled and 'panic_enabled' or 'panic_disabled')
    end

    return PanicEnabled
end

local function TogglePanicEnabled()
    return SetPanicEnabled(not PanicEnabled, true)
end

local function GetPanicEnabled()
    return PanicEnabled
end

local function OpenTrackerMenu()
    if not PlayerData.job or not IsMenuJobAuthorized(PlayerData.job.name) then
        ShowNotification('not_authorized')
        return
    end

    if not IsOxLibMenuAvailable() then
        ShowNotification('ox_lib_required')
        return
    end

    local trackerEnabled = TrackerEnabled
    local panicEnabled = PanicEnabled
    local isCuffed = IsPlayerCuffed()

    local menuConfig = Config.Menu or {}
    local branding = menuConfig.branding or {}
    local logoIcon = (branding.enabled ~= false and type(branding.icon) == 'string' and branding.icon ~= '') and branding.icon or 'shield-halved'
    local titlePrefix = (branding.enabled ~= false and type(branding.titlePrefix) == 'string' and branding.titlePrefix ~= '') and branding.titlePrefix or '🚓'
    local customTitle = (branding.enabled ~= false and type(branding.title) == 'string' and branding.title ~= '') and branding.title or 'Emergency Services Tracker System'
    local menuTitle = string.format('%s %s', titlePrefix, customTitle)

    local trackerStateLabel = trackerEnabled and 'ONLINE' or 'OFFLINE'
    local panicStateLabel = panicEnabled and 'ARMED' or 'SAFE'

    lib.registerContext({
        id = 'gps_tracker:menu',
        title = menuTitle,
        options = {
            {
                title = (branding.enabled ~= false and branding.label and branding.label ~= '') and branding.label or 'Emergency Dispatch',
                description = 'Field console status snapshot',
                icon = logoIcon,
                iconColor = trackerEnabled and 'green' or 'orange',
                readOnly = true,
                metadata = {
                    { label = 'Tracker Uplink', value = trackerStateLabel },
                    { label = 'Panic Device', value = panicStateLabel },
                    { label = 'Restraints', value = isCuffed and 'ENGAGED' or 'CLEAR' }
                }
            },
            {
                title = trackerEnabled and 'Disable Tracker Broadcast' or 'Enable Tracker Broadcast',
                description = trackerEnabled and 'Stop sending your unit coordinates to command.' or 'Start sending your unit coordinates to command.',
                icon = trackerEnabled and 'tower-broadcast' or 'location-crosshairs',
                iconColor = trackerEnabled and 'red' or 'green',
                progress = trackerEnabled and 100 or 0,
                colorScheme = trackerEnabled and 'red' or 'green',
                disabled = isCuffed,
                metadata = isCuffed and {
                    { label = 'Control Lock', value = 'Tracker changes are blocked while cuffed' }
                } or {
                    { label = 'Action', value = trackerEnabled and 'Disable uplink' or 'Enable uplink' }
                },
                onSelect = function()
                    if trackerEnabled then
                        DisableTracker(true)
                    else
                        EnableTracker(true, true)
                    end

                    OpenTrackerMenu()
                end
            },
            {
                title = panicEnabled and 'Disarm Panic Button' or 'Arm Panic Button',
                description = panicEnabled and 'Prevent accidental panic broadcasts for now.' or 'Allow emergency panic broadcasts from this tablet.',
                icon = panicEnabled and 'bell-slash' or 'bell',
                iconColor = panicEnabled and 'orange' or 'green',
                progress = panicEnabled and 100 or 0,
                colorScheme = panicEnabled and 'orange' or 'blue',
                metadata = {
                    { label = 'Status', value = panicEnabled and 'Armed' or 'Disarmed' }
                },
                onSelect = function()
                    TogglePanicEnabled()
                    OpenTrackerMenu()
                end
            },
            {
                title = 'Transmit Panic Alert',
                description = 'Broadcast a high-priority emergency location beacon.',
                icon = 'triangle-exclamation',
                iconColor = 'red',
                disabled = (not panicEnabled) or isCuffed,
                metadata = {
                    { label = 'Ready', value = ((panicEnabled and not isCuffed) and 'YES' or 'NO') }
                },
                onSelect = function()
                    UsePanic()
                end
            },
            {
                title = 'Update Unit Details',
                description = 'Set your callsign, rank, and clocked-on department for map legend display.',
                icon = 'id-badge',
                disabled = isCuffed,
                onSelect = function()
                    ShowIdentityUpdateDialog()
                end
            }
        }
    })

    lib.showContext('gps_tracker:menu')
end

UsePanic = function()
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
    local cooldownMs = ((Config.Panic and Config.Panic.cooldownMs) or 45000)
    if LastPanicAt > 0 and (now - LastPanicAt) < cooldownMs then
        ShowNotification('panic_cooldown')
        return
    end

    LastPanicAt = now
    PlayConfigAnimation(Config.Animations and Config.Animations.panic)

    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('gps_tracker:panic', {
        coords = { x = coords.x, y = coords.y, z = coords.z }
    })
end

_G.UsePanic = UsePanic


exports('UseTrackerItem', function()
    OpenTrackerMenu()
end)

exports('UsePanicItem', function()
    OpenTrackerMenu()
end)

exports('SetTrackerStatus', SetTrackerStatus)
exports('SetPanicStatus', SetPanicEnabled)
exports('GetPanicStatus', GetPanicEnabled)

RegisterNetEvent('gps_tracker:updateBlips', function(players)
    if not TrackerEnabled then return end

    local active = {}
    for _, playerData in ipairs(players or {}) do
        active[playerData.serverId] = true
        CreateOrUpdateBlip(playerData)
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

RegisterNetEvent('gps_tracker:panicSent', function(data)
    CreatePanicBlip(data)
    PlayPanicSoundForDuration((Config.Panic and Config.Panic.blipDurationMs) or 15000)
    ShowNotification('panic_sent')
end)

RegisterNetEvent('gps_tracker:panicDenied', function(reason)
    ShowNotification(reason or 'panic_failed')
end)

RegisterNetEvent('gps_tracker:receivePanic', function(data)
    CreatePanicBlip(data)
    PlayPanicSoundForDuration((Config.Panic and Config.Panic.blipDurationMs) or 15000)
    ShowNotification('panic_received')
end)

RegisterNetEvent('gps_tracker:useTrackerItem', function()
    OpenTrackerMenu()
end)

RegisterNetEvent('gps_tracker:usePanicItem', function()
    OpenTrackerMenu()
end)

RegisterNetEvent('gps_tracker:identityUpdated', function()
    ShowNotification('identity_updated')
end)

local function GetCommandName(commandConfig)
    if type(commandConfig) == 'table' then
        if type(commandConfig.name) == 'string' and commandConfig.name ~= '' then
            return commandConfig.name
        end

        return nil
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

        return type(commandConfig.name) == 'string' and commandConfig.name ~= ''
    end

    return type(commandConfig) == 'string' and commandConfig ~= ''
end

local function RegisterTrackerCommands()
    if not Config.Commands or Config.Commands.enabled == false then
        return
    end

    if IsCommandEnabled(Config.Commands.tracker) then
        RegisterCommand(GetCommandName(Config.Commands.tracker), function()
            OpenTrackerMenu()
        end, false)
    end

    if IsCommandEnabled(Config.Commands.panic) then
        RegisterCommand(GetCommandName(Config.Commands.panic), function()
            UsePanic()
        end, false)
    end

    if IsCommandEnabled(Config.Commands.callsign) then
        RegisterCommand(GetCommandName(Config.Commands.callsign), function(_, args)
            UpdateIdentityMetadata({ callsign = table.concat(args or {}, ' ') })
        end, false)
    end

    if IsCommandEnabled(Config.Commands.rank) then
        RegisterCommand(GetCommandName(Config.Commands.rank), function(_, args)
            UpdateIdentityMetadata({ rank = table.concat(args or {}, ' ') })
        end, false)
    end

    if IsCommandEnabled(Config.Commands.department) then
        RegisterCommand(GetCommandName(Config.Commands.department), function(_, args)
            UpdateIdentityMetadata({ department = table.concat(args or {}, ' ') })
        end, false)
    end

end

local function RegisterKeybindAction(keybindConfig, fallbackName, callback)
    if not keybindConfig or keybindConfig.enabled == false then
        return
    end

    local internalCommand = ('+gps_tracker:%s'):format(fallbackName)
    if type(keybindConfig.command) == 'string' and keybindConfig.command ~= '' and keybindConfig.command:sub(1, 1) == '+' then
        internalCommand = keybindConfig.command
    end

    RegisterCommand(internalCommand, callback, false)

    RegisterKeyMapping(
        internalCommand,
        keybindConfig.description or fallbackName,
        keybindConfig.defaultMapper or 'keyboard',
        keybindConfig.defaultParameter or 'F6'
    )
end

local function RegisterTrackerKeybinds()
    if not Config.Keybinds or Config.Keybinds.enabled == false then
        return
    end

    RegisterKeybindAction(Config.Keybinds.toggleTracker, 'toggle_tracker', function()
        OpenTrackerMenu()
    end)

    RegisterKeybindAction(Config.Keybinds.panic, 'panic_alert', function()
        UsePanic()
    end)

    RegisterKeybindAction(Config.Keybinds.togglePanic, 'toggle_panic', function()
        TogglePanicEnabled()
    end)
end

local function RegisterTrackerMenuBindings()
    local menuConfig = Config.Menu
    if not menuConfig or menuConfig.enabled == false then
        return
    end

    if menuConfig.command and menuConfig.command ~= '' then
        RegisterCommand(menuConfig.command, function()
            OpenTrackerMenu()
        end, false)
    end

    if menuConfig.keybindEnabled ~= false then
        RegisterKeybindAction({
            enabled = true,
            command = menuConfig.keybindCommand,
            description = menuConfig.description or 'Open GPS tracker menu',
            defaultMapper = menuConfig.defaultMapper or 'keyboard',
            defaultParameter = menuConfig.defaultParameter or 'F9'
        }, 'open_menu', function()
            OpenTrackerMenu()
        end)
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

    TriggerServerEvent('gps_tracker:setPanicState', PanicEnabled)

    RegisterTrackerCommands()
    RegisterTrackerKeybinds()
    RegisterTrackerMenuBindings()
    exports('GetTrackerStatus', GetTrackerStatus)


    print('[GPS Tracker] Client initialized')
end)
