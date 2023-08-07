local env              = require "config.env"
local ipairs           = ipairs
local utils            = require "lib.tools.utils"
local singletons       = require "config.singletons"
local response         = require "lib.response"
local ngx_balancer     = require "ngx.balancer"
local get_last_failure = ngx_balancer.get_last_failure
local set_current_peer = ngx_balancer.set_current_peer
local set_timeouts     = ngx_balancer.set_timeouts
local set_more_tries   = ngx_balancer.set_more_tries
local tonumber         = tonumber
local ngx_re_match     = ngx.re.match
local string_format    = string.format
local table_insert     = table.insert
local ngx_log          = ngx.log
local ngx_DEBUG        = ngx.DEBUG
local ngx_ERR          = ngx.ERR
local ngx_WARN         = ngx.WARN

local enable_plugins = {
    'project',
    'router',
    'jwt-auth',
    'sign-auth',
    'cors',
}

local function loading_plugins(plugins, store)
    local load_plugins = {}
    for _, name in ipairs(plugins) do
        local plugin_path = string_format("plugins.%s.handler", name)
        local ok, plugin_handler = utils.load_module(plugin_path)
        if not ok then
            ngx_log(ngx_WARN, "The following plugin is not installed or has no handler: " .. name)
        else
            ngx_log(ngx_DEBUG, "Loading plugin: " .. name)
            table_insert(load_plugins, {
                name    = name,
                handler = plugin_handler(store),
            })
        end
    end
    return load_plugins
end

local plugins = {}

local _M = {}

function _M.init(options)
    options = options or {}
    singletons.config = env
    plugins = loading_plugins(enable_plugins)
end

function _M.init_worker()
    for _, plugin in ipairs(plugins) do
        plugin.handler:init_worker()
    end
end

function _M.rewrite()
    for _, plugin in ipairs(plugins) do
        plugin.handler:rewrite()
    end
end

function _M.access()
    local var = ngx.var
    local ctx = ngx.ctx
    local headers = ngx.req.get_headers()
    local gateway_path = var.uri
    local gateway_path_info = ngx_re_match(gateway_path, "/([a-z-0-9]+)/(.*)", "jo")
    if gateway_path_info == nil or gateway_path_info[1] == nil or gateway_path_info[2] == nil then
        return response:error(200, 'Welcome Used API Gateway System'):response()
    end

    headers.k_version = headers.k_version or 'v1'
    headers.k_platform = headers.k_platform or 'web'

    ctx.path = gateway_path_info[2]
    ctx.backend_name = gateway_path_info[1]
    ctx.method = var.request_method
    ctx.version = headers.k_version
    ctx.platform = headers.k_platform
    ctx.client_ip = utils.get_client_ip()
    ctx.client_network = 1
    ctx.api = {}
    ctx.upstream = {}
    if ctx.method == "POST" then
        ngx.req.read_body()
    end
    for _, plugin in ipairs(plugins) do
        plugin.handler:access(ctx)
    end
end

function _M.balancer()
    local ctx = ngx.ctx
    local upstream = ctx.upstream
    if not ctx.tries then
        ctx.tries = 0
    end
    local server_count = #upstream.servers
    if ctx.api.try_times > server_count then
        ctx.api.try_times = server_count - 1
    end
    if not ctx.hash then
        ctx.hash = 1
    end
    if ctx.tries > 0 then
        local state, code = get_last_failure()
        if ctx.hash >= server_count then
            ctx.hash = 1
        else
            ctx.hash = ctx.hash + 1
        end
        ngx_log(ngx_ERR, "retry : ", ctx.backend_host .. ":" .. ctx.backend_port .. " request:" .. state .. " code:" .. code .. " hash:".. ctx.hash .. " streams: " .. utils.dump(upstream) .. " server_count:" .. server_count)
    else
        local key = ctx.client_ip .. ctx.path .. ctx.method
        if server_count > 1 then
            local hash = ngx.crc32_long(key)
            ctx.hash = (hash % server_count) + 1
            ngx_log(ngx_ERR, "crc32_long : ", hash .. " ctx.hash:" .. ctx.hash)
        end
    end
    if ctx.api.try_times > 0 and ctx.tries < ctx.api.try_times and server_count > 1 then
        set_more_tries(1)
    end
    ctx.tries = ctx.tries + 1
    ctx.backend_host = upstream.servers[ctx.hash]['host']
    ctx.backend_port = upstream.servers[ctx.hash]['port'] or 80
    ngx_log(ngx_ERR, "backend_host: ", ctx.backend_host, " backend_port: ", ctx.backend_port)
    local ok, err = set_current_peer(ctx.backend_host, ctx.backend_port)
    if not ok then
        ngx_log(ngx_ERR, "failed to set the current peer: ", err)
        return ngx.exit(500)
    end
    local timeout = tonumber(ctx.api.timeout)
    if timeout >= 10 or timeout <= 0 then
        timeout = 10
    end
    local balancer_address = {
        connect_timeout = 6,
        send_timeout = 6,
        read_timeout = timeout,
    }
    ok, err = set_timeouts(balancer_address.connect_timeout, balancer_address.send_timeout, balancer_address.read_timeout)
    if not ok then
        ngx_log(ngx_ERR, "could not set upstream timeouts: ", err)
    end
end

function _M.header_filter()
    local ctx = ngx.ctx
    for _, plugin in ipairs(plugins) do
        plugin.handler:header_filter(ctx)
    end
end

function _M.body_filter()
    local ctx = ngx.ctx
    for _, plugin in ipairs(plugins) do
        plugin.handler:body_filter(ctx)
    end
end

function _M.log()
    local ctx = ngx.ctx
    for _, plugin in ipairs(plugins) do
        plugin.handler:log(ctx)
    end
end

return _M
