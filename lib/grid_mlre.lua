-- grid for mlre
local grd = {}

function grd.nav(x, z, pos)
  if z == 1 then
    if x == 1 then
      if alt == 1 then
        clear_splice(track_focus)
      else
        set_gridview(vREC, pos)
        set_view(vMAIN)
      end
    elseif x == 2 then
      if alt == 1 then
        clear_tape(track_focus)
      else
        set_gridview(vCUT, pos)
        set_view(vMAIN)
        cutview_hold = true
      end
    elseif x == 3 then
      if alt == 1 then
        clear_buffers()
      else
        set_gridview(vTRSP, pos)
        set_view(vMAIN)
      end
    elseif x == 4 and alt == 0 then
      local view = pos == "o" and grido_view or gridz_view
      if view == vLFO then
        set_gridview(vENV, pos)
        set_view(vENV)
      else
        set_gridview(vLFO, pos)
        set_view(vLFO)
      end
    elseif x == 15 and alt == 0 and mod == 0 and pos == "o" then
      quantizing = not quantizing
    elseif x == 16 then alt = 1
      dirtyscreen = true
    elseif x == 15 and alt == 1 then
      set_gridview(vTAPE, pos)
      set_view(vTAPE)
      render_splice()
    elseif x == 15 and mod == 1 then
      set_gridview(vPATTERNS, pos)
      set_view(vPATTERNS)
    elseif x == 14 and alt == 0 then
      mod = 1
    elseif x == 14 and alt == 1 then
      retrig()  -- set all playing tracks to pos 1
    elseif x == 13 and alt == 0 and stop_all_active then
      stopall() -- stops all tracks
    elseif x == 13 and alt == 1 then
      altrun()  -- stops all running tracks and runs all stopped tracks if track[i].sel == 1
    end
  elseif z == 0 then
    if x == 2 then cutview_hold = false end
    if x == 16 then alt = 0 dirtyscreen = true
    elseif x == 14 and alt == 0 then mod = 0 -- lock mod if mod released before alt is released
    end
  end
  if GRID_SIZE == 128 then
    if z == 1 then
      if x > 4 and x < (macro_slot_mode == 1 and 9 or 13) and macro_slot_mode ~= 3 then
        local i = x - 4
        if alt == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "clear"} event(e)
        elseif mod == 1 then
          if pattern[i].count == 0 then
            local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
          elseif pattern[i].rec == 1 then
            local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
            local e = {t = ePATTERN, i = i, action = "start"} event(e)
          elseif pattern[i].overdub == 1 then
            local e = {t = ePATTERN, i = i, action = "overdub_undo"} event(e)
          else
            local e = {t = ePATTERN, i = i, action = "overdub_on"} event(e)
          end
        elseif pattern[i].overdub == 1 then
          local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
        elseif pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "start"} event(e)
        elseif pattern[i].count == 0 then
          local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
        elseif pattern[i].play == 1 and pattern[i].overdub == 0 then
          local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        else
          local e = {t = ePATTERN, i = i, action = "start"} event(e)
        end
      elseif x > (macro_slot_mode == 3 and 4 or 8) and x < 13 and macro_slot_mode ~= 2 then
        local i = x - 4
        if snapshot_mode then
          if alt == 1 then
            snap[i].data = false
            snap[i].active = false
          elseif alt == 0 then
            if not snap[i].data then
              save_snapshot(i)
            elseif snap[i].data then
              if held_focus > 0 then
                load_snapshot(i, track_focus)
              else
                load_snapshots(i)
              end
              snap[i].active = true
            end
          end
        elseif not snapshot_mode then
          if alt == 1 then
            recall[i].event = {}
            recall[i].recording = false
            recall[i].has_data = false
            recall[i].active = false
          elseif recall[i].recording == true then
            recall[i].recording = false
          elseif recall[i].has_data == false then
            recall[i].recording = true
          elseif recall[i].has_data == true then
            recall_exec(i)
            recall[i].active = true
          end
        end
      end
    elseif z == 0 then
      if x > (macro_slot_mode == 3 and 4 or 8) and x < 13 and macro_slot_mode ~= 2 then
        if snapshot_mode then
          snap[x - 4].active = false
        else
          recall[x - 4].active = false
        end
      end
    end
  elseif GRID_SIZE == 256 then
    local i = (x - 4)
    if x > 4 and x < 13 then
      if pos == "o" and z == 1 then
        if alt == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "clear"} event(e)
        elseif mod == 1 then
          if pattern[i].count == 0 then
            local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
          elseif pattern[i].rec == 1 then
            local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
            local e = {t = ePATTERN, i = i, action = "start"} event(e)
          elseif pattern[i].overdub == 1 then
            local e = {t = ePATTERN, i = i, action = "overdub_undo"} event(e)
          else
            local e = {t = ePATTERN, i = i, action = "overdub_on"} event(e)
          end
        elseif pattern[i].overdub == 1 then
          local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
        elseif pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
          local e = {t = ePATTERN, i = i, action = "start"} event(e)
        elseif pattern[i].count == 0 then
          local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
        elseif pattern[i].play == 1 and pattern[i].overdub == 0 then
          local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        else
          local e = {t = ePATTERN, i = i, action = "start"} event(e)
        end
      elseif pos == "z" and z == 1 then
        if snapshot_mode then
          if alt == 1 then
            snap[i].data = false
            snap[i].active = false
          elseif alt == 0 then
            if not snap[i].data then
              save_snapshot(i)
            elseif snap[i].data then
              if held_focus < 0 then
                load_snapshot(i, track_focus)
              else
                load_snapshots(i)
              end
              snap[i].active = true
            end
          end
        elseif not snapshot_mode then
          if alt == 1 then
            recall[i].event = {}
            recall[i].recording = false
            recall[i].has_data = false
            recall[i].active = false
          elseif recall[i].recording == true then
            recall[i].recording = false
          elseif recall[i].has_data == false then
            recall[i].recording = true
          elseif recall[i].has_data == true then
            recall_exec(i)
            recall[i].active = true
          end
        end
      elseif pos == "z" and z == 0 then
        local row = pos == "o" and 0 or 1
        local i = (x - 8) + row * 4
        if snapshot_mode then
          snap[i].active = false
        else
          recall[i].active = false
        end
      end  
    end
  end
  dirtygrid = true
