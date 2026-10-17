local Fnutils <const> = hs.fnutils
local Geometry <const> = hs.geometry
local LeftMouseDown <const> = hs.eventtap.event.types.leftMouseDown
local LeftMouseDragged <const> = hs.eventtap.event.types.leftMouseDragged
local LeftMouseUp <const> = hs.eventtap.event.types.leftMouseUp
local MouseEventDeltaX <const> = hs.eventtap.event.properties.mouseEventDeltaX
local MouseEventDeltaY <const> = hs.eventtap.event.properties.mouseEventDeltaY
local ScrollWheel <const> = hs.eventtap.event.types.scrollWheel
local ScrollWheelEventDeltaAxis1 <const> = hs.eventtap.event.properties.scrollWheelEventDeltaAxis1
local ScrollWheelEventDeltaAxis2 <const> = hs.eventtap.event.properties.scrollWheelEventDeltaAxis2
local FlagsChanged <const> = hs.eventtap.event.types.flagsChanged
local Screen <const> = hs.screen
local Spaces <const> = hs.spaces
local Timer <const> = hs.timer
local Window <const> = hs.window
local WindowFilter <const> = hs.window.filter

local Events = {}
Events.__index = Events

---initialize module with reference to PaperWM
---@param paperwm PaperWM
function Events.init(paperwm)
    Events.PaperWM = paperwm
    Events.Swipe = dofile(hs.spoons.resourcePath("swipe.lua"))
end

---refresh window layout on screen change
local screen_watcher = Screen.watcher.new((function()
    local pending_timer = nil
    return function()
        if not pending_timer then
            pending_timer = Timer.doAfter(Window.animationDuration, function()
                pending_timer = nil
                Events.PaperWM.logger.d("refreshing window layout on screen change")
                Events.PaperWM.windows.refreshWindows()
            end)
        end
    end
end)())

---track spaces on space changed
local space_watcher = Spaces.watcher.new(function(spaceID) Events.PaperWM.space.Tracker.trackSpaces(spaceID) end)

---callback for window events
---@param window Window
---@param event string name of the event
---@param self PaperWM
function Events.windowEventHandler(window, event, self)
    if not window["id"] then
        self.logger.ef("no id method for window %s in windowEventHandler", window)
        return
    end

    self.logger.df("%s for [%s]: %d", event, window:title(), window:id())
    local space, anchor_window = nil, nil

    --[[ When a new window is created, We first get a windowVisible event but
    without a Space. Next we receive a windowFocused event for the window, but
    this also sometimes lacks a Space. Our approach is to store the window
    pending a Space in the pending_window variable and set a timer to try to add
    the window again later. Also schedule the windowFocused handler to run later
    after the window was added ]]
    --

    if self.floating.isFloating(window) then
        -- this event is only meaningful for floating windows
        if event == "windowDestroyed" then
            self.floating.removeFloating(window)
        end
        -- no other events are meaningful for floating windows
        return
    end

    if event == "windowFocused" then
        if self.state.pending_window and window == self.state.pending_window then
            Timer.doAfter(Window.animationDuration,
                function()
                    self.logger.vf("pending window timer for %s", window)
                    Events.windowEventHandler(window, event, self)
                end)
            return
        end
        if self.state.prev_focused_window == window then
            self.logger.df("ignoring already focused window: [%s]: %d", window:title(), window:id())
            return
        end
        self.state.prev_focused_window = window -- for addWindow()
        space, anchor_window = Spaces.windowSpaces(window)[1], window
    elseif event == "windowVisible" or event == "windowUnfullscreened" then
        space, anchor_window = self.windows.addWindow(window), window
        if self.state.pending_window and window == self.state.pending_window then
            self.state.pending_window = nil -- tried to add window for the second time
        elseif not space then
            self.state.pending_window = window
            Timer.doAfter(Window.animationDuration,
                function()
                    Events.windowEventHandler(window, event, self)
                end)
            return
        end
    elseif event == "windowNotVisible" then
        space, anchor_window = self.windows.removeWindow(window)
    elseif event == "windowFullscreened" then
        space = self.windows.removeWindow(window, true) -- don't focus new window if fullscreened
    elseif event == "AXWindowMoved" or event == "AXWindowResized" then
        space = Spaces.windowSpaces(window)[1]
    end

    if space then self:tileSpace(space, anchor_window) end
