local QBCore = exports['qbr-core']:GetCoreObject()
local SelectedHorseId = {}

Citizen.CreateThread(function()
	if GetCurrentResourceName() ~= "qbr-stable" then
		print("^1=====================================")
		print("^1SCRIPT NAME OTHER THAN ORIGINAL")
		print("^1YOU SHOULD STOP SCRIPT")
		print("^1CHANGE NAME TO: ^2qbr-stable^1")
		print("^1=====================================^0")
	end
end)

RegisterNetEvent("qbr-stable:UpdateHorseComponents")
AddEventHandler("qbr-stable:UpdateHorseComponents", function(components, idhorse, MyHorse_entity)
        local src = source
        local encodedComponents = json.encode(components)
        local Player = QBCore.Functions.GetPlayer(src)
        local Playercid = Player.PlayerData.citizenid
        local id = idhorse
        print("UpdateHorseComponents"..encodedComponents)
        MySQL.Async.execute("UPDATE horses SET `components`=@components WHERE `cid`=@cid AND `id`=@id", {components = encodedComponents, cid = Playercid, id = id}, function(done)
            print("ComponentsUpdated")
            TriggerClientEvent("qbr-stable:client:UpdadeHorseComponents", src, MyHorse_entity, components)
        end)    
end)


RegisterNetEvent("qbr-stable:CheckSelectedHorse")
AddEventHandler("qbr-stable:CheckSelectedHorse", function()
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local Playercid = Player.PlayerData.citizenid

        MySQL.Async.fetchAll('SELECT * FROM horses WHERE `cid`=@cid;', {cid = Playercid}, function(horses)
            if #horses ~= 0 then
                for i = 1, #horses do
                    if horses[i].selected == 1 then
                        TriggerClientEvent("VP:HORSE:SetHorseInfo", src, horses[i].model, horses[i].name, horses[i].components)
                    end
                end                    
            end
        end)
end)

RegisterNetEvent("qbr-stable:AskForMyHorses")
AddEventHandler("qbr-stable:AskForMyHorses", function()
        local src = source
        local horseId = nil
        local components = nil
        local Player = QBCore.Functions.GetPlayer(src)
        local Playercid = Player.PlayerData.citizenid
        print("AskForMyHorses")
        MySQL.Async.fetchAll('SELECT * FROM horses WHERE `cid`=@cid;', {cid = Playercid}, function(horses)
            if horses[1]then
                horseId = horses[1].id
            else
                horseId = nil
            end

            MySQL.Async.fetchAll('SELECT * FROM horses WHERE `cid`=@cid;', {cid = Playercid}, function(components)
                if components[1] then
                    components = components[1].components
                end
            end)
            TriggerClientEvent("qbr-stable:ReceiveHorsesData", src, horses)      
        end)
end)

local Horses

RegisterNetEvent("qbr-stable:BuyHorse")
AddEventHandler("qbr-stable:BuyHorse", function(data, name)
        local src = source     
        local Player = QBCore.Functions.GetPlayer(src)
        local Playercid = Player.PlayerData.citizenid    

        MySQL.Async.fetchAll('SELECT * FROM horses WHERE `cid`=@cid;', {cid = Playercid}, function(horses)
            if #horses >= 3 then
                TriggerClientEvent('QBCore:Notify', src, "Du kannst maximal 3 Pferde haben!", 'error')
                return
            end
            Wait(200)
            if data.IsGold then
                if Player.Functions.RemoveMoney("bank", data.Gold, "stable-bought-horse") then
                    TriggerEvent('qbr-log:server:CreateLog', 'shops', 'Stable', 'green', "**"..GetPlayerName(Player.PlayerData.source) .. " (citizenid: "..Player.PlayerData.citizenid.." | id: "..Player.PlayerData.source..")** bought a horse for $"..data.Gold..".")
                else
                    print('not enough money')
                    return
                end
            else
                if Player.Functions.RemoveMoney("cash", data.Dollar, "stable-bought-horse") then
                    TriggerEvent('qbr-log:server:CreateLog', 'shops', 'Stable', 'green', "**"..GetPlayerName(Player.PlayerData.source) .. " (citizenid: "..Player.PlayerData.citizenid.." | id: "..Player.PlayerData.source..")** bought a horse for $"..data.Dollar..".")
                else
                    print('not enough money')
                    return
                end
            end
            MySQL.Async.execute('INSERT INTO horses (`cid`, `name`, `model`) VALUES (@Playercid, @name, @model);',
                {
                    Playercid = Playercid,
                    name = tostring(name),
                    model = data.ModelH
                }, function(rowsChanged)

                end)    

            end)
end)

RegisterNetEvent("qbr-stable:SelectHorseWithId")
AddEventHandler("qbr-stable:SelectHorseWithId", function(id)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local Playercid = Player.PlayerData.citizenid
        MySQL.Async.fetchAll('SELECT * FROM horses WHERE `cid`=@cid;', {cid = Playercid}, function(horse)
            for i = 1, #horse do  
                local horseID = horse[i].id
                MySQL.Async.execute("UPDATE horses SET `selected`='0' WHERE `cid`=@cid AND `id`=@id", {cid = Playercid,  id = horseID}, function(done)            
                end)

                Wait(300)
                
                if horse[i].id == id then      
                    MySQL.Async.execute("UPDATE horses SET `selected`='1' WHERE `cid`=@cid AND `id`=@id", {cid = Playercid, id = id}, function(done)                        
                        TriggerClientEvent("VP:HORSE:SetHorseInfo", src, horse[i].model, horse[i].name, horse[i].components)
                    end)            
                end
            end
        end)       
end)

RegisterNetEvent("qbr-stable:SellHorseWithId")
AddEventHandler("qbr-stable:SellHorseWithId", function(id)
        local modelHorse = nil
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        local Playercid = Player.PlayerData.citizenid
        MySQL.Async.fetchAll('SELECT * FROM horses WHERE `cid`=@cid;', {cid = Playercid}, function(horses)

            for i = 1, #horses do
               if tonumber(horses[i].id) == tonumber(id) then
                    modelHorse = horses[i].model
                    MySQL.Async.fetchAll('DELETE FROM horses WHERE `cid`=@cid AND`id`=@id;', {cid = Playercid,  id = id}, function(result)
                    end)                   
                end
            end

            for k,v in pairs(Config.Horses) do
                for models,values in pairs(v) do
                    if models ~= "name" then                
                        if models == modelHorse then
                            local price = tonumber(values[3]/2)
                            Player.Functions.AddMoney("cash", price, "stable-sell-horse")
                            TriggerEvent('qbr-log:server:CreateLog', 'shops', 'Stable', 'red', "**"..GetPlayerName(Player.PlayerData.source) .. " (citizenid: "..Player.PlayerData.citizenid.." | id: "..Player.PlayerData.source..")** sold a horse for $"..price..".")
                        end
                    end
                end
            end
        end)
end)
