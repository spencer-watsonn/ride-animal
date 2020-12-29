--[[

Know Bugs/Issues:
	Some poses on top of the animal are 'not perfect' and might cause some slight clipping

Changes:
	Range for Speed = Animal.Speed.Run has been changed from 8.0 to 4.0
		This has made the run less buggy
		Run now works in a straight line
        	When turning while running, the animal walks then runs once straight
        	Going up rough terrain (eg. mountainside with no path) sometimes makes the animal ragdoll

	Speed for run has been changed from 3.0 to 10.0
		This makes the run a run and not a speed walk/light jog
		Run speed seems to be around the same as that of a player on foot

Unlisted YouTube Video of the Modified Script in Use:
	With Run Removed: https://youtu.be/1bWWwbRCy2k
	With Run: https://youtu.be/V_V7FUIkDbs

]]

function OnPlayerRequestToRideAnimal()
	return true
end

local AllowRidingAnimalPlayers = false
IhaveReplacedMyDeerWithModNumber1 = false --[[
										Current supported mod: https://www.gta5-mods.com/misc/horse-mod
										If mod is installed, change "IhaveReplacedMyDeerWithModNumber1" to true
										]]

local rideAnimal = 21 -- Defines "21" to variable rideAnimal

local HelperMessageID = 0
AnimalControlStatus =  0.05 -- Sets the player to have no control over the animal
XNL_IsRidingAnimal = false	-- Sets the player to not riding the animal	

local Animal = {
	Handle = nil,
	Invincible = false, -- Sets animal to take damage and ragdoll as normal
	Ragdoll = false, -- Sets whether or not the animal is ragdolling to false
	Marker = false,
	InControl = false, -- Sets the player to not being in control
	IsFleeing = false,
	Speed = {
		Walk = 2.0, -- Sets animal walk speed to 2
		Run = 10.0, -- Sets animal run speed to 10
	},
}

local entityEnumerator = {
	__gc = function(enum)
		if enum.destructor and enum.handle then
			enum.destructor(enum.handle)
		end
		enum.destructor = nil
		enum.handle = nil
	end
}

function EnumerateEntities(initFunc, moveFunc, disposeFunc)
	return coroutine.wrap(function()
		local iter, id = initFunc()
		if not id or id == 0 then
			disposeFunc(iter)
			return
		end
	
		local enum = {handle = iter, destructor = disposeFunc}
		setmetatable(enum, entityEnumerator)
	
		local next = true
		repeat
			coroutine.yield(id)
			next, id = moveFunc(iter)
		until not next 
	
		enum.destructor = nil
		enum.handle = nil
		disposeFunc(iter)
	end)
end

function EnumeratePeds()
    return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

function GetNearbyPeds(X, Y, Z, Radius)
	local NearbyPeds = {}
	for Ped in EnumeratePeds() do
		if DoesEntityExist(Ped) then
			local PedPosition = GetEntityCoords(Ped, false)
			if Vdist(X, Y, Z, PedPosition.x, PedPosition.y, PedPosition.z) <= Radius then
				table.insert(NearbyPeds, Ped)
			end
		end
	end
	return NearbyPeds
end