end

function grd.drawnav(y)
  local view = y == 9 and gridz_view or grido_view
  local one = y == 1 and true or false
  g:led(1, y, view == vREC and 10 or 4) -- vREC
  g:led(2, y, view == vCUT and 10 or 3) -- vCUT
  g:led(3, y, view == vTRSP and 10 or 2) -- vTRSP
  g:led(4, y, view == vLFO and 10 or (view == vENV and pulse_key_slow or 0)) -- vLFO
  g:led(16, y, alt == 1 and 15 or 9) -- alt
  g:led(15, y, y ~= 9 and (quantizing and (pulse_bar and 15 or (pulse_beat and 6 or 2))) or 3) -- Q flash
  g:led(14, y, mod == 1 and 9 or 2) -- mod
  if one then 
    for i = 1, (macro_slot_mode == 1 and 4 or 8) do
      if macro_slot_mode ~= 3 then
        if pattern[i].rec == 1 and pattern[i].count == 0 then
          g:led(i + 4, y, 15)
        elseif pattern[i].rec == 1 and pattern[i].count > 0 then
          g:led(i + 4, y, pulse_key_fast)
        elseif pattern[i].overdub == 1 then
          g:led(i + 4, y, pulse_key_fast)
        elseif pattern[i].play == 1 then
          g:led(i + 4, y, pattern[i].flash and 15 or 12)
        elseif pattern[i].count > 0 then
          g:led(i + 4, y, 9)
        else
          g:led(i + 4, y, 4)
        end
      end
    end
    for i = (macro_slot_mode == 1 and 5 or 1), 8 do
      if macro_slot_mode ~= 2 then
        local b = 2
        if snapshot_mode then
          if snap[i].active then
            b = 10
          elseif snap[i].data then
            b = 6
          end
        else
          if recall[i].recording then
            b = 15
          elseif recall[i].active then
            b = 10
          elseif recall[i].has_data then
            b = 6
          end
        end
        g:led(i + 4, y, b)
      end
    end
  else
    for i = 1, 8 do
      if y == 8 then
        if pattern[i].rec == 1 and pattern[i].count == 0 then
          g:led(i + 4, y, 15)
        elseif pattern[i].rec == 1 and pattern[i].count > 0 then
          g:led(i + 4, y, pulse_key_fast)
        elseif pattern[i].overdub == 1 then
          g:led(i + 4, y, pulse_key_fast)
        elseif pattern[i].play == 1 then
          g:led(i + 4, y, pattern[i].flash and 15 or 12)
        elseif pattern[i].count > 0 then
          g:led(i + 4, y, 9)
        else
          g:led(i + 4, y, 4)
        end
      elseif y == 9 then
        local b = 2
        if snapshot_mode then
          if snap[i].active then
            b = 10
          elseif snap[i].data then
            b = 6
          end
        else
          if recall[i].recording then
            b = 15
          elseif recall[i].active then
            b = 10
          elseif recall[i].has_data then
            b = 6
          end
        end
        g:led(i + 4, y, b)
      end
    end
  end
