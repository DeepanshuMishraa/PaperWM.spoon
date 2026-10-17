local Fnutils <const> = hs.fnutils

local Actions = {}
Actions.__index = Actions

---initialize modules with reference to PaperWM
---@param paperwm PaperWM
function Actions.init(paperwm)
    Actions.PaperWM = paperwm
end

---supported window movement actions
function Actions.actions()
    local Direction = Actions.PaperWM.windows.Direction
    return {
        start_events = Fnutils.partial(Actions.PaperWM.start, Actions.PaperWM),
        stop_events = Fnutils.partial(Actions.PaperWM.stop, Actions.PaperWM),
        refresh_windows = Actions.PaperWM.windows.refreshWindows,
        refresh_windows_forcedly = Fnutils.partial(Actions.PaperWM.windows.refreshWindows, true),
        dump_state = Actions.PaperWM.state.dump,
        toggle_floating = Actions.PaperWM.floating.toggleFloating,
        focus_floating = Actions.PaperWM.floating.focusFloating,
        focus_left = Fnutils.partial(Actions.PaperWM.windows.focusWindow, Direction.LEFT),
        focus_right = Fnutils.partial(Actions.PaperWM.windows.focusWindow, Direction.RIGHT),
        focus_up = Fnutils.partial(Actions.PaperWM.windows.focusWindow, Direction.UP),
        focus_down = Fnutils.partial(Actions.PaperWM.windows.focusWindow, Direction.DOWN),
        focus_prev = Fnutils.partial(Actions.PaperWM.windows.focusWindow, Direction.PREVIOUS),
        focus_next = Fnutils.partial(Actions.PaperWM.windows.focusWindow, Direction.NEXT),
        swap_left = Fnutils.partial(Actions.PaperWM.windows.swapWindows, Direction.LEFT),
        swap_right = Fnutils.partial(Actions.PaperWM.windows.swapWindows, Direction.RIGHT),
        swap_up = Fnutils.partial(Actions.PaperWM.windows.swapWindows, Direction.UP),
        swap_down = Fnutils.partial(Actions.PaperWM.windows.swapWindows, Direction.DOWN),
        swap_column_left = function()
            Actions.PaperWM.logger.e("swap_column_left is deprecated, please use swap_left")
            Actions.PaperWM.windows.swapWindows(Direction.LEFT)
        end,
        swap_column_right = function()
            Actions.PaperWM.logger.e("swap_column_right is deprecated, please use swap_right")
            Actions.PaperWM.windows.swapWindows(Direction.RIGHT)
        end,
        center_window = Actions.PaperWM.windows.centerWindow,
        anchor_window_left = Fnutils.partial(Actions.PaperWM.windows.moveToSideEdge, Direction.LEFT),
        anchor_window_right = Fnutils.partial(Actions.PaperWM.windows.moveToSideEdge, Direction.RIGHT),
        full_width = Actions.PaperWM.windows.toggleWindowFullWidth(),
        increase_width = Fnutils.partial(Actions.PaperWM.windows.increaseWindowSize, Direction.WIDTH, 1),
        decrease_width = Fnutils.partial(Actions.PaperWM.windows.increaseWindowSize, Direction.WIDTH, -1),
        increase_height = Fnutils.partial(Actions.PaperWM.windows.increaseWindowSize, Direction.HEIGHT, 1),
        decrease_height = Fnutils.partial(Actions.PaperWM.windows.increaseWindowSize, Direction.HEIGHT, -1),
        cycle_width = Fnutils.partial(Actions.PaperWM.windows.cycleWindowSize, Direction.WIDTH, Direction.ASCENDING),
        cycle_height = Fnutils.partial(Actions.PaperWM.windows.cycleWindowSize, Direction.HEIGHT, Direction.ASCENDING),
        reverse_cycle_width = Fnutils.partial(Actions.PaperWM.windows.cycleWindowSize, Direction.WIDTH,
            Direction.DESCENDING),
        reverse_cycle_height = Fnutils.partial(Actions.PaperWM.windows.cycleWindowSize, Direction.HEIGHT,
            Direction.DESCENDING),
        slurp_in = Actions.PaperWM.windows.slurpWindow,
        barf_out = Actions.PaperWM.windows.barfWindow,
        switch_recent_space = Actions.PaperWM.space.switchToRecentSpace,
        toggle_stack = Actions.PaperWM.windows.toggleStack,
        split_screen = Actions.PaperWM.windows.splitScreen,
        switch_space_l = Fnutils.partial(Actions.PaperWM.space.incrementSpace, Direction.LEFT),
        switch_space_r = Fnutils.partial(Actions.PaperWM.space.incrementSpace, Direction.RIGHT),
        switch_space_1 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 1),
        switch_space_2 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 2),
        switch_space_3 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 3),
        switch_space_4 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 4),
        switch_space_5 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 5),
        switch_space_6 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 6),
        switch_space_7 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 7),
        switch_space_8 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 8),
        switch_space_9 = Fnutils.partial(Actions.PaperWM.space.switchToSpace, 9),
        move_window_l = Fnutils.partial(Actions.PaperWM.space.moveWindowToScreen, Direction.LEFT),
        move_window_r = Fnutils.partial(Actions.PaperWM.space.moveWindowToScreen, Direction.RIGHT),
        move_window_u = Fnutils.partial(Actions.PaperWM.space.moveWindowToScreen, Direction.UP),
        move_window_d = Fnutils.partial(Actions.PaperWM.space.moveWindowToScreen, Direction.DOWN),
        move_window_1 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 1),
        move_window_2 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 2),
        move_window_3 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 3),
        move_window_4 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 4),
        move_window_5 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 5),
        move_window_6 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 6),
        move_window_7 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 7),
        move_window_8 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 8),
        move_window_9 = Fnutils.partial(Actions.PaperWM.space.moveWindowToSpace, 9),
        focus_window_1 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 1),
        focus_window_2 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 2),
        focus_window_3 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 3),
        focus_window_4 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 4),
        focus_window_5 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 5),
        focus_window_6 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 6),
        focus_window_7 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 7),
        focus_window_8 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 8),
        focus_window_9 = Fnutils.partial(Actions.PaperWM.windows.focusWindowAt, 9),
        move_column_1 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 1),
        move_column_2 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 2),
        move_column_3 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 3),
        move_column_4 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 4),
        move_column_5 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 5),
        move_column_6 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 6),
        move_column_7 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 7),
        move_column_8 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 8),
        move_column_9 = Fnutils.partial(Actions.PaperWM.windows.moveColumnTo, 9),
        focus_window_first = Actions.PaperWM.windows.focusWindowFirst,
        focus_window_last = Actions.PaperWM.windows.focusWindowLast,
    }