end

---tiled windows in a space, from the window list instead of hs.window.get,
---which enumerates every window on the system for each lookup
---@param self PaperWM
---@param space Space
---@return Window[]
local function space_windows(self, space)
    local windows = {}
    for _, column in ipairs(self.state.windowList(space)) do
        for _, window in ipairs(column) do table.insert(windows, window) end
    end
    return windows
end

---start sliding the windows of a space: cache windows, frames, and virtual x
---positions, and stop window watchers
---@param self PaperWM
---@param space Space
---@param screen_frame Frame
---@return table slide state for slide_move and slide_end
local function slide_begin(self, space, screen_frame)
    local x_positions = self.state.xPositions(space)
    local windows     = {}
    for _, window in ipairs(space_windows(self, space)) do
        local id = window:id()
        local x = x_positions[id]
        if x then
            self.animation.cancel(id, true) -- swipe takes over from a running animation
            self.state.uiWatcherStop(id)
            table.insert(windows, { window = window, frame = window:frame(), x = x })
        end
    end
    return {
        space = space,
        screen_frame = screen_frame,
        left_margin = screen_frame.x + self.screen_margin,
        right_margin = screen_frame.x2 - self.screen_margin,
        windows = windows,
    }
end

---slide every window in a slide by dx pixels
---@param slide table state from slide_begin
---@param dx number
local function slide_move(slide, dx)
    for _, item in ipairs(slide.windows) do
        item.x = item.x + dx -- scroll left or right
        local x = math.max(slide.left_margin - item.frame.w, math.min(item.x, slide.right_margin))
        -- windows pinned in the screen margin don't move, skip the AX call
        if x ~= item.frame.x then
            item.frame.x = x
            item.window:_setTopLeft({ x = x, y = item.frame.y })
        end
    end
end

---finish a slide: restart window watchers and make sure a focused window is on screen
---@param self PaperWM
---@param slide table state from slide_begin
local function slide_end(self, slide)
    local space, screen_frame = slide.space, slide.screen_frame

    -- restart watchers once macOS has delivered the move events from the slide
    local ids = {}
    for _, item in ipairs(slide.windows) do table.insert(ids, item.window:id()) end
    Timer.doAfter(0.1, function()
        for _, id in ipairs(ids) do self.state.uiWatcherStart(id) end
    end)

    local focused_window = Window.focusedWindow()
    if focused_window then
        local frame = focused_window:frame()
        local visible_window = (function()
            if frame.x < screen_frame.x then
                return self.windows.getFirstVisibleWindow(space, screen_frame,
                    self.windows.Direction.LEFT)
            elseif frame.x2 > screen_frame.x2 then
                return self.windows.getFirstVisibleWindow(space, screen_frame,
                    self.windows.Direction.RIGHT)
            end
        end)()
        if visible_window and visible_window ~= focused_window then
            visible_window:focus() -- switching focus will cause space to tile
        else
            self:tileSpace(space)  -- retile with same focused window
        end
    else
        self.logger.e("no focused window at end of swipe")
    end
end

