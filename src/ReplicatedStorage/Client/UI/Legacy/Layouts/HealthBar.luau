--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.HealthBar in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "HealthBar",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		-- legacy behaviour: LocalScript (LocalScript, 23 lines)
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				Position = UDim2.fromScale(0.35, 0),
				Size = UDim2.new(0.3, 0, 0, 36),
				Visible = false,
				[Children] = {
					scope:New("Frame")({
						Name = "HealthBar",
						BackgroundColor3 = Color3.fromRGB(17, 255, 0),
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Size = UDim2.fromScale(1, 1),
						-- legacy behaviour: ClientHealthBar (LocalScript, 95 lines)
					}),
					scope:New("TextLabel")({
						Name = "Label",
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						ClipsDescendants = true,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Size = UDim2.fromScale(1, 1),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0,
						TextWrapped = true,
						ZIndex = 3,
					}),
					scope:New("ImageLabel")({
						Name = "SysFail",
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://1915498085",
						ImageTransparency = 0.6,
						Position = UDim2.fromOffset(-25, 0),
						Size = UDim2.fromOffset(20, 20),
						Visible = false,
						-- legacy behaviour: ClientSysFail (LocalScript, 31 lines)
					}),
					scope:New("Frame")({
						Name = "Haki",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.fromScale(1, 0.3),
						Visible = false,
						-- legacy behaviour: Message (LocalScript, 18 lines)
						[Children] = {
							scope:New("Frame")({
								BackgroundColor3 = Color3.fromRGB(127, 0, 255),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Size = UDim2.fromScale(1, 1),
								-- legacy behaviour: LocalScript (LocalScript, 91 lines)
								-- legacy state not exported: Min (IntValue)
								-- legacy state not exported: Max (IntValue)
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Status",
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Position = UDim2.fromScale(0.512, 1.35),
						Size = UDim2.fromScale(1, 1),
						SizeConstraint = Enum.SizeConstraint.RelativeXX,
						[Children] = {
							scope:New("UIGridLayout")({
								CellPadding = UDim2.fromScale(0.025, 0.025),
								CellSize = UDim2.fromScale(0.1, 0.1),
								FillDirectionMaxCells = 10,
								SortOrder = Enum.SortOrder.LayoutOrder,
								-- legacy behaviour: StatusEffectsGUI (LocalScript, 402 lines)
								[Children] = {
									scope:New("Frame")({
										Name = "Effect",
										BackgroundColor3 = Color3.fromRGB(178, 192, 255),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Size = UDim2.fromScale(1, 1),
										-- legacy behaviour: StatusEffectClient (LocalScript, 9 lines)
										[Children] = {
											scope:New("ImageLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.45,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												Position = UDim2.fromScale(0.5, 0.5),
												Size = UDim2.new(1, -2, 1, -2),
											}),
											scope:New("TextLabel")({
												Name = "Label",
												AnchorPoint = Vector2.new(0.5, 0),
												BackgroundColor3 = Color3.fromRGB(28, 32, 38),
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
												Position = UDim2.fromScale(0.5, 1),
												Size = UDim2.fromScale(5, 0.5),
												Text = "Label",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												Visible = false,
											}),
										},
									}),
								},
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Imagery",
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0, -5),
						Size = UDim2.fromScale(1, 1),
						[Children] = {
							scope:New("ImageLabel")({
								Name = "UsingVenomDemon",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458457803",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "SnowTouched",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458456756",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingVenomBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458457279",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "SnowFlying",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458456227",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingSnowBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458455595",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "VenomDoT",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458451134",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "SmeltBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458454931",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "OpeSevered",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458454230",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "RumbleStun",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458453686",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Revived",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5823555324",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Returned",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458452760",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Projecting",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458452155",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Possessed",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458451664",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingBarrierBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458437181",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Negative",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458450565",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Mored",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458450052",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "BurnMagmaOverTime",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458449558",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingMagmaBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458448667",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "LoveStunned",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458448204",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingObs",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458447529",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "ChillyPunched",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458447034",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Hobbied",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458444584",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "HeartStolen",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458443862",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingGear2nd",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458442813",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "GasAirless",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458442314",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "GasPoison",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458442314",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "BurnOverTime",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458441699",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "DiamondBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458440874",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "DarkCharge",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458440145",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingClearBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458439649",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingCandyBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458438175",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "UsingHaki",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458437751",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "SanguineVampiris",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5644211707",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "CandyTouched",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5688145965",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "DF_Disabled",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5688146386",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "HotBody",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5688146718",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "VoidStone",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5688147081",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "HypnosisOnCooldown",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5819589244",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Cheshire",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=9200736710",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "InsideCage",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
							}),
							scope:New("ImageLabel")({
								Name = "LightningSlash",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=5458437751",
								Size = UDim2.fromOffset(100, 100),
							}),
							scope:New("ImageLabel")({
								Name = "Concentrate",
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "rbxassetid://101017178910451",
								Size = UDim2.fromOffset(100, 100),
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Ilmagery",
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0, -5),
						Size = UDim2.fromScale(1, 1),
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Shield",
						BackgroundColor3 = Color3.fromRGB(0, 234, 255),
						Position = UDim2.fromScale(0.8986, 0),
						Size = UDim2.fromScale(0, 1),
					}),
				},
			}),
		},
	}) :: any
end
