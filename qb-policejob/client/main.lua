-- Variables
QBCore = exports['qb-core']:GetCoreObject()
isHandcuffed = false
cuffType = 1
isEscorted = false
draggerId = 0
PlayerJob = {}
onDuty = true
local DutyBlips = {}

-- Functions
local function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    
    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= ped then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(pedCoords - targetCoords)
            if closestDistance == -1 or distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end
    
    return closestPlayer, closestDistance
end

local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)
    if not DoesBlipExist(blip) then
        if NetworkIsPlayerActive(playerId) then
            blip = AddBlipForEntity(ped)
        else
            blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
        end
        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(playerLocation.w))
        SetBlipScale(blip, 1.0)
        if playerJob == "police" then
            SetBlipColour(blip, 26)
        elseif playerJob == "bcso" then
            SetBlipColour(blip, 46)
        elseif playerJob == "sasp" then
            SetBlipColour(blip, 40)
        elseif playerJob == "saspr" then
            SetBlipColour(blip, 25)
        elseif playerJob == "sdso" then
            SetBlipColour(blip, 37)
        elseif playerJob == "pbso" then
            SetBlipColour(blip, 27)
        else
            SetBlipColour(blip, 8)
        end
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(playerLabel)
        EndTextCommandSetBlipName(blip)
        DutyBlips[#DutyBlips+1] = blip
    end

    if GetBlipFromEntity(PlayerPedId()) == blip then
        -- Ensure we remove our own blip.
        RemoveBlip(blip)
    end
end

-- Events
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()
    PlayerJob = player.job
    onDuty = player.job.onduty
    isHandcuffed = false
    TriggerServerEvent("QBCore:Server:SetMetaData", "ishandcuffed", false)
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    TriggerServerEvent("police:server:UpdateBlips")
    TriggerServerEvent("police:server:UpdateCurrentCops")

    if player.metadata.tracker then
        local trackerClothingData = {
            outfitData = {
                ["accessory"] = {
                    item = 13,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    else
        local trackerClothingData = {
            outfitData = {
                ["accessory"] = {
                    item = -1,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    end

    if PlayerJob and (PlayerJob.name ~= "police" or PlayerJob.name ~= "bcso" or PlayerJob.name ~= "sasp" or PlayerJob.name ~= "saspr" or PlayerJob.name ~= "sdso" or PlayerJob.name ~= "pbso") then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    TriggerServerEvent("police:server:UpdateCurrentCops")
    isHandcuffed = false
    isEscorted = false
    onDuty = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    if DutyBlips then
        for k, v in pairs(DutyBlips) do
            RemoveBlip(v)
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    TriggerServerEvent("police:server:UpdateBlips")
    if JobInfo.name == "police" or JobInfo.name == "bcso" or JobInfo.name == "sasp" or JobInfo.name == "saspr" or JobInfo.name == "sdso" or JobInfo.name == "pbso" then
        if PlayerJob.onduty then
            TriggerServerEvent("QBCore:ToggleDuty")
            onDuty = false
        end
    end

    if (PlayerJob ~= nil) and PlayerJob.name ~= "police" or PlayerJob.name ~= "bcso" or PlayerJob.name ~= "sasp" or PlayerJob.name ~= "saspr" or PlayerJob.name ~= "sdso" or PlayerJob.name ~= "pbso" then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('police:client:sendBillingMail', function(amount)
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')
        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end
        local charinfo = QBCore.Functions.GetPlayerData().charinfo
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('email.sender'),
            subject = Lang:t('email.subject'),
            message = Lang:t('email.message', {value = gender, value2 = charinfo.lastname, value3 = amount}),
            button = {}
        })
    end)
end)

RegisterNetEvent('police:client:UpdateBlips', function(players)
    if PlayerJob and (PlayerJob.name == 'police' or PlayerJob.name == 'ambulance' or PlayerJob.name == 'bcso' or PlayerJob.name == 'sasp' or PlayerJob.name == 'saspr' or PlayerJob.name == 'sdso' or PlayerJob.name == 'pbso') and
        onDuty then
        if DutyBlips then
            for k, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
        if players then
            for k, data in pairs(players) do
                local id = GetPlayerFromServerId(data.source)
                CreateDutyBlips(id, data.label, data.job, data.location)

            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)
    QBCore.Functions.Notify({text = text, caption = street1name.. ' ' ..street2name}, 'police')
    PlaySound(-1, "Lose_1st", "GTAO_FM_Events_Soundset", 0, 0, 1)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.blip_text', {value = text})
    SetBlipSprite(blip, 60)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(blipText)
    EndTextCommandSetBlipName(blip)
    while transG ~= 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
        if transG == 0 then
            RemoveBlip(blip)
            return
        end
    end
end)

RegisterNetEvent('police:client:SendToJail', function(time)
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    isHandcuffed = false
    isEscorted = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    TriggerEvent("prison:client:Enter", time)
end)

-- Handcuffs Item Usage
local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 10000 do
        Wait(10)
        timeout = timeout + 10
    end
    return timeout < 10000
end

RegisterNetEvent('police:client:UseHandcuffs', function(item)
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer == -1 then
        QBCore.Functions.Notify("No player nearby!", "error")
        return
    end
    
    if closestDistance > 3.0 then
        QBCore.Functions.Notify("Target too far!", "error")
        return
    end
    
    local targetPed = GetPlayerPed(closestPlayer)
    local targetServerId = GetPlayerServerId(closestPlayer)
    
    if GetEntityHealth(targetPed) <= 100 then
        QBCore.Functions.Notify("Target is dead!", "error")
        return
    end
    
    -- Load and play cuffing animation
    RequestAnimDict("mp_arrest_paired")
    local loadTimeout = 0
    while not HasAnimDictLoaded("mp_arrest_paired") and loadTimeout < 5000 do
        Wait(10)
        loadTimeout = loadTimeout + 10
    end
    
    -- Play animation on officer
    local ped = PlayerPedId()
    TaskPlayAnim(ped, "mp_arrest_paired", "cop_arrest_paired_05_pl830", 8.0, -8.0, 5000, 49, 1.0, false, false, false)
    
    Wait(5000)
    StopAnimTask(ped, "mp_arrest_paired", "cop_arrest_paired_05_pl830", 1.0)
    
    TriggerServerEvent("police:server:UseHandcuffs", targetServerId)
    TriggerServerEvent('inventory:server:RemoveItem', 'handcuffs', 1)
    TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items['handcuffs'], 'remove')
end)

RegisterNetEvent('police:client:GetCuffed', function(copId, isSoftcuff)
    local ped = PlayerPedId()
    
    RequestAnimDict("mp_arrest_paired")
    local timeout = 0
    while not HasAnimDictLoaded("mp_arrest_paired") and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    isHandcuffed = true
    cuffType = isSoftcuff and 2 or 1
    TriggerServerEvent("police:server:SetHandcuffStatus", true)
    TriggerEvent('qb-inventory:client:set:busy', true)
    
    -- Play cuffed animation and keep it playing
    CreateThread(function()
        while isHandcuffed do
            if not IsEntityPlayingAnim(ped, "mp_arrest_paired", "cop_arrest_paired_05_a_pl830", 3) then
                TaskPlayAnim(ped, "mp_arrest_paired", "cop_arrest_paired_05_a_pl830", 8.0, -8.0, -1, 49, 0, false, false, false)
            end
            Wait(100)
        end
    end)
    
    -- Disable controls while cuffed
    CreateThread(function()
        while isHandcuffed do
            Wait(0)
            DisableControlAction(0, 47, true) -- Disable weapon select
            DisableControlAction(0, 54, true) -- Disable aim
            DisableControlAction(0, 25, true) -- Disable aim assist
            DisableControlAction(0, 140, true) -- Disable melee attack light
            DisableControlAction(0, 141, true) -- Disable melee attack heavy
            DisableControlAction(0, 142, true) -- Disable melee attack alternate
            DisableControlAction(0, 263, true) -- Disable melee attack to left
            DisableControlAction(0, 264, true) -- Disable melee attack to right
            DisableControlAction(0, 22, true) -- Disable jump
        end
    end)
    
    QBCore.Functions.Notify("You are handcuffed!", "primary")
end)

RegisterNetEvent('police:client:GetUnCuffed', function()
    local ped = PlayerPedId()
    
    isHandcuffed = false
    TriggerServerEvent("police:server:SetHandcuffStatus", false)
    ClearPedTasks(ped)
    TriggerEvent('qb-inventory:client:set:busy', false)
    
    QBCore.Functions.Notify("You are no longer handcuffed!", "success")
end)





-- Threads
CreateThread(function()
    for k, station in pairs(Config.Locations["stations"]) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 29)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)

RegisterNetEvent('police:client:takeoffmask')
AddEventHandler('police:client:takeoffmask', function()
    local player, distance = GetClosestPlayer()
    if player ~= -1 and distance < 2.5 then
        local playerId = GetPlayerServerId(player)
        QBCore.Functions.GetPlayerData(function(PlayerData)
            if PlayerData.job.name == "police" or PlayerData.job.name == "bcso" then
                TriggerServerEvent("police:server:takeoffmask", playerId)
            end
        end)
    else
        QBCore.Functions.Notify("No one nearby!", "error")
    end
end)

RegisterNetEvent('police:client:takeoffmaskc')
AddEventHandler('police:client:takeoffmaskc', function()
    local ad = "missheist_agency2ahelmet"
    loadAnimDict(ad)
    RequestAnimDict(dict)
    TaskPlayAnim(PlayerPedId(), ad, "take_off_helmet_stand", 8.0, 1.0, -1, 49, 0, 0, 0, 0 )
    Wait(600)
    ClearPedSecondaryTask(PlayerPedId())
    SetPedComponentVariation(PlayerPedId(), 1, 0, 0, 2)
    QBCore.Functions.Notify("Taken your mask off", "error")
end)

RegisterNetEvent('police:client:Useadrenshot', function()
    local ped = PlayerPedId()
      QBCore.Functions.Progressbar("use_bandage", "Taking Adrenshot...", 2500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
		disableMouse = false,
		disableCombat = true,
    }, {
		animDict = "amb@world_human_clipboard@male@idle_a",
		anim = "idle_c",
		flags = 49,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, "amb@world_human_clipboard@male@idle_a", "idle_c", 1.0)
        TriggerServerEvent("QBCore:Server:RemoveItem", "adrenshot", 1)
        TriggerEvent("inventory:client:ItemBox", QBCore.Shared.Items["adrenshot"], "remove")
        TriggerServerEvent('hud:server:RelieveStress', math.random(12, 24))
        SetEntityHealth(ped, GetEntityHealth(ped) + 10)
        onPainKillers = true
        if painkillerAmount < 3 then
            painkillerAmount = painkillerAmount + 1
        end
        if math.random(1, 100) < 50 then
            RemoveBleed(1)
        end
    end, function() -- Cancel
        StopAnimTask(ped, "amb@world_human_clipboard@male@idle_a", "idle_c", 1.0)
        QBCore.Functions.Notify(Lang:t('error.canceled'), "error")
    end)
end)