---generate callback function for touchpad swipe gesture event
---@param self PaperWM
function Events.swipeHandler(self)
    -- saved upvalues between callback function calls
    local slide, screen_frame = nil, nil

    -- a gesture moves windows only once it is clearly horizontal, so ordinary
    -- (two finger) scrolling never slides or retiles windows
    local lock_distance <const> = 0.02 -- normalized trackpad travel before deciding
    local direction, travel_dx, travel_dy = nil, 0, 0 ---@type "horizontal"|"vertical"|nil, number, number

    -- gesture events arrive faster than windows can move: accumulate them and
    -- move windows once per frame, keeping the eventtap callback cheap so
    -- macOS never times out and disables the tap
    local pending_dx, frame_timer = 0, nil
    local function flush()
        local step = pending_dx >= 0 and math.floor(pending_dx) or math.ceil(pending_dx)
        if step ~= 0 and slide then
            pending_dx = pending_dx - step
            slide_move(slide, step)
        end
    end
    local function stop_frames()
        if frame_timer then frame_timer:stop() end
        frame_timer, pending_dx = nil, 0
    end

    local function finish()
        direction, travel_dx, travel_dy = nil, 0, 0
        if not slide then return end
        flush()
        stop_frames()
        local finished = slide
        slide = nil -- clear first: ending can trigger nested events
        slide_end(self, finished)
    end

    ---start sliding the focused window's space
    ---@return boolean started
    local function start()
        local focused_window = Window.focusedWindow()
        if not focused_window then
            self.logger.d("focused window not found")
            return false
        end

        local focused_index = self.state.windowIndex(focused_window)
        if not focused_index then
            self.logger.d("focused window is not tiled")
            return false
        end

        local screen = Screen(Spaces.spaceDisplay(focused_index.space))
        if not screen then
            self.logger.e("no screen for space")
            return false
        end

        screen_frame = screen:frame()
        slide = slide_begin(self, focused_index.space, screen_frame)
        stop_frames()
        frame_timer = Timer.doEvery(1 / 120, flush)
        return true
    end

    ---callback for touchpad swipe gesture event
    ---@param id number unique id across callbacks for the same swipe
    ---@param type number one of Swipe.BEGIN, Swipe.MOVED, Swipe.END
    ---@param dx number change in horizontal position since last callback: between 0 and 1
    ---@param dy number change in vertical position since last callback: between 0 and 1
    return function(id, type, dx, dy)
        if type == Events.Swipe.BEGIN then
            self.logger.df("new swipe: %d", id)
            finish() -- end an unfinished swipe whose END event was lost
        elseif type == Events.Swipe.END then
            self.logger.df("swipe end: %d", id)
            finish()
        elseif type == Events.Swipe.MOVED then
            if direction == nil then
                travel_dx, travel_dy = travel_dx + dx, travel_dy + dy
                if math.abs(travel_dx) + math.abs(travel_dy) < lock_distance then return end
                if math.abs(travel_dx) > 2 * math.abs(travel_dy) and start() then
                    direction = "horizontal"
                    dx = travel_dx -- include the travel spent deciding
                else
                    direction = "vertical"
                end
            end
            if direction == "horizontal" and slide and screen_frame then
                pending_dx = pending_dx + self.swipe_gain * dx * screen_frame.w
            end
        end
    end
end

---generate callback function for mouse events
---@param self PaperWM
function Events.mouseHandler(self)
    local lift_window, drag_slide = nil, nil

    ---find a Window under the mouse cursor
    ---@param event userdata
    ---@return Window|nil
    local function windowUnderCursor(event)
        local cursor = Geometry.new(event:location())
        local screen = Fnutils.find(Screen.allScreens(), function(screen) return cursor:inside(screen:frame()) end)
        if not screen then return end
        local space = Spaces.activeSpaceOnScreen(screen)
        if not space then return end
        for _, window in ipairs(space_windows(self, space)) do
            if cursor:inside(window:frame()) then return window end
        end
    end

    ---callback for mouse event
    ---@param event userdata
    ---@return boolean delete or propagate event
    return function(event)
        local delete_event = false
        local type = event:getType()
        if type == LeftMouseDown then
            local flags = event:getFlags()
            if self.drag_window and flags:containExactly(self.drag_window) then
                local drag_window = windowUnderCursor(event)
                if drag_window then
                    local index = self.state.windowIndex(drag_window)
                    if not index then
                        self.logger.e("drag window index not found")
                        return delete_event
                    end
                    local screen = Screen(Spaces.spaceDisplay(index.space))
                    if not screen then
                        self.logger.e("no screen for space")
                        return delete_event
                    end
                    drag_slide = slide_begin(self, index.space, screen:frame())
                    self.logger.df("drag window start for: %s", drag_window)
                    delete_event = true
                end
            elseif self.lift_window and flags:containExactly(self.lift_window) then
                -- get window from cursor location, set window to floating, tile
                lift_window = windowUnderCursor(event)
                if lift_window then self.floating.toggleFloating(lift_window) end
                self.logger.df("lift window start for: %s", lift_window)
                delete_event = true
            end
        elseif type == LeftMouseDragged then
            if drag_slide then
                slide_move(drag_slide, event:getProperty(MouseEventDeltaX))
                delete_event = true
            elseif lift_window then
                local frame = lift_window:frame()
                lift_window:setTopLeft(
                    frame.x + event:getProperty(MouseEventDeltaX),
                    frame.y + event:getProperty(MouseEventDeltaY)
                )
                delete_event = true
            end
        elseif type == LeftMouseUp then
            if drag_slide then
                self.logger.df("drag window stop")
                local finished = drag_slide
                drag_slide = nil
                slide_end(self, finished)
                delete_event = true
            elseif lift_window then
                -- set window to not floating, tile
                self.logger.d("lift window stop")
                self.floating.toggleFloating(lift_window)
                lift_window = nil
                delete_event = true
            end
        end
        return delete_event
    end
