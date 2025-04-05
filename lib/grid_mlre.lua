-- grid for mlre

local grd = {}

-- grid key logic
local held = {}
local heldmax = {}
local first = {}
local second = {}
for i = 1, 8 do
  held[i] = 0
  heldmax[i] = 0
  first[i] = 0
  second[i] = 0
end

-- snap n punch
local snap_track = 0
local snap_last = 0
local event_reset_timeout = false
local event_reset_clk = nil

-- lfo
local lfo_params = {"vol", "pan", "dub", "transpose", "detune", "rate_slew", "cutoff"}
local lfo_trksel = 0
local lfo_dstsel = 0
local lfo_launch = 0


local function pattern_actions(i, z)
  if z == 1 then
    if alt == 1 then
      pattern[i]:clear()
      pattern_rec = false
    elseif pattern[i].overdub == 1 then
      if mod == 1 then
        pattern[i]:set_overdub(-1) -- overdub flag undo
      else
        pattern[i]:set_overdub(0) -- overdub off
      end
      pattern_rec = false
    elseif pattern[i].rec == 1 then
      if mod == 1 then
        pattern[i]:set_overdub(1) -- overdub on
      else
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "start"} event(e)
        pattern_rec = false
      end
    elseif pattern[i].count == 0 then
      pattern[i]:rec_start()
      pattern_rec = true
    elseif pattern[i].play == 1 then
      if mod == 1 then
        pattern[i]:set_overdub(1) -- overdub on
        pattern_rec = true
      else
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
      end
    else
      local beat_sync = pattern[i].count_in > 1 and (pattern[i].count_in == 2 and 1 or bar_val) or (quantizing and q_rate or nil)
      if beat_sync ~= nil then
        clock.run(function()
          clock.sync(beat_sync)
          local e = {t = ePATTERN, i = i, action = "start", sync = true} event(e)
        end)
      else
        local e = {t = ePATTERN, i = i, action = "start"} event(e)
      end
    end
    if view == vMACRO then dirtyscreen = true end
  end
end

local function snapshot_actions(i, z)
  snap[i].active = z == 1 and true or false
  if z == 1 then
    if alt == 1 then
      snap[i].data = false
      snap[i].active = false
    else
      if snap[i].data then
        if snap_track > 0 then
          launch_snapshot(i, track_focus)
        else
          for track = 1, 6 do
            launch_snapshot(i, track)
          end
        end
        snap_last = i
      else
        save_snapshot(i)
      end
    end
  end
  if view == vMACRO then dirtyscreen = true end
end

local function punch_actions(i, z)
  if held[1] < 0 then held[1] = 0 end
  held[1] = held[1] + (z * 2 - 1)
  punch[i].active = z == 1 and true or false
  if z == 1 then
    if held[1] == 1 and event_reset_clk == nil then
      save_event_state()
    end
    if alt == 1 then
      punch[i].event = {}
      punch[i].has_data = false
      punch[i].active = false
    elseif punch[i].has_data then
      for _, e in pairs(punch[i].event) do
        event(e)
      end
    else
      punch.rec = i
    end
    -- min timeout
    event_reset_timeout = false
    if event_reset_clk ~= nil then
      clock.cancel(event_reset_clk)
    end
    event_reset_clk = clock.run(function()
      clock.sync(q_rate)
      if not punch[i].active then
        reset_event_state(true)
      end
      event_reset_timeout = true
      event_reset_clk = nil
    end)
  else
    if held[1] < 1 and event_reset_timeout then
      reset_event_state(true)
    end
    if punch.rec == i then punch.rec = 0 end
  end
  if view == vMACRO then dirtyscreen = true end
end

function grd.clear_keylogic() -- reset key logic in case of stuck loops
  for i = 1, 8 do
    held[i] = 0
  end
end
 
