-- martian chess visual effects

effects = {}

local frames_per_second = 60
local sparkle_lifetime_frames = frames_per_second * 3
local sparkle_colors = {16, 12, 28, 12, 16}
local maximum_sparkles = 5
local minimum_spawn_delay_frames = 15
local maximum_spawn_delay_frames = 45
local minimum_sparkle_speed = 0.05
local sparkle_speed_range = 0.05

local canal = nil
local canal_sparkles = {}
local spawn_delay_frames = 0

local function random_spawn_delay()
	return minimum_spawn_delay_frames +
		flr(rnd(maximum_spawn_delay_frames -
			minimum_spawn_delay_frames + 1))
end

local function spawn_canal_sparkle()
	canal_sparkles[#canal_sparkles + 1] = {
		x = canal.x + flr(rnd(canal.width)),
		y = canal.y + flr(rnd(canal.height)),
		speed = minimum_sparkle_speed + rnd(sparkle_speed_range),
		age = 0
	}
end

function effects.initialize_canal_sparkles(x, y, width, height)
	canal = {
		x = x,
		y = y,
		width = width,
		height = height
	}
	canal_sparkles = {}
	spawn_delay_frames = random_spawn_delay()
end

function effects.update_canal_sparkles()
	if not canal then
		return
	end

	for index = #canal_sparkles, 1, -1 do
		local sparkle = canal_sparkles[index]
		sparkle.age += 1
		sparkle.x -= sparkle.speed
		if sparkle.age >= sparkle_lifetime_frames or
			sparkle.x < canal.x then
			table.remove(canal_sparkles, index)
		end
	end

	spawn_delay_frames -= 1
	if #canal_sparkles < maximum_sparkles and
		spawn_delay_frames <= 0 then
		spawn_canal_sparkle()
		spawn_delay_frames = random_spawn_delay()
	end
end

function effects.draw_canal_sparkles()
	for sparkle in all(canal_sparkles) do
		local color_phase = flr(
			sparkle.age * #sparkle_colors / sparkle_lifetime_frames
		) + 1
		color_phase = min(color_phase, #sparkle_colors)
		pset(flr(sparkle.x), sparkle.y, sparkle_colors[color_phase])
	end
end
