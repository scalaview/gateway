local cjson = require("cjson")

local _M = {}
function _M.getArgs(name, default)
    local request_method = ngx.var.request_method
    local args = {}
    if "POST" == request_method or "PUT" == request_method then
        ngx.req.read_body()
        local postArgs = ngx.req.get_post_args()
        if postArgs then
            for k, v in pairs(postArgs) do
                args[k] = v
            end
        end
    end
    if name ~= nil then
        if default == nil then
            default = ''
        end
        return args[name] or default
    end
    return args
end

function _M.input(name, default)
    local args = {}
    local request_method = ngx.var.request_method
    if (request_method == 'GET') then
        args = ngx.req.get_uri_args()
    else
        ngx.req.read_body()
        local body = ngx.req.get_body_data()
        if (body ~= nil and body ~= '[]') then
            local res, table_body = pcall(cjson.decode, body)
            if res == false then
                return args
            end
            args = table_body
        end
    end
    if name ~= nil then
        if default == nil then
            default = ''
        end
        return args[name] or default
    end
    return args
end

return _M