function grd.nav(x, z, pos)
  if x == 1 and z == 1 then
    if alt == 1 then
      local msg = "clear   splice"
      popupscreen(msg, clear_splice)
    else
      set_gridview(vREC, pos)
      set_view(vMAIN)
    end
  elseif x == 2 then
    if z == 1 and alt == 1 then
      local msg = "clear   tape"
      popupscreen(msg, clear_tape)
    elseif alt == 0 then
      if z == 1 then
        set_gridview(vCUT, pos)
        set_view(vMAIN)
      end
      cutview_hold = z == 1 and true or false
    end
  elseif x == 3 and z == 1 then
    if alt == 1 then
      local msg = "clear   buffers"
      popupscreen(msg, clear_buffers)
    else
      set_gridview(vTRSP, pos)
      set_view(vMAIN)
    end
  elseif x == 4 and z == 1 and alt == 0 then
    local view = pos == "o" and grido_view or gridz_view
    if view == vLFO then
      set_gridview(vENV, pos)
      set_view(vENV)
    else
      set_gridview(vLFO, pos)
      set_view(vLFO)
    end
  elseif x > 4 and x < 13 then
    local i = x - 4
    local s = pos == "o" and kmac[pos].sec or kmac[pos].sec + 2
    if kmac.slot[s][i] == mPTN then
      pattern_actions(i, z)
    elseif kmac.slot[s][i] == mSNP then
      snapshot_actions(i, z)
    elseif kmac.slot[s][i] == mPIN then
      punch_actions(i, z)
    end
  elseif x == 13 then
    if alt == 1 and z == 1 then
      kmac[pos].tog = not kmac[pos].tog
      local msg = kmac[pos].tog and "toggle" or "momentary"
      show_message(msg)
    elseif mod == 1 and z == 1 then
      stopall()
    else
      if kmac[pos].tog then
        if z == 1 then
          kmac[pos].sec = kmac[pos].sec == 1 and 2 or 1
        end
      else
        kmac[pos].sec = z == 1 and 2 or 1
      end
      if z == 0 then
        if held[1] > 0 then
          reset_event_state()
        end
        for i = 1, 8 do
          punch[i].active = false
        end
        held[1] = 0
        punch.rec = 0
      end
      if view == vMACRO then dirtyscreen = true end
    end    
  elseif x == 14 then
    mod = z
    if alt == 1 and z == 1 then
      reset_playheads()
    end
  elseif x == 15 then
    if alt == 0 and mod == 0 and pos == "o" then
      keyquant_edit = z == 1 and true or false
      dirtyscreen = true
    elseif alt == 1 and z == 1 then
      set_gridview(vTAPE, pos)
      set_view(vTAPE)
      render_splice(track_focus)
    elseif mod == 1 and z == 1 then
      set_gridview(vMACRO, pos)
      set_view(vMACRO)
    end
  elseif x == 16 then
    alt = z
  end
end

function grd.drawnav(y)
  local view = y == 9 and gridz_view or grido_view
  local pos = y == 9 and "z" or "o"
  -- nav keys
  g:led(1, y, view == vREC and 10 or 4) -- vREC
  g:led(2, y, view == vCUT and 10 or 3) -- vCUT
  g:led(3, y, view == vTRSP and 10 or 2) -- vTRSP
  g:led(4, y, view == vLFO and 10 or (view == vENV and pulse_key_slow or 0)) -- vLFO
  -- key macro keys
  for i = 1, 8 do
    local s = pos == "o" and kmac[pos].sec or kmac[pos].sec + 2
    if kmac.slot[s][i] == mPTN then
      if pattern[i].rec == 1 and pattern[i].count == 0 then
        g:led(i + 4, y, 15)
      elseif pattern[i].rec == 1 and pattern[i].count > 0 then
        g:led(i + 4, y, pulse_key_fast)
      elseif pattern[i].overdub == 1 then
        g:led(i + 4, y, pulse_key_fast)
      elseif pattern[i].play == 1 then
        g:led(i + 4, y, pattern[i].flash and 15 or 13)
      elseif pattern[i].count > 0 then
        g:led(i + 4, y, 8)
      else
        g:led(i + 4, y, 4)
      end
    elseif kmac.slot[s][i] == mSNP then
      g:led(i + 4, y, snap[i].active and 15 or ((snap_last == i and snap[i].data) and 10 or (snap[i].data and 6 or 2)))
    elseif kmac.slot[s][i] == mPIN then
      g:led(i + 4, y, punch.rec == i and 15 or (punch[i].active and 10 or (punch[i].has_data and 4 or 1)))
    end
  end
  -- nav and function keys
  g:led(13, y, kmac[pos].sec == 2 and 2 or 0) -- k-mac
  g:led(14, y, mod == 1 and 9 or 2) -- mod
  g:led(15, y, y ~= 9 and (quantizing and (pulse_bar and 15 or (pulse_beat and 6 or 2))) or 3) -- Q flash
  g:led(16, y, alt == 1 and 15 or 9) -- alt
