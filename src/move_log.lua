-- martian chess move log

move_log = {}

local log_version = 7
local board_rows = 8
local column_names = {"a", "b", "c", "d"}
local piece_names = {
	[1] = "P",
	[2] = "D",
	[3] = "Q"
}

local log_text = ""

local function square_name(column, row)
	local column_name = column_names[column + 1]
	local row_name = board_rows - row
	return column_name..row_name
end

local function move_number_name(move_number)
	if move_number < 10 then
		return "0"..move_number
	end
	return move_number
end

function move_log.reset(starting_player)
	log_text = "version="..log_version.."\n"..
		"starting_player="..starting_player
end

function move_log.record(
	move_number,
	piece_type,
	from_column,
	from_row,
	to_column,
	to_row,
	options
)
	local entry = move_number_name(move_number).."."..
		piece_names[piece_type].."-"..
		square_name(from_column, from_row).."-"..
		square_name(to_column, to_row)
	if options.capture then
		entry ..= "x"
	end
	if options.promotion then
		entry ..= ">"..piece_names[options.promotion]
	end
	if options.canal_ending then
		entry ..= "^"
	end
	if options.deadlock_ending then
		entry ..= "~"
	end
	log_text ..= "\n"..entry
	if options.winner then
		log_text ..= "\nwinner: "..options.winner
	end
end

function move_log.append(entry)
	log_text ..= "\n"..entry
end

function move_log.copy_to_clipboard()
	set_clipboard(log_text)
end

function move_log.get_text()
	return log_text
end
