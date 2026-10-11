--!strict
--[[
	Bottom-right corner of the spawn menu: how long this server has been up and the game
	version. The same two lines in both interfaces: this is the legacy screen.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(ReplicatedStorage.Client.UI.Legacy.Screens.Version)