end

function grd.cutfocus_keys(x, z)
  local row = track_focus + 1
  local i = track_focus
  if z == 1 and held[row] then heldmax[row] = 0 end
  held[row] = held[row] + (z * 2 - 1)
  if held[row] > heldmax[row] then heldmax[row] = held[row] end
  if z == 1 then
    if alt == 1 and mod == 0 then
      toggle_playback(i)
    elseif mod == 1 then -- "hold mode" as on cut page
      heldmax[row] = x
      loop_event(i, x, x)
    elseif held[row] == 1 then -- cut at pos
      if not track[i].loaded then
        load_track_tape(i)
      end
      first[row] = x
      local cut = x - 1
      if track[i].play == 1 or track[i].start_launch == 1 then
        local e = {} e.t = eCUT e.i = i e.pos = cut event(e)
        if env[i].active then
          local e = {} e.t = eGATEON e.i = i event(e)
        end
      elseif track[i].play == 0 and track[i].start_launch > 1 then
        clock.run(function()
          local beats = track[i].start_launch == 2 and 1 or 4
          clock.sync(beats)
          local e = {} e.t = eCUT e.i = i e.pos = cut e.sync = true event(e)
          if env[i].active then
            local e = {} e.t = eGATEON e.i = i e.sync = true event(e)
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
    end
    if track[i].play_mode == 3 and track[i].loop == 0 and not env[i].active then
      local e = {} e.t = eSTOP e.i = i event(e)
    end
    if env[i].active and track[i].loop == 0 then
      local e = {} e.t = eGATEOFF e.i = i event(e)
    end
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
  if z == 1 and view ~= vMAIN then
    set_view(vMAIN)
  end
  if y > 1 and y < 8 then
    local i = y - 1
    if x > 2 and x < 7 then
      held_focus = held_focus + (z * 2 - 1)
      if z == 1 then
        if track_focus ~= i then
          track_focus = i
          arc_track_focus = track_focus
          dirtyscreen = true
        end
        if alt == 1 and mod == 0 then
          params:set(i.."tempo_map_mode", util.wrap(params:get(i.."tempo_map_mode") + 1, 1, 3))
        elseif alt == 0 and mod == 1 then
          params:set(track_focus.."buffer_sel", tape[track_focus].side == 1 and 2 or 1)
        end
      end
    elseif x == 1 and alt == 0 and z == 1 then
      toggle_rec(i)
    elseif x == 1 and alt == 1 and z == 1 then
      track[i].fade = 1 - track[i].fade
      set_rec(i)
    elseif x == 2 and z == 1 then
      track[i].oneshot = 1 - track[i].oneshot
      for n = 1, 6 do
        if n ~= i then
          track[n].oneshot = 0
        end
      end
      armed_track = i
      arm_thresh_rec(i) -- amp_in poll starts
      update_dur(i)  -- duration of oneshot is set
      if alt == 1 then -- if alt then go into autolength mode and stop track
        autolength = true
        local e = {}
        e.t = eSTOP
        e.i = i
        event(e)
      else
        autolength = false
      end
    elseif x == 16 and alt == 0 and mod == 0 and z == 1 then
      toggle_playback(i)
    elseif x == 16 and alt == 0 and mod == 1 and z == 1 then
      track[i].sel = 1 - track[i].sel
    elseif x == 16 and alt == 1 and mod == 0 and z == 1 then
      local n = 1 - track[i].mute
      local e = {} e.t = eMUTE e.i = i e.mute = n
      event(e)
    elseif x > 8 and x < 16 and alt == 0 and z == 1 then
      local n = x - 12
      local e = {} e.t = eSPEED e.i = i e.speed = n
      event(e)
    elseif x == 8 and alt == 0 and z == 1 then
      local n = 1 - track[i].rev
      local e = {} e.t = eREV e.i = i e.rev = n
      event(e)
    elseif x == 8 and alt == 1 and z == 1 then
      params:set(i.."warble_state", track[i].warble == 0 and 2 or 1)
      update_rate(i)
    elseif x == 12 and alt == 1 and z == 1 then
      randomize(i)
    end
    dirtygrid = true
  elseif y == 8 then -- cut for focused track
    if GRID_SIZE == 128 or offset == 8 then 
      grd.cutfocus_keys(x, z)
    end
  end
end

function grd.rec_draw(offset)
  local off = offset or 0
  g:led(4, track_focus + 1 + off, tape[track_focus].side == 1 and 7 or 3)
  g:led(5, track_focus + 1 + off, tape[track_focus].side == 2 and 7 or 3)
  for i = 1, 6 do
    local y = i + 1 + off
    g:led(1, y, track[i].rec == 1 and 15 or (track[i].fade == 1 and 7 or 3)) -- rec key
    g:led(2, y, track[i].oneshot == 1 and pulse_key_mid or 0)
    g:led(3, y, track[i].loaded and (track_focus == i and 7 or 0) or pulse_key_mid)
    g:led(6, y, track[i].tempo_map == 1 and 7 or (track[i].tempo_map == 2 and 12 or (track_focus == i and 3 or 0)))
    g:led(8, y, track[i].rev == 1 and (track[i].warble == 1 and 15 or 11) or (track[i].warble == 1 and 8 or 4))
    g:led(16, y, 3) -- start/stop
    if track[i].mute == 1 then
      g:led(16, y, track[i].play == 0 and (track[i].sel == 0 and pulse_key_slow - 2 or pulse_key_slow) or (track[i].sel == 0 and pulse_key_slow or pulse_key_slow + 3))
    elseif track[i].play == 1 and track[i].sel == 1 then
      g:led(16, y, 15)
    elseif track[i].play == 1 and track[i].sel == 0 then
      g:led(16, y, 10)
    elseif track[i].play == 0 and track[i].sel == 1 then
      g:led(16, y, 5)
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
  if z == 1 and view ~= vMAIN then
    set_view(vMAIN)
  end
  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z * 2 - 1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end
  if y == 8 and z == 1 then
    local i = track_focus
    if mod == 0 then
      if x >= 1 and x <=8 then local e = {} e.t = eTRSP e.i = i e.val = x event(e) end
      if x >= 9 and x <=16 then local e = {} e.t = eTRSP e.i = i e.val = x - 1 event(e) end
    elseif mod == 1 then
      if x == 8 then
        local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
      elseif x == 9 then
        local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
      end
    end
  else
    local i = y - 1
    if z == 1 then
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
      end
      if alt == 1 and y < 8 then
        toggle_playback(i)
      elseif mod == 1 and y < 8 then -- "hold mode"
        heldmax[y] = x
        loop_event(i, x, x)
      elseif y < 8 and held[y] == 1 then
        if not track[i].loaded then
          load_track_tape(i)
        end
        first[y] = x
        local cut = x - 1
        if track[i].play == 1 or track[i].start_launch == 1 then
          local e = {} e.t = eCUT e.i = i e.pos = cut event(e)
          if env[i].active then
            local e = {} e.t = eGATEON e.i = i event(e)
          end
        elseif track[i].play == 0 and track[i].start_launch > 1 then
          clock.run(function()
            local beats = track[i].start_launch == 2 and 1 or 4
            clock.sync(beats)
            local e = {} e.t = eCUT e.i = i e.pos = cut e.sync = true event(e)
            if env[i].active then
              local e = {} e.t = eGATEON e.i = i e.sync = true event(e)
            end
          end)
        end
      elseif y < 8 and held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if y < 8 then 
        if held[y] == 1 and heldmax[y] == 2 then
          local lstart = math.min(first[y], second[y])
          local lend = math.max(first[y], second[y])
          loop_event(i, lstart, lend)
        else
          if track[i].play_mode == 3 and track[i].loop == 0 and not env[i].active then
            local e = {} e.t = eSTOP e.i = i event(e)
          end
          if env[i].active and track[i].loop == 0 then
            local e = {} e.t = eGATEOFF e.i = i event(e)
          end
        end
      end
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
      g:led(track[i].pos_grid, i + 1 + off, track[i].loaded and (track_focus == i and 15 or 10) or pulse_key_mid)
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
  if z == 1 and view ~= vMAIN then
    set_view(vMAIN)
  end
  if y > 1 and y < 8 then
    if z == 1 then
      local i = y - 1
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
      end
      if alt == 0 and mod == 0 then
        if x >= 1 and x <=8 then local e = {} e.t = eTRSP e.i = i e.val = x event(e) end
        if x >= 9 and x <=16 then local e = {} e.t = eTRSP e.i = i e.val = x - 1 event(e) end
      end
      if alt == 1 and x > 7 and x < 10 then
        toggle_playback(i)
      end
      if mod == 1 then
        if x == 8 then
          local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
        elseif x == 9 then
          local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
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
  if z == 1 and view ~= vLFO then
    set_view(vLFO)
  end
  if z == 1 then
    if y > 1 and y < 8 then
      local i = y - 1
      if lfo_focus ~= i then
        lfo_focus = i
        arc_lfo_focus = lfo_focus
        if lfo_pageNum == 3 then
          lfo_page_params_r[lfo_pageNum] = lfo_rate_params[params:get("lfo_mode_lfo_"..lfo_focus)]
        end
      end
      if x == 1 then
        params:set("lfo_lfo_"..lfo_focus, params:get("lfo_lfo_"..lfo_focus) == 1 and 2 or 1)
      elseif x > 1 and x <= 16 then
        params:set("lfo_depth_lfo_"..lfo_focus, (x - 2) * util.round_up((100 / 14), 0.1))
      end
    end
    if y == 8 then
      if x > 2 and x < 9 then
        lfo_trksel = x - 2
      end
      if x == 9 then
        set_lfo(lfo_focus, lfo_trksel, 'none')
      end
      if x > 9 then
        lfo_dstview = 1
        lfo_dstsel = x - 9
        set_lfo(lfo_focus, lfo_trksel, lfo_params[lfo_dstsel])
      end
    end
  elseif z == 0 then
    if x > 9 then
      lfo_dstview = 0
    end
  end
  dirtyscreen = true
  dirtygrid = true
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
    g:led(i + 9, 8 + off, (lfo_dstsel == i and lfo_dstview == 1) and 12 or 1)
  end
end

function grd.env_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vENV then
    set_view(vENV)
  end
  if z == 1 then
    if y > 1 and y < 8 then
      local i = y - 1
      if x == 1 then
        params:set(i.."adsr_active", env[i].active and 1 or 2)
      elseif x == 2 then
        if env_focus ~= i then
          env_focus = i
        end
        if env[i].active then
          local e = {} e.t = eGATEON e.i = i event(e)
        end
      end
    end
  elseif z == 0 then
    if y > 1 and y < 8 then
      local i = y - 1
      if x == 2 then
        if env[i].active then
          local e = {} e.t = eGATEOFF e.i = i event(e)
        end
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
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

function grd.pattern_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vPATTERNS then
    set_view(vPATTERNS)
  end
  if z == 1 then
    if x > 1 and x < 4 then
      if y > 2 and y < 6 and GRID_SIZE == 128 then
        params:set("slot_assign", y - 2)
      elseif y == 6 then
        snapshot_mode = not snapshot_mode
      end
    elseif x > 4 and x < 13 then
      local i = x - 4
      -- set track_focus
      if y > 1 and y < 9 then
        if pattern_focus ~= i then
          pattern_focus = i
        end
      end
      -- set params
      if y == 3 then
        pattern[i].synced = not pattern[i].synced
      elseif y == 4 then
        if pattern[i].synced then 
          params:set("patterns_countin"..i, pattern[i].count_in == 1 and 2 or 1)
        end
      end
    elseif x > 13 and x < 16 then
      if y > 2 and y < 7 then
        local val = (y - 2) + (x - 14) * 4
        params:set("quant_rate", val)
        show_message("key    quantization:     "..params:string("quant_rate"))
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

function grd.pattern_draw(offset)
  local off = offset or 0
  for i = 1, 2 do
    local x = i + 1
    g:led(x, 3 + off, GRID_SIZE == 128 and (macro_slot_mode == 1 and 10 or 4) or 1)
    g:led(x, 4 + off, GRID_SIZE == 128 and (macro_slot_mode == 2 and 10 or 4) or 1)
    g:led(x, 5 + off, GRID_SIZE == 128 and (macro_slot_mode == 3 and 10 or 4) or 1)
    g:led(x, 6 + off, snapshot_mode and 4 or 10)
  end
  for i = 1, 8 do
    g:led(i + 4, 3 + off, pattern[i].synced and 10 or 4)
    g:led(i + 4, 4 + off, pattern[i].synced and (pattern[i].count_in == 4 and 6 or 2) or 0)
    g:led(i + 4, 5 + off, pattern_focus == i and 6 or 0)
    g:led(i + 4, 6 + off, pattern_focus == i and 6 or 0)
  end
  for i = 1, 2 do
    local x = i + 13
    for j = 1, 4 do
      local y = j + 2 + off
      g:led(x, y, params:get("quant_rate") == (y - 2) + (x - 14) * 4 and 10 or 4)
    end
  end
end

function grd.tape_keys(x, y, z, offset)
  local y = offset and y - offset or y
  if z == 1 and view ~= vTAPE then
    set_view(vTAPE)
  end
  if y > 1 and y < 8 then
    local i = y - 1
    if x < 9 and z == 1 then
      track_focus = i
      arc_track_focus = i
      track[track_focus].splice_focus = x
      arc_splice_focus = track[track_focus].splice_focus
      if alt == 1 and mod == 0 then
        local e = {} e.t = eSPLICE e.i = track_focus e.active = x event(e)
      elseif alt == 0 and mod == 1 then
        local src = tape[track_focus].side == 1 and 1 or 2
        local dst = tape[track_focus].side == 1 and 2 or 1
        copy_buffer(track_focus, src, dst)
      end
      render_splice()
    elseif x == 9 then
      track_focus = i
      arc_track_focus = i
      view_buffer = z == 1 and true or false
      render_splice()
    elseif x == 10 and z == 1 then
      if mod == 1 then
        params:set(i.."tempo_map_mode", util.wrap(params:get(i.."tempo_map_mode") + 1, 1, 3))
      else
        params:set(i.."buffer_sel", tape[i].side == 1 and 2 or 1)
        if track_focus == i then
          render_splice()
        end
      end
    elseif x == 11 then
      track_focus = i
      arc_track_focus = track_focus
      view_splice_info = z == 1 and true or false
      if z == 0 then
        render_splice()
      end
    elseif x == 12 and z == 1 then
      if tape[i].input == 1 then
        params:set(i.."input_options", 3)
      elseif tape[i].input == 2 then
        params:set(i.."input_options", 4)
      elseif tape[i].input == 3 then
        params:set(i.."input_options", 1)
      elseif tape[i].input == 4 then 
        params:set(i.."input_options", 2)
      end
    elseif x == 13 and z == 1 then
      if tape[i].input == 1 then
        params:set(i.."input_options", 2)
      elseif tape[i].input == 2 then
        params:set(i.."input_options", 1)
      elseif tape[i].input == 3 then
        params:set(i.."input_options", 4)
      elseif tape[i].input == 4 then 
        params:set(i.."input_options", 3)
      end
    elseif x == 14 and y < 7 then
      sends_focus = i
      view_track_send = z == 1 and true or false
      if z == 0 then
        render_splice()
      end
    elseif x == 15 and z == 1 then
      if y < 6 then
        track[i].t5 = 1 - track[i].t5
        local e = {} e.t = eROUTE e.i = i e.ch = 5 e.route = track[i].t5 event(e)
      end
    elseif x == 16 then
      if y < 7 and z == 1 then
        track[i].t6 = 1 - track[i].t6
        local e = {} e.t = eROUTE e.i = i e.ch = 6 e.route = track[i].t6 event(e)
      elseif y == 7 and z == 1 then
        view_presets = not view_presets
        if view_presets == false then
          render_splice()
        end
      end
    end
  elseif y == 8 then
    if GRID_SIZE == 128 or offset == 8 then 
      grd.cutfocus_keys(x, z)
    end
  end
  dirtyscreen = true
  dirtygrid = true
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
        g:led(i, j + 1 + off, 5)
      end
    end
  end

  -- buffer selection / tempo map
  if mod == 1 then
    for i = 1, 6 do
      g:led(10, i + 1 + off, track[i].tempo_map == 2 and 12 or (track[i].tempo_map == 1 and 7 or 2))
    end
  else
    for i = 1, 6 do
      g:led(10, i + 1 + off, tape[i].side == 1 and 10 or 4)
    end
  end

  -- input selection
  for i = 1, 6 do
    g:led(12, i + 1 + off, (tape[i].input == 1 or tape[i].input == 2) and 6 or 2)
    g:led(13, i + 1 + off, (tape[i].input == 1 or tape[i].input == 3) and 6 or 2)
  end
  -- routing
  for i = 1, 4 do
    local y = i + 1 + off
    g:led(15, y, track[i].t5 == 1 and 9 or 2)
  end
  for i = 1, 5 do
    local y = i + 1 + off
    g:led(16, y, track[i].t6 == 1 and 9 or 2)
  end
  g:led(16, 7 + off, view_presets and 15 or 5)
  -- cut focus
  if GRID_SIZE == 128 or offset == 8 then 
    grd.cutfocus_draw(8 + off)
  end
end

return grd
