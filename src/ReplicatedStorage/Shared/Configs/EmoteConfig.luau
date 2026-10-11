--!strict
--[[
	From StarterGui.Emotes in the legacy place.
	Marks: the 16 unlockable emotes (owned flags live in data.Emotes["CB_Mark<N>"]).
	Free: the basic emotes every player has; in the legacy GUI their buttons were only
	named by position, so they are listed in button order.
]]
local Marks: { string } = {
	"rbxassetid://105282027339125",
	"rbxassetid://93905002742221",
	"rbxassetid://139494631202407",
	"rbxassetid://118655776490780",
	"rbxassetid://112485810000456",
	"rbxassetid://120751595722616",
	"rbxassetid://124407655112621",
	"rbxassetid://108729318603372",
	"rbxassetid://78384998558719",
	"rbxassetid://115257027045251",
	"rbxassetid://89469657674562",
	"rbxassetid://110520694202608",
	"rbxassetid://123265953859015",
	"rbxassetid://111854424929299",
	"rbxassetid://97005596980882",
	"rbxassetid://76689800944619",
}

local Free: { string } = {
	"rbxassetid://130039618691878",
	"rbxassetid://91219050447805",
	"rbxassetid://122288598326469",
	"rbxassetid://97788197599153",
	"rbxassetid://94548477325164",
	"rbxassetid://133338153680802",
	"rbxassetid://615961416",
	"rbxassetid://108035740556742",
	"rbxassetid://105312579286643",
}

return table.freeze({
	Marks = table.freeze(Marks),
	Free = table.freeze(Free),
	-- Emotes only start while standing still on the ground.
	ButtonCooldown = 0.5,
})