end

---generate callback for scroll wheel events
---@param self PaperWM
function Events.scrollHandler(self)
    local flags_watcher, scroll_slide = nil, nil

    ---callback for scroll wheel event
    ---@param event userdata
    ---@return boolean delete or propagate event
    return function(event)
        local delete_event = false
        if self.scroll_window and event:getType() == ScrollWheel
            and event:getFlags():containExactly(self.scroll_window or {}) then
            delete_event = true
            if not scroll_slide then
                self.logger.d("scroll window start")

                local focused_window = Window.focusedWindow()
                if not focused_window then
                    self.logger.d("focused window not found")
                    return delete_event
                end

                local focused_index = self.state.windowIndex(focused_window)
                if not focused_index then
                    self.logger.e("focused index not found")
                    return delete_event
                end

                local screen = Screen(Spaces.spaceDisplay(focused_index.space))
                if not screen then
                    self.logger.e("no screen for space")
                    return delete_event
                end

                scroll_slide = slide_begin(self, focused_index.space, screen:frame())
            else
                local deltaAxis1 = event:getProperty(ScrollWheelEventDeltaAxis1)
                local deltaAxis2 = event:getProperty(ScrollWheelEventDeltaAxis2)
                local delta = (math.abs(deltaAxis1) > math.abs(deltaAxis2)) and deltaAxis1 or deltaAxis2
                slide_move(scroll_slide, delta * (self.scroll_gain or 1))
            end
            if not flags_watcher then
                flags_watcher = hs.eventtap.new({ FlagsChanged },
                    function(event) ---@diagnostic disable-line:redefined-local
                        if not event:getFlags():contain(self.scroll_window or {}) then
                            self.logger.d("scroll window stop")
                            local finished = assert(scroll_slide)
                            assert(flags_watcher):stop()
                            scroll_slide = nil
                            flags_watcher = nil
                            slide_end(self, finished)
                        end
                        return false -- forward event
                    end):start()
            end
        end
        return delete_event
    end
end

---start monitoring for window events
function Events.start()
    -- listen for window events
    Events.PaperWM.window_filter:subscribe({
        WindowFilter.windowFocused, WindowFilter.windowVisible,
        WindowFilter.windowNotVisible, WindowFilter.windowFullscreened,
        WindowFilter.windowUnfullscreened, WindowFilter.windowDestroyed,
    }, function(window, _, event) Events.windowEventHandler(window, event, Events.PaperWM) end)

    -- watch for external monitor plug / unplug
    screen_watcher:start()
    space_watcher:start()

    -- recognize horizontal touchpad swipe gestures
    if Events.PaperWM.swipe_fingers > 1 then
        Events.Swipe:start(Events.PaperWM.swipe_fingers, Events.swipeHandler(Events.PaperWM))
    end

    -- register a mouse event watcher if the drag window or lift window hotkeys are set
    if Events.PaperWM.drag_window or Events.PaperWM.lift_window then
        Events.mouse_watcher = hs.eventtap.new({ LeftMouseDown, LeftMouseDragged, LeftMouseUp },
            Events.mouseHandler(Events.PaperWM)):start()
    end

    -- register a scroll wheel watcher if the scroll_window hotkey is set
    if Events.PaperWM.scroll_window then
        Events.scroll_watcher = hs.eventtap.new({ ScrollWheel },
            Events.scrollHandler(Events.PaperWM)):start()
    end
end

---stop monitoring for window events
function Events.stop()
    -- stop events
    Events.PaperWM.window_filter:unsubscribeAll()
    Events.PaperWM.state.uiWatcherStopAll()
    screen_watcher:stop()
    space_watcher:stop()

    -- stop listening for touchpad swipes
    Events.Swipe:stop()

    -- stop listening for mouse events
    if Events.mouse_watcher then Events.mouse_watcher:stop() end

    -- stop listening for scroll events
    if Events.scroll_watcher then Events.scroll_watcher:stop() end
end

return Events
