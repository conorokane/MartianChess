-- martian chess
-- by Conor O'Kane

include("src/cpu_player.lua")
include("src/effects.lua")

local board_columns = 4
local board_rows = 8
local zone_rows = 4
local border_size = 4
local side_panel_width = 102
local panel_offset_x = 2
local canal_height = 4
local canal_color = 1
local tile_width = 20
local tile_height = 20
local piece_width = 18
local piece_height = 18
local piece_offset_x = (tile_width - piece_width) / 2
local piece_offset_y = (tile_height - piece_height) / 2
local move_duration_frames = 20
local cpu_move_delay_frames = 60
local deadlock_start_after_move = 40
local deadlock_move_limit = 7
local deadlock_warning_start = 3
local capture_group_spacing = 30
local capture_count_offset_x = piece_width + 2
local capture_count_offset_y = 5
local score_panel_height = 34
local score_panel_padding = 4
local score_text_offset_x = 2
local score_panel_radius = 4
local score_panel_fill_color = 2
local score_panel_border_color = 25
local turn_highlight_color = 10

local pawn = 1
local drone = 2
local queen = 3
local highlight_sprite = 6
local selected_dark_sprite = 8
local selected_light_sprite = 9
local previous_move_dark_sprite = 10
local previous_move_light_sprite = 11
local valid_move_dark_sprite = 12
local valid_move_light_sprite = 13
local dark_board_tile = 4

local board_width = 0
local board_tiles = nil
local board_x = border_size
local board_origin_y = border_size
local canal_y = 0
local bottom_board_y = 0
local window_width = 0
local window_height = 0
local game_over_panel_x = 0
local game_over_panel_y = 0
local game_over_panel_width = 0
local game_over_panel_height = 0
local restart_button_x = 1
local restart_button_y = 0
local restart_button_width = 42
local restart_button_height = 14
local restart_hovered = false
local hover_column = nil
local hover_row = nil
local selected_column = nil
local selected_row = nil
local valid_moves = {}
local previous_left_click = false
local return_restriction = nil
local move_animation = nil
local previous_move = nil
local cpu_move_delay_elapsed = 0

local cpu = "cpu"
local player = "player"
local next_starting_player = player

local game = {
	board = {},
	turn = player,
	cpu_score = 0,
	player_score = 0,
	cpu_captures = {},
	player_captures = {},
	move_count = 0,
	non_capture_move_count = 0,
	over = false,
	winner = nil,
	empty_player = nil
}

local function place_piece(column, row, piece_type, owner)
	game.board[row + 1][column + 1] = {
		type = piece_type,
		owner = owner
	}
end

local function initialize_board()
	game.board = {}
	game.turn = next_starting_player
	next_starting_player = next_starting_player == player and cpu or player
	game.cpu_score = 0
	game.player_score = 0
	game.cpu_captures = {}
	game.player_captures = {}
	game.move_count = 0
	game.non_capture_move_count = 0
	game.over = false
	game.winner = nil
	game.empty_player = nil
	move_animation = nil
	previous_move = nil
	cpu_move_delay_elapsed = 0
	return_restriction = nil
	selected_column = nil
	selected_row = nil
	valid_moves = {}
	hover_column = nil
	hover_row = nil
	restart_hovered = false
	for row = 1, board_rows do
		game.board[row] = {}
	end

	-- CPU setup in the top-left corner from the player's viewpoint.
	place_piece(0, 0, queen, cpu)
	place_piece(1, 0, queen, cpu)
	place_piece(2, 0, drone, cpu)
	place_piece(0, 1, queen, cpu)
	place_piece(1, 1, drone, cpu)
	place_piece(2, 1, pawn, cpu)
	place_piece(0, 2, drone, cpu)
	place_piece(1, 2, pawn, cpu)
	place_piece(2, 2, pawn, cpu)

	-- Player setup is the 180-degree rotation in the bottom-right corner.
	place_piece(1, 5, pawn, player)
	place_piece(2, 5, pawn, player)
	place_piece(3, 5, drone, player)
	place_piece(1, 6, pawn, player)
	place_piece(2, 6, drone, player)
	place_piece(3, 6, queen, player)
	place_piece(1, 7, drone, player)
	place_piece(2, 7, queen, player)
	place_piece(3, 7, queen, player)
