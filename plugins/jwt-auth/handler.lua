local pairs          = pairs
local next           = next
local response       = require "lib.response"
local jwt            = require "resty.jwt"
local ngx_re_match   = ngx.re.match
local string_upper   = string.upper
local string_gsub    = string.gsub
local tostring       = tostring
local ngx_log        = ngx.log
local ngx_timer_at   = ngx.timer.at
local ngx_ERR        = ngx.ERR
local plugin         = require "plugins.base_plugin"
local jwt_auth       = require "plugins.jwt-auth.service"
local JwtAuthService = jwt_auth:new()
local JwtAuthHandler = plugin:extend()

function JwtAuthHandler:new()
    JwtAuthHandler.super.new(self, "jwt-auth")
end

function JwtAuthHandler:init_worker()
    if ngx.worker.id() == 0 then
        local ok, err = ngx_timer_at(0, function(premature)
            JwtAuthService:init_config()
        end)
        if not ok then
            ngx_log(ngx_ERR, "failed to create the timer: ", err)
            return
        end
    end
end

function JwtAuthHandler:access(ctx)
    if ctx.api.is_auth == 1 then
        local cjson = require "cjson"
        local headers = ngx.req.get_headers()
        local jwtsecret = JwtAuthService:get_config_by_backendname(ctx.backend_name)
        if not jwtsecret then
            return response:error(401, "Project Secret Undefined"):response()
        end

        local authorization_header = headers["authorization"] or nil
        if not authorization_header then
            return response:error(401, "Header Token Undefined"):response()
        end

        local jwttoken = ngx_re_match(authorization_header, "\\s*[Bb]earer\\s+(.+)")
        if not jwttoken then
            return response:error(401, "Header Token Format Error"):response()
        end

        local verifyinfo = jwt:verify(tostring(jwtsecret.secret_key), tostring(jwttoken[1]))
        if not verifyinfo["verified"] then
            return response:error(401, "Unauthorized"):response()
        end

        local payload = verifyinfo["payload"]
        if not payload or not next(payload) then
            return response:error(401, "Unauthorized"):response()
        end

        for key, value in pairs(payload) do
            local header_key = string_upper("JWT-" .. string_gsub(key, "_", "-"))
            ngx_log(ngx_ERR, "header_key: ", header_key, " value: ", value)
            ngx.req.set_header(header_key, value)
        end
    end
end

return JwtAuthHandler