end

local modifier_aliases <const> = {
    alt = "alt", option = "alt", opt = "alt", ["⌥"] = "alt",
    cmd = "cmd", command = "cmd", ["⌘"] = "cmd",
    ctrl = "ctrl", control = "ctrl", ["⌃"] = "ctrl",
    shift = "shift", ["⇧"] = "shift",
}

---canonical modifier signature, e.g. "alt+shift"; fn is ignored because
---macOS sets it on arrow, home, and end key events
---@param has fun(name: string): boolean
---@return string
local function modifier_signature(has)
    local parts = {}
    for _, name in ipairs({ "alt", "cmd", "ctrl", "shift" }) do
        if has(name) then table.insert(parts, name) end
    end
    return table.concat(parts, "+")
end

---bind userdefined hotkeys to PaperWM actions
---use PaperWM.default_hotkeys for suggested defaults
---
---bindings use a keyDown eventtap rather than hs.hotkey: since macOS 15,
---hotkeys whose only modifiers are option or option+shift never fire
---@param mapping Mapping table of actions and hotkeys
function Actions.bindHotkeys(mapping)
    local spec = Actions.actions()
    local bindings = {}
    for name, binding in pairs(mapping) do
        local action = spec[name]
        local mods, key = binding[1], binding[2]
        local keycode = type(key) == "string" and hs.keycodes.map[key:lower()] or nil
        if not action then
            Actions.PaperWM.logger.ef("bindHotkeys: unknown action '%s', binding skipped", name)
        elseif not keycode then
            Actions.PaperWM.logger.ef("bindHotkeys: unknown key '%s' for action '%s', binding skipped", key, name)
        else
            local wanted = {}
            for _, mod in ipairs(mods) do
                local canonical = modifier_aliases[mod:lower()]
                if canonical then wanted[canonical] = true end
            end
            local sig = modifier_signature(function(n) return wanted[n] == true end)
            bindings[keycode .. ":" .. sig] = action
        end
    end

    if Actions.key_tap then Actions.key_tap:stop() end
    if Actions.key_watchdog then Actions.key_watchdog:stop() end

    local KeyDown <const> = hs.eventtap.event.types.keyDown
    local Autorepeat <const> = hs.eventtap.event.properties.keyboardEventAutorepeat
    Actions.key_tap = hs.eventtap.new({ KeyDown }, function(event)
        local flags = event:getFlags()
        local sig = modifier_signature(function(n) return flags[n] == true end)
        local action = bindings[event:getKeyCode() .. ":" .. sig]
        if not action then return false end
        if event:getProperty(Autorepeat) == 0 then
            -- run outside the tap callback so slow actions can't stall typing
            hs.timer.doAfter(0, action)
        end
        return true -- swallow, so option+key doesn't type a symbol
    end):start()

    -- macOS silently disables an eventtap whose callback was too slow
    Actions.key_watchdog = hs.timer.doEvery(1, function()
        if not Actions.key_tap:isEnabled() then Actions.key_tap:start() end
    end)
end

return Actions
