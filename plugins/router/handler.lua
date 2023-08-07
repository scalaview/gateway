local response     = require "lib.response"
local utils            = require "lib.tools.utils"
local ngx_log      = ngx.log
local ngx_timer_at = ngx.timer.at
local ngx_ERR      = ngx.ERR
local pairs        = pairs
local singletons   = require "config.singletons"
local tostring     = tostring
local tonumber     = tonumber
local next         = next
local type         = type
local ngx_re_sub   = ngx.re.sub
local ngx_re_match = ngx.re.match
local string_len   = string.len
local ngx_HTTP_OK  = ngx.HTTP_OK
local ngx_print    = ngx.print
local ngx_exit     = ngx.exit
local plugin       = require "plugins.base_plugin"
local router       = require "plugins.router.service"

local RouteHandler  = plugin:extend()
local RouterService = router:new()

local function match_api(curapi, baseapis)
    if not curapi or type(curapi) ~= "string" or string_len(curapi) <= 0 then
        return nil
    end
    if not baseapis or type(baseapis) ~= "table" or next(baseapis) == nil then
        return nil
    end
    ngx_log(ngx_ERR, "curapi: ", curapi, " baseapis: ", utils.dump(baseapis))
    local apiinfo
    for k, v in pairs(baseapis) do
        local s = ngx_re_match(curapi, k .. '$', "jo")
        if s ~= nil then
            ngx_log(ngx_ERR, "ngx_re_match success: ", curapi, " res: ", utils.dump(s))
            apiinfo = v
            apiinfo['rewrite_url'] = ngx_re_sub(curapi, k, v['path'])
            break
        end
    end
    return apiinfo
end

local function get_api(ctx)
    local apiinfo
    if ctx.backend_name and ctx.method and ctx.version and ctx.path then
        local routerkey = tostring(ctx.method) .. "/" .. tostring(ctx.version) .. "/" .. tostring(ctx.path)
        local routerapis = RouterService:get_config_by_backendname(ctx.backend_name)
        apiinfo = match_api(routerkey, routerapis)
    end
    return apiinfo
end

function RouteHandler:new()
    RouteHandler.super.new(self, "router")
end

function RouteHandler:init_worker()
    if ngx.worker.id() == 0 then
        local ok, err = ngx_timer_at(0, function(premature)
            RouterService:init_config()
        end)
        if not ok then
            ngx_log(ngx_ERR, "failed to create the timer: ", err)
            return
        end
    end
end

function RouteHandler:access(ctx)
    if ctx.method == 'OPTIONS' then
        return response:success():response()
    end

    if ctx.version == nil then
        ctx.version = 'v1'
    end

    local apiinfo = get_api(ctx)
    if not apiinfo then
        return response:error(404, "Not Found"):response()
    end

    if tonumber(apiinfo["api_id"]) <= 0 then
        if apiinfo["response_type"] == 1 then
            ngx.header.Content_Type = "application/json"
        else
            ngx.header.Content_Type = "text/html"
        end
        ngx_print(apiinfo["response_text"])
        ngx_exit(ngx_HTTP_OK)
    end
    if ctx.client_network == 1 and apiinfo['network'] == 2 then
        return response:error(403, "Forbidden"):response()
    end
    ngx_log(ngx_ERR, "rewrite_url: ", apiinfo["rewrite_url"])
    ngx.req.set_uri(apiinfo["rewrite_url"], false)
    local var = ngx.var
    if tonumber(apiinfo["is_cache"]) == 1 then
        var.no_cache = 0
    end
    var.upstream_request = apiinfo["rewrite_url"]
    var.route_path = apiinfo["route_path"]
    ctx.api = apiinfo
end

return RouteHandler

