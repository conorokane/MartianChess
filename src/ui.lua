-- martian chess game UI

ui = {}

ui.side_panel_width = 102
ui.tooltip_offset_y = 3
ui.tooltip_padding_x = 3
ui.tooltip_padding_y = 4
ui.tooltip_text_height = 6
ui.tooltip_panel_margin = 2
ui.tooltip_radius = 1
ui.tooltip_fill_color = 1
ui.tooltip_border_color = 6
ui.tooltip_text_color = 7
ui.announcement_top_padding = 3
ui.announcement_bottom_padding = 3
ui.announcement_text_height = 6
ui.announcement_line_spacing = 2
ui.announcement_text_color = 6
ui.button = {
	color = 1,
	border_color = 6,
	radius = 2,
	hover_color = 16,
	click_color = 25
}

local panel_offset_x = 2
local capture_group_spacing = 30
local capture_count_offset_x = 20
local capture_count_offset_y = 5
local score_panel_height = 34
local score_panel_padding = 4
local score_text_offset_x = 2
local panel_radius = 4
local score_panel_fill_color = 2
local score_panel_border_color = 25
local turn_highlight_color = 10
local middle_panel_turn_clearance = 12
local middle_button_size = 18
local middle_button_spacing = 4
local middle_button_top_padding = 4
local restart_button_width = 42
local restart_button_height = 14
local middle_buttons = {
	{
		id = "resign",
		name = "Resign",
		announcement = "",
		sprite = 7,
		sprite_x = 2,
		sprite_y = 1
	},
	{
		id = "instructions",
		name = "Instructions",
		announcement = {"Instructions", " website copied", "to clipboard"},
		sprite = 14,
		sprite_x = 4,
		sprite_y = 2
	},
	{
		id = "leaderboards",
		name = "Leaderboard",
		announcement = "",
		sprite = 15,
		sprite_x = 2,
		sprite_y = 2
	},
	{
		id = "game_log",
		name = "Game log",
		announcement = {"Game log copied", "to clipboard"},
		sprite = 16,
		sprite_x = 4,
		sprite_y = 2
	}
}

local panel_x = 0
local panel_width = 0
local north_panel_y = 0
local south_panel_y = 0
local middle_panel_y = 0
local middle_panel_height = 0
local deadlock_warning_start = 0
local deadlock_move_limit = 0
local announcement_lines = nil
local game_over_panel_x = 0
local game_over_panel_y = 0
local game_over_panel_width = 0
local game_over_panel_height = 0
local restart_button_x = 0
local restart_button_y = 0
local button_hover_states = {}

function ui.initialize_layout(options)
	panel_x = options.board_x + options.board_width +
		options.border_size / 2 + panel_offset_x
	panel_width = options.window_width - panel_x - options.border_size
	north_panel_y = options.board_origin_y
	south_panel_y = options.board_bottom_y - score_panel_height
	middle_panel_y = north_panel_y + score_panel_height +
		middle_panel_turn_clearance
	middle_panel_height = south_panel_y -
		middle_panel_turn_clearance - middle_panel_y
	deadlock_warning_start = options.deadlock_warning_start
	deadlock_move_limit = options.deadlock_move_limit

	game_over_panel_x = panel_x
	game_over_panel_width = panel_width
	game_over_panel_height = middle_panel_height / 2
	game_over_panel_y = middle_panel_y + middle_panel_height -
		game_over_panel_height
	restart_button_x = game_over_panel_x +
		(game_over_panel_width - restart_button_width) / 2
	restart_button_y = game_over_panel_y + game_over_panel_height -
		restart_button_height - 4
end

function ui.set_announcement(text)
	announcement_lines = type(text) == "table" and text or {text}
end

function ui.clear_announcement()
	announcement_lines = nil
end

local function is_over_button(x, y, button_x, button_y, width, height)
	return x >= button_x and x < button_x + width and
		y >= button_y and y < button_y + height
end

