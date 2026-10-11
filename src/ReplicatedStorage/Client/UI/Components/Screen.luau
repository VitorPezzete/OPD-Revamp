--!strict
--[[
	The ScreenGui of a screen. UIController enables, scales and parents it.

		return UI.Screen(scope, { Name = "Storage", DisplayOrder = 5, Children = { ... } })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Props = {
	Name: string,
	DisplayOrder: number?,
	-- True for full-screen pieces (backdrops, the spawn screen) that go under the top bar.
	IgnoreGuiInset: boolean?,
	Children: Fusion.Child?,
}

return function(scope: Scope, props: Props): ScreenGui
	return scope:New("ScreenGui")({
		Name = props.Name,
		DisplayOrder = props.DisplayOrder or 0,
		IgnoreGuiInset = props.IgnoreGuiInset or false,
		ResetOnSpawn = false,
		[Fusion.Children] = props.Children,
	}) :: any
end