-- rifle rack in interceptor vehicles
RegisterNetEvent('police:client:riflerack', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    QBCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.job.name == "police" then
            if onDuty then
                if GetEntityModel(vehicle) == `npolchal` or GetEntityModel(vehicle) == `npolvette` or GetEntityModel(vehicle) == `npolstang` or GetEntityModel(vehicle) == `npolvic` or GetEntityModel(vehicle) == `npolchar` or GetEntityModel(vehicle) == `npolexp` or GetEntityModel(vehicle) == `npolretinue` then 
                    TriggerEvent('qb-inventory:client:set:busy', true)
                    QBCore.Functions.Progressbar("open-rifle-rack", "Opening Rifle Rack...", 2500, false, true, {
                        disableMovement = true,
                        disableCarMovement = false,
                        disableMouse = false,
                        disableCombat = true,
                    }, {}, {}, {}, function() -- Done
                        TriggerServerEvent("inventory:server:OpenInventory", "stash", 'Riflerack_'..QBCore.Functions.GetPlayerData().citizenid, {maxweight = 26000, slots = 2})
                        TriggerEvent("inventory:client:SetCurrentStash", 'Riflerack_'..QBCore.Functions.GetPlayerData().citizenid)
                    end, function()
                        TriggerEvent('qb-inventory:client:set:busy', false)
                        QBCore.Functions.Notify("Canceled..", "error")
                    end)
                else
                    QBCore.Functions.Notify("Thats not a Police Vehicle!", "error")
                end
            else
                QBCore.Functions.Notify("You have to be On Duty!", "error")
            end
        else
            QBCore.Functions.Notify("You are not Police Officer!", "error")
        end
    end)
end)