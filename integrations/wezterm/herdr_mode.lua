local wezterm = require("wezterm")
local act = wezterm.action

local M = {}

-- Must match Herdr keys.prefix (ctrl+semicolon). CSI-u encoding of Ctrl+;.
local PREFIX_KEY = ";"
local PREFIX_MODS = "CTRL"
local PREFIX = "\x1b[59;5u"

local MODES = {
	main = "herdr_mode",
	copy = "herdr_copy_mode",
	selection = "herdr_selection_mode",
	resize = "herdr_resize_mode",
}

M.modes = MODES

M.styles = {
	[MODES.main] = {
		bg = "#2f4a38",
		fg = "#c8facc",
		label = " HERDR ",
	},
	[MODES.copy] = {
		bg = "#2f4a38",
		fg = "#c8facc",
		label = " HERDR ",
	},
	[MODES.selection] = {
		bg = "#2f4a38",
		fg = "#c8facc",
		label = " HERDR ",
	},
	[MODES.resize] = {
		bg = "#4a3f24",
		fg = "#e6c384",
		label = " HERDR:RESIZE ",
	},
}

local indicator_enabled = true

local function window_key(window)
	local ok, id = pcall(function()
		return window:window_id()
	end)
	if ok and id ~= nil then
		return tostring(id)
	end
	return tostring(window)
end

local function set_active_mode(window, mode)
	if not indicator_enabled or not M.styles[mode] then
		return
	end

	wezterm.GLOBAL.herdr_active_modes = wezterm.GLOBAL.herdr_active_modes or {}
	wezterm.GLOBAL.herdr_active_modes[window_key(window)] = mode
end

local function clear_active_mode(window)
	if not wezterm.GLOBAL.herdr_active_modes then
		return
	end
	wezterm.GLOBAL.herdr_active_modes[window_key(window)] = nil
end

function M.active_mode_for_tab(tab)
	if not tab.window_id or not wezterm.GLOBAL.herdr_active_modes then
		return nil
	end
	return wezterm.GLOBAL.herdr_active_modes[tostring(tab.window_id)]
end

function M.clear_all_modes()
	wezterm.GLOBAL.herdr_active_modes = {}
end

local function foreground_process_name(pane)
	local ok, process = pcall(function()
		return pane:get_foreground_process_name()
	end)
	if not ok or not process then
		return ""
	end
	return process:match("([^/]+)$") or process
end

local function pane_title(pane)
	local ok, title = pcall(function()
		return pane:get_title()
	end)
	if not ok or not title then
		return ""
	end
	return title
end

local function is_herdr_pane(pane)
	if foreground_process_name(pane) == "herdr" then
		return true
	end
	return pane_title(pane):match("^herdr") ~= nil
end

local function notify_mode_change(window, pane)
	wezterm.emit("herdr-mode-changed", window, pane)
end

local function activate_mode(window, pane, mode)
	window:perform_action(
		act.ActivateKeyTable({
			name = mode,
			one_shot = false,
			replace_current = true,
		}),
		pane
	)
	set_active_mode(window, mode)
	notify_mode_change(window, pane)
end

local function leave_mode(window, pane)
	window:perform_action(act.PopKeyTable, pane)
	clear_active_mode(window)
	notify_mode_change(window, pane)
end

local function leave_main_mode()
	return wezterm.action_callback(function(window, pane)
		leave_mode(window, pane)
	end)
end

local function herdr_key(key, mods)
	return act.Multiple({
		act.SendString(PREFIX),
		act.SendKey({ key = key, mods = mods or "NONE" }),
	})
end

local function herdr_shift_key(key)
	return act.Multiple({
		act.SendString(PREFIX),
		act.SendString("\x1b[" .. string.byte(key) .. ";2u"),
	})
end

local function herdr_shift_number(n)
	return act.Multiple({
		act.SendString(PREFIX),
		act.SendString("\x1b[" .. string.byte(n) .. ";2u"),
	})
end

local function handoff(action)
	return wezterm.action_callback(function(window, pane)
		window:perform_action(action, pane)
		leave_mode(window, pane)
	end)
end

local function enter_submode(action, mode)
	return wezterm.action_callback(function(window, pane)
		window:perform_action(action, pane)
		activate_mode(window, pane, mode)
	end)
end

local function send_raw_and_leave(key, mods)
	return handoff(act.SendKey({ key = key, mods = mods or "NONE" }))
end

local function send_raw_and_return_to_main(key, mods)
	return wezterm.action_callback(function(window, pane)
		window:perform_action(act.SendKey({ key = key, mods = mods or "NONE" }), pane)
		activate_mode(window, pane, MODES.main)
	end)
end

local function cancel_submode_and_leave()
	return send_raw_and_leave("Escape")
end

local function enter_resize_mode(key)
	return wezterm.action_callback(function(window, pane)
		window:perform_action(herdr_key("r"), pane)
		window:perform_action(act.SendKey({ key = key, mods = "NONE" }), pane)
		activate_mode(window, pane, MODES.resize)
	end)
end

local function exit_resize_mode(leave_outer_mode)
	return wezterm.action_callback(function(window, pane)
		window:perform_action(act.SendKey({ key = "Escape" }), pane)
		if leave_outer_mode then
			leave_mode(window, pane)
		else
			activate_mode(window, pane, MODES.main)
		end
	end)
end

