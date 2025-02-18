--[[
  This is not injected into Discordia, and only used by the modules in this tree.
--]]

local enums = require('enums')
local class = require('class')
local classes = class.classes
local buttonStyle = enums.buttonStyle
local componentType = enums.componentType

local isInstance = class.isInstance

local resolver = {}

function resolver.buttonStyle(style)
	local t = type(style)
	if t == 'string' then
		return buttonStyle[style]
	elseif t == 'number' then
		return style
	end
end

function resolver.emoji(
emoji,
	id,
	animated -- Partial emoji object
)
	emoji = type(emoji) == 'table' and emoji or {
		id = id,
		name = emoji,
		animated = animated,
	}
	assert(type(emoji.name) == 'string', 'an emoji object must at least contain a string name field')
	return {
		id = emoji.id,
		name = emoji.name,
		animated = emoji.animated,
	}
end

function resolver.rawComponents(comp)
	if isInstance(comp, classes.Components) then
		return comp:raw()
	elseif isInstance(comp, classes.Component) then
		return { -- Auto-wrap the component in an Action Row
		{
			type = componentType.actionRow,
			components = { comp:raw() },
		} }
	elseif #comp > 0 then	  
	  local res = {}

	  for _, s_comp in pairs(comp) do
	    if s_comp.raw then table.insert(res, s_comp:raw()[1])
	    else table.insert(res, s_comp) end
	  end

	  return res
	end
end

function resolver.objComponents(data)
	local bases =
		{
			nil,
			classes.Button,
			classes.SelectMenu,
			nil,
			classes.SelectUserMenu,
			classes.SelectRoleMenu,
			classes.SelectMentionMenu,
			classes.SelectChannelMenu,
		}
	local instance, cell = classes.Components(), nil
	for c = 1, #data do
		cell = data[c]
		if type(cell) ~= 'table' then return end -- definitely an invalid component
		local cell_type = type(cell.type) == 'number' and cell.type or componentType[cell.type]
		if bases[cell_type] then
			instance:_buildComponent(bases[cell_type], cell)
		end
	end
	return instance
end

return resolver