end

function grd.cutfocus_keys(x, z)
  local row = track_focus + 1
  local i = track_focus
  if z == 1 and held[row] then heldmax[row] = 0 end
  held[row] = held[row] + (z * 2 - 1)
  if held[row] > heldmax[row] then heldmax[row] = held[row] end
  if z == 1 then
    -- flip the unflipped
    if not track[i].loaded and alt == 0 and mod == 0 then
      queue_track_tape(i)
    end
    -- cutfocus 
    if alt == 1 and mod == 0 then
      toggle_playback(i)
    elseif mod == 1 then -- "hold mode" as on cut page
      heldmax[row] = x
      loop_event(i, x, x)
    elseif held[row] == 1 then -- cut at pos
      first[row] = x
      if track[i].play == 1 or track[i].start_launch == 1 then
        local e = {t = eCUT, i = i, pos = x} event(e)
        if env[i].active then
          local e = {t = eGATEON, i = i} event(e)
        end
      elseif track[i].play == 0 and track[i].start_launch > 1 then
        clock.run(function()
          local beat_sync = track[i].start_launch == 2 and 1 or bar_val
          clock.sync(beat_sync)
          local e = {t = eCUT, i = i, pos = x, sync = true} event(e)
          if env[i].active then
            local e = {t = eGATEON, i = i, sync = true} event(e)
          end
        end)
      end
    elseif held[row] == 2 then -- second keypress
      second[row] = x
    end
  elseif z == 0 then
    if held[row] == 1 and heldmax[row] == 2 then -- if two keys held at release then loop
      local lstart = math.min(first[row], second[row])
      local lend = math.max(first[row], second[row])
      loop_event(i, lstart, lend)
    else
      if track[i].play_mode == 3 and track[i].loop == 0 and not env[i].active then
        local e = {t = eSTOP, i = i} event(e)
      end
      if env[i].active and track[i].loop == 0 then
        local e = {t = eGATEOFF, i = i} event(e)
      end
    end
    if held[row] < 1 then held[row] = 0 end
  end
end

function grd.cutfocus_draw(y)
  if track[track_focus].loop == 1 then
    for x = math.floor(track[track_focus].loop_start), math.ceil(track[track_focus].loop_end) do
      g:led(x, y, 4)
    end
  end
  if track[track_focus].play == 1 then
    g:led(track[track_focus].pos_grid, y, 15)
  end
end

function grd.rec_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vMAIN and autofocus then
    set_view(vMAIN)
  end
  if y > 1 and y < 8 then
    local i = y - 1
    if x == 1 and z == 1 then
      if alt == 0 then
        if mod == 0 then
          toggle_rec(i)
          chop(i)
        else
          backup_rec(i, "undo")
        end
      elseif alt == 1 then
        if mod == 0 then
          track[i].fade = 1 - track[i].fade
          set_rec(i)
        else
          set_rec_enable(i, not track[i].rec_enabled)
        end
      end
    elseif x == 2 and z == 1 then
      arm_thresh_rec(i)
    elseif x > 2 and x < 7 then
      snap_track = z == 1 and i or 0
      if z == 1 then
        if track_focus ~= i then
          track_focus = i
          arc_track_focus = track_focus
          dirtyscreen = true
          render_splice(i)
        end
        if alt == 1 and mod == 0 then
          params:set(i.."tempo_map_mode", util.wrap(track[i].tempo_map + 2, 1, 3))
        elseif alt == 0 and mod == 1 then
          params:set(i.."tape_side", tp[i].side == 1 and 2 or 1)
        end
        if x == 3 and not track[i].loaded then
          queue_track_tape(i)
        end
      end
    elseif x == 7 then
      wrb_focus = i
      if alt == 1 and z == 1 then
        params:set(i.."warble_state", track[i].warble == 0 and 2 or 1)
        update_rate(i)
      elseif track[i].warble == 1 then
        warble_edit = z == 1 and true or false
        dirtyscreen = true
      end
    elseif x == 8 and z == 1 then
      local e = {t = eREV, i = i, rev = (1 - track[i].rev)} event(e)
    elseif x > 8 and x < 16 and z == 1 then
      if alt == 0 then
        local e = {t = eSPEED, i = i, speed = (x - 12)} event(e)
      elseif x == 12 then
        randomize(i)
      end
    elseif x == 16 and z == 1 then
      if alt == 0 and mod == 0 then
        toggle_playback(i)
      elseif alt == 0 and mod == 1 then
        track[i].sel = 1 - track[i].sel
      elseif alt == 1 and mod == 0 then
        local e = {t = eMUTE, i = i, mute = (1 - track[i].mute)} event(e)
      end
    end
  elseif y == 8 then -- cut for focused track
    if GRID_SIZE == 128 or offset == 8 then 
      grd.cutfocus_keys(x, z)
    end
  end
