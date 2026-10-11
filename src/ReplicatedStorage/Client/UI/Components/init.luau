--!strict
--[[
	The component kit of the interface. Every screen is built from these and from
	Client.UI.Theme; no screen creates styled instances by hand.

		local UI = require(ReplicatedStorage.Client.UI.Components)

		UI.Screen     ScreenGui of a screen
		UI.Window     titled panel with close button and padded body
		UI.Panel      rounded surface
		UI.Backdrop   full-screen dim layer behind dialogs
		UI.Confirm    message + two buttons
		UI.Stack      row / column layout          UI.Scroll   scrolling list or grid
		UI.Label      text                         UI.Image    image
		UI.Button     button                       UI.Tabs     one-of-many buttons
		UI.Card       picture + title tile         UI.Badge    small pill
		UI.ProgressBar                             UI.Divider
		UI.Toggle     UI.Slider     UI.TextInput
		UI.TouchButton   round see-through button of the touch controls

	Each component is (scope, props) -> Instance; its file documents the props. Props
	that may change take a Fusion state object or a plain value.
]]
return {
	Screen = require(script.Screen),
	Window = require(script.Window),
	Panel = require(script.Panel),
	Backdrop = require(script.Backdrop),
	Confirm = require(script.Confirm),
	Stack = require(script.Stack),
	Scroll = require(script.Scroll),
	Label = require(script.Label),
	Image = require(script.Image),
	Button = require(script.Button),
	Tabs = require(script.Tabs),
	Card = require(script.Card),
	Badge = require(script.Badge),
	ProgressBar = require(script.ProgressBar),
	Divider = require(script.Divider),
	Toggle = require(script.Toggle),
	Slider = require(script.Slider),
	TextInput = require(script.TextInput),
	TouchButton = require(script.TouchButton),
}
