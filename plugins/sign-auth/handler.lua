local ngx_HTTP_UNAUTHORIZED = ngx.HTTP_UNAUTHORIZED
local ngx_log       = ngx.log
local ngx_timer_at  = ngx.timer.at
local ngx_ERR       = ngx.ERR
local response      = require "lib.response"
local cjson         = require "cjson"
local pairs         = pairs
local next          = next
local type          = type
local pcall         = pcall
local tostring      = tostring
local table_insert  = table.insert
local table_sort    = table.sort
local table_concat  = table.concat
local string_upper  = string.upper
local string_len    = string.len
local ngx_encode_base64 = ngx.encode_base64
local ngx_md5       = ngx.md5
local hmac          = require "resty.hmac"
local sign_auth     = require "plugins.sign-auth.service"
local plugin        = require "plugins.base_plugin"

local SignAuthService   = sign_auth:new()
local SignAuthHandler   = plugin:extend()

local function get_params_to_string(method)
    local paramstr
    if method == "GET" then
        local querys = ngx.req.get_uri_args()
        if type(querys) == "table" and next(querys) then
            local getparams = {}
            for key, value in pairs(querys) do
                table_insert(getparams, tostring(key) .. tostring(value))
            end
            if #getparams > 0 then
                table_sort(getparams)
                paramstr = table_concat(getparams, "")
            end
        end
    else
        local sign_body
        local bodys = ngx.req.get_body_data()
        if type(bodys) == "string" and string_len(bodys) > 0 then
            local ok, postparams = pcall(cjson.decode, bodys)
            if ok and next(postparams) ~= nil then
                local md5 = ngx_md5(bodys)
                paramstr = ngx_encode_base64(string_upper(md5))
            end
        end
    end
    return paramstr
end

local function verify_sign(sign_str, app_secret, sign)
    local hmac_sha256 = hmac:new(app_secret, hmac.ALGOS.SHA256)
    if not hmac_sha256 then
        ngx_log(ngx_ERR, "failed to create the hmac_sha256 object")
        return
    end
    local result = hmac_sha256:final(sign_str, true)
    ngx_log(ngx_ERR, "sign result: ", result)
    if result == sign then
        return true
    else
        return false
    end
end

function SignAuthHandler:new()
    SignAuthHandler.super.new(self, "sign-auth")
end

function SignAuthHandler:init_worker()
    if ngx.worker.id() == 0 then
        local ok, err = ngx_timer_at(0, function(premature)
            SignAuthService:init_config()
        end)
        if not ok then
            ngx_log(ngx_ERR, "failed to create the timer: ", err)
            return
        end
    end
end

function SignAuthHandler:access(ctx)
    if ctx.api.is_sign == 1 then
        local headers = ngx.req.get_headers()
        local var     = ngx.var
        local params = {
            app_key      = headers.k_key,
            sign         = headers.k_sign,
            timestamp    = headers.k_timestamp,
            method       = var.request_method,
            gateway_path = var.uri,
            platform     = headers.k_platform,
        }
        if not params.app_key or
           not params.sign or
           not params.timestamp or
           not params.method or
           params.gateway_path == '/'
        then
            return response:error(ngx_HTTP_UNAUTHORIZED, "Incomplete Signature Parameters"):response()
        end

        local appkey = params.app_key
        local appsecret = SignAuthService:get_config_by_appkey(appkey)
        if not appsecret then
            return response:error(ngx_HTTP_UNAUTHORIZED, "App Secret Undefined"):response()
        end
        local parstr = get_params_to_string(params.method) or ""
        local signstr = params.timestamp..params.gateway_path..params.method..parstr..params.app_key
        ngx_log(ngx_ERR, "signstr: ", signstr, " appsecret: ", appsecret, " params.sign:", params.sign )
        local succ = verify_sign(signstr, appsecret, params.sign)
        if not succ then
            return response:error(ngx_HTTP_UNAUTHORIZED, "Signature Authentication Failed"):response()
        end
    end
end

return SignAuthHandler
