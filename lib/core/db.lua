local _M = {}
_M._VERSION = '0.01'

local mt = { __index = _M }

function _M.new(self, opts)
    return setmetatable({}, mt)
end

return _M