end

function grd.rec_draw(offset)
  local off = offset or 0
  g:led(4, track_focus + 1 + off, tp[track_focus].side == 1 and 7 or 3)
  g:led(5, track_focus + 1 + off, tp[track_focus].side == 2 and 7 or 3)
  g:led(6, track_focus + 1 + off, track[track_focus].tempo_map * 6 + 2)
  for i = 1, 6 do
    local y = i + 1 + off
    g:led(1, y, track[i].rec_enabled and (track[i].rec == 1 and 15 or (track[i].fade == 1 and 7 or 3)) or 1)
    g:led(2, y, track[i].oneshot == 1 and pulse_key_fast or 0)
    g:led(3, y, track[i].loaded and (track_focus == i and 7 or 0) or pulse_key_mid)
    g:led(7, y, track[i].warble == 1 and (2 + track[i].wrbviz) or 0)
    g:led(8, y, track[i].rev == 1 and 12 or 6)
    if track[i].mute == 1 then
      g:led(16, y, track[i].play == 0 and (track[i].sel == 0 and pulse_key_slow - 2 or pulse_key_slow) or (track[i].sel == 0 and pulse_key_slow or pulse_key_slow + 3))
    elseif track[i].play == 1 and track[i].sel == 1 then
      g:led(16, y, 15)
    elseif track[i].play == 1 and track[i].sel == 0 then
      g:led(16, y, 10)
    elseif track[i].play == 0 and track[i].sel == 1 then
      g:led(16, y, 5)
    else
      g:led(16, y, 3)
    end
    g:led(12, y, 3)
    g:led(12 + track[i].speed, y, 9)
  end
  if GRID_SIZE == 128 or offset == 8 then 
    grd.cutfocus_draw(8 + off)
  end
end

function grd.cut_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vMAIN and autofocus then
    set_view(vMAIN)
  end
  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z * 2 - 1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end
  if y == 8 then
    if z == 1 then
      local i = track_focus
      if mod == 0 then
        if x >= 1 and x <= 8 then
          local e = {t = eTRSP, i = i, val = x} event(e)
        end
        if x >= 9 and x <= 16 then
          local e = {t = eTRSP, i = i, val = (x - 1)} event(e)
        end
      elseif mod == 1 then
        if x == 8 then
          local n = util.clamp(track[i].speed - 1, -3, 3)
          local e = {t = eSPEED, i = i, speed = n} event(e)
        elseif x == 9 then
          local n = util.clamp(track[i].speed + 1, -3, 3)
          local e = {t = eSPEED, i = i, speed = n} event(e)
        end
      end
    end
  else
    local i = y - 1
    if z == 1 then
      -- flip the unflipped
      if not track[i].loaded and alt == 0 and mod == 0 then
        queue_track_tape(i)
      end
      -- cutpage
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
        render_splice(i)
      end
      if alt == 1 and y < 8 then
        toggle_playback(i)
      elseif mod == 1 and y < 8 then -- "hold mode"
        heldmax[y] = x
        loop_event(i, x, x)
      elseif y < 8 and held[y] == 1 then
        first[y] = x
        if track[i].play == 1 or track[i].start_launch == 1 then
          local e = {t = eCUT, i = i, pos = x} event(e)
          if env[i].active then
            local e = {t = eGATEON, i = i} event(e)
          end
        elseif track[i].play == 0 and track[i].start_launch > 1 then
          clock.run(function()
            local beat_sync = track[i].start_launch == 2 and 1 or bar_val
            clock.sync(beat_sync)
            local e = {t = eCUT, i = i, pos = x, sync = true} event(e)
            if env[i].active then
              local e = {t = eGATEON, i = i, sync = true} event(e)
            end
          end)
        end
      elseif y < 8 and held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if held[y] == 1 and heldmax[y] == 2 then
        local lstart = math.min(first[y], second[y])
        local lend = math.max(first[y], second[y])
        loop_event(i, lstart, lend)
      else
        if track[i].play_mode == 3 and track[i].loop == 0 and not env[i].active then
          local e = {t = eSTOP, i = i} event(e)
        end
        if env[i].active and track[i].loop == 0 then
          local e = {t = eGATEOFF, i = i} event(e)
        end
      end
      if held[y] < 1 then held[y] = 0 end
    end
  end