end

local function initialize_layout()
	local map_layers = fetch("/ram/cart/map/0.map")
	local board_layer = map_layers[1]

	board_tiles = board_layer.bmp
	board_width = board_columns * tile_width
	canal_y = board_origin_y + zone_rows * tile_height
	bottom_board_y = canal_y + canal_height
	window_width = border_size + board_width + border_size + side_panel_width
	window_height = border_size + board_rows * tile_height + canal_height + border_size
	game_over_panel_x = board_x + board_width + border_size / 2 +
		panel_offset_x
	game_over_panel_width = window_width - game_over_panel_x - border_size
	game_over_panel_height = zone_rows * tile_height / 2
	local north_panel_bottom = board_origin_y + score_panel_height
	local board_bottom_y = bottom_board_y + zone_rows * tile_height
	local south_panel_y = board_bottom_y - score_panel_height
	game_over_panel_y = north_panel_bottom +
		(south_panel_y - north_panel_bottom - game_over_panel_height) / 2
	restart_button_x = game_over_panel_x +
		(game_over_panel_width - restart_button_width) / 2
	restart_button_y = game_over_panel_y + game_over_panel_height -
		restart_button_height - 4
	effects.initialize_canal_sparkles(
		board_x,
		canal_y,
		board_width,
		canal_height
	)
end

local function screen_y_for_row(row)
	local y = board_origin_y + row * tile_height
	if row >= zone_rows then
		y = y + canal_height
	end
	return y
end

local function is_on_board(column, row)
	return column >= 0 and column < board_columns and
		row >= 0 and row < board_rows
end

local function owner_for_row(row)
	if row < zone_rows then
		return cpu
	end
	return player
end

local function has_piece_type_in_zone(owner, piece_type)
	local first_row = owner == cpu and 0 or zone_rows
	local last_row = first_row + zone_rows - 1
	for row = first_row, last_row do
		for column = 0, board_columns - 1 do
			local piece = game.board[row + 1][column + 1]
			if piece and piece.type == piece_type then
				return true
			end
		end
	end
	return false
end

local function promotion_result(moving_piece, target_piece, destination_row)
	if owner_for_row(destination_row) != game.turn then
		return nil
	end

	local is_pawn_drone_pair =
		(moving_piece.type == pawn and target_piece.type == drone) or
		(moving_piece.type == drone and target_piece.type == pawn)
	if is_pawn_drone_pair and not has_piece_type_in_zone(game.turn, queen) then
		return queen
	end

	if moving_piece.type == pawn and target_piece.type == pawn and
		not has_piece_type_in_zone(game.turn, drone) then
		return drone
	end

	return nil
end

local function is_immediate_return(piece, column, row)
	return return_restriction and
		return_restriction.piece == piece and
		return_restriction.column == column and
		return_restriction.row == row
end

local function add_valid_move(column, row, promotion)
	valid_moves[#valid_moves + 1] = {
		column = column,
		row = row,
		promotion = promotion
	}
end

local function scan_moves_in_direction(piece, from_column, from_row, dx, dy, distance)
	for step = 1, distance do
		local column = from_column + dx * step
		local row = from_row + dy * step
		if not is_on_board(column, row) then
			break
		end

		local target = game.board[row + 1][column + 1]
		local promotion = nil
		local can_land = target == nil
		if target then
			if owner_for_row(row) != game.turn then
				can_land = true
			else
				promotion = promotion_result(piece, target, row)
				can_land = promotion != nil
			end
		end

		if can_land and not is_immediate_return(piece, column, row) then
			add_valid_move(column, row, promotion)
		end

		if target then
			break
		end
	end
end

