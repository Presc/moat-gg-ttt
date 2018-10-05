local WriteBool, ReadBool, WriteBit = net.WriteBool, net.ReadBool, net.WriteBit
local ReadString, WriteString = net.ReadString, net.WriteString
local WriteVector, ReadVector = net.WriteVector, net.ReadVector
local Start, Broadcast = net.Start, SERVER and net.Broadcast
local WriteFloat, ReadFloat = net.WriteFloat, net.ReadFloat
local WriteAngle, ReadAngle = net.WriteAngle, net.ReadAngle
local WriteUInt, ReadUInt = net.WriteUInt, net.ReadUInt
local Send = SERVER and net.Send or net.SendToServer
local WriteInt, ReadInt = net.WriteInt, net.ReadInt
local TickInterval = engine.TickInterval()
local BytesLimit = 30000 * TickInterval
local BytesWritten = net.BytesWritten
local Simple = timer.Simple
local IsValid = IsValid
local Entity = Entity

----
-- Register the global types
----

local Globals = {}
local Lookup = {Count = 0}
local Internal = {Count = 0}

local function RegisterGlobalClass(name, write, read, valid)
	Lookup.Count = Lookup.Count + 1

	local data = {ID = Lookup.Count, Name = name, Stored = {}}
	data.Write = function(var) return write(var) end
	data.Read = function() return read() end
	data.Valid = type(valid) == "string" and function(var) 
		return type(var) == valid 
	end or function(var) return valid[type(var)] end

	Globals[name] = data

	Lookup[Lookup.Count] = name
	Lookup[name] = Lookup.Count
end

-- SetGlobalAngle/GetGlobalAngle
RegisterGlobalClass("Angle", WriteAngle, ReadAngle, "Angle")

-- SetGlobalBool/GetGlobalBool
RegisterGlobalClass("Bool", WriteBool, ReadBool, {["boolean"] = true, ["nil"] = true})

-- SetGlobalEntity/GetGlobalEntity
RegisterGlobalClass("Entity", function(var) 
	return WriteUInt(IsValid(var) and var:EntIndex() or 0, 12) 
end, function(var) return Entity(ReadUInt(12) or -1) end, {["Entity"] = true, ["Player"] = true})

-- SetGlobalFloat/GetGlobalFloat
RegisterGlobalClass("Float", WriteFloat, ReadFloat, "number")

-- SetGlobalInt/GetGlobalInt
RegisterGlobalClass("Int", function(var) 
	return WriteInt(var, 32) end, 
function() return ReadInt(32) end, "number")

-- SetGlobalString/GetGlobalString
RegisterGlobalClass("String", WriteString, ReadString, "string")

-- SetGlobalVector/GetGlobalVector
RegisterGlobalClass("Vector", WriteVector, ReadVector, "Vector")


----
-- Begin our detours
----

if (SERVER) then
	util.AddNetworkString "LoadGlobalVariables"
	for kind, _ in pairs(Globals) do
		util.AddNetworkString("SetGlobal" .. kind)
	end

	local function CreateGlobalVariable(kind, key, val, int)
		Internal.Count = Internal.Count + 1
		Internal[Internal.Count] = {Kind = kind, Key = key, Value = val}

		Globals[kind].Stored[key] = {Value = val}
		Globals[kind].Stored[key].Index = Internal.Count
	end

	local function UpdateGlobalVariable(kind, key, val)
		if (Globals[kind].Stored[key].Value == val) then
			return
		end

		Globals[kind].Stored[key].Value = val
		Internal[Globals[kind].Stored[key].Index].Value = val
		
		Start("SetGlobal" .. kind)
			WriteString(key)
			Globals[kind].Write(val)
		Broadcast()
	end

	local function SetGlobalVariable(kind, key, val, int)
		assert(Globals[kind].Valid(val), "Attempt to call SetGlobal" .. kind .. " with an invalid data type!")
		if (Globals[kind].Stored[key] == nil) then
			return CreateGlobalVariable(kind, key, val, int)
		end

		return UpdateGlobalVariable(kind, key, val, int)
	end

	function SetGlobalAngle(key, val)
		SetGlobalVariable("Angle", key, val)
	end

	function SetGlobalBool(key, val)
		SetGlobalVariable("Bool", key, val)
	end

	function SetGlobalEntity(key, val)
		SetGlobalVariable("Entity", key, val)
	end

	function SetGlobalFloat(key, val)
		SetGlobalVariable("Float", key, val)
	end

	function SetGlobalInt(key, val)
		SetGlobalVariable("Int", key, val)
	end

	function SetGlobalString(key, val)
		SetGlobalVariable("String", key, val)
	end

	function SetGlobalVector(key, val)
		SetGlobalVariable("Vector", key, val)
	end

	----
	-- Sync globals for new players super fast
	----

	local function SendGlobalVariables(int, data, args)
		int = int or 1

		if (not data[int]) then return end
		if (not args.check(data[int], int)) then 
			int = int + 1 
			return SendGlobalVariables(int, data, args) 
		end

		args.start(int, data[int])
			while (data[int]) do
				if (not args.check(data[int], int)) then int = int + 1 continue end

				WriteBit(1)
				args.write(data[int], int)

				int = int + 1

				if (BytesWritten() >= BytesLimit) then
					Simple(0, function() SendGlobalVariables(int, data, args) end)
					break
				end
			end
			WriteBit(0)
		args.send(int, BytesWritten() >= BytesLimit)
	end

	net.Receive("LoadGlobalVariables", function(_, pl)
		if (pl.HasGlobalVariables) then return end
		pl.HasGlobalVariables = true

		SendGlobalVariables(1, Internal, {
			start = function(int)
				Start "LoadGlobalVariables"
			end,
			write = function(var)
				WriteUInt(Globals[var.Kind].ID, 3)
				WriteString(var.Key)
				Globals[var.Kind].Write(var.Value)
			end,
			send = function() net.Send(pl) end,
			check = function(var) return type(var.Value) ~= "nil" end
		})
	end)
else
	----
	-- Client receives globals from server
	----

	local function SetGlobalVariable(kind, key, val)
		Globals[kind].Stored[key] = val
	end

	for kind, info in pairs(Globals) do
		net.Receive("SetGlobal" .. kind, function()
			local key = ReadString()

			SetGlobalVariable(kind, key, info.Read())
		end)
	end

	net.Receive("LoadGlobalVariables", function()
		while (ReadBool()) do
			local kind = Lookup[ReadUInt(3)]
			local key = ReadString()
			local val = Globals[kind].Read()

			SetGlobalVariable(kind, key, val)
		end
	end)

	hook.Add("InitPostEntity", "LoadGlobalVariables", function()
		Start "LoadGlobalVariables" Send()
	end)
end

----
-- GetGlobal detours
----

local function GetGlobalVariable(kind, key, default)
	if (Globals[kind].Stored[key] == nil) then
		return default
	end

	if (CLIENT) then return Globals[kind].Stored[key] end
	return Globals[kind].Stored[key].Value
end

function GetGlobalAngle(key, default)
	return GetGlobalVariable("Angle", key, default)
end

function GetGlobalBool(key, default)
	return GetGlobalVariable("Bool", key, default)
end

function GetGlobalEntity(key, default)
	return GetGlobalVariable("Entity", key, default)
end

function GetGlobalFloat(key, default)
	return GetGlobalVariable("Float", key, default)
end

function GetGlobalInt(key, default)
	return GetGlobalVariable("Int", key, default)
end

function GetGlobalString(key, default)
	return GetGlobalVariable("String", key, default)
end

function GetGlobalVector(key, default)
	return GetGlobalVariable("Vector", key, default)
end