function Animal.Attach()
	local Ped = PlayerPedId()

	FreezeEntityPosition(Animal.Handle, true)
	FreezeEntityPosition(Ped, true)

	local AnimalPosition = GetEntityCoords(Animal.Handle, false)
	SetEntityCoords(Ped, AnimalPosition.x, AnimalPosition.y, AnimalPosition.z)

	AnimalName = "Deer"
	AnimalType = 1
	XAminalOffSet = 0.0 -- Default DEER offset
	AnimalOffSet  = 0.2 -- Default DEER offset

	if GetEntityModel(Animal.Handle) == GetHashKey('a_c_deer') and IhaveReplacedMyDeerWithModNumber1 then -- If the supported mod is installed, and it is stated, the follow IF statement will run
		AnimalName = "Horse"
		AnimalType = 1
		AnimalOffSet  = 0.12
		XAminalOffSet = -0.2
	end
	
	
	if GetEntityModel(Animal.Handle) == GetHashKey('a_c_cow') then 
		AnimalName = "Cow"
		AnimalType = 2
		AnimalOffSet  = 0.1
		XAminalOffSet = 0.1
	end
		
	if GetEntityModel(Animal.Handle) == GetHashKey('a_c_boar') then 
		AnimalName = "Boar"
		AnimalOffSet = 0.3
		AnimalType = 3
		XAminalOffSet = -0.0
	end

	if NetworkGetPlayerIndexFromPed(Animal.Handle) == -1 then
		if not (HelperMessageID == 2) and not Animal.InControl then
			DisplayHelpText('Keep tapping ~INPUT_VEH_ACCELERATE~ to get control of the ' .. AnimalName)
			HelperMessageID = 2
			AnimalControlStatus = 0.05
		end
	end

	SetCurrentPedWeapon(Ped, "weapon_unarmed", true) -- Sets player to unarmed (animals can possibly freak out if player is armed)
													
	AttachEntityToEntity(Ped, Animal.Handle, GetPedBoneIndex(Animal.Handle, 24816), XAminalOffSet, 0.0, AnimalOffSet, 0.0, 0.0, -90.0, false, false, false, true, 2, true)

	if AnimalType == 1  then
		RequestAnimDict("amb@prop_human_seat_chair@male@generic@base") -- Requests player animation for on deer
		while not HasAnimDictLoaded("amb@prop_human_seat_chair@male@generic@base") do
			Citizen.Wait(500)
		end
		TaskPlayAnim(Ped, "amb@prop_human_seat_chair@male@generic@base", "base", 8.0, 1, -1, 1, 1.0, 0, 0, 0) -- Sets player animation for on deer
	elseif AnimalType == 2 or AnimalType == 3 then
		RequestAnimDict("amb@prop_human_seat_chair@male@elbows_on_knees@idle_a") -- Requests player animation for on cow
		while not HasAnimDictLoaded("amb@prop_human_seat_chair@male@elbows_on_knees@idle_a") do
			Citizen.Wait(500)
		end
		TaskPlayAnim(Ped, "amb@prop_human_seat_chair@male@elbows_on_knees@idle_a", "idle_a", 8.0, 1, -1, 1, 1.0, 0, 0, 0) -- Sets player animation for on cow
	end
	

	
	FreezeEntityPosition(Animal.Handle, false)
	FreezeEntityPosition(Ped, false)
	XNL_IsRidingAnimal = true -- Sets the player to riding animal
end