local function calculate_valid_moves(column, row)
	valid_moves = {}
	local piece = game.board[row + 1][column + 1]
	if not piece then
		return
	end

	if piece.type == pawn then
		scan_moves_in_direction(piece, column, row, -1, -1, 1)
		scan_moves_in_direction(piece, column, row, 1, -1, 1)
		scan_moves_in_direction(piece, column, row, -1, 1, 1)
		scan_moves_in_direction(piece, column, row, 1, 1, 1)
	elseif piece.type == drone then
		scan_moves_in_direction(piece, column, row, -1, 0, 2)
		scan_moves_in_direction(piece, column, row, 1, 0, 2)
		scan_moves_in_direction(piece, column, row, 0, -1, 2)
		scan_moves_in_direction(piece, column, row, 0, 1, 2)
	elseif piece.type == queen then
		for dy = -1, 1 do
			for dx = -1, 1 do
				if dx != 0 or dy != 0 then
					scan_moves_in_direction(piece, column, row, dx, dy, board_rows)
				end
			end
		end
	end
end

local function clear_selection()
	selected_column = nil
	selected_row = nil
	valid_moves = {}
end

local function deselect_piece()
	if selected_column != nil then
		sfx(2)
	end
	clear_selection()
end

local function valid_move_at(column, row)
	for move in all(valid_moves) do
		if move.column == column and move.row == row then
			return move
		end
	end
	return nil
end

local function zone_is_empty(owner)
	local first_row = owner == cpu and 0 or zone_rows
	local last_row = first_row + zone_rows - 1
	for row = first_row, last_row do
		for column = 0, board_columns - 1 do
			if game.board[row + 1][column + 1] then
				return false
			end
		end
	end
	return true
end

local function check_game_over(moving_player)
	local north_empty = zone_is_empty(cpu)
	local south_empty = zone_is_empty(player)
	if not north_empty and not south_empty then
		return false
	end

	game.over = true
	game.empty_player = north_empty and cpu or player
	if game.cpu_score > game.player_score then
		game.winner = cpu
	elseif game.player_score > game.cpu_score then
		game.winner = player
	else
		game.winner = moving_player
	end
	return true
end

local function end_deadlock()
	game.over = true
	game.empty_player = nil
	if game.cpu_score > game.player_score then
		game.winner = cpu
	elseif game.player_score > game.cpu_score then
		game.winner = player
	else
		game.winner = nil
	end
end

