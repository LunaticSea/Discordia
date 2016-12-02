local opus = require('../opus')
local sodium = require('../sodium')
local ffi = require('ffi')

local Buffer = require('../utils/Buffer')
local Emitter = require('../utils/Emitter')
local VoiceSocket = require('./VoiceSocket')

local Encoder = opus.Encoder
local encrypt = sodium.encrypt

local VoiceClient = class('VoiceClient', Emitter)

function VoiceClient:__init()
	Emitter.__init(self)
	self._encoder = Encoder(48000, 2)
	self._voice_socket = VoiceSocket(self)
	self._seq = 0
	self._timestamp = 0
	self._frame_size = 480
	local header = Buffer(12)
	local nonce = Buffer(24)
	header[0] = 0x80
	header[1] = 0x78
	self._header = header
	self._nonce = nonce
end

function VoiceClient:_prepare(udp, ip, port, ssrc)
	self._udp, self._ip, self._port, self._ssrc = udp, ip, port, ssrc
end

function VoiceClient:joinChannel(channel, selfMute, selfDeaf)
	local client = channel.client
	client._voice_client = self
	return client._socket:joinVoiceChannel(channel._parent._id, channel._id, selfMute, selfDeaf)
end

function VoiceClient:send(data)

	local header = self._header
	local nonce = self._nonce

	header:writeUInt16BE(2, self._seq)
	header:writeUInt32BE(4, self._timestamp)
	header:writeUInt32BE(8, self._ssrc)

	header:copy(nonce)

	self._seq = self._seq < 0xFFFF and self._seq + 1 or 0
	self._timestamp = self._timestamp < 0xFFFFFFFF and self._timestamp + self._frame_size or 0

	data = self._encoder:encode(data, self._frame_size, #data)
	local encrypted = encrypt(data, tostring(nonce), self._key)
	assert(data == sodium.decrypt(encrypted, tostring(nonce), self._key)) -- debug

	local len = #encrypted
	local packet = Buffer(12 + len)
	header:copy(packet)
	packet:writeString(12, encrypted, len)

	self._udp:send(tostring(packet), self._ip, self._port)

end

return VoiceClient