local timer = require('timer')
local class = require('class')
local enums = require('enums')
local Emitter = require('utils/Emitter')
local Snowflake = require('containers/abstract/Snowflake')

local setTimeout, clearTimeout = timer.setTimeout, timer.clearTimeout

local Collector, get = class('Collector', Emitter)

function Collector:__init(message, type, timeout, filter, interaction_mode)
  self._listeners = {}
  self._message = assert(message, 'Missing Parent class')
  self._client = message.client
  self._type = assert(type, 'Missing component type') 
  self._timeout = timeout
  self._timeout_check = nil
  self._filter = filter or function() return true end
  self._fn = nil
  self._inter_mode = interaction_mode
  self:_checkValid()
  self:_setupEvents()
end

function Collector:_checkValid()
  assert(
    #self._message._components > 0,
    'Cannot wait for components on a message that does not even contain any components'
	)
	if not self._inter_mode then
    assert(
      self._message.author.id == self._message.client.user.id,
      'Cannot wait for components on a message not owned by this bot client'
    )
	end
end

function Collector:_setupEvents()
  self._fn = self:_listenerGenerate()
  self._client:on('interactionCreate', self._fn)

  if type(self._timeout) == 'number' then
    self:_setupTimeout()
  end
end

function Collector:_listenerGenerate()
  return function (inter)
    local componentType = enums.componentType
    local typ = type(self._type) == 'number' and self._type or componentType[self._type]
    local is_pass_type = typ == inter.data.component_type
    local is_pass_filter = self._filter(inter)
    if is_pass_type and is_pass_filter then
      self:emit('collect', inter, self)
    end
  end
end

function Collector:_setupTimeout()
  self._timeout_check = setTimeout(self._timeout, function ()
    self:stop()
    clearTimeout(self._timeout_check)
	end)
end

function Collector:stop()
  self._client:removeListener('interactionCreate', self._fn)
  self:removeAllListeners()
  self:emit('end')
end

--[=[@p parent Container/Client The parent object of to which this container is
a child. For example, the parent of a role is the guild in which the role exists.]=]
function get.message(self)
	return self._message
end

function get.type(self)
	return self._type
end

function get.timeout(self)
	return self._timeout
end

function get.filter(self)
	return self._filter
end

return Collector