end

function grd.cut_draw(offset)
  local off = offset or 0
  for i = 1, 6 do
    if track[i].loop == 1 then
      for x = math.floor(track[i].loop_start), math.ceil(track[i].loop_end) do
        g:led(x, i + 1 + off, 4)
      end
    end
    if track[i].play == 1 then
      g:led(track[i].pos_grid, i + 1 + off, track[i].loaded and (track_focus == i and 15 or 12) or pulse_key_mid)
    end
  end
  g:led(8, 8 + off, 6)
  g:led(9, 8 + off, 6)
  if track[track_focus].transpose < 0 then
    g:led(params:get(track_focus.."transpose"), 8 + off, 10)
  elseif track[track_focus].transpose > 0 then
    g:led(params:get(track_focus.."transpose") + 1, 8 + off, 10)
  end
end

function grd.trsp_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vMAIN and autofocus then
    set_view(vMAIN)
  end
  if y > 1 and y < 8 then
    if z == 1 then
      local i = y - 1
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
        render_splice(i)
      end
      if alt == 0 and mod == 0 then
        if x >= 1 and x <= 8 then
          local e = {t = eTRSP, i = i, val = x} event(e)
        end
        if x >= 9 and x <= 16 then
          local e = {t = eTRSP, i = i, val = (x - 1)} event(e)
        end
      end
      if alt == 1 and x > 7 and x < 10 then
        toggle_playback(i)
      end
      if mod == 1 then
        if x == 8 then
          local n = util.clamp(track[i].speed - 1, -3, 3)
          local e = {t = eSPEED, i = i, speed = n} event(e)
        elseif x == 9 then
          local n = util.clamp(track[i].speed + 1, -3, 3)
          local e = {t = eSPEED, i = i, speed = n} event(e)
        end
      end
    end
  elseif y == 8 then -- cut for focused track
    if GRID_SIZE == 128 or offset == 8 then 
      grd.cutfocus_keys(x, z)
    end
  end
end

function grd.trsp_draw(offset)
  local off = offset or 0
  for i = 1, 6 do
    g:led(8, i + 1 + off, track_focus == i and 10 or 6)
    g:led(9, i + 1 + off, track_focus == i and 10 or 6)
    if track[i].transpose < 0 then
      g:led(params:get(i.."transpose"), i + 1 + off, 10)
    elseif track[i].transpose > 0 then
      g:led(params:get(i.."transpose") + 1, i + 1 + off, 10)
    end
  end
  if GRID_SIZE == 128 or offset == 8 then 
    grd.cutfocus_draw(8 + off)
  end
end

function grd.lfo_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vLFO and autofocus then
    set_view(vLFO)
  end
  if y > 1 and y < 8 and z == 1 then
    local i = y - 1
    if lfo_focus ~= i then
      lfo_focus = i
      arc_lfo_focus = lfo_focus
      update_param_lfo_rate()
    end
    if x == 1 then
      local action = lfo[lfo_focus].enabled == 1 and "lfo_off" or "lfo_on"
      if lfo_launch > 0 and action == "lfo_on" then
        local beat_sync = lfo_launch == 2 and bar_val or 1
        clock.run(function()
          clock.sync(beat_sync)
          local e = {t = eLFO, i = lfo_focus, action = action , sync = true} event(e)
        end)
      else
        local e = {t = eLFO, i = lfo_focus, action = action} event(e)
      end
    elseif x > 1 and x <= 16 then
      params:set("lfo_depth_lfo_"..lfo_focus, (x - 2) * util.round_up((100 / 14), 0.1))
    end
  end
  if y == 8 then
    if x == 1 and z == 1 then
      lfo_launch = util.wrap(lfo_launch + 1, 0, 2)
    end
    if x > 2 and x < 9 then
      lfo_trksel = z == 1 and (x - 2) or 0
    end
    if x == 9 and z == 1 then
      set_lfo(lfo_focus, "none")
    end
    if x > 9 then
      lfo_dstsel = z == 1 and (x - 9) or 0
      if z == 1 and lfo_trksel > 0 then
        set_lfo(lfo_focus, lfo_params[lfo_dstsel], lfo_trksel)
      end
    end
  end
  dirtyscreen = true
