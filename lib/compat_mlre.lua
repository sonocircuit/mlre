local cp = {}

local function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
end

function convert_event_positions()
  local num = 0
  for i = 1, 8 do
    if next(pattern[i].event) then
      for n, k in ipairs(pattern[i].event) do
        if pattern[i].event[n].t == 1 then
          pattern[i].event[n].pos = pattern[i].event[n].pos + 1
          num = num + 1
        end
      end
    end
    if next(punch[i].event) then
      for n, k in ipairs(punch[i].event) do
        if punch[i].event[n].t == 1 then
          punch[i].event[n].pos = punch[i].event[n].pos + 1
          num = num + 1
        end
      end
    end
  end
  print(">> converted "..num.." macro events!")
end

function load_cp_macros(data)
  -- load pmac and kmac
  if data.pmac_d ~= nil then
    pmac.d = deep_copy(data.pmac_d)
    print(">> p-macro config loaded")
  end
  if data.kmac ~= nil then
    kmac.slot = deep_copy(data.kmac.slot)
    print(">> macro slot config loaded")
  end
  -- load key macros
  for i = 1, 8 do
    -- stop patterns
    pattern[i]:rec_stop()
    pattern[i]:set_overdub(0)
    pattern[i]:stop()
    -- load patterns
    pattern[i].count = data[i].pattern_count
    pattern[i].time = {table.unpack(data[i].pattern_time)}
    pattern[i].event = {table.unpack(data[i].pattern_event)}
    pattern[i].time_factor = data[i].pattern_time_factor
    pattern[i].synced = data[i].pattern_synced
    params:set("patterns_meter"..i, data[i].pattern_sync_meter)
    params:set("patterns_barnum"..i, data[i].pattern_sync_beatnum)
    params:set("patterns_playback"..i, data[i].pattern_loop)
    params:set("patterns_countin"..i, data[i].pattern_count_in)
    pattern[i].bpm = data[i].pattern_bpm
    if pattern[i].bpm ~= nil then
      pattern[i].time_factor = pattern[i].bpm / params:get("clock_tempo")
    end
    punch[i].has_data = data[i].recall_has_data
    punch[i].event = {table.unpack(data[i].recall_event)}
    snap[i].data = data[i].snap_data
    snap[i].play = {table.unpack(data[i].snap_play)}
    snap[i].mute = {table.unpack(data[i].snap_mute)}
    snap[i].loop = {table.unpack(data[i].snap_loop)}
    snap[i].loop_start = {table.unpack(data[i].snap_loop_start)}
    snap[i].loop_end = {table.unpack(data[i].snap_loop_end)}
    snap[i].speed = {table.unpack(data[i].snap_speed)}
    snap[i].rev = {table.unpack(data[i].snap_rev)}
    snap[i].transpose_val = {table.unpack(data[i].snap_transpose_val)}
    if data.newerformat ~= nil then
      snap[i].active_splice = {table.unpack(data[i].snap_active_splice)}
      snap[i].rec = {table.unpack(data[i].snap_rec)}
      snap[i].route_t5 = {table.unpack(data[i].snap_route_t5)}
      snap[i].route_t6 = {table.unpack(data[i].snap_route_t6)}
      snap[i].lfo_enabled = {table.unpack(data[i].snap_lfo_enabled)}
    end
  end
  convert_event_positions()
end

function cp.load_data(data)
  if data.newerformat then
    print(">> preset format: v2.2.0 beta")
  else
    print(">> preset format: v2.0.1")
  end
  -- set tempo
  if data.tempo ~= nil then
    params:set("clock_tempo", data.tempo)
  end
  -- load data
  for i = 1, 6 do
    -- set defaults
    params:set(i.."filter_q", 0.2)
    params:set(i.."level_slew", 0.1)
    params:set(i.."rate_slew", 0)
    -- tape data
    tp[i].s = data[i].tape_s
    tp[i].e = data[i].tape_e
    tp[i].splice = {table.unpack(data[i].tape_splice)}
    if tp[i].splice[1].resize == nil then
      for j = 1, 8 do
        tp[i].splice[j].resize = 4
      end
    end
    -- route data
    if data.newerformat ~= nil then
      track[i].route_t5 = data[i].track_route_t5
      track[i].route_t6 = data[i].track_route_t6
    else
      track[i].route_t5 = 0
      track[i].route_t6 = 0
    end
    set_track_sends(i)
    -- track data
    track[i].loaded = true
    track[i].splice_active = data[i].track_splice_active
    track[i].splice_focus = data[i].track_splice_focus
    track[i].sel = data[i].track_sel
    track[i].fade = data[i].track_fade
    track[i].loop = data[i].track_loop
    track[i].loop_start = data[i].track_loop_start
    track[i].loop_end = data[i].track_loop_end
    -- set track state
    track[i].mute = data[i].track_mute
    track[i].speed = data[i].track_speed
    track[i].rev = data[i].track_rev
    clock.run(function() clock.sleep(0.1) set_tempo_map(i) end)
    set_level(i)
    set_rec(i)
    -- set lfo params
    if data[i].lfo_track ~= nil then
      set_lfo(i, data[i].lfo_destination, data[i].lfo_track, data[i].lfo_offset)
    else
      set_lfo(i, "none")
    end
  end
  load_cp_macros(data)
end

return cp