function Animal.Ride()
	local Ped = PlayerPedId()
	local PedPosition = GetEntityCoords(Ped, false)
	if IsPedSittingInAnyVehicle(Ped) or IsPedGettingIntoAVehicle(Ped) then
		return
	end

	local AttachedEntity = GetEntityAttachedTo(Ped)

	if (IsEntityAttached(Ped)) and (GetEntityModel(AttachedEntity) == GetHashKey("a_c_deer") or GetEntityModel(AttachedEntity) == GetHashKey("a_c_cow") 
	    or GetEntityModel(AttachedEntity) == GetHashKey("a_c_boar")) then -- Checks if player is on animal
		local SideCoordinates = GetCoordsInfrontOfEntityWithDistance(AttachedEntity, 1.0, 90.0) -- Ensures player and animal are at the correct coords
		local SideHeading = GetEntityHeading(AttachedEntity)

		SideCoordinates.z = GetGroundZ(SideCoordinates.x, SideCoordinates.y, SideCoordinates.z)

		Animal.Handle = nil
		Animal.InControl = false -- Sets player to not have control
		DetachEntity(Ped, true, false)
		ClearPedSecondaryTask(Ped)
		ClearPedTasksImmediately(Ped)

		AminD2 = "amb@prop_human_seat_chair@male@elbows_on_knees@react_aggressive"
		RequestAnimDict(AminD2) -- Requests animation
		while not HasAnimDictLoaded(AminD2) do -- Checks to see if animation has loaded
			Citizen.Wait(10)
		end
		TaskPlayAnim(Ped, AminD2, "exit_left", 8.0, 1, -1, 0, 1.0, 0, 0, 0)
		Wait(100)
		SetEntityCoords(Ped, SideCoordinates.x, SideCoordinates.y, SideCoordinates.z)
		SetEntityHeading(Ped, SideHeading)
		ClearPedSecondaryTask(Ped)
		ClearPedTasksImmediately(Ped)
		RemoveAnimDict(AminD2)
		if HelperMessageID > 0 then
			HelperMessageID = 0
			ClearAllHelpMessages() -- Clears all help messages on screen
		end

	else
		for _, Ped in pairs(GetNearbyPeds(PedPosition.x, PedPosition.y, PedPosition.z, 2.0)) do
			if not IsPedFalling(Ped) and not IsPedFatallyInjured(Ped) and not IsPedDeadOrDying(Ped) 
			   and not IsPedDeadOrDying(Ped) and not IsPedGettingUp(Ped) and not IsPedRagdoll(Ped) then -- Checks animal status (dead/dying/ragdolled)
				if (GetEntityModel(Ped) == GetHashKey("a_c_deer") or GetEntityModel(Ped) == GetHashKey("a_c_cow")
					or GetEntityModel(Ped) == GetHashKey("a_c_boar")) then
					
					if NetworkGetPlayerIndexFromPed(Ped) > -1 and not AllowRidingAnimalPlayers then	-- Stops player riding animal if animal is dead/dying/ragdolled
						return
					end
				
					for _, Ped2 in pairs(GetNearbyPeds(PedPosition.x, PedPosition.y, PedPosition.z, 4.0)) do -- Does not allow player to attach to another animal while already attached to one
						if IsEntityAttachedToEntity(Ped2, Ped) then
							return
						end
					end

					if OnPlayerRequestToRideAnimal() then -- Checks if player is allowed to ride
						Animal.Handle = Ped
						Animal.Attach()
					end
					break
				end
			end
		end
	end
end

function DropPlayerFromAnimal()
	local Ped = PlayerPedId()
	Animal.Handle = nil
	DetachEntity(Ped, true, false)
	ClearPedTasksImmediately(Ped)
	ClearPedSecondaryTask(Ped)
	Animal.InControl = false -- Stops player from being in control
	AminD2 = "amb@prop_human_seat_chair@male@elbows_on_knees@react_aggressive"
	RequestAnimDict(AminD2)
	while not HasAnimDictLoaded(AminD2) do
		Citizen.Wait(20)
	end
	TaskPlayAnim(Ped, AminD2, "exit_left", 8.0, 1, -1, 0, 1.0, 0, 0, 0)
	Wait(200)
	ClearPedSecondaryTask(Ped)
	ClearPedTasksImmediately(Ped)
	Wait(200)
	SetPedToRagdoll(Ped, 1500, 1500, 0, 0, 0, 0) -- Ragdolls the player
	AnimalControlStatus = 0 -- Sets player to have no control over the animal
	XNL_IsRidingAnimal = false -- Sets player to not riding
end

function GetCoordsInfrontOfEntityWithDistance(Entity, Distance, Heading)
	local Coordinates = GetEntityCoords(Entity, false)
	local Head = (GetEntityHeading(Entity) + (Heading or 0.0)) * math.pi / 180.0
	return {x = Coordinates.x + Distance * math.sin(-1.0 * Head), y = Coordinates.y + Distance * math.cos(-1.0 * Head), z = Coordinates.z}
end

function GetGroundZ(X, Y, Z)
	if tonumber(X) and tonumber(Y) and tonumber(Z) then
		local _, GroundZ = GetGroundZFor_3dCoord(X + 0.0, Y + 0.0, Z + 0.0, Citizen.ReturnResultAnyway())
		return GroundZ
	else
		return 0.0
	end
end

function DisplayHelpText(str)
	SetTextComponentFormat("STRING")
	AddTextComponentString(str)
	DisplayHelpTextFromStringLabel(0, 0, 1, -1)
	EndTextCommandDisplayHelp(0, 0, true, 8000)
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(50)
		if AnimalControlStatus > 0 then
			AnimalControlStatus = AnimalControlStatus - 0.001 -- Takes 0.001 off the player control over animal until the player has no control over animal
		end
	end