local function middle_buttons_origin()
	local group_width = #middle_buttons * middle_button_size +
		(#middle_buttons - 1) * middle_button_spacing
	local first_button_x = panel_x + (panel_width - group_width) / 2
	local button_y = middle_panel_y + middle_button_top_padding
	return first_button_x, button_y
end

function ui.action_button_at(x, y)
	local first_button_x, button_y = middle_buttons_origin()
	for index = 1, #middle_buttons do
		local button_x = first_button_x +
			(index - 1) * (middle_button_size + middle_button_spacing)
		if is_over_button(
			x,
			y,
			button_x,
			button_y,
			middle_button_size,
			middle_button_size
		) then
			local button = middle_buttons[index]
			return button.id, button.announcement
		end
	end
	return nil
end

function ui.is_over_restart_button(x, y)
	return is_over_button(
		x,
		y,
		restart_button_x,
		restart_button_y,
		restart_button_width,
		restart_button_height
	)
end

local function draw_panel(y, height, border_color)
	rrectfill(
		panel_x,
		y,
		panel_width,
		height,
		panel_radius,
		score_panel_fill_color
	)
	rrect(
		panel_x,
		y,
		panel_width,
		height,
		panel_radius,
		border_color
	)
end

function ui.draw_button(x, y, width, height, text)
	local hovered = is_over_button(
		mouse_x,
		mouse_y,
		x,
		y,
		width,
		height
	)
	local button_key = x..":"..y..":"..width..":"..height
	if hovered and not button_hover_states[button_key] then
		sfx(0)
	end
	button_hover_states[button_key] = hovered
	local clicked = hovered and mouse_buttons == 0x1
	local fill_color = ui.button.color
	if clicked then
		fill_color = ui.button.click_color
	elseif hovered then
		fill_color = ui.button.hover_color
	end
	rrectfill(
		x,
		y,
		width,
		height,
		ui.button.radius,
		fill_color
	)
	rrect(
		x,
		y,
		width,
		height,
		ui.button.radius,
		ui.button.border_color
	)
	if text then
		local text_width = print(text, 0, -1000)
		print(
			text,
			x + (width - text_width) / 2,
			y + 3,
			7
		)
	end
end

function ui.play_button_click()
	sfx(3)
end

local function draw_middle_buttons(mouse_x, mouse_y)
	local first_button_x, button_y = middle_buttons_origin()
	local hovered_button = nil
	local hovered_button_x = nil
	for index = 1, #middle_buttons do
		local button = middle_buttons[index]
		local button_x = first_button_x +
			(index - 1) * (middle_button_size + middle_button_spacing)
		local hovered = is_over_button(
			mouse_x,
			mouse_y,
			button_x,
			button_y,
			middle_button_size,
			middle_button_size
		)
		if hovered then
			hovered_button = button
			hovered_button_x = button_x
		end
		ui.draw_button(
			button_x,
			button_y,
			middle_button_size,
			middle_button_size
		)
		spr(
			button.sprite,
			button_x + button.sprite_x,
			button_y + button.sprite_y
		)
	end
	return hovered_button, hovered_button_x, button_y
end

local function draw_tooltip(text, button_x, button_y)
	local text_width = print(text, 0, -1000)
	local tooltip_width = text_width + ui.tooltip_padding_x * 2
	local tooltip_height = ui.tooltip_text_height +
		ui.tooltip_padding_y * 2
	local tooltip_x = button_x +
		(middle_button_size - tooltip_width) / 2
	local minimum_x = panel_x + ui.tooltip_panel_margin
	local maximum_x = panel_x + panel_width -
		ui.tooltip_panel_margin - tooltip_width
	if tooltip_x < minimum_x then
		tooltip_x = minimum_x
	elseif tooltip_x > maximum_x then
		tooltip_x = maximum_x
	end
	local tooltip_y = button_y + middle_button_size +
		ui.tooltip_offset_y

	rrectfill(
		tooltip_x,
		tooltip_y,
		tooltip_width,
		tooltip_height,
		ui.tooltip_radius,
		ui.tooltip_fill_color
	)
	rrect(
		tooltip_x,
		tooltip_y,
		tooltip_width,
		tooltip_height,
		ui.tooltip_radius,
		ui.tooltip_border_color
	)
	print(
		text,
		tooltip_x + ui.tooltip_padding_x,
		tooltip_y + ui.tooltip_padding_y,
		ui.tooltip_text_color
	)
end

local function draw_capture_list(captures, x, y)
	local capture_counts = {0, 0, 0}
	for piece_type in all(captures) do
		capture_counts[piece_type] += 1
	end
	for piece_type = 1, 3 do
		local group_x = x + (piece_type - 1) * capture_group_spacing
		spr(piece_type, group_x, y)
		print(
			capture_counts[piece_type],
			group_x + capture_count_offset_x,
			y + capture_count_offset_y,
			7
		)
	end
end

local function draw_right_panels(game, mouse_x, mouse_y)
	draw_panel(
		north_panel_y,
		score_panel_height,
		game.turn == "cpu" and turn_highlight_color or
			score_panel_border_color
	)
	draw_panel(
		south_panel_y,
		score_panel_height,
		game.turn == "player" and turn_highlight_color or
			score_panel_border_color
	)
	draw_panel(
		middle_panel_y,
		middle_panel_height,
		score_panel_border_color
	)
	local hovered_button, hovered_button_x, hovered_button_y =
		draw_middle_buttons(mouse_x, mouse_y)

	if not game.over then
		local turn_text = game.turn == "cpu" and "CPU's turn" or
			"Player's turn"
		local turn_text_width = print(turn_text, 0, -1000)
		local turn_text_y = game.turn == "cpu" and
			north_panel_y + score_panel_height + 2 or
			south_panel_y - 9
		print(
			turn_text,
			panel_x + (panel_width - turn_text_width) / 2,
			turn_text_y,
			7
		)
	end

	local content_x = panel_x + score_panel_padding
	local north_label_y = north_panel_y + score_panel_padding
	local south_label_y = south_panel_y + score_panel_padding
	print(
		"CPU score: "..game.cpu_score,
		content_x + score_text_offset_x,
		north_label_y,
		7
	)
	draw_capture_list(game.cpu_captures, content_x, north_label_y + 8)
	print(
		"Player score: "..game.player_score,
		content_x + score_text_offset_x,
		south_label_y,
		7
	)
	draw_capture_list(game.player_captures, content_x, south_label_y + 8)
	return hovered_button, hovered_button_x, hovered_button_y
end

local function announcement_for_game(game)
	if game.over then
		return nil
	end
	if game.non_capture_move_count < deadlock_warning_start then
		return announcement_lines
	end

	local moves_remaining =
		deadlock_move_limit - game.non_capture_move_count
	return {
		"Game ends in "..moves_remaining,
		moves_remaining == 1 and "move without" or "moves without",
		"a capture"
	}
end

local function draw_announcement(game)
	local lines = announcement_for_game(game)
	if not lines or #lines == 0 then
		return
	end

	local _, button_y = middle_buttons_origin()
	local area_top = button_y + middle_button_size +
		ui.announcement_top_padding
	local area_bottom = middle_panel_y + middle_panel_height -
		ui.announcement_bottom_padding
	local line_step = ui.announcement_text_height +
		ui.announcement_line_spacing
	local text_height = ui.announcement_text_height +
		(#lines - 1) * line_step
	local text_y = flr(
		area_top + (area_bottom - area_top - text_height) / 2
	)
	for line in all(lines) do
		local text_width = print(line, 0, -1000)
		print(
			line,
			panel_x + (panel_width - text_width) / 2,
			text_y,
			ui.announcement_text_color
		)
		text_y += line_step
	end
end

local function draw_game_over_panel(game)
	if not game.over then
		return
	end

	rrectfill(
		game_over_panel_x,
		game_over_panel_y,
		game_over_panel_width,
		game_over_panel_height,
		4,
		1
	)
	rrect(
		game_over_panel_x,
		game_over_panel_y,
		game_over_panel_width,
		game_over_panel_height,
		4,
		7
	)
	local winner_text = "Draw"
	if game.winner then
		local winner_name = game.winner == "cpu" and "CPU" or "Player"
		winner_text = winner_name.. " wins!"
	end
	local winner_text_width = print(winner_text, 0, -1000)
	print(
		winner_text,
		game_over_panel_x +
			(game_over_panel_width - winner_text_width) / 2,
		game_over_panel_y + 5,
		7
	)
	ui.draw_button(
		restart_button_x,
		restart_button_y,
		restart_button_width,
		restart_button_height,
		"Restart"
	)
end

function ui.draw_game_ui(game)
	local hovered_button, hovered_button_x, hovered_button_y =
		draw_right_panels(game, mouse_x, mouse_y)
	draw_announcement(game)
	if hovered_button and not game.over then
		draw_tooltip(
			hovered_button.name,
			hovered_button_x,
			hovered_button_y
		)
	end
	draw_game_over_panel(game)
end
