local response       = require "lib.response"
local ngx_log        = ngx.log
local ngx_timer_at   = ngx.timer.at
local ngx_ERR        = ngx.ERR
local plugin         = require "plugins.base_plugin"
local projects       = require "plugins.project.service"

local ProjectHandler = plugin:extend()
local ProjectService = projects:new()

function ProjectHandler:new()
    ProjectHandler.super.new(self, "project")
end

function ProjectHandler:init_worker()
    if ngx.worker.id() == 0 then
        local ok, err = ngx_timer_at(0, function(premature)
            ProjectService:init_config()
        end)
        if not ok then
            ngx_log(ngx_ERR, "failed to create the timer: ", err)
            return
        end
    end
end

function ProjectHandler:access(ctx)
    if ctx.method == 'OPTIONS' then
        return response:success():response()
    end
    local upstream = ProjectService:get_config_by_backendname(ctx.backend_name)
    if not upstream then
        return response:error(404, 'Not Project'):response()
    end
    local var = ngx.var
    var.upstream_host = upstream.domain
    ctx.upstream = upstream
end

return ProjectHandler
