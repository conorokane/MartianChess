-- martian chess cpu player

cpu_player = {}

local board_columns = 4
local board_rows = 8
local zone_rows = 4

local pawn = 1
local drone = 2
local queen = 3

local cpu = "cpu"
local player = "player"

local function choose_random_move(moves)
	if #moves == 0 then
		return nil
	end
	return moves[flr(rnd(#moves)) + 1]
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

local function zone_will_be_empty_after_move(
	board,
	owner,
	from_column,
	from_row
)
	local first_row = owner == cpu and 0 or zone_rows
	local last_row = first_row + zone_rows - 1
	for row = first_row, last_row do
		for column = 0, board_columns - 1 do
			local is_departing_square =
				column == from_column and row == from_row
			if not is_departing_square and board[row + 1][column + 1] then
				return false
			end
		end
	end
	return true
end

local function highest_capture_value_for_piece(
	board,
	piece_type,
	from_column,
	from_row,
	owner,
	empty_column,
	empty_row
)
	local highest_value = 0

	local function scan_direction(dx, dy, distance)
		for step = 1, distance do
			local column = from_column + dx * step
			local row = from_row + dy * step
			if not is_on_board(column, row) then
				break
			end

			-- An empty square can be supplied when evaluating the board
			-- after a hypothetical move.
			local target = nil
			if column != empty_column or row != empty_row then
				target = board[row + 1][column + 1]
			end
			if target then
				if owner_for_row(row) != owner and
					target.type > highest_value then
					highest_value = target.type
				end
				break
			end
		end
	end

	if piece_type == pawn then
		scan_direction(-1, -1, 1)
		scan_direction(1, -1, 1)
		scan_direction(-1, 1, 1)
		scan_direction(1, 1, 1)
	elseif piece_type == drone then
		scan_direction(-1, 0, 2)
		scan_direction(1, 0, 2)
		scan_direction(0, -1, 2)
		scan_direction(0, 1, 2)
	elseif piece_type == queen then
		for dy = -1, 1 do
			for dx = -1, 1 do
				if dx != 0 or dy != 0 then
					scan_direction(dx, dy, board_rows)
				end
			end
		end
	end

	return highest_value
end

function cpu_player.change_is_favorable(
	change,
	cpu_score,
	player_score
)
	local projected_score_difference =
		cpu_score - player_score + change
	return projected_score_difference > 0
end

local function board_after_move(board, move)
	local next_board = {}
	for row = 1, board_rows do
		next_board[row] = {}
		for column = 1, board_columns do
			local piece = board[row][column]
			if piece then
				next_board[row][column] = {
					type = piece.type,
					owner = piece.owner
				}
			end
		end
	end

	local piece = next_board[move.from_row + 1][move.from_column + 1]
	next_board[move.from_row + 1][move.from_column + 1] = nil
	if move.promotion then
		piece.type = move.promotion
	end
	piece.owner = owner_for_row(move.row)
	next_board[move.row + 1][move.column + 1] = piece
	return next_board
end

local function evaluate_resulting_move(
	board,
	move,
	cpu_score,
	player_score
)
	local target = board[move.row + 1][move.column + 1]
	local score_change = 0
	if target and not move.promotion then
		score_change = target.type
	end

	local next_board = board_after_move(board, move)
	local board_state_value = cpu_player.evaluate_board_state(
		next_board,
		player
	)
	score_change += board_state_value
	local is_favorable = cpu_player.change_is_favorable(
		score_change,
		cpu_score,
		player_score
	)
	return board_state_value, is_favorable, score_change
end

function cpu_player.choose_move(
	board,
	valid_moves,
	cpu_score,
	player_score
)
	-- Cache every resulting position for the selection stages below.
	for move in all(valid_moves) do
		local board_state_value, is_favorable, score_change =
			evaluate_resulting_move(
				board,
				move,
				cpu_score,
				player_score
			)
		move.evaluated_board_state = board_state_value
		move.evaluated_is_favorable = is_favorable
		move.evaluated_score_change = score_change
	end

	-- Emptying the CPU zone ends the game. A tied final score is won by
	-- the player who made the final move.
	local winning_exits = {}
	local winning_exit_score = nil
	for move in all(valid_moves) do
		if move.moves_last_piece_over_canal then
			local score_after_move = cpu_score
			local target = board[move.row + 1][move.column + 1]
			if target and not move.promotion then
				score_after_move += target.type
			end
			if score_after_move >= player_score and (
				#winning_exits == 0 or
				score_after_move > winning_exit_score
			) then
				winning_exits = {move}
				winning_exit_score = score_after_move
			elseif score_after_move >= player_score and
				score_after_move == winning_exit_score then
				winning_exits[#winning_exits + 1] = move
			end
		end
	end
	if #winning_exits > 0 then
		return choose_random_move(winning_exits)
	end

	-- Prefer the highest-valued capture whose resulting position is favorable.
	local best_captures = {}
	local best_capture_value = nil
	local best_capture_board_state = nil
	for move in all(valid_moves) do
		if move.capture_value != nil then
			if move.evaluated_is_favorable and (
				#best_captures == 0 or
				move.capture_value > best_capture_value or
				(move.capture_value == best_capture_value and
					move.evaluated_board_state > best_capture_board_state)
			) then
				best_captures = {move}
				best_capture_value = move.capture_value
				best_capture_board_state = move.evaluated_board_state
			elseif move.evaluated_is_favorable and
				move.capture_value == best_capture_value and
				move.evaluated_board_state == best_capture_board_state then
				best_captures[#best_captures + 1] = move
			end
		end
	end
	if #best_captures > 0 then
		return choose_random_move(best_captures)
	end

	-- Save the most valuable threatened piece that has a favorable escape.
	local threatened_pieces_available = false
	for move in all(valid_moves) do
		if move.source_piece_is_exposed then
			threatened_pieces_available = true
			break
		end
	end
	if threatened_pieces_available then
		for piece_value = queen, pawn, -1 do
			local best_evasions = {}
			local best_evasion_board_state = nil
			for move in all(valid_moves) do
				if move.capture_value == nil and
					move.source_piece_is_exposed and
					move.source_piece_value == piece_value and
					not move.moved_piece_is_exposed then
					if move.evaluated_is_favorable and (
						#best_evasions == 0 or
						move.evaluated_board_state >
							best_evasion_board_state
					) then
						best_evasions = {move}
						best_evasion_board_state =
							move.evaluated_board_state
					elseif move.evaluated_is_favorable and
						move.evaluated_board_state ==
							best_evasion_board_state then
						best_evasions[#best_evasions + 1] = move
					end
				end
			end
			if #best_evasions > 0 then
				return choose_random_move(best_evasions)
			end
		end
	end

	-- If no prioritized move is favorable, make the most favorable legal move.
	local best_moves = {}
	local best_score_change = nil
	local best_moves_are_negative_captures = false
	for move in all(valid_moves) do
		local move_is_negative_capture = move.capture_value != nil and
			move.capture_value < 0
		if #best_moves == 0 or
			move.evaluated_score_change > best_score_change then
			best_moves = {move}
			best_score_change = move.evaluated_score_change
			best_moves_are_negative_captures = move_is_negative_capture
		elseif move.evaluated_score_change == best_score_change and
			best_moves_are_negative_captures and
			not move_is_negative_capture then
			best_moves = {move}
			best_moves_are_negative_captures = false
		elseif move.evaluated_score_change == best_score_change and
			move_is_negative_capture ==
				best_moves_are_negative_captures then
			best_moves[#best_moves + 1] = move
		end
	end
	return choose_random_move(best_moves)
end

function cpu_player.evaluate_capture_value(
	board,
	turn,
	from_column,
	from_row,
	move
)
	local target = board[move.row + 1][move.column + 1]
	if not target or move.promotion then
		return nil
	end

	local piece = board[from_row + 1][from_column + 1]
	if not piece then
		return nil
	end

	local captured_value = target.type
	if zone_will_be_empty_after_move(
		board,
		turn,
		from_column,
		from_row
	) then
		-- Emptying a zone ends the game, so the opponent gets no reply.
		return captured_value
	end

	local gifted_owner = owner_for_row(move.row)
	local reply_value = highest_capture_value_for_piece(
		board,
		piece.type,
		move.column,
		move.row,
		gifted_owner,
		from_column,
		from_row
	)
	return captured_value - reply_value
end

local function board_piece_after_move(
	board,
	column,
	row,
	from_column,
	from_row
)
	if column == from_column and row == from_row then
		return nil
	end
	return board[row + 1][column + 1]
end

local function path_is_clear_after_move(
	board,
	from_column,
	from_row,
	to_column,
	to_row,
	empty_column,
	empty_row
)
	local dx = to_column == from_column and 0 or
		(to_column > from_column and 1 or -1)
	local dy = to_row == from_row and 0 or
		(to_row > from_row and 1 or -1)
	local column = from_column + dx
	local row = from_row + dy
	while column != to_column or row != to_row do
		if board_piece_after_move(
			board,
			column,
			row,
			empty_column,
			empty_row
		) then
			return false
		end
		column += dx
		row += dy
	end
	return true
end

local function piece_can_capture_after_move(
	board,
	piece,
	from_column,
	from_row,
	to_column,
	to_row,
	empty_column,
	empty_row
)
	local column_distance = abs(to_column - from_column)
	local row_distance = abs(to_row - from_row)
	local can_reach = false
	if piece.type == pawn then
		can_reach = column_distance == 1 and row_distance == 1
	elseif piece.type == drone then
		can_reach = (column_distance == 0 and row_distance <= 2) or
			(row_distance == 0 and column_distance <= 2)
	elseif piece.type == queen then
		can_reach = column_distance == 0 or row_distance == 0 or
			column_distance == row_distance
	end

	return can_reach and path_is_clear_after_move(
		board,
		from_column,
		from_row,
		to_column,
		to_row,
		empty_column,
		empty_row
	)
end

local function highest_evaluated_capture_value(board, owner)
	local highest_value = nil
	local first_row = owner == cpu and 0 or zone_rows
	local last_row = first_row + zone_rows - 1
	local target_first_row = owner == cpu and zone_rows or 0
	local target_last_row = target_first_row + zone_rows - 1
	for row = first_row, last_row do
		for column = 0, board_columns - 1 do
			local piece = board[row + 1][column + 1]
			if piece then
				for target_row = target_first_row, target_last_row do
					for target_column = 0, board_columns - 1 do
						local target =
							board[target_row + 1][target_column + 1]
						if target and piece_can_capture_after_move(
							board,
							piece,
							column,
							row,
							target_column,
							target_row,
							-1,
							-1
						) then
							local capture_value =
								cpu_player.evaluate_capture_value(
									board,
									owner,
									column,
									row,
									{
										column = target_column,
										row = target_row
									}
								)
							if highest_value == nil or
								capture_value > highest_value then
								highest_value = capture_value
							end
						end
					end
				end
			end
		end
	end
	-- Captures are optional, so a side can reject every capture whose
	-- evaluated value is negative.
	return max(highest_value or 0, 0)
end

function cpu_player.evaluate_board_state(board, next_player)
	local capture_value = highest_evaluated_capture_value(
		board,
		next_player
	)
	if next_player == cpu then
		return capture_value
	end
	return -capture_value
end

function cpu_player.opponent_can_capture_moved_piece(
	board,
	turn,
	from_column,
	from_row,
	move
)
	-- Crossing the canal gives the moved piece to the opponent, so it is
	-- no longer a piece that opponent can capture.
	if owner_for_row(move.row) != turn then
		return false
	end

	local opponent = turn == cpu and player or cpu
	local first_row = opponent == cpu and 0 or zone_rows
	local last_row = first_row + zone_rows - 1
	for row = first_row, last_row do
		for column = 0, board_columns - 1 do
			local piece = board[row + 1][column + 1]
			if piece and piece_can_capture_after_move(
				board,
				piece,
				column,
				row,
				move.column,
				move.row,
				from_column,
				from_row
			) then
				return true
			end
		end
	end
	return false
end

function cpu_player.opponent_can_capture_piece(
	board,
	turn,
	column,
	row
)
	local opponent = turn == cpu and player or cpu
	local first_row = opponent == cpu and 0 or zone_rows
	local last_row = first_row + zone_rows - 1
	for opponent_row = first_row, last_row do
		for opponent_column = 0, board_columns - 1 do
			local piece = board[opponent_row + 1][opponent_column + 1]
			if piece and piece_can_capture_after_move(
				board,
				piece,
				opponent_column,
				opponent_row,
				column,
				row,
				-1,
				-1
			) then
				return true
			end
		end
	end
	return false
end
