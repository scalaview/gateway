local setmetatable  = setmetatable
local pool          = require "lib.core.db"
local ngx_cache     = require "lib.cache"
local tonumber      = tonumber
local tostring      = tostring
local ipairs        = ipairs
local next          = next
local type          = type
local ngx_log       = ngx.log
local ngx_DEBUG     = ngx.DEBUG
local ngx_ERR       = ngx.ERR
local string_format = string.format
local string_len    = string.len
local ngx_re_find   = ngx.re.find
local ngx_re_gsub   = ngx.re.gsub
local utils            = require "lib.tools.utils"

local _M = {}

function _M:new()
    local instance = {}
    instance.db = pool:new()
    instance.cachekey = "routes"
    setmetatable(instance, {
        __index = self
    })
    return instance
end

function _M:init_config()
    local projects = {
        {
            id = 1,
            backend_name = "pay-server"
        },
        {
            id = 2,
            backend_name = "pay-core"
        }
    }
    if projects and next(projects) then
        for _, project in ipairs(projects) do
            local apis = self:get_apis_by_projectid(project.id)
            ngx_log(ngx_ERR, "apis: ", utils.dump(apis))
            if apis and next(apis) then
                local succ, err = ngx_cache:set(self.cachekey, project.backend_name, apis)
                ngx_log(ngx_DEBUG, string_format("CREATE ROUTER API [%s] status:%s error:%s", project.backend_name,
                    succ, err))
            end
        end
    end
    return true
end

function _M:get_apis_by_projectid(projectid)
    local routersmap = {}
    if projectid and tonumber(projectid) > 0 then

        local routers = {
            {
                api_id = 1,
                upstream_url = "pay-server-api:80",
                network = 1,
                is_auth = 1,
                is_sign = 1,
                is_cache = 0,
                try_times = 3,
                timeout = 3,
                response_type= 1, -- 1:json, 0:html
                method = "POST",
                version = "v1",
                server_path = "/payments",
                path = "/pay/payments"
            },
            {
                api_id = 2,
                upstream_url = "pay-core-api:80",
                network = 1,
                is_auth = 1,
                is_sign = 1,
                is_cache = 0,
                try_times = 3,
                timeout = 3,
                response_type= 1, -- 1:json, 0:html
                method = "POST",
                version = "v1",
                server_path = "/payments",
                path = "/pay/payments"
            }
        }
        if routers and next(routers) then
            local customparamnum = 0
            local customparamrep = function(m)
                customparamnum = customparamnum + 1
                return "$" .. tostring(customparamnum)
            end
            for _, router in ipairs(routers) do
                local apppath = router['server_path']
                local routerkey = tostring(router["method"]) .. "/" .. tostring(router["version"])
                local pathcustomparams = ngx_re_find(router['path'], "({[a-z_]+})", "jo")
                if pathcustomparams then
                    local gatewaypath = ngx_re_gsub(router['path'], "{[a-z_]+}", "(.+)")
                    apppath = ngx_re_gsub(router['server_path'], "{[a-z_]+}", customparamrep)
                    routerkey = tostring(routerkey) .. tostring(gatewaypath)
                    customparamnum = 0
                else
                    routerkey = tostring(routerkey) .. tostring(router['path'])
                end
                local routervals = {
                    path          = apppath,
                    route_path    = router['path'],
                    is_auth       = router['is_auth'],
                    network       = router['network'],
                    is_sign       = router['is_sign'],
                    method        = router['method'],
                    timeout       = router['timeout'],
                    is_cache      = router['is_cache'],
                    try_times     = router['try_times'],
                    upstream_url  = router['upstream_url'],
                    response_type = router['response_type'],
                    response_text = router['response_text'] or {},
                    api_id   = router['api_id']
                }
                routersmap[routerkey] = routervals
            end
        end
    end
    return routersmap
end

function _M:get_config_by_backendname(backendname)
    if not backendname or type(backendname) ~= "string" and string_len(backendname) <= 0 then
        return nil
    end
    local routerapis = ngx_cache:get(self.cachekey, backendname)
    if not routerapis then
        local succ = self:init_config()
        if succ then
            routerapis = ngx_cache:get(self.cachekey, backendname)
        end
    end
    return routerapis
end

return _M
