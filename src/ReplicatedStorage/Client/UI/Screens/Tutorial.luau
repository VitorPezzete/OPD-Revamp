--!strict
--[[
	Tutorial, opened from the spawn screen. A list of six chapters; each chapter is a set
	of pages with previous / next arrows and its own camera shot of the map
	(ReplicatedStorage.Assets.Models.World.TutorialParts.<part>.CFrame).

	The bottom button reads "Back" inside a chapter and "Main Menu" on the list, where it
	closes the tutorial. The chapters borrow the camera: with a character alive it is
	handed back on close; on the spawn screen the Load screen takes it again by itself.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type Chapter = { Title: string, Part: string, Pages: { string } }

local MENU_PART = "Start"

local CHAPTERS: { Chapter } = {
	{
		Title = "Basics and Training",
		Part = "A_Basics",
		Pages = {
			"You will have your Melee attack unlocked by default when starting. As you use your Melee attack you will gain experience and eventually unlock new attacks.",
			"When you unlock or meet the requirements of a new attack, you can find your attacks and abilities in your Talents menu.",
			"You should spend some time looking at the menu. You can see your stats, abilities, and customize your character!",
			"As you progress you may find that you want to optimize your play style. You can find keybinds in the Settings menu.",
		},
	},
	{
		Title = "Stats",
		Part = "B_Stats",
		Pages = {
			"Swinging your fists, shooting a gun, slashing a sword, or getting punched in the face! These can all give experience.",
			"A successful action with a weapon can result in gaining experience with that weapon's attack type.",
			"You can find basic weapons at some merchant's shops. These are perfect for leveling up your stats!",
			"Some merchants sell drinks that give experience boosts, too! Kill enemies for money to buy drinks and increase your stats!",
		},
	},
	{
		Title = "Merchants",
		Part = "C_Merchants",
		Pages = {
			"If you want boats, quests, experience drinks, emotes, weapons and more then keep an eye out for merchants!",
			"Sam's quest takes a while to prepare, but you're guaranteed to get a Devil Fruit!",
			"Weapon merchants are scattered across multiple islands. Find them and you can buy swords or sniper weapons!",
			"Some merchants will only appear under special conditions. When you're strong enough, maybe you'll sense someone.",
			"You won't always need a boat, but if you're a Devil Fruit user then you might consider buying one. There are several boat merchants on multiple islands.",
		},
	},
	{
		Title = "Devil Fruits",
		Part = "D_DevilFruits",
		Pages = {
			"Devil Fruits grant strange powers to those who eat them. A person who eats a Devil Fruit is known as a Devil Fruit user.",
			"All Devil Fruits have a side effect when they are eaten: the Devil Fruit user becomes weak to water!",
			"When hunting for Devil Fruits you should talk to Sam. Talk to Sam when his quest is ready and he will give you a compass!",
			"While activating your compass, the red arrow will show you the way. Activate your compass while you're next to the spot it's pointing you towards to get your reward!",
			"A compass can give you 1 of 4 possible rewards: a common, uncommon, rare, or ultra rare box!",
			"Activate your Devil Fruit box to see what Devil Fruit is inside!",
		},
	},
	{
		Title = "Combat",
		Part = "E_Combat",
		Pages = {
			"Enemy NPCs and players will give bounty and money when you kill them.",
			"The amount of bounty and money that you get from killing something is based on the strength of your target.",
			"Some rewards can be unlocked by reaching a certain number of kills, or even achieving a high enough bounty!",
			"NPCs that you can find around the spawn islands are good for basic training.",
			"If your target is too powerful, consider getting stronger and coming back later.",
			"Basic stats have a maximum level of 500. Some stats will increase your maximum health, like Melee and Defense!",
		},
	},
	{
		Title = "Legendary Mode",
		Part = "F_Legendary",
		Pages = {
			"Legendary Mode is the promise of power to those who meet the requirements to unlock it.",
			"Players who have unlocked Legendary Mode are capable of eating two Devil Fruits. Be careful of these powerful players!",
			"To begin, you will need to be a Devil Fruit user with max stats, 10,000,000 bounty, and have an extra Devil Fruit with you to destroy.",
			"Bring the Devil Fruit to the hidden altar and place a Devil Fruit on the pedestal.",
			"Once completed it will reset your stats, money, Devil Fruit, and activate Legendary Mode.",
			"Players who have unlocked Legendary Mode may have a purple diamond next to their name on the player list.",
		},
	},
}

local WINDOW_SIZE = UDim2.fromOffset(600, 560)
-- Left of the screen, so the camera shot of the chapter stays visible.
local EDGE_MARGIN = 80
local FOOTER_HEIGHT = 48
local CHAPTER_HEIGHT = 54
local ARROW_SIZE = UDim2.fromOffset(FOOTER_HEIGHT, FOOTER_HEIGHT)

local warned = false

-- ReplicatedStorage.Assets.Models.World.TutorialParts: one camera part per chapter.
local function getParts(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local world = models and models:FindFirstChild("World")
	return world and world:FindFirstChild("TutorialParts")
end

local function lookFrom(partName: string)
	local camera = Workspace.CurrentCamera
	local folder = getParts()
	local part = folder and folder:FindFirstChild(partName)
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if part and part:IsA("BasePart") then
		camera.CFrame = part.CFrame
	elseif not warned then
		warned = true
		warn(`[Tutorial] Assets.Models.World.TutorialParts.{partName} is missing: camera left where it is`)
	end
end

return {
	-- On a phone the engine's tool bar would be drawn over this window (UIController).
	HidesHotbar = true,
	Mount = function(scope: Scope, _gui: any, context: any)
		-- The chapters move the camera. With a character alive, hand it back on close;
		-- on the spawn screen the Load screen takes it again by itself.
		table.insert(scope, function()
			local camera = Workspace.CurrentCamera
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if camera and humanoid then
				camera.CameraSubject = humanoid
				camera.CameraType = Enum.CameraType.Custom
			end
		end)

		-- Index of the chapter being read, nil on the chapter list.
		local viewing: Fusion.Value<number?> = scope:Value(nil :: number?)
		local page = scope:Value(1)

		local chapter = scope:Computed(function(use): Chapter?
			local index = use(viewing)
			return if index then CHAPTERS[index] else nil
		end)
		local reading = scope:Computed(function(use): boolean
			return use(viewing) ~= nil
		end)
		local pageCount = scope:Computed(function(use): number
			local current = use(chapter)
			return if current then #current.Pages else 0
		end)

		local chapterButtons: { any } = {}
		for index, entry in CHAPTERS do
			table.insert(
				chapterButtons,
				UI.Button(scope, {
					Name = entry.Part,
					Text = entry.Title,
					Variant = "Secondary",
					Size = UDim2.new(1, 0, 0, CHAPTER_HEIGHT),
					LayoutOrder = index,
					OnClick = function()
						page:set(1)
						viewing:set(index)
						lookFrom(entry.Part)
					end,
				})
			)
		end

		lookFrom(MENU_PART)

		local contentSize = UDim2.new(1, 0, 1, -(FOOTER_HEIGHT + Theme.Space.M))

		return UI.Screen(scope, {
			Name = "Tutorial",
			DisplayOrder = 30,
			Children = {
				UI.Window(scope, {
					Title = scope:Computed(function(use): string
						local current = use(chapter)
						return if current then current.Title else "Tutorial"
					end),
					Subtitle = scope:Computed(function(use): string
						return if use(reading) then `{use(page)} / {use(pageCount)}` else ""
					end),
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, EDGE_MARGIN, 0.5, 0),
					Size = WINDOW_SIZE,
					OnClose = context.Close,
					Children = {
						UI.Stack(scope, {
							Name = "Main",
							Size = contentSize,
							Gap = Theme.Space.S,
							Visible = scope:Computed(function(use): boolean
								return not use(reading)
							end),
							Children = chapterButtons,
						}),

						UI.Panel(scope, {
							Name = "Pages",
							Size = contentSize,
							Color = Theme.Colors.Sunken,
							Padding = Theme.Space.L,
							Gradient = false,
							Visible = reading,
							Children = {
								UI.Label(scope, {
									Name = "Page",
									Text = scope:Computed(function(use): string
										local current = use(chapter)
										return if current then current.Pages[use(page)] or "" else ""
									end),
									Variant = "Heading",
									Font = Theme.Fonts.Body,
									Wrapped = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Top,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),

						UI.Button(scope, {
							Name = "MainMenuButton",
							Text = scope:Computed(function(use): string
								return if use(reading) then "Back" else "Main Menu"
							end),
							Variant = "Secondary",
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
							Size = UDim2.fromOffset(200, FOOTER_HEIGHT),
							OnClick = function()
								if Fusion.peek(viewing) then
									viewing:set(nil)
									lookFrom(MENU_PART)
								else
									context.Close()
								end
							end,
						}),
						UI.Button(scope, {
							Name = "Next",
							Text = ">",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.fromScale(1, 1),
							Size = ARROW_SIZE,
							Visible = reading,
							Disabled = scope:Computed(function(use): boolean
								return use(page) >= use(pageCount)
							end),
							OnClick = function()
								page:set(math.min(math.max(1, Fusion.peek(pageCount)), Fusion.peek(page) + 1))
							end,
						}),
						UI.Button(scope, {
							Name = "Previous",
							Text = "<",
							Variant = "Secondary",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.new(1, -(FOOTER_HEIGHT + Theme.Space.S), 1, 0),
							Size = ARROW_SIZE,
							Visible = reading,
							Disabled = scope:Computed(function(use): boolean
								return use(page) <= 1
							end),
							OnClick = function()
								page:set(math.max(1, Fusion.peek(page) - 1))
							end,
						}),
					},
				}),
			},
		})
	end,
}