local function finish_move()
	local move = move_animation.move
	local piece = move_animation.piece
	local target = game.board[move.row + 1][move.column + 1]
	local was_capture = target and not move.promotion
	local from_column = move_animation.from_column
	local from_row = move_animation.from_row
	if was_capture then
		if game.turn == player then
			game.player_score += target.type
			game.player_captures[#game.player_captures + 1] = target.type
		else
			game.cpu_score += target.type
			game.cpu_captures[#game.cpu_captures + 1] = target.type
		end
	end
	game.board[from_row + 1][from_column + 1] = nil
	if move.promotion then
		piece.type = move.promotion
	end
	game.board[move.row + 1][move.column + 1] = piece
	piece.owner = owner_for_row(move.row)
	previous_move = {
		from_column = from_column,
		from_row = from_row,
		column = move.column,
		row = move.row
	}

	if owner_for_row(from_row) != owner_for_row(move.row) then
		return_restriction = {
			piece = piece,
			column = from_column,
			row = from_row
		}
	else
		return_restriction = nil
	end

	game.move_count += 1
	if game.move_count > deadlock_start_after_move then
		if was_capture then
			game.non_capture_move_count = 0
		else
			game.non_capture_move_count += 1
		end
	else
		game.non_capture_move_count = 0
	end

	if move.promotion == drone then
		sfx(13)
	elseif move.promotion == queen then
		sfx(14)
	elseif was_capture then
		sfx(target.type + 3)
	elseif game.non_capture_move_count >= deadlock_warning_start and
		game.non_capture_move_count <= 7 then
		sfx(game.non_capture_move_count + 5)
	else
		sfx(2)
	end

	local moving_player = game.turn
	move_animation = nil
	local game_ended = check_game_over(moving_player)
	if not game_ended and
		game.non_capture_move_count >= deadlock_move_limit then
		end_deadlock()
		game_ended = true
	end
	if not game_ended then
		game.turn = game.turn == player and cpu or player
	end
end

local function begin_move(move)
	local piece = game.board[selected_row + 1][selected_column + 1]
	local start_x = board_x + selected_column * tile_width + piece_offset_x
	local start_y = screen_y_for_row(selected_row) + piece_offset_y
	move_animation = {
		piece = piece,
		move = move,
		from_column = selected_column,
		from_row = selected_row,
		start_x = start_x,
		start_y = start_y,
		x = start_x,
		y = start_y,
		target_x = board_x + move.column * tile_width + piece_offset_x,
		target_y = screen_y_for_row(move.row) + piece_offset_y,
		elapsed_frames = 0
	}
	sfx(3)
	clear_selection()
	hover_column = nil
	hover_row = nil
end

local function update_move_animation()
	move_animation.elapsed_frames += 1
	local progress = move_animation.elapsed_frames / move_duration_frames
	if progress >= 1 then
		move_animation.x = move_animation.target_x
		move_animation.y = move_animation.target_y
		finish_move()
		return
	end

	move_animation.x = move_animation.start_x +
		(move_animation.target_x - move_animation.start_x) * progress
	move_animation.y = move_animation.start_y +
		(move_animation.target_y - move_animation.start_y) * progress
end

local function handle_board_click()
	if hover_column == nil or hover_row == nil then
		deselect_piece()
		return
	end
	if hover_column == selected_column and hover_row == selected_row then
		deselect_piece()
		return
	end

	local move = valid_move_at(hover_column, hover_row)
	if selected_column != nil and move then
		begin_move(move)
		return
	end

	local piece = game.board[hover_row + 1][hover_column + 1]
	if piece and owner_for_row(hover_row) == game.turn then
		selected_column = hover_column
		selected_row = hover_row
		calculate_valid_moves(selected_column, selected_row)
		sfx(1)
	else
		deselect_piece()
	end
end

local function collect_cpu_moves()
	local cpu_moves = {}
	local cpu_piece_count = 0
	for row = 0, zone_rows - 1 do
		for column = 0, board_columns - 1 do
			if game.board[row + 1][column + 1] then
				cpu_piece_count += 1
			end
		end
	end
	for row = 0, zone_rows - 1 do
		for column = 0, board_columns - 1 do
			local piece = game.board[row + 1][column + 1]
			if piece then
				local source_piece_is_exposed =
					cpu_player.opponent_can_capture_piece(
						game.board,
						game.turn,
						column,
						row
					)
				calculate_valid_moves(column, row)
				for move in all(valid_moves) do
					local crosses_canal = owner_for_row(row) !=
						owner_for_row(move.row)
					local capture_value = cpu_player.evaluate_capture_value(
						game.board,
						game.turn,
						column,
						row,
						move
					)
					cpu_moves[#cpu_moves + 1] = {
						from_column = column,
						from_row = row,
						column = move.column,
						row = move.row,
						promotion = move.promotion,
						capture_value = capture_value,
						source_piece_value = piece.type,
						source_piece_is_exposed = source_piece_is_exposed,
						crosses_canal = crosses_canal,
						moves_last_piece_over_canal =
							cpu_piece_count == 1 and crosses_canal,
						moved_piece_is_exposed = capture_value == nil and
							cpu_player.opponent_can_capture_moved_piece(
								game.board,
								game.turn,
								column,
								row,
								move
							)
					}
				end
			end
		end
	end
	valid_moves = {}
	return cpu_moves
end

local function start_cpu_move()
	local move = cpu_player.choose_move(
		collect_cpu_moves(),
		game.cpu_score,
		game.player_score
	)
	if not move then
		return
	end

	selected_column = move.from_column
	selected_row = move.from_row
	begin_move(move)
end

local function draw_board()
	-- Map 0 stores one 4x4 board half. Draw it on the 20-pixel grid
	-- above and below the canal.
	for row = 0, zone_rows - 1 do
		for column = 0, board_columns - 1 do
			local tile = board_tiles:get(column, row)
			local x = board_x + column * tile_width
			spr(tile, x, board_origin_y + row * tile_height)
			spr(tile, x, bottom_board_y + row * tile_height)
		end
	end

	rectfill(
		board_x,
		canal_y,
		board_x + board_width - 1,
		canal_y + canal_height - 1,
		canal_color
	)
end

local function draw_selected_piece_background()
	if selected_column == nil or selected_row == nil then
		return
	end

	local map_row = selected_row % zone_rows
	local tile = board_tiles:get(selected_column, map_row)
	local sprite = tile == dark_board_tile and
		selected_dark_sprite or selected_light_sprite
	spr(
		sprite,
		board_x + selected_column * tile_width,
		screen_y_for_row(selected_row)
	)
end

local function draw_previous_move_background()
	if not previous_move then
		return
	end

	local function draw_light_square(column, row)
		local map_row = row % zone_rows
		local tile = board_tiles:get(column, map_row)
		local sprite = tile == dark_board_tile and
			previous_move_dark_sprite or previous_move_light_sprite
		spr(
			sprite,
			board_x + column * tile_width,
			screen_y_for_row(row)
		)
	end

	draw_light_square(previous_move.from_column, previous_move.from_row)
	draw_light_square(previous_move.column, previous_move.row)
end

local function draw_pieces()
	for row = 0, board_rows - 1 do
		for column = 0, board_columns - 1 do
			local piece = game.board[row + 1][column + 1]
			local is_moving_piece = move_animation and
				column == move_animation.from_column and
				row == move_animation.from_row
			if piece and not is_moving_piece then
				spr(
					piece.type,
					board_x + column * tile_width + piece_offset_x,
					screen_y_for_row(row) + piece_offset_y
				)
			end
		end
	end
end

local function draw_move_animation()
	if not move_animation then
		return
	end

	spr(
		move_animation.piece.type,
		move_animation.x,
		move_animation.y
	)
end

local function draw_valid_moves()
	for move in all(valid_moves) do
		local map_row = move.row % zone_rows
		local tile = board_tiles:get(move.column, map_row)
		local sprite = tile == dark_board_tile and
			valid_move_dark_sprite or valid_move_light_sprite
		spr(
			sprite,
			board_x + move.column * tile_width,
			screen_y_for_row(move.row)
		)
	end
end

local function draw_capture_list(captures, x, y)
	local capture_counts = {0, 0, 0}
	for piece_type in all(captures) do
		capture_counts[piece_type] += 1
	end
	for piece_type = pawn, queen do
		local group_x = x + (piece_type - 1) * capture_group_spacing
		spr(
			piece_type,
			group_x,
			y
		)
		print(
			capture_counts[piece_type],
			group_x + capture_count_offset_x,
			y + capture_count_offset_y,
			7
		)
	end
end

local function draw_captured_pieces()
	local panel_x = board_x + board_width + border_size / 2 +
		panel_offset_x
	local panel_width = window_width - panel_x - border_size
	local north_panel_y = board_origin_y
	local board_bottom_y = bottom_board_y + zone_rows * tile_height
	local south_panel_y = board_bottom_y - score_panel_height

	local function draw_score_panel(y, owner)
		rrectfill(
			panel_x,
			y,
			panel_width,
			score_panel_height,
			score_panel_radius,
			score_panel_fill_color
		)
		rrect(
			panel_x,
			y,
			panel_width,
			score_panel_height,
			score_panel_radius,
			game.turn == owner and turn_highlight_color or
				score_panel_border_color
		)
	end

	draw_score_panel(north_panel_y, cpu)
	draw_score_panel(south_panel_y, player)
	if not game.over then
		local turn_text = game.turn == cpu and "CPU's turn" or
			"Player's turn"
		local turn_text_width = print(turn_text, 0, -1000)
		local turn_text_y = game.turn == cpu and
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
	draw_capture_list(
		game.cpu_captures,
		content_x,
		north_label_y + 8
	)
	print(
		"Player score: "..game.player_score,
		content_x + score_text_offset_x,
		south_label_y,
		7
	)
	draw_capture_list(
		game.player_captures,
		content_x,
		south_label_y + 8
	)
end

local function draw_deadlock_countdown()
	if game.over or
		game.non_capture_move_count < deadlock_warning_start then
		return
	end

	local moves_remaining =
		deadlock_move_limit - game.non_capture_move_count
	local x = board_x + board_width + border_size
	print(
		"Game ends in "..moves_remaining,
		x,
		canal_y - 11,
		7
	)
	print(
		moves_remaining == 1 and "move without" or "moves without",
		x,
		canal_y - 3,
		7
	)
	print(
		"a capture",
		x,
		canal_y + 5,
		7
	)
end

local function is_over_restart_button(x, y)
	return x >= restart_button_x and
		x < restart_button_x + restart_button_width and
		y >= restart_button_y and
		y < restart_button_y + restart_button_height
end

local function draw_game_over_panel()
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
		local winner_name = game.winner == cpu and "CPU" or "Player"
		winner_text = winner_name.. " wins!"
	end
	local winner_text_width = print(winner_text, 0, -1000)
	print(
		winner_text,
		game_over_panel_x + (game_over_panel_width - winner_text_width) / 2,
		game_over_panel_y + 5,
		7
	)
	rrectfill(
		restart_button_x,
		restart_button_y,
		restart_button_width,
		restart_button_height,
		4,
		restart_hovered and 25 or 5
	)
	rrect(
		restart_button_x,
		restart_button_y,
		restart_button_width,
		restart_button_height,
		4,
		7
	)
	local restart_text = "Restart"
	local restart_text_width = print(restart_text, 0, -1000)
	print(
		restart_text,
		restart_button_x + (restart_button_width - restart_text_width) / 2 + 1,
		restart_button_y + 3,
		7
	)
end

local function hovered_tile_is_visible()
	if move_animation or hover_column == nil or hover_row == nil then
		return false
	end
	if selected_column != nil then
		return game.turn == player and
			valid_move_at(hover_column, hover_row) != nil
	end
	return hover_row >= zone_rows
end

local function update_hovered_tile()
	local mouse_x, mouse_y = mouse()
	local previous_hover_column = hover_column
	local previous_hover_row = hover_row
	hover_column = nil
	hover_row = nil

	if mouse_x < board_x or mouse_x >= board_x + board_width then
		return
	end

	hover_column = flr((mouse_x - board_x) / tile_width)
	if mouse_y >= board_origin_y and mouse_y < canal_y then
		hover_row = flr((mouse_y - board_origin_y) / tile_height)
	elseif mouse_y >= bottom_board_y and
		mouse_y < bottom_board_y + zone_rows * tile_height then
		hover_row = zone_rows + flr((mouse_y - bottom_board_y) / tile_height)
	else
		hover_column = nil
	end

	if hovered_tile_is_visible() and
		(hover_column != previous_hover_column or
			hover_row != previous_hover_row) then
		sfx(0)
	end
end

local function draw_hovered_tile()
	if not hovered_tile_is_visible() then
		return
	end

	spr(
		highlight_sprite,
		board_x + hover_column * tile_width,
		screen_y_for_row(hover_row)
	)
end

function _init()
	initialize_layout()
	window{
		width = window_width,
		height = window_height,
		resizeable = false,
		title = "Martian Chess"
	}
	initialize_board()
end

function _update()
	local mouse_x, mouse_y, mouse_buttons = mouse()
	local left_click = type(mouse_buttons) == "number" and mouse_buttons % 2 == 1
	effects.update_canal_sparkles()
	if move_animation then
		update_move_animation()
		previous_left_click = left_click
		return
	end
	if game.over then
		restart_hovered = is_over_restart_button(mouse_x, mouse_y)
		if restart_hovered and left_click and not previous_left_click then
			sfx(0)
			initialize_board()
		end
		previous_left_click = left_click
		return
	end
	if game.turn == cpu then
		cpu_move_delay_elapsed += 1
		if cpu_move_delay_elapsed < cpu_move_delay_frames then
			previous_left_click = left_click
			return
		end
		cpu_move_delay_elapsed = 0
		start_cpu_move()
		previous_left_click = left_click
		return
	end

	cpu_move_delay_elapsed = 0
	update_hovered_tile()
	if left_click and not previous_left_click then
		handle_board_click()
	end
	previous_left_click = left_click
end

function _draw()
	cls(21)
	draw_board()
	effects.draw_canal_sparkles()
	draw_previous_move_background()
	draw_selected_piece_background()
	draw_valid_moves()
	draw_hovered_tile()
	draw_pieces()
	draw_move_animation()
	draw_captured_pieces()
	draw_deadlock_countdown()
	draw_game_over_panel()
end
