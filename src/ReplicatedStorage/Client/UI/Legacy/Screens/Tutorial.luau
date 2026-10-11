--!strict
--[[
	Tutorial (legacy Tutorial), opened from the spawn screen. A main list of six chapters;
	each chapter is a box of pages with previous / next arrows, "n / total" between them,
	and its own camera shot of the map
	(ReplicatedStorage.Assets.Models.World.TutorialParts.<part>.CFrame).

	The old look: a blue rounded box in the middle of the screen with the six chapters as
	blue buttons, the "Main Menu" button above it, and each chapter in a box of its own
	colour on the right of the screen (the shot of the map shows on the left): its title
	on a pill, the page, the arrows. Every box is a column now, so the buttons are evenly
	spaced and the title, page and arrows share one margin; the chapters are written once
	as data instead of six drawn copies.

	The top button reads "Back" inside a chapter and "Main Menu" on the list, where it
	closes the tutorial. The chapters borrow the camera: with a character alive it is
	handed back on close; on the spawn screen the Load screen takes it again by itself.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local ArrowButton = require(ReplicatedStorage.Client.UI.Legacy.Components.ArrowButton)
local GamepadWindow = require(ReplicatedStorage.Client.UI.Legacy.Components.GamepadWindow)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

type Chapter = {
	Letter: string,
	Title: string,
	-- Camera part of the chapter.
	Part: string,
	-- The rim of its box (also its title pill and arrows) and the inside.
	Rim: Color3,
	Inside: Color3,
	Pages: { string },
}

local CHAPTERS: { Chapter } = {
	{
		Letter = "A",
		Title = "Basics and Training",
		Part = "A_Basics",
		Rim = Color3.fromRGB(255, 114, 96),
		Inside = Color3.fromRGB(255, 181, 176),
		Pages = {
			"You will have your Melee attack unlocked by default when starting. As you use your Melee attack you will gain experience and eventually unlock new attacks.",
			"When you unlock or meet the requirements of a new attack, you can find your attacks and abilities in your Talents menu.",
			"You should spend some time looking at the menu. You can see your stats, abilities, and customize your character!",
			"As you progress you may find that you want to optimize your play style. You can find keybinds in the Settings menu.",
		},
	},
	{
		Letter = "B",
		Title = "Stats",
		Part = "B_Stats",
		Rim = Color3.fromRGB(255, 142, 62),
		Inside = Color3.fromRGB(255, 224, 192),
		Pages = {
			"Swinging your fists, shooting a gun, slashing a sword, or getting punched in the face! These can all give experience.",
			"A successful action with a weapon can result in gaining experience with that weapon's attack type.",
			"You can find basic weapons at some merchant's shops. These are perfect for leveling up your stats!",
			"Some merchants sell drinks that give experience boosts, too! Kill enemies for money to buy drinks and increase your stats!",
		},
	},
	{
		Letter = "C",
		Title = "Merchants",
		Part = "C_Merchants",
		Rim = Color3.fromRGB(234, 224, 71),
		Inside = Color3.fromRGB(255, 253, 183),
		Pages = {
			"If you want boats, quests, experience drinks, emotes, weapons and more then keep an eye out for merchants!",
			"Sam's quest takes a while to prepare, but you're guaranteed to get a Devil Fruit!",
			"Weapon merchants are scattered across multiple islands. Find them and you can buy swords or sniper weapons!",
			"Some merchants will only appear under special conditions. When you're strong enough, maybe you'll sense someone.",
			"You won't always need a boat, but if you're a Devil Fruit user then you might consider buying one. There are several boat merchants on multiple islands.",
		},
	},
	{
		Letter = "D",
		Title = "Devil Fruits",
		Part = "D_DevilFruits",
		Rim = Color3.fromRGB(77, 234, 87),
		Inside = Color3.fromRGB(176, 255, 167),
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
		Letter = "E",
		Title = "Combat",
		Part = "E_Combat",
		Rim = Color3.fromRGB(39, 234, 228),
		Inside = Color3.fromRGB(170, 255, 250),
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
		Letter = "F",
		Title = "Legendary Mode",
		Part = "F_Legendary",
		Rim = Color3.fromRGB(112, 36, 167),
		Inside = Color3.fromRGB(185, 149, 238),
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
local MENU_PART = "Start"
-- Over the spawn screen, like the rework's.
local DISPLAY_ORDER = 30

local PAGE_POP = TweenInfo.new(0.2, Enum.EasingStyle.Elastic)
local PAGE_SMALL = UDim2.fromScale(0.8, 0.8)
local PAGE_FULL = UDim2.fromScale(1, 1)

-- The old boxes on a 1920x1080 screen: 40% of the screen's height wide, 60% tall.
local BOX_SIZE = Vector2.new(408, 612)
local RIM = 15
local CORNER = 10
local MENU_RIM = Color3.fromRGB(73, 138, 234)
local MENU_INSIDE = Color3.fromRGB(179, 219, 255)
local CHAPTER_BUTTON = Vector2.new(302, 58)
local MENU_BUTTON = Vector2.new(306, 76)
local TITLE_HEIGHT = 40
local NAVIGATION_HEIGHT = 56
-- What the title, the arrows, the gaps and the padding leave of the inside of a box.
local PAGE_HEIGHT = BOX_SIZE.Y - 2 * RIM - 2 * Kit.Space.M - TITLE_HEIGHT - NAVIGATION_HEIGHT - 2 * Kit.Space.M

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

-- A rounded box of two colours: the rim and, inside it, a column of children.
local function box(
	scope: Scope,
	props: {
		Name: string,
		Position: UDim2,
		Rim: Color3,
		Inside: Color3,
		Visible: Fusion.UsedAs<boolean>,
		Gap: number,
		VerticalAlignment: Enum.VerticalAlignment?,
		Children: Fusion.Child,
	}
): Instance
	return Kit.Panel(scope, {
		Name = props.Name,
		Image = "",
		Color = props.Rim,
		Transparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = UDim2.fromOffset(BOX_SIZE.X, BOX_SIZE.Y),
		Visible = props.Visible,
		Children = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
			Kit.Panel(scope, {
				Name = "Frame",
				Image = "",
				Color = props.Inside,
				Transparency = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -2 * RIM, 1, -2 * RIM),
				Children = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
					Kit.Stack(scope, {
						Name = "Column",
						Size = UDim2.fromScale(1, 1),
						Gap = props.Gap,
						Padding = Kit.Space.M,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = props.VerticalAlignment or Enum.VerticalAlignment.Top,
						Children = props.Children,
					}),
				},
			}),
		},
	})
end

-- The box of a chapter. Returns it with the page it is on.
local function chapterBox(scope: Scope, chapter: Chapter, shown: Fusion.UsedAs<boolean>): (Instance, Fusion.Value<number>)
	local count = #chapter.Pages
	local current = scope:Value(1)

	local pages: { TextLabel } = {}
	for index, text in chapter.Pages do
		pages[index] = Kit.Label(scope, {
			Name = `Label{index}`,
			Text = text,
			TextSize = Kit.TextSize.Heading,
			TextYAlignment = Enum.TextYAlignment.Top,
			Fit = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = PAGE_FULL,
			Visible = scope:Computed(function(use): boolean
				return use(current) == index
			end),
		})
	end

	-- The page pops in from 80% of its size.
	scope:Observer(current):onChange(function()
		local page = pages[Fusion.peek(current)]
		if page then
			page.Size = PAGE_SMALL
			TweenService:Create(page, PAGE_POP, { Size = PAGE_FULL }):Play()
		end
	end)

	-- An arrow with nowhere to go is faded and takes neither clicks nor the gamepad.
	local atStart = scope:Computed(function(use): boolean
		return use(current) <= 1
	end)
	local atEnd = scope:Computed(function(use): boolean
		return use(current) >= count
	end)

	local built = box(scope, {
		Name = `Frame{chapter.Letter}`,
		-- On the right: the left of the screen is the chapter's shot of the map.
		Position = UDim2.fromScale(0.75, 0.5),
		Rim = chapter.Rim,
		Inside = chapter.Inside,
		Visible = shown,
		Gap = Kit.Space.M,
		Children = {
			Kit.Panel(scope, {
				Name = "Title",
				Image = "",
				Color = chapter.Rim,
				Transparency = 0,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
				LayoutOrder = 1,
				Children = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, CORNER) }),
					Kit.Label(scope, {
						Text = chapter.Title,
						TextSize = Kit.TextSize.Heading,
						Fit = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -2 * Kit.Space.M, 1, -Kit.Space.XS),
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Pages",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, PAGE_HEIGHT),
				LayoutOrder = 2,
				[Fusion.Children] = pages,
			}),
			Kit.Stack(scope, {
				Name = "Navigation",
				Direction = "Horizontal",
				Gap = Kit.Space.L,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				LayoutOrder = 3,
				Children = {
					ArrowButton(scope, {
						Name = "Arrow1",
						Direction = "Left",
						Color = chapter.Rim,
						Size = UDim2.fromOffset(NAVIGATION_HEIGHT, NAVIGATION_HEIGHT),
						LayoutOrder = 1,
						Disabled = atStart,
						OnClick = function()
							current:set(math.max(1, Fusion.peek(current) - 1))
						end,
					}),
					-- The old page counter was never filled in.
					Kit.Label(scope, {
						Name = "PageLabel",
						Text = scope:Computed(function(use): string
							return `{use(current)} / {count}`
						end),
						TextSize = Kit.TextSize.Button,
						Size = UDim2.fromOffset(120, NAVIGATION_HEIGHT),
						LayoutOrder = 2,
					}),
					ArrowButton(scope, {
						Name = "Arrow2",
						Direction = "Right",
						Color = chapter.Rim,
						Size = UDim2.fromOffset(NAVIGATION_HEIGHT, NAVIGATION_HEIGHT),
						LayoutOrder = 3,
						Disabled = atEnd,
						OnClick = function()
							current:set(math.min(math.max(1, count), Fusion.peek(current) + 1))
						end,
					}),
				},
			}),
		},
	})
	return built, current
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
		-- Chapter letter being read, nil on the chapter list.
		local viewing = scope:Value(nil :: string?)

		local children: { Instance } = {}
		local chapterButtons: { Instance } = {}
		for index, chapter in CHAPTERS do
			local built, current = chapterBox(
				scope,
				chapter,
				scope:Computed(function(use): boolean
					return use(viewing) == chapter.Letter
				end)
			)
			table.insert(children, built)

			table.insert(
				chapterButtons,
				Kit.Button(scope, {
					Name = chapter.Letter,
					Text = chapter.Title,
					Variant = "Blue",
					Size = UDim2.fromOffset(CHAPTER_BUTTON.X, CHAPTER_BUTTON.Y),
					LayoutOrder = index,
					OnClick = function()
						current:set(1)
						viewing:set(chapter.Letter)
						lookFrom(chapter.Part)
					end,
				})
			)
		end

		table.insert(
			children,
			box(scope, {
				Name = "Main",
				Position = UDim2.fromScale(0.5, 0.5),
				Rim = MENU_RIM,
				Inside = MENU_INSIDE,
				Gap = Kit.Space.XL,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Visible = scope:Computed(function(use): boolean
					return use(viewing) == nil
				end),
				Children = chapterButtons,
			})
		)

		table.insert(
			children,
			Kit.Button(scope, {
				Name = "MainMenuButton",
				Variant = "Blue",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.1),
				Size = UDim2.fromOffset(MENU_BUTTON.X, MENU_BUTTON.Y),
				Text = scope:Computed(function(use): string
					return if use(viewing) then "Back" else "Main Menu"
				end),
				OnClick = function()
					if Fusion.peek(viewing) then
						viewing:set(nil)
						lookFrom(MENU_PART)
					else
						context.Close()
					end
				end,
			})
		)

		local gui = Kit.Screen(scope, {
			Name = "Tutorial",
			DisplayOrder = DISPLAY_ORDER,
			Children = children,
		})
		-- Not one window but a button and a box at a time: the mark gives the gamepad the
		-- selection when the tutorial opens, and its B closes it like the rework's close button.
		GamepadWindow.mark(scope, gui, context.Close)

		lookFrom(MENU_PART)
		return gui
	end,
}
