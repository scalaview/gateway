local _M = {}
local cjson = require "cjson"
local env = require "config.env"

_M.code = {
    [404] = 'URL NOT FOUND',
    [601] = 'Incomplete Signature Parameters',
    [603] = 'URL Invalid',
    [604] = 'Invalid JSON',
    [605] = 'Secret Undefined',
    [609] = 'Signature Authentication Failed',
}

_M.debug = 1
_M.env = env.env
_M.mysql = env.mysql

function _M.log_info(info, flag)
    if flag == nil then
        flag = ''
    end
    if type(info) == 'table' then
        info = cjson.encode(info)
    end
    ngx.log(ngx.INFO, flag .. ':', info)
end

function _M.log_error(info, flag)
    if flag == nil then
        flag = ''
    end
    if type(info) == 'table' then
        info = cjson.encode(info)
    end

    ngx.log(ngx.ERR, flag .. ':', info)
end

return _M
