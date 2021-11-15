-- hnds
--
-- Lua lfo's for script
-- parameters.
-- ----------
--
-- v0.4 @justmat slightly adapted by @sonocircuit

local number_of_outputs = 6

local tau = math.pi * 2

local options = {
  lfotypes = {
    "sine",
    "square",
    "s+h"
  }
}

local lfo = {}
for i = 1, number_of_outputs do
  lfo[i] = {
    freq = 0.01,
    counter = 1,
    waveform = options.lfotypes[1],
    slope = 0,
    depth = 100,
    offset = 0,
    active = 0 -- this adds possibility to toggle on/off via grid with one button
  }
end

-- redefine in user script ---------
for i = 1, number_of_outputs do
  lfo[i].lfo_targets = {"none"}
end

function lfo.process()
end
------------------------------------


function lfo.scale(old_value, old_min, old_max, new_min, new_max)
  -- scale ranges
  local old_range = old_max - old_min

  if old_range == 0 then
    old_range = new_min
  end

  local new_range = new_max - new_min
  local new_value = (((old_value - old_min) * new_range) / old_range) + new_min

  return new_value
end


local function make_sine(n)
  return 1 * math.sin(((tau / 100) * (lfo[n].counter)) - (tau / (lfo[n].freq)))
end


local function make_square(n)
  return make_sine(n) >= 0 and 1 or -1
end


local function make_sh(n)
  local polarity = make_square(n)
  if lfo[n].prev_polarity ~= polarity then
    lfo[n].prev_polarity = polarity
    return math.random() * (math.random(0, 1) == 0 and 1 or -1)
  else
    return lfo[n].prev
  end
end


function lfo.init()
    --params:add_separator("modulation")
  for i = 1, number_of_outputs do
    --params:add_separator("lfo " .. i)
    params:add_group("lfo " .. i, 6)
    -- modulation destination
    params:add_option(i .. "lfo_target", "lfo target", lfo[i].lfo_targets, 1)
    -- lfo shape
    params:add_option(i .. "lfo_shape", "lfo shape", options.lfotypes, 1)
    params:set_action(i .. "lfo_shape", function(value) lfo[i].waveform = options.lfotypes[value] end)
    -- lfo depth
    params:add_number(i .. "lfo_depth", "lfo depth", 0, 100, 0)
    params:set_action(i .. "lfo_depth", function(value) lfo[i].depth = value end)
    -- lfo offset
    params:add_control(i .."offset", "offset", controlspec.new(-1, 1, "lin", 0.1, 0.0, ""))
    params:set_action(i .. "offset", function(value) lfo[i].offset = value end)
    -- lfo speed
    params:add_control(i .. "lfo_freq", "lfo freq", controlspec.new(0.1, 10.0, "lin", 0.1, 0.1, ""))
    params:set_action(i .. "lfo_freq", function(value) lfo[i].freq = value end)
    -- lfo on/off
    params:add_option(i .. "lfo", "lfo on/off", {"off", "on"}, 1)
  end

  local lfo_metro = metro.init()
  lfo_metro.time = .01
  lfo_metro.count = -1
  lfo_metro.event = function()
    for i = 1, number_of_outputs do
      if params:get(i .. "lfo") == 2 then
        local slope
        if lfo[i].waveform == "sine" then
          slope = make_sine(i)
        elseif lfo[i].waveform == "square" then
          slope = make_square(i)
        elseif lfo[i].waveform == "s+h" then
          slope = make_sh(i)
        end
        lfo[i].prev = slope
        lfo[i].slope = math.max(-1.0, math.min(1.0, slope)) * (lfo[i].depth * 0.01) + lfo[i].offset
        lfo[i].counter = lfo[i].counter + lfo[i].freq
      end
    end
    lfo.process()
    dirtygrid = true --for blinkenlights (lfo slope on "on" grid button)
  end
  lfo_metro:start()
end


return lfo
