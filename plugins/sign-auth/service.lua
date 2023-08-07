local setmetatable = setmetatable
local next          = next
local pairs         = pairs
local type          = type
local pool          = require "lib.core.db"
local ngx_cache     = require "lib.cache"
local ngx_log       = ngx.log
local ngx_DEBUG     = ngx.DEBUG
local ngx_ERR       = ngx.ERR
local string_format = string.format
local string_len    = string.len
local tostring      = tostring
local utils            = require "lib.tools.utils"

local _M = {}

function _M:new()
    local instance = {}
    instance.db = pool:new()
    instance.cachekey = "sgin-auth"
    setmetatable(instance, {
        __index = self
    })
    return instance
end

function _M:init_config()
    local secrets = {
        {
            app_secret = "tghyriowaqubgnwoe",
            app_key = "tghyriowaqubgnwoe"
        },
        {
            app_secret = "DjHG1EDiK4CM6JfygFSavtv6lnP30NO5PcrMmDS6GNY",
            app_key = "abc"
        }
    }
    if secrets and next(secrets) ~= nil then
        for _, secret in pairs(secrets) do
            ngx_log(ngx_ERR, "secret: ", utils.dump(secret))
            local success, error = ngx_cache:set(self.cachekey, secret.app_key, secret)
            ngx_log(ngx_ERR, string_format("CREATE SIGN SECRET [%s] status:%s error:%s", secret.app_key,
                success, error))
        end
    end
    return true
end

function _M:get_config_by_appkey(appkey)
    if not appkey or type(appkey) ~= "string" or string_len(appkey) <= 0 then
        return nil
    end

    local secret = ngx_cache:get(self.cachekey, "abc")
    if not secret then
        local succ = self:init_config()
        if succ then
            secret = ngx_cache:get(self.cachekey, appkey)
        end
    end
    return secret.app_secret
end

return _M