end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustPressed(1, 23) then -- Checks for key press of [F] key
			Animal.Ride()
		end

		if XNL_IsRidingAnimal then
			local Ped = PlayerPedId()
			local AttachedEntity = GetEntityAttachedTo(Ped)
	
			if (not IsPedSittingInAnyVehicle(Ped) or not IsPedGettingIntoAVehicle(Ped)) and IsEntityAttached(Ped) and AttachedEntity == Animal.Handle then
			if DoesEntityExist(Animal.Handle) then
				AnimalChecksOkay = true
				if IsPedFalling(AttachedEntity) or IsPedFatallyInjured(AttachedEntity) or IsPedDeadOrDying(AttachedEntity) 
				   or IsPedDeadOrDying(AttachedEntity) or IsPedDeadOrDying(Ped) or IsPedGettingUp(AttachedEntity) or IsPedRagdoll(AttachedEntity) then -- Checks if animal is dead/dying/ragdolled
					Animal.IsFleeing = false -- Sets animal to calm/not fleeing
					Animal.InControl = false -- Sets player to not have control
					AnimalChecksOkay = false 
					DropPlayerFromAnimal() -- Runs function to detach player from animal and ragdoll
				end
			
				if AnimalChecksOkay then -- If animal is okay, resume riding
					local LeftAxisXNormal, LeftAxisYNormal = GetControlNormal(2, 218), GetControlNormal(2, 219)
					local Speed, Range = Animal.Speed.Walk, 4.0 -- Animal speed is a walk when control buttons pressed (W/A/S/D)

					if IsControlPressed(0, rideAnimal) then
                        Speed = Animal.Speed.Run -- If key pressed, animal speed is run
                        Range = 4.0
                    end

					if Animal.InControl then
						Animal.IsFleeing = false
						local GoToOffset = GetOffsetFromEntityInWorldCoords(Animal.Handle, LeftAxisXNormal * Range, LeftAxisYNormal * -1.0 * Range, 0.0)
		
						TaskLookAtCoord(Animal.Handle, GoToOffset.x, GoToOffset.y, GoToOffset.z, 0, 0, 2)
						TaskGoStraightToCoord(Animal.Handle, GoToOffset.x, GoToOffset.y, GoToOffset.z, Speed, 20000, 40000.0, 0.5)
		
						if Animal.Marker then
							DrawMarker(6, GoToOffset.x, GoToOffset.y, GoToOffset.z, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 255, 255, 255, 0, 0, 2, 0, 0, 0, 0)
						end
					else
						if NetworkGetPlayerIndexFromPed(Animal.Handle) == -1 then
							if IsControlJustPressed(1, 71) then -- Rapidly pressing the [W] key allows the player to gain control of the animal
								if AnimalControlStatus < 0.1 then
									AnimalControlStatus = AnimalControlStatus + 0.005
									if AnimalControlStatus > 0.1 then 
										AnimalControlStatus = 0.1 
										if HelperMessageID > 4 or HelperMessageID < 4 then
											DisplayHelpText("You've gained control of the animal.") -- If [W] key is pressed enough, the player will have control over the animal
											HelperMessageID = 4
											AnimalControlStatus = 0
											Animal.InControl = true
										end
									end
								end
							end
						
							if AnimalControlStatus <= 0.001 and not Animal.InControl then
								if HelperMessageID > 3 or HelperMessageID < 3 then
									DisplayHelpText("You've the lost your grip and fell off.") -- If [W] key is not pressed enough, the player will have no control over the animal and fall off
									HelperMessageID = 3
								end
								DropPlayerFromAnimal()
							end
							
							if not Animal.IsFleeing then
								Animal.IsFleeing = true
								TaskSmartFleePed(Animal.Handle, Ped, 9000.0, -1, false, false)
							end
						end
					end
				end
			end
		end
		end
	end
end)