-- martian chess leaderboard screen

leaderboard = {}
highscores = {}

local background_color = 1
local screen_width = 190
local title_text = "Highest scoring wins"
local title_offset_x = 10
local title_y = 8
local back_button_x = 4
local back_button_y = 4
local back_button_width = 42
local back_button_height = 14
local entry_icon_x = 4
local entry_text_x = 24
local entry_score_margin_right = 14
local first_entry_y = 22
local entry_spacing = 18
local entry_text_offset_y = 5
local entries_per_page = 7
local maximum_entry_count = 70
local page_button_y = 152
local previous_button_x = 46
local previous_button_width = 50
local next_button_x = 102
local next_button_width = 42
local page_button_height = 14
local current_page = 1
local previous_left_click = false
local return_update = nil
local return_draw = nil

local function is_left_click(mouse_buttons)
	return mouse_buttons == 0x1
end

local function is_over_button(x, y, button_x, button_y, width, height)
	return x >= button_x and x < button_x + width and
		y >= button_y and y < button_y + height
end

local function is_over_back_button(x, y)
	return is_over_button(
		x,
		y,
		back_button_x,
		back_button_y,
		back_button_width,
		back_button_height
	)
end

local function leaderboard_entry_count()
	return maximum_entry_count
end

local function leaderboard_entry_at(index)
	return highscores[index]
end

local function leaderboard_page_count()
	local entry_count = leaderboard_entry_count()
	return max(1, flr((entry_count + entries_per_page - 1) /
		entries_per_page))
end

function leaderboard.submit_score(score)
	scoresub("martian_chess_highscores", score)
end

function leaderboard.submit_player_victory(game)
	if game.over and game.winner == "player" then
		leaderboard.submit_score(game.player_score)
	end
end

function init_leaderboard()
	highscores = {}
	current_page = 1
end

function leaderboard.open(game_update, game_draw)
	return_update = game_update
	return_draw = game_draw
	init_leaderboard()
	_update = update_leaderboard
	_draw = draw_leaderboard
end

function update_leaderboard()
	mouse_x, mouse_y, mouse_buttons = mouse()
	local left_click = is_left_click(mouse_buttons)
	if left_click and not previous_left_click then
		if is_over_back_button(mouse_x, mouse_y) then
			ui.play_button_click()
			_update = return_update
			_draw = return_draw
		elseif is_over_button(
			mouse_x,
			mouse_y,
			previous_button_x,
			page_button_y,
			previous_button_width,
			page_button_height
		) then
			ui.play_button_click()
			current_page = max(1, current_page - 1)
		elseif is_over_button(
			mouse_x,
			mouse_y,
			next_button_x,
			page_button_y,
			next_button_width,
			page_button_height
		) then
			ui.play_button_click()
			current_page = min(
				leaderboard_page_count(),
				current_page + 1
			)
		end
	end
	previous_left_click = left_click

	-- check online scores
	local latest_scores = scoresub("martian_chess_highscores")
	if latest_scores then
		highscores = latest_scores
		current_page = min(current_page, leaderboard_page_count())
	end
end

local function draw_leaderboard_entry(entry, rank, y)
	local padding = rank < 10 and " " or ""
	if not entry then
		print(padding..rank, entry_text_x, y + entry_text_offset_y, 7)
		return
	end
	spr(entry.icon, entry_icon_x, y)
	local rounded_score = flr(entry.score + 0.5)
	local padding = rank < 10 and " " or ""
	local player_text = padding..rank.." - "..entry.username
	local score_text = ""..rounded_score
	local score_width = print(score_text, 0, -1000)
	print(
		player_text,
		entry_text_x,
		y + entry_text_offset_y,
		7
	)
	print(
		score_text,
		screen_width - entry_score_margin_right - score_width,
		y + entry_text_offset_y,
		7
	)
end

function draw_leaderboard()
	cls(background_color)
	ui.draw_button(
		back_button_x,
		back_button_y,
		back_button_width,
		back_button_height,
		"Back"
	)
	local title_width = print(title_text, 0, -1000)
	print(
		title_text,
		(screen_width - title_width) / 2 + title_offset_x,
		title_y,
		7
	)

	-- render leaderboard
	local first_rank = (current_page - 1) * entries_per_page + 1
	local last_rank = min(
		first_rank + entries_per_page - 1,
		leaderboard_entry_count()
	)
	for rank = first_rank, last_rank do
		local entry = leaderboard_entry_at(rank)
		draw_leaderboard_entry(
			entry,
			rank,
			first_entry_y +
				(rank - first_rank) * entry_spacing
		)
	end

	ui.draw_button(
		previous_button_x,
		page_button_y,
		previous_button_width,
		page_button_height,
		"Previous"
	)
	ui.draw_button(
		next_button_x,
		page_button_y,
		next_button_width,
		page_button_height,
		"Next"
	)
end