end

function grd.lfo_draw(offset)
  local off = offset or 0
  for i = 1, 6 do
    g:led(1, i + 1 + off, params:get("lfo_lfo_"..i) == 2 and math.floor(util.linlin(0, 1, 6, 15, lfo[i].slope)) or 3) --nice one mat!
    local range = math.floor(util.linlin(0, 100, 2, 16, params:get("lfo_depth_lfo_"..i)))
    g:led(range, i + 1 + off, 7)
    for x = 2, range - 1 do
      g:led(x, i + 1 + off, 3)
    end
    g:led(i + 2, 8 + off, lfo_trksel == i and 12 or 2)
  end
  for i = 1, 7 do
    g:led(i + 9, 8 + off, lfo_dstsel == i and 12 or 2)
  end
  g:led(1, 8 + off, lfo_launch * 6)
end

function grd.env_keys(x, y, z, offset)
  local y = offset and y - offset or y
  local i = y - 1
  if z == 1 and view ~= vENV and autofocus then
    set_view(vENV)
  end
  if z == 1 then
    if y > 1 and y < 8 then
      if x == 1 then
        params:set(i.."adsr_active", env[i].active and 1 or 2)
      elseif x == 2 then
        env_focus = i
        if env[i].active then
          local e = {t = eGATEON, i = i} event(e)
        end
      end
    end
  elseif z == 0 then
    if y > 1 and y < 8 then
      if x == 2 then
        if env[i].active then
          local e = {t = eGATEOFF, i = i} event(e)
        end
      end
    end
  end
  dirtyscreen = true
end

function grd.env_draw(offset)
  local off = offset or 0
  for i = 1, 6 do
    g:led(1, i + 1 + off, env[i].active and 10 or 3)
    local range = math.floor(util.linlin(1, 100, 2, 16, track[i].level * 100))
    if env[i].active then
      g:led(range, i + 1 + off, 7)
      for x = 2, range - 1 do
        g:led(x, i + 1 + off, 3)
      end
    end
    g:led(2, i + 1 + off, env_focus == i and 10 or 6)
  end
end

function grd.macro_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vMACRO and autofocus then
    set_view(vMACRO)
  end
  if x > 1 and x < 4 then
    local i = x - 1
    if y > 2 and y < 5 then -- macro slot assignment grid one / top row
      kmac.slot_focus = z == 1 and (y - 2) or 0
    elseif y == 5 and z == 1 then
      kmac.pattern_edit = not kmac.pattern_edit
    elseif y > 5 and y < 8 and GRID_SIZE == 256 then -- macro slot assignment grid one / top row
      kmac.slot_focus = z == 1 and (y - 3) or 0
    end
  elseif x > 4 and x < 13 then
    local i = x - 4
    if y > 1 and y < 8 then
      if kmac.slot_focus > 0 then -- if kit edit mode
        if y > 3 and y < 7 then
          kmac.slot[kmac.slot_focus][i] = y - 3 -- assign to PTN, SNP, PIN
        end
      elseif kmac.pattern_edit then
        if z == 1 then
          pattern_focus = i
          if y == 4 then
            pattern_actions(i, z)
          elseif y == 5 then
            pattern[i].synced = not pattern[i].synced
          elseif y == 6 then
            local val = util.wrap(pattern[i].count_in + 1, 1, 3)
            params:set("patterns_countin"..i, val)
          end
        end
      else
        if y == 4 then
          pattern_actions(i, z)
        elseif y == 5 then
          snapshot_actions(i, z)
        elseif y == 6 then
          punch_actions(i, z)
        end
      end
    end
  elseif x > 13 and x < 16 and y > 2 and y < 8 and z == 1 then
    if y < 6 then
      pmac_focus = (x - 13) + (y - 3) * 2
    elseif y > 5 and y < 8 then
      local e = (x - 13) + (y - 6) * 2
      if pmac_edit_view then
        if e ~= pmac_enc then
          pmac_enc = e
        else
          pmac_edit_view = false
        end
      else
        pmac_enc = e
        pmac_edit_view = true
      end
    end
  end
  dirtyscreen = true
