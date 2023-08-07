local setmetatable  = setmetatable
local next          = next
local type          = type
local pairs         = pairs
local pool          = require "lib.core.db"
local ngx_cache     = require "lib.cache"
local ngx_log       = ngx.log
local ngx_ERR       = ngx.ERR
local ngx_DEBUG     = ngx.DEBUG
local string_format = string.format
local string_len    = string.len
local tostring      = tostring
local utils            = require "lib.tools.utils"

local _M = {}

function _M:new()
    local instance = {}
    instance.cachekey = "jwt-auth"
    setmetatable(instance, {
        __index = self
    })
    return instance
end

function _M:init_config()
    local secrets = {
        {
            project_name = "pay-server",
            secret_key = "juJ5o9zlMytDkQeLyblePuVNHaGge2",
            secret_alg = "HS256"
        },
        {
            project_name = "pay-core",
            secret_key = "7BE09C9CF8BB9D36C02351DA22C4A649",
            secret_alg = "HS256"
        }
    }

    if secrets and next(secrets) ~= nil then
        for _, secret in pairs(secrets) do
            local success, error = ngx_cache:set(self.cachekey, secret.project_name, secret)
            ngx_log(ngx_DEBUG, string_format("CREATE JWT SECRET [%s] status:%s error:%s", secret.project_name,
                success, error))
        end
    end
    return true
end

function _M:get_config_by_backendname(backendname)
    ngx_log(ngx_ERR, "backendname: ", backendname)
    if not backendname or type(backendname) ~= "string" or string_len(backendname) <= 0 then
        return nil
    end
    local jwtconf = ngx_cache:get(self.cachekey, backendname)
    if not jwtconf then
        local succ = self:init_config()
        if succ then
            jwtconf = ngx_cache:get(self.cachekey, backendname)
        end
    end
    return jwtconf
end

return _M
