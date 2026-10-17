local Geometry <const> = hs.geometry
local Timer <const> = hs.timer

local Animation = {}
Animation.__index = Animation

---easing curves: map linear progress t in [0, 1] to eased progress
---curves ending in "back" or "spring" overshoot the target before settling
---@type table<string, fun(t: number): number>
Animation.easings = {
    linear = function(t) return t end,
    ease_out_quad = function(t) return 1 - (1 - t) ^ 2 end,
    ease_out_cubic = function(t) return 1 - (1 - t) ^ 3 end,
    ease_out_quart = function(t) return 1 - (1 - t) ^ 4 end,
    ease_out_expo = function(t) return t >= 1 and 1 or 1 - 2 ^ (-10 * t) end,
    ease_in_out_cubic = function(t)
        if t < 0.5 then return 4 * t ^ 3 end
        return 1 - (-2 * t + 2) ^ 3 / 2
    end,
    ease_out_back = function(t)
        local c1 <const> = 1.70158
        return 1 + (c1 + 1) * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
    end,
    spring = function(t) return 1 - math.exp(-6 * t) * math.cos(12 * t) end,
}

---windows being animated, keyed by window id
---@type table<number, { window: Window, x: number, y: number, from_x: number, from_y: number, to: Frame, start: number }>
local active = {}
local tick_timer = nil ---@type userdata|nil hs.timer
local original_frame = nil ---@type fun(self: Window): Frame

---initialize module with reference to PaperWM
---@param paperwm PaperWM
function Animation.init(paperwm)
    Animation.PaperWM = paperwm

    -- while PaperWM animates a window, report its target frame like hs.window
    -- does for its own animations, so a retile started mid-animation lays out
    -- from where windows will land instead of from intermediate positions
    if not original_frame then
        local window_mt = hs.getObjectMetatable("hs.window")
        original_frame = window_mt.frame
        window_mt.frame = function(self)
            if next(active) then
                local anim = active[self:id()]
                if anim then return Geometry.copy(anim.to) end
            end
            return original_frame(self)
        end
    end
end

---restart ui watchers once macOS has delivered the move events we caused
---@param ids number[]
local function resume_watchers(ids)
    Timer.doAfter(0.05, function()
        for _, id in ipairs(ids) do
            if not active[id] then Animation.PaperWM.state.uiWatcherStart(id) end
        end
    end)
end

local function tick()
    local now <const> = Timer.secondsSinceEpoch()
    local duration <const> = Animation.PaperWM.animation_duration
    local ease <const> = Animation.easings[Animation.PaperWM.animation_easing] or Animation.easings.ease_out_cubic
    local finished = {}

    for id, anim in pairs(active) do
        local t = math.min(1, (now - anim.start) / duration)
        local x, y
        if t >= 1 then
            x, y = anim.to.x, anim.to.y
            table.insert(finished, id)
        else
            local p = ease(t)
            x = math.floor(anim.from_x + (anim.to.x - anim.from_x) * p + 0.5)
            y = math.floor(anim.from_y + (anim.to.y - anim.from_y) * p + 0.5)
        end
        -- position only: resizing every frame forces apps to relayout
        if x ~= anim.x or y ~= anim.y then
            anim.window:_setTopLeft({ x = x, y = y })
            anim.x, anim.y = x, y
        end
    end

    for _, id in ipairs(finished) do active[id] = nil end
    if #finished > 0 then resume_watchers(finished) end
    if not next(active) and tick_timer then
        tick_timer:stop()
        tick_timer = nil
    end
end

---animate a window to frame: size snaps once at the start, position eases
---over animation_duration using animation_easing
---@param window Window
---@param frame Frame target frame
function Animation.move(window, frame)
    local id = window:id()
    local anim = active[id]
    local actual = original_frame(window)
    local to = Geometry.copy(frame)

    Animation.PaperWM.state.uiWatcherStop(id)

    if actual.w ~= to.w or actual.h ~= to.h then
        window:_setSize({ w = to.w, h = to.h })
    end

    local x, y = actual.x, actual.y
    if anim then x, y = anim.x, anim.y end -- continue from the in-flight position

    if x == to.x and y == to.y then
        active[id] = nil
        resume_watchers({ id })
        return
    end

    active[id] = {
        window = window,
        x = x,
        y = y,
        from_x = x,
        from_y = y,
        to = to,
        start = Timer.secondsSinceEpoch(),
    }

    if not tick_timer then
        tick_timer = Timer.doEvery(1 / Animation.PaperWM.animation_fps, tick)
        tick() -- first frame now instead of one interval late
    end
end

---stop animating a window, optionally snapping it to its target frame
---@param id number window id
---@param snap boolean|nil
function Animation.cancel(id, snap)
    local anim = active[id]
    if not anim then return end
    active[id] = nil
    if snap then anim.window:_setTopLeft({ x = anim.to.x, y = anim.to.y }) end
end

---snap every animating window to its target frame
function Animation.finishAll()
    local ids = {}
    for id in pairs(active) do
        Animation.cancel(id, true)
        table.insert(ids, id)
    end
    if tick_timer then
        tick_timer:stop()
        tick_timer = nil
    end
    if #ids > 0 then resume_watchers(ids) end
end

return Animation
