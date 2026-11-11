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

local function highest_reply_capture_value(
	board,
	piece_type,
	from_column,
	from_row,
	gifted_owner,
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

			-- Evaluate the reply on the board as it will look after the
			-- capture: the capturing piece's original square is empty.
			local target = nil
			if column != empty_column or row != empty_row then
				target = board[row + 1][column + 1]
			end
			if target then
				if owner_for_row(row) != gifted_owner and
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
	local reply_value = highest_reply_capture_value(
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

local function choose_random_move(moves)
	local index = flr(rnd(#moves)) + 1
	return moves[index]
end

function cpu_player.choose_move(valid_moves, cpu_score, opponent_score)
	if #valid_moves == 0 then
		return nil
	end

	local minimum_capture_value = cpu_score < opponent_score and 1 or 0
	local highest_capture_value = nil
	local best_captures = {}
	local non_captures = {}
	local safe_non_captures = {}
	for _, move in ipairs(valid_moves) do
		if move.capture_value == nil then
			non_captures[#non_captures + 1] = move
			if not move.moved_piece_is_exposed then
				safe_non_captures[#safe_non_captures + 1] = move
			end
		elseif move.capture_value >= minimum_capture_value then
			if highest_capture_value == nil or
				move.capture_value > highest_capture_value then
				highest_capture_value = move.capture_value
				best_captures = {move}
			elseif move.capture_value == highest_capture_value then
				best_captures[#best_captures + 1] = move
			end
		end
	end

	if #best_captures > 0 then
		return choose_random_move(best_captures)
	end
	if #safe_non_captures > 0 then
		return choose_random_move(safe_non_captures)
	end
	if #non_captures > 0 then
		return choose_random_move(non_captures)
	end
	return nil
end