end

function grd.macro_draw(offset)
  local off = offset or 0
  for x = 2, 3 do
    g:led(x, 3 + off, kmac.slot_focus == 1 and 10 or 2)
    g:led(x, 4 + off, kmac.slot_focus == 2 and 10 or 2)
    g:led(x, 5 + off, kmac.pattern_edit and 6 or 1)
    g:led(x, 6 + off, kmac.slot_focus == 3 and 10 or 2)
    g:led(x, 7 + off, kmac.slot_focus == 4 and 10 or 2)
  end
  if kmac.slot_focus > 0 then
    for i = 1, 8 do
      g:led(i + 4, 4 + off, kmac.slot[kmac.slot_focus][i] == mPTN and 12 or 6)
      g:led(i + 4, 5 + off, kmac.slot[kmac.slot_focus][i] == mSNP and 12 or 4)
      g:led(i + 4, 6 + off, kmac.slot[kmac.slot_focus][i] == mPIN and 12 or 2)
    end
  else
    for i = 1, 8 do
      if pattern[i].rec == 1 and pattern[i].count == 0 then
        g:led(i + 4, 4 + off, 15)
      elseif pattern[i].rec == 1 and pattern[i].count > 0 then
        g:led(i + 4, 4 + off, pulse_key_fast)
      elseif pattern[i].overdub == 1 then
        g:led(i + 4, 4 + off, pulse_key_fast)
      elseif pattern[i].play == 1 then
        g:led(i + 4, 4 + off, pattern[i].flash and 15 or 13)
      elseif pattern[i].count > 0 then
        g:led(i + 4, 4 + off, 8)
      else
        g:led(i + 4, 4 + off, 4)
      end
    end
    if kmac.pattern_edit then
      for i = 1, 8 do
        local l = pattern_focus == i and 2 or 0
        g:led(i + 4, 3 + off, l)
        g:led(i + 4, 5 + off, (pattern[i].synced and 10 or 3) + l)
        g:led(i + 4, 6 + off, ((pattern[i].count_in) * 4 - 2) + l)
        g:led(i + 4, 7 + off, l)
      end
    else
      for i = 1, 8 do
        g:led(i + 4, 5 + off, snap[i].active and 15 or ((snap_last == i and snap[i].data) and 10 or (snap[i].data and 6 or 2)))
        g:led(i + 4, 6 + off, punch.rec == i and 15 or (punch[i].active and 10 or (punch[i].has_data and 4 or 1)))
      end
    end
  end
  for i = 1, 2 do
    local x = i + 13
    for j = 1, 3 do
      local y = j + 2
      local num = i + (j - 1) * 2
      g:led(x, y + off, pmac_edit_view and (pmac_focus == num and 12 or 4) or 2)
    end
    g:led(x, 6 + off, pmac_edit_view and (pmac_enc == i and 10 or 2) or 4)
    g:led(x, 7 + off, pmac_edit_view and (pmac_enc == i + 2 and 10 or 2) or 4)
  end
end