-- Mode transitions follow who should receive the next key:
-- - stay: continue treating input as Herdr commands (pane/tab/workspace/resize)
-- - submode: hand input to a Herdr UI, then return to main or leave
-- - leave: the next input belongs to another surface (rename, help, overlay)
local function main_key_table()
	return {
		{ key = "Escape", action = leave_main_mode() },
		{ key = PREFIX_KEY, mods = PREFIX_MODS, action = leave_main_mode() },

		{ key = "h", action = herdr_key("h") },
		{ key = "j", action = herdr_key("j") },
		{ key = "k", action = herdr_key("k") },
		{ key = "l", action = herdr_key("l") },

		{ key = "H", mods = "SHIFT", action = enter_resize_mode("h") },
		{ key = "J", mods = "SHIFT", action = enter_resize_mode("j") },
		{ key = "K", mods = "SHIFT", action = enter_resize_mode("k") },
		{ key = "L", mods = "SHIFT", action = enter_resize_mode("l") },

		{ key = "[", action = herdr_key("[") },
		{ key = "]", action = herdr_key("]") },
		{ key = "{", mods = "SHIFT", action = herdr_shift_key("[") },
		{ key = "}", mods = "SHIFT", action = herdr_shift_key("]") },
		{ key = ",", action = herdr_key(",") },
		{ key = ".", action = herdr_key(".") },

		{ key = "p", action = herdr_key("p") },
		{ key = "p", mods = "ALT", action = handoff(herdr_key("p", "ALT")) },
		{ key = "t", action = handoff(herdr_key("t")) },
		{ key = "t", mods = "ALT", action = handoff(herdr_key("t", "ALT")) },
		{ key = "v", action = enter_submode(herdr_key("v"), MODES.copy) },
		{ key = "V", mods = "SHIFT", action = handoff(herdr_shift_key("v")) },
		{ key = "d", action = herdr_key("d") },
		{ key = "D", mods = "SHIFT", action = herdr_shift_key("d") },
		{ key = "P", mods = "SHIFT", action = handoff(herdr_shift_key("p")) },
		{ key = "T", mods = "SHIFT", action = handoff(herdr_shift_key("t")) },
		{ key = "z", action = herdr_key("z") },

		{ key = "w", action = herdr_key("w") },
		{ key = "w", mods = "ALT", action = handoff(herdr_key("w", "ALT")) },
		{ key = "W", mods = "SHIFT", action = handoff(herdr_shift_key("w")) },
		{ key = "Space", action = enter_submode(herdr_key("Space"), MODES.selection) },
		{ key = "g", action = enter_submode(herdr_key("g"), MODES.selection) },
		{ key = "?", action = handoff(herdr_key("?")) },
		{ key = "s", action = handoff(herdr_key("s")) },
		{ key = "r", action = enter_submode(herdr_key("r"), MODES.resize) },
		{ key = "R", mods = "SHIFT", action = herdr_shift_key("r") },
		{ key = "O", mods = "SHIFT", action = handoff(herdr_shift_key("o")) },

		{ key = "1", action = herdr_shift_number("1") },
		{ key = "2", action = herdr_shift_number("2") },
		{ key = "3", action = herdr_shift_number("3") },
		{ key = "4", action = herdr_shift_number("4") },
		{ key = "5", action = herdr_shift_number("5") },
		{ key = "6", action = herdr_shift_number("6") },
		{ key = "7", action = herdr_shift_number("7") },
		{ key = "8", action = herdr_shift_number("8") },
		{ key = "9", action = herdr_shift_number("9") },
	}
end

local function copy_key_table()
	return {
		{ key = "Escape", action = send_raw_and_return_to_main("Escape") },
		{ key = "q", action = send_raw_and_return_to_main("q") },
		{ key = "y", action = send_raw_and_leave("y") },
		{ key = "Y", mods = "SHIFT", action = send_raw_and_leave("Y", "SHIFT") },
		{ key = PREFIX_KEY, mods = PREFIX_MODS, action = cancel_submode_and_leave() },
	}
end

local function selection_key_table()
	return {
		{ key = "Escape", action = send_raw_and_return_to_main("Escape") },
		{ key = "q", action = send_raw_and_return_to_main("q") },
		{ key = "Enter", action = send_raw_and_leave("Enter") },
		{ key = PREFIX_KEY, mods = PREFIX_MODS, action = cancel_submode_and_leave() },
	}
end

local function resize_key_table()
	return {
		{ key = "Escape", action = exit_resize_mode(false) },
		{ key = "Enter", action = exit_resize_mode(false) },
		{ key = PREFIX_KEY, mods = PREFIX_MODS, action = exit_resize_mode(true) },
		{ key = "r", action = exit_resize_mode(false) },

		{ key = "h", action = act.SendKey({ key = "h" }) },
		{ key = "j", action = act.SendKey({ key = "j" }) },
		{ key = "k", action = act.SendKey({ key = "k" }) },
		{ key = "l", action = act.SendKey({ key = "l" }) },
		{ key = "LeftArrow", action = act.SendKey({ key = "LeftArrow" }) },
		{ key = "DownArrow", action = act.SendKey({ key = "DownArrow" }) },
		{ key = "UpArrow", action = act.SendKey({ key = "UpArrow" }) },
		{ key = "RightArrow", action = act.SendKey({ key = "RightArrow" }) },
	}
end

function M.install(keys, key_tables, opts)
	opts = opts or {}
	if opts.indicator == false then
		indicator_enabled = false
	end

	table.insert(keys, {
		key = PREFIX_KEY,
		mods = PREFIX_MODS,
		action = wezterm.action_callback(function(window, pane)
			if is_herdr_pane(pane) then
				activate_mode(window, pane, MODES.main)
			else
				window:perform_action(act.SendKey({ key = PREFIX_KEY, mods = PREFIX_MODS }), pane)
			end
		end),
	})

	key_tables[MODES.main] = main_key_table()
	key_tables[MODES.copy] = copy_key_table()
	key_tables[MODES.selection] = selection_key_table()
	key_tables[MODES.resize] = resize_key_table()
end

return M
