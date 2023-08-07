local pool          = require "lib.core.db"
local ngx_cache     = require "lib.cache"
local singletons    = require "config.singletons"
local cjson         = require "cjson"
local pl_stringx    = require "pl.stringx"
local tonumber      = tonumber
local setmetatable  = setmetatable
local ipairs        = ipairs
local next          = next
local type          = type
local ngx_log       = ngx.log
local ngx_DEBUG     = ngx.DEBUG
local ngx_ERR       = ngx.ERR
local string_format = string.format
local string_len    = string.len
local string_split  = pl_stringx.split
local table_insert  = table.insert
local utils            = require "lib.tools.utils"

local _M = {}

function _M:new()
    local instance = {}
    instance.db = pool:new()
    instance.cachekey = "projects"
    setmetatable(instance, {
        __index = self
    })
    return instance
end

function _M:init_config()
    local servers = {
            {
                domain = "pay-server-api",
                backend_name = "pay-server",
                servers = {
                    {
                        port = 80,
                        host = "172.22.0.3"
                    },
                    {
                        port = 80,
                        host = "172.22.0.5"
                    },
                    {
                        port = 80,
                        host = "172.22.0.6"
                    }
                }
            },
            {
                domain = "pay-core-api",
                backend_name = "pay-core",
                servers = {
                    {
                        port = 80,
                        host = "172.22.0.4"
                    }
                }
            }
        }
    for _, server in ipairs(servers) do
        ngx_log(ngx_ERR, "server: ", utils.dump(server))
        local success, error = ngx_cache:set(self.cachekey, server.backend_name, server)
        ngx_log(ngx_DEBUG, string_format("CREATE PROJECT SETTING [%s] status:%s error:%s", server.backend_name,
            success, error))
    end
    return true
end

function _M:get_config_by_backendname(backendname)
    if not backendname or type(backendname) ~= "string" and string_len(backendname) <= 0 then
        return nil
    end
    local projectconf = ngx_cache:get(self.cachekey, backendname)
    if not projectconf then
        local succ = self:init_config()
        if succ then
            projectconf = ngx_cache:get(self.cachekey, backendname)
        end
    end
    return projectconf
end


return _M