function grd.tape_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vTAPE and autofocus then
    set_view(vTAPE)
  end
  if y > 1 and y < 8 then
    local i = y - 1
    if x < 9 and z == 1 then
      track_focus = i
      arc_track_focus = i
      track[i].splice_focus = x
      arc_splice_focus = track[i].splice_focus
      if track[i].loaded then
        if alt == 1 and mod == 0 then
          load_splice(i, x)
        elseif alt == 0 and mod == 1 then
          local s = track[i].splice_focus
          local src = tp[i].side == 1 and 1 or 2
          local dst = tp[i].side == 1 and 2 or 1
          mirror_splice(i, s, src, dst)
          show_message("splice   copied   to   "..(dst == 1 and "main" or "temp").."   buffer")
        end
      else
        queue_track_tape(i)
      end
      render_splice(i)
    elseif x == 9 then
      track_focus = i
      arc_track_focus = i
      view_buffer = z == 1 and true or false
      render_splice(i)
    elseif x == 10 and z == 1 then
      if alt == 1 and mod == 0 then
        params:set(i.."tempo_map_mode", util.wrap(track[i].tempo_map + 2, 1, 3))
      elseif mod == 1 and alt == 0 then
        params:set(i.."tape_side", tp[i].side == 1 and 2 or 1)
        render_splice(i)
      end
    elseif x == 11 then
      track_focus = i
      arc_track_focus = i
      view_splice_info = z == 1 and true or false
      if z == 0 then
        render_splice(i)
      end
    elseif x == 12 and z == 1 then
      if tp[i].input == 1 then
        params:set(i.."input_options", 3)
      elseif tp[i].input == 2 then
        params:set(i.."input_options", 4)
      elseif tp[i].input == 3 then
        params:set(i.."input_options", 1)
      elseif tp[i].input == 4 then 
        params:set(i.."input_options", 2)
      end
    elseif x == 13 and z == 1 then
      if tp[i].input == 1 then
        params:set(i.."input_options", 2)
      elseif tp[i].input == 2 then
        params:set(i.."input_options", 1)
      elseif tp[i].input == 3 then
        params:set(i.."input_options", 4)
      elseif tp[i].input == 4 then 
        params:set(i.."input_options", 3)
      end
    elseif x == 14 and y < 7 then
      sends_focus = i
      view_track_send = z == 1 and true or false
      if z == 0 then
        render_splice(i)
      end
    elseif x == 15 and y < 6 and z == 1 then
      if tp[i].buffer == tp[5].buffer then
        show_message("assign   different   buffer")
      else
        track[i].route_t5 = 1 - track[i].route_t5
        local e = {t = eROUTE, i = i, ch = 5, route = track[i].route_t5} event(e)
      end
    elseif x == 16 and y < 7 and z == 1 then
      if tp[i].buffer == tp[6].buffer then
        show_message("assign   different   buffer")
      else
        track[i].route_t6 = 1 - track[i].route_t6
        local e = {t = eROUTE, i = i, ch = 6, route = track[i].route_t6} event(e)
      end
    elseif x == 16 and y == 7 and z == 1 then
      view_presets = not view_presets
      if view_presets == false then
        render_splice(i)
      end
    end
  elseif y == 8 then
    if GRID_SIZE == 128 or offset == 8 then 
      grd.cutfocus_keys(x, z)
    end
  end
  dirtyscreen = true
end

function grd.tape_draw(offset)
  local off = offset or 0
  -- splice selection
  for i = 1, 8 do
    g:led(i, track_focus + 1 + off, 2)
    for j = 1, 6 do
      if i == track[j].splice_active then
        g:led(i, j + 1 + off, track[j].loaded and 10 or pulse_key_mid)
      elseif i == track[j].splice_focus then
        g:led(i, j + 1 + off, splice_queued and pulse_key_fast or 5)
      end
    end
  end
  -- buffer selection / tempo map
  if mod == 1 then
    for i = 1, 6 do
      g:led(10, i + 1 + off, tp[i].side == 1 and 10 or 4)
    end
  else
    for i = 1, 6 do
      g:led(10, i + 1 + off, track[i].tempo_map == 2 and 12 or (track[i].tempo_map == 1 and 7 or 2))
    end
  end
  -- input selection
  for i = 1, 6 do
    g:led(12, i + 1 + off, (tp[i].input == 1 or tp[i].input == 2) and 6 or 2)
    g:led(13, i + 1 + off, (tp[i].input == 1 or tp[i].input == 3) and 6 or 2)
  end
  -- routing
  for i = 1, 4 do
    local y = i + 1 + off
    g:led(15, y, track[i].route_t5 == 1 and 9 or 2)
  end
  for i = 1, 5 do
    local y = i + 1 + off
    g:led(16, y, track[i].route_t6 == 1 and 9 or 2)
  end
  g:led(16, 7 + off, view_presets and 15 or 5)
  -- cut focus
  if GRID_SIZE == 128 or offset == 8 then 
    grd.cutfocus_draw(8 + off)
  end
end

return grd
