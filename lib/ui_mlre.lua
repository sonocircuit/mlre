-- ui for mlre

ui = {}

function display_message()
  if view_message ~= "" then
    screen.clear()
    screen.font_size(8)
    screen.level(10)
    screen.move(1, 24)
    screen.line_rel(128, 0)
    screen.move(1, 41)
    screen.line_rel(128, 0)
    screen.stroke()
    screen.level(15)
    screen.move(64, 35)
    screen.text_center(view_message)
  end
end


---------------------- MAIN VIEW -------------------------

function ui.main_key(n, z)
  if n == 2 and z == 1 then
    if shift == 0 then
      main_pageNum = util.wrap(main_pageNum - 1, 1, 8)
    else
      if macro_slot_mode == 2 then
        params:set("slot_assign", 3)
        show_message("recall   slots")
      elseif macro_slot_mode == 3 then
        params:set("slot_assign", 2)
        show_message("pattern   slots")
      end
    end
    dirtyscreen = true
  elseif n == 3 and z == 1 then
    if shift == 0 then
      main_pageNum = util.wrap(main_pageNum + 1, 1, 8)
    else
      if arc_is then
        arc_pageNum = (arc_pageNum % 2) + 1
        if arc_pageNum == 1 then
          show_message("arc  -  play head")
        elseif arc_pageNum == 2 then
          show_message("arc  -  levels")
        end
      end
    end
    dirtyscreen = true
  end
end

function ui.main_enc(n, d)
  if n == 1 then
    if shift == 0 then
      track_focus = util.clamp(track_focus + d, 1, 6)
    elseif shift == 1 then
      params:delta("output_level", d)
    end
    dirtyscreen = true
  elseif n == 2 then
    params:delta(track_focus..main_page_params_l[main_pageNum], d)
  elseif n == 3 then
    if main_page_params_r[main_pageNum] == "post_dry" then
      if params:get(track_focus.."filter_type") < 5 then
        params:delta(track_focus..main_page_params_r[main_pageNum], d)
      end
    else
      params:delta(track_focus..main_page_params_r[main_pageNum], d)
    end
  end
end

function ui.main_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(4, 12)
  screen.text("TRACK "..track_focus)
  for i = 1, 4 do
    screen.level(main_pageNum == i and 15 or 4)
    screen.rect(112 + (i - 1) * 4, 6, 2, 2)
    screen.fill()
  end
  for i = 1, 4 do
    screen.level(main_pageNum == i + 4 and 15 or 4)
    screen.rect(112 + (i - 1) * 4, 10, 2, 2)
    screen.fill()
  end
  -- param list
  screen.font_size(8)
  screen.level(4)
  screen.move(35, 54)
  screen.text_center(main_page_names_l[main_pageNum])
  screen.move(94, 54)
  screen.text_center(main_page_names_r[main_pageNum])
  screen.font_size(16)
  screen.level(15)
  screen.move(35, 40)
  screen.text_center(params:string(track_focus..main_page_params_l[main_pageNum]))
  screen.move(94, 40)
  if params:get(track_focus.."filter_type") == 5 and main_pageNum == 4 then
    screen.text_center("-")
  else
    screen.text_center(params:string(track_focus..main_page_params_r[main_pageNum]))
  end
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_main_delta(n, d)
  if arc_pageNum == 1 then
    -- enc 1:
    if n == 1 then
      -- start playback
      if params:get("arc_enc_1_start") == 2 then
        if track[track_focus].play == 0 and (d > 2 or d < -2) then
          local e = {} e.t = eSTART e.i = track_focus
          event(e)
          if params:get(track_focus.."play_mode") == 3 then
            local e = {} e.t = eGATEON e.i = track_focus
            event(e)
          end
        end
      end
      -- stop playback when enc stops
      if params:get(track_focus.."play_mode") == 3 then
        inc = (inc % 100) + 1
        clock.run(
          function()
            local prev_inc = inc
            clock.sleep(0.05)
            if prev_inc == inc then
              if params:get(track_focus.."adsr_active") == 2 then
                local e = {} e.t = eGATEOFF e.i = track_focus event(e)
              else
                local e = {} e.t = eSTOP e.i = track_focus event(e)
              end
            end
          end
        )
      end
      -- set direction
      if params:get("arc_enc_1_dir") == 2 then
        if d < -2 and track[track_focus].rev == 0 then
          local e = {} e.t = eREV e.i = track_focus e.rev = 1
          event(e)
        elseif d > 2 and track[track_focus].rev == 1 then
          local e = {} e.t = eREV e.i = track_focus e.rev = 0
          event(e)
        end
      end
      -- temp warble
      if (d > 10 or d < -10) and params:get("arc_enc_1_mod") == 2 then
        if track[track_focus].play == 1 then
          clock.run(
            function()
              local speedmod = 1 - d / 80
              local n = math.pow(2, track[track_focus].speed + track[track_focus].transpose + track[track_focus].detune)
              if track[track_focus].rev == 1 then n = -n end
              if track[track_focus].tempo_map == 2 then
                local bpmmod = clock.get_tempo() / clip[i].bpm
                n = n * bpmmod
              end
              local rate = n * speedmod
              softcut.rate_slew_time(track_focus, 0.25)
              softcut.rate(track_focus, rate)
              clock.sleep(0.4)
              update_rate(track_focus)
              softcut.rate_slew_time(track_focus, track[track_focus].rate_slew)
            end
          )
        end
      end
      -- scrub
      if (d > 2 or d < -2) and params:get("arc_enc_1_mod") == 3 then
        if track[track_focus].play == 1 then
          arc_inc1 = (arc_inc1 % 12) + 1
          if arc_inc1 == 1 then
            local shift = d / scrub_sens
            local curr_pos = track[track_focus].pos_abs
            local new_pos = curr_pos + shift
            softcut.position(track_focus, new_pos)
          end
        end
      end
    -- enc 2: activate loop or move loop window
    elseif n == 2 then
      if track[track_focus].loop == 0 and (d > 2 or d < -2) and alt == 0 then
        enc2_wait = true
        local e = {}
        e.t = eLOOP
        e.i = track_focus
        e.loop = 1
        e.loop_start = track[track_focus].loop_start
        e.loop_end = track[track_focus].loop_end
        event(e)
        if params:get(track_focus.."adsr_active") == 2 then
          local e = {} e.t = eGATEON e.i = track_focus event(e)
        end
        clock.run(
          function()
            clock.sleep(0.4)
            enc2_wait = false
            arc_inc2 = 0
          end
        )
      end
      if track[track_focus].loop == 1 and alt == 1 then
        local e = {} e.t = eUNLOOP e.i = track_focus event(e)
        if params:get(track_focus.."adsr_active") == 2 then
          local e = {} e.t = eGATEOFF e.i = track_focus event(e)
        end
      end
      if track[track_focus].loop == 1 and not enc2_wait then
        arc_inc2 = (arc_inc2 % 20) + 1
        local new_loop_start = track[track_focus].loop_start + d / 200
        local new_loop_end = track[track_focus].loop_end + d / 200
        if math.abs(new_loop_start) - 1 <= track[track_focus].loop_end and math.abs(new_loop_end) <= 16 then
          track[track_focus].loop_start = util.clamp(new_loop_start, 1, 16.9)
        end
        if math.abs(new_loop_end) + 1 >= track[track_focus].loop_start and math.abs(new_loop_start) >= 1 then
          track[track_focus].loop_end = util.clamp(new_loop_end, 0.1, 16)
        end
        if arc_inc2 == 20 and track[track_focus].play == 1 and pattern_rec then
          local e = {}
          e.t = eLOOP
          e.i = track_focus
          e.loop = 1
          e.loop_start = track[track_focus].loop_start
          e.loop_end = track[track_focus].loop_end
          event(e)
        else
          local lstart = clip[track_focus].s + (track[track_focus].loop_start - 1) / 16 * clip[track_focus].l
          local lend = clip[track_focus].s + (track[track_focus].loop_end) / 16 * clip[track_focus].l
          softcut.loop_start(track_focus, lstart)
          softcut.loop_end(track_focus, lend)
        end
        dirtygrid = true
      end
    -- enc 3: set loop start
    elseif n == 3 then
      arc_inc3 = (arc_inc3 % 20) + 1
      local new_loop_start = track[track_focus].loop_start + d / 500
      if math.abs(new_loop_start) - 1 <= track[track_focus].loop_end then
        track[track_focus].loop_start = util.clamp(new_loop_start, 1, 16.9)
      end
      if track[track_focus].loop == 1 then
        if arc_inc3 == 20 and track[track_focus].play == 1 and pattern_rec then
          local e = {}
          e.t = eLOOP
          e.i = track_focus
          e.loop = 1
          e.loop_start = track[track_focus].loop_start
          e.loop_end = track[track_focus].loop_end
          event(e)
        else
          local lstart = clip[track_focus].s + (track[track_focus].loop_start - 1) / 16 * clip[track_focus].l
          softcut.loop_start(track_focus, lstart)
        end
      end
      dirtygrid = true
    -- enc 4: set loop end
    elseif n == 4 then
      if cutview_hold then
        arc_track_focus = util.clamp(arc_track_focus + d / 100, 1, 6)
        track_focus = math.floor(arc_track_focus)
      else
        arc_inc4 = (arc_inc4 % 20) + 1
        local new_loop_end = track[track_focus].loop_end + d / 500
        if math.abs(new_loop_end) + 1 >= track[track_focus].loop_start then
          track[track_focus].loop_end = util.clamp(new_loop_end, 0.1, 16)
        end
        if track[track_focus].loop == 1 then
          if arc_inc4 == 20 and track[track_focus].play == 1 and pattern_rec then
            local e = {}
            e.t = eLOOP
            e.i = track_focus
            e.loop = 1
            e.loop_start = track[track_focus].loop_start
            e.loop_end = track[track_focus].loop_end
            event(e)
          else
            local lend = clip[track_focus].s + (track[track_focus].loop_end) / 16 * clip[track_focus].l
            softcut.loop_end(track_focus, lend)
          end
        end
      end
      dirtygrid = true
    end
  elseif arc_pageNum == 2 then
    if n == 1 then
      params:delta(track_focus.."vol", d / 12)
    elseif n == 2 then
      params:delta(track_focus.."pan", d / 12)
    elseif n == 3 then
      params:delta(track_focus.."cutoff", d / 16)
    elseif n == 4 then
      if cutview_hold then
        arc_track_focus = util.clamp(arc_track_focus + d / 100, 1, 6)
        track_focus = math.floor(arc_track_focus)
      else
        params:delta(track_focus.."filter_q", d / 12)
      end
    end
  end
end

function ui.arc_main_draw()
  a:all(0)
  if arc_pageNum == 1 then
    -- draw positon
    a:led(1, 33 - arc_off, 8)
    --a:led(1, -track[track_focus].pos_arc + 66 - arc_off, 15)
    a:led(1, track[track_focus].pos_arc + 32 - arc_off, 15)
    -- draw loop
    a:led(2, 33 - arc_off, 8)
    local startpoint = math.ceil(track[track_focus].loop_start * 4) - 3
    local endpoint = math.ceil(track[track_focus].loop_end * 4)
    for i = startpoint, endpoint do
      a:led(2, i + 32 - arc_off, 8)
    end
    if track[track_focus].play == 1 and track[track_focus].loop == 1 then
      a:led(2, track[track_focus].pos_arc + 32 - arc_off, 15)
    end
    -- draw loop start
    a:led(3, 33 - arc_off, 8)
    for i = 0, 3 do
      a:led(3, startpoint + 32 + i - arc_off, 10 - i * 3)
    end
    if track[track_focus].play == 1 and track[track_focus].loop == 1 then
      a:led(3, track[track_focus].pos_arc + 32 - arc_off, 15)
    end
    -- draw loop end
    if cutview_hold then
      -- draw track_focus
      for i = 1, 6 do
        local off = -13
        for j = 0, 5 do
          a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
        end
        a:led(4, (i + (track_focus - 1) * 7 - 6) + 50 - arc_off, 15)
      end
    else
      a:led(4, 33 - arc_off, 8)
      for i = 0, 3 do
        a:led(4, endpoint + 32 - i - arc_off, 10 - i * 3)
      end
      if track[track_focus].play == 1 and track[track_focus].loop == 1 then
        a:led(4, track[track_focus].pos_arc + 32 - arc_off, 15)
      end
    end
  elseif arc_pageNum == 2 then
    -- draw volume
    local arc_vol = math.floor(params:get(track_focus.."vol") * 64)
    for i = 1, 64 do
      if i < arc_vol then
        a:led(1, i - arc_off, 3)
      end
      a:led(1, arc_vol - arc_off, 15)
    end
    -- draw pan
    local arc_pan = math.floor(params:get(track_focus.."pan") * 24)
    a:led (2, 1 - arc_off, 7)
    a:led (2, 25 - arc_off, 5)
    a:led (2, -23 - arc_off, 5)
    if arc_pan > 0 then
      for i = 2, arc_pan do
        a:led(2, i - arc_off, 4)
      end
    elseif arc_pan < 0 then
      for i = arc_pan + 2, 0 do
        a:led(2, i - arc_off, 4)
      end
    end
    a:led (2, arc_pan + 1 - arc_off, 15)
    -- draw cutoff
    local arc_cut = math.floor(util.explin(20, 18000, 0, 1, params:get(track_focus.."cutoff")) * 48) + 41
    a:led (3, 25 - arc_off, 5)
    a:led (3, -23 - arc_off, 5)
    for i = -22, 24 do
      if i < arc_cut - 64 then
        a:led(3, i - arc_off, 3)
      end
    end
    a:led(3, arc_cut - arc_off, 15)
    if cutview_hold then
      -- draw track_focus
      for i = 1, 6 do
        local off = -13
        for j = 0, 5 do
          a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
        end
        a:led(4, (i + (track_focus - 1) * 7 - 6) + 50 - arc_off, 15)
      end
    else
      -- draw filter_q
      arc_q = math.floor(util.explin(0.1, 4, 0, 1, params:get(track_focus.."filter_q")) * 32) + 17
      for i = 17, 49 do
        if i > arc_q then
          a:led(4, i - arc_off, 3)
        end
      end
      a:led(4, 17 - arc_off, 7)
      a:led(4, 49 - arc_off, 7)
      a:led(4, 42 - arc_off, 7)
      a:led(4, 36 - arc_off, 7)
      a:led(4, arc_q - arc_off, 15)
    end
  end
  a:refresh()
end

---------------------- LFO VIEW -------------------------

function ui.lfo_key(n, z)
  if n == 2 and z == 1 then
    lfo_pageNum = util.wrap(lfo_pageNum - 1, 1, 3)
  elseif n == 3 and z == 1 then
    lfo_pageNum = util.wrap(lfo_pageNum + 1, 1, 3)
  end
  if lfo_pageNum == 3 then
    lfo_page_params_r[lfo_pageNum] = lfo_rate_params[params:get("lfo_mode_lfo_"..lfo_focus)]
  end
  dirtyscreen = true
end

function ui.lfo_enc(n, d)
  if n == 1 then
    if shift == 0 then
      lfo_focus = util.clamp(lfo_focus + d, 1, 6)
      arc_lfo_focus = lfo_focus
      if lfo_pageNum == 3 then
        lfo_page_params_r[lfo_pageNum] = lfo_rate_params[params:get("lfo_mode_lfo_"..lfo_focus)]
      end
    elseif shift == 1 then
      params:delta("output_level", d)
    end
  elseif n == 2 then
    params:delta(lfo_page_params_l[lfo_pageNum]..lfo_focus, d)
    if lfo_pageNum == 3 then
      lfo_page_params_r[lfo_pageNum] = lfo_rate_params[params:get("lfo_mode_lfo_"..lfo_focus)]
    end
  elseif n == 3 then
    params:delta(lfo_page_params_r[lfo_pageNum]..lfo_focus, d)
  end
  dirtyscreen = true
end

function ui.lfo_redraw()
  screen.clear()
  screen.level(15)
  screen.font_face(2)
  screen.font_size(8)
  screen.move(4, 12)
  screen.text("LFO "..lfo_focus)

  screen.level(4)
  screen.move(64, 12)
  screen.text_center("- "..lfo[lfo_focus].info.." -")
  for i = 1, 3 do
    screen.level(lfo_pageNum == i and 15 or 4)
    screen.rect(116 + (i - 1) * 4, 6, 2, 6)
    screen.fill()
  end
  -- param list
  screen.font_size(8)
  screen.level(4)
  screen.move(32, 54)
  screen.text_center(lfo_page_names_l[lfo_pageNum])
  screen.move(96, 54)
  screen.text_center(lfo_page_names_r[lfo_pageNum])
  screen.font_size(16)
  screen.level(15)
  screen.move(32, 40)
  screen.text_center(params:string(lfo_page_params_l[lfo_pageNum]..lfo_focus))
  screen.move(96, 40)
  screen.text_center(params:string(lfo_page_params_r[lfo_pageNum]..lfo_focus))
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_lfo_delta(n, d)
  if n == 1 then
    params:delta("lfo_depth_lfo_"..lfo_focus, d / 10)
    if lfo[lfo_focus].depth > 0 and lfo[lfo_focus].enabled == 0 then
      params:set("lfo_lfo_"..lfo_focus, 2)
    elseif lfo[lfo_focus].depth == 0 then
      params:set("lfo_lfo_"..lfo_focus, 1)
    end
  elseif n == 2 then
    params:delta("lfo_offset_lfo_"..lfo_focus, d / 20)
  elseif n == 3 then
    if lfo[lfo_focus].mode == 'clocked' then
      arc_inc5 = (arc_inc5 % 20) + 1
      if arc_inc5 == 20 then
        params:delta("lfo_clocked_lfo_"..lfo_focus, d / 50)
      end
    else
      params:delta("lfo_free_lfo_"..lfo_focus, d / 20)
    end
  elseif n == 4 then
    arc_lfo_focus = util.clamp(arc_lfo_focus + d / 100, 1, 6)
    lfo_focus = math.floor(arc_lfo_focus)
  end
  if view == vLFO then dirtyscreen = true end
end

function ui.arc_lfo_draw()
  a:all(0)
  -- draw lfo lfo depth
  local lfo_dth = math.floor((lfo[lfo_focus].depth) * 48) + 41
  a:led (1, 25 - arc_off, 5)
  a:led (1, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < lfo_dth - 64 then
      a:led(1, i - arc_off, 3)
    end
  end
  a:led(1, lfo_dth - arc_off, 15)
  -- draw lfo offset
  local lfo_off = math.floor(lfo[lfo_focus].offset * 100 / ((lfo[lfo_focus].baseline == 'center' and 50 or 100)) * 24)
  a:led (2, 1 - arc_off, 7)
  a:led (2, 25 - arc_off, 5)
  a:led (2, -23 - arc_off, 5)
  if lfo_off > 0 then
    for i = 2, lfo_off do
      a:led(2, i - arc_off, 4)
    end
  elseif lfo_off < 0 then
    for i = lfo_off + 2, 0 do
      a:led(2, i - arc_off, 4)
    end
  end
  a:led (2, lfo_off + 1 - arc_off, 15)
  local min = lfo[lfo_focus].mode == 'clocked' and 1 or 0.1
  local max = lfo[lfo_focus].mode == 'clocked' and 22 or 300
  local val = lfo[lfo_focus].mode == 'clocked' and params:get("lfo_clocked_lfo_"..lfo_focus) or params:get("lfo_free_lfo_"..lfo_focus)
  local lfo_frq = lfo[lfo_focus].mode == 'clocked' and (math.floor(util.linlin(min, max, 0, 1, val) * 48) + 41) or (math.floor(util.explin(min, max, 0, 1, val) * 48) + 41)
  a:led (3, 25 - arc_off, 5)
  a:led (3, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < lfo_frq - 64 then
      a:led(3, i - arc_off, 3)
    end
  end
  a:led(3, lfo_frq - arc_off, 15)
  -- draw lfo selection
  for i = 1, 6 do
    local off = -13
    for j = 0, 5 do
      a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(4, (i + (lfo_focus - 1) * 7 - 6) + 50 - arc_off, 15)
  end
  a:refresh()
end



---------------------- ENV VIEW -------------------------

function ui.env_key(n, z)
  if n == 2 and z == 1 then
    env_pageNum = util.wrap(env_pageNum - 1, 1, 3)
  elseif n == 3 and z == 1 then
    env_pageNum = util.wrap(env_pageNum + 1, 1, 3)
  end
  dirtyscreen = true
end

function ui.env_enc(n, d)
  if n == 1 then
    if shift == 0 then
      env_focus = util.clamp(env_focus + d, 1, 6)
      dirtyscreen = true
    else
      --
    end
  end
  if env_pageNum == 1 then
    if n == 2 then
      params:delta(env_focus.."adsr_attack", d)
    elseif n == 3 then
      params:delta(env_focus.."adsr_decay", d)
    end
  elseif env_pageNum == 2 then
    if n == 2 then
      params:delta(env_focus.."adsr_sustain", d)
    elseif n == 3 then
      params:delta(env_focus.."adsr_release", d)
    end
  elseif env_pageNum == 3 then
    if n == 2 then
      params:delta(env_focus.."adsr_amp", d)
    elseif n == 3 then
      params:delta(env_focus.."adsr_init", d)
    end
  end
end

function ui.env_redraw()
  screen.clear()
  screen.level(15)
  screen.font_face(2)
  screen.font_size(8)
  screen.move(4, 12)
  screen.text("ENVELOPE "..env_focus)
  for i = 1, 3 do
    screen.level(env_pageNum == i and 15 or 4)
    screen.rect(116 + (i - 1) * 4, 6, 2, 6)
    screen.fill()
  end
  if env_pageNum < 3 then
    -- a/d
    screen.level(env_pageNum == 1 and 15 or 4)
    screen.font_size(16)
    screen.move(24, 40)
    screen.text_center("A")
    screen.move(51, 40)
    screen.text_center("D")
    screen.font_size(8)
    screen.move(24, 54)
    screen.text_center(params:string(env_focus.."adsr_attack"))
    screen.move(51, 54)
    screen.text_center(params:string(env_focus.."adsr_decay"))
    -- s/r
    screen.level(env_pageNum == 2 and 15 or 4)
    screen.font_size(16)
    screen.move(78, 40)
    screen.text_center("S")
    screen.move(105, 40)
    screen.text_center("R")
    screen.font_size(8)
    screen.move(78, 54)
    screen.text_center(params:string(env_focus.."adsr_sustain"))
    screen.move(105, 54)
    screen.text_center(params:string(env_focus.."adsr_release"))
  elseif env_pageNum == 3 then
    screen.font_size(16)
    screen.level(15)
    screen.move(35, 40)
    screen.text_center(params:string(env_focus.."adsr_amp"))
    screen.move(94, 40)
    screen.text_center(params:string(env_focus.."adsr_init"))
    screen.font_size(8)
    screen.level(3)
    screen.move(35, 54)
    screen.text_center("max   vol")
    screen.move(94, 54)
    screen.text_center("min   vol")
  end
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_env_delta(n, d)
  if n == 1 then
    params:delta(env_focus.."adsr_attack", d / 20)
  elseif n == 2 then
    params:delta(env_focus.."adsr_decay", d / 20)
  elseif n == 3 then
    params:delta(env_focus.."adsr_sustain", d / 20)
  elseif n == 4 then
    params:delta(env_focus.."adsr_release", d / 20)
  end
end

function ui.arc_env_draw()
  a:all(0)
  -- draw adsr attack
  local attack = math.floor(util.linlin(0.1, 10, 0, 1, params:get(env_focus.."adsr_attack")) * 48) + 41
  a:led (1, 25 - arc_off, 5)
  a:led (1, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < attack - 64 then
      a:led(1, i - arc_off, 3)
    end
  end
  a:led(1, attack - arc_off, 15)
  -- draw adsr decay
  local decay = math.floor(util.linlin(0.1, 10, 0, 1, params:get(env_focus.."adsr_decay")) * 48) + 41
  a:led (2, 25 - arc_off, 5)
  a:led (2, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < decay - 64 then
      a:led(2, i - arc_off, 3)
    end
  end
  a:led(2, decay - arc_off, 15)
  -- draw adsr sustain
  local sustain = math.floor(params:get(env_focus.."adsr_sustain") * 48) + 41
  a:led (3, 25 - arc_off, 5)
  a:led (3, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < sustain - 64 then
      a:led(3, i - arc_off, 3)
    end
  end
  a:led(3, sustain - arc_off, 15)
  -- draw adsr release
  local release = math.floor(util.linlin(0.1, 10, 0, 1, params:get(env_focus.."adsr_release")) * 48) + 41
  a:led (4, 25 - arc_off, 5)
  a:led (4, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < release - 64 then
      a:led(4, i - arc_off, 3)
    end
  end
  a:led(4, release - arc_off, 15)
  a:refresh()
end


---------------------- PATTERN VIEW ---------------------

function ui.patterns_key(n, z)
  if n == 2 and z == 1 then
    patterns_pageNum = util.wrap(patterns_pageNum - 1, 1, 2)
  elseif n == 3 and z == 1 then
    patterns_pageNum = util.wrap(patterns_pageNum + 1, 1, 2)
  end
  dirtyscreen = true
end

function ui.patterns_enc(n, d)
  if n == 1 then
    if shift == 0 then
      pattern_focus = util.clamp(pattern_focus + d, 1, 8)
    elseif shift == 1 then
      params:delta("output_level", d)
    end
  elseif n == 2 and pattern[pattern_focus].synced then
    params:delta(patterns_page_params_l[patterns_pageNum]..pattern_focus, d)
  elseif n == 3 and (pattern[pattern_focus].synced or patterns_pageNum == 2) then
    params:delta(patterns_page_params_r[patterns_pageNum]..pattern_focus, d)
  end
  dirtygrid = true
  dirtyscreen = true
end

function ui.patterns_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(4, 12)
  screen.text("PATTERN "..pattern_focus)
  for i = 1, 2 do
    screen.level(patterns_pageNum == i and 15 or 4)
    screen.rect(116 + (i - 1) * 6, 6, 4, 6)
    screen.fill()
  end
  -- param list
  screen.font_size(8)
  screen.level(4)
  screen.move(35, 54)
  screen.text_center(patterns_page_names_l[patterns_pageNum])
  screen.move(94, 54)
  screen.text_center(patterns_page_names_r[patterns_pageNum])
  screen.font_size(16)
  screen.level(15)
  screen.move(35, 40)
  if pattern[pattern_focus].synced then
    screen.text_center(params:string(patterns_page_params_l[patterns_pageNum]..pattern_focus))
  else
    local str = patterns_pageNum == 1 and "-" or "free"
    screen.text_center(str)
  end
  screen.move(94, 40)
  if pattern[pattern_focus].synced or patterns_pageNum == 2 then
    screen.text_center(params:string(patterns_page_params_r[patterns_pageNum]..pattern_focus))
  else
    screen.text_center("free")
  end
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_pattern_delta(n, d)
  -- noting yet
end

function ui.arc_pattern_draw()
  a:all(0)
  -- light save mode
  a:refresh()
end


---------------------- TAPE VIEW ------------------------

function ui.tape_key(n, z)
  if view_presets then
    if n == 2 and z == 1 then
      local num = get_pset_num(pset_list[pset_focus])
      params:read(num)
      show_message("pset   loaded")
      view_presets = false
    elseif n == 3 and z == 1 then
      local num = string.format("%0.2i", get_pset_num(pset_list[pset_focus]))
      local pset_id = pset_list[pset_focus]
      silent_load(num, pset_id)
      show_message("silent   load")
      view_presets = false
    end
  elseif view_track_send then
    -- do nothing
  else
    -- tape view
    if shift == 0 then
      if n == 2 then
        if tape_actions[tape_action] == "load" and z == 1 then
          screenredrawtimer:stop()
          fileselect.enter(os.getenv("HOME").."/dust/audio", function(n) fileselect_callback(n, track_focus) end)
        elseif tape_actions[tape_action] == "clear" and z == 1 then
          clear_splice(track_focus)
        elseif tape_actions[tape_action] == "save" and z == 0 then
          screenredrawtimer:stop()
          textentry.enter(filesave_callback, "mlre-" .. (math.random(9000) + 1000))
        elseif tape_actions[tape_action] == "copy" and z == 1 then
          copy_track = track_focus
          copy_splice = track[track_focus].splice_focus
          show_message("copied   to   clipboard")
        elseif tape_actions[tape_action] == "paste" and z == 1 then
          local paste_track = track_focus
          local paste_splice = track[track_focus].splice_focus
          if copy_splice ~= nil then
            local src_ch = tape[copy_track].side
            local dst_ch = tape[paste_track].side
            local start_src = tape[copy_track].splice[copy_splice].s
            local start_dst = tape[paste_track].splice[paste_splice].s
            local length = tape[copy_track].splice[copy_splice].e - tape[copy_track].splice[copy_splice].s
            local preserve = alt == 1 and 0.5 or 0
            if tape[paste_track].splice[paste_splice].e + length <= tape[paste_track].e then
              softcut.buffer_copy_mono(src_ch, dst_ch, start_src, start_dst, length, 0.01, preserve)
              tape[paste_track].splice[paste_splice].e = start_dst + length
              tape[paste_track].splice[paste_splice].l = length
              tape[paste_track].splice[paste_splice].init_start = start_dst
              tape[paste_track].splice[paste_splice].init_len = length
              tape[paste_track].splice[paste_splice].beatnum = tape[copy_track].splice[copy_splice].beatnum
              tape[paste_track].splice[paste_splice].bpm = 60 / length * tape[copy_track].splice[copy_splice].beatnum
              tape[paste_track].splice[paste_splice].name = tape[copy_track].splice[copy_splice].name
              splice_resize(paste_track, paste_splice, length)
              render_splice()
              copy_splice = nil
            else
              show_message("out   of   boundries")
            end
          else
            show_message("clipboard   empty")
          end
        end
      elseif n == 3 and z == 1 then
        -- set barnum
        tape[track_focus].splice[track[track_focus].splice_focus].beatnum = track[track_focus].resize_val
        splice_resize(track_focus, track[track_focus].splice_focus)
        render_splice()
      end
    else
      if n == 2 and z == 1 then
        tape[track_focus].splice[track[track_focus].splice_focus].init_len = tape[track_focus].splice[track[track_focus].splice_focus].l
        tape[track_focus].splice[track[track_focus].splice_focus].init_start = tape[track_focus].splice[track[track_focus].splice_focus].s
        tape[track_focus].splice[track[track_focus].splice_focus].init_beatnum = tape[track_focus].splice[track[track_focus].splice_focus].beatnum
        show_message("default   markers   set")
      elseif n == 3 and z == 1 then
        splice_reset(track_focus, track[track_focus].splice_focus)
        render_splice()
      end
    end
  end
end

function edit_splices(n, d, src, sens)
  -- set local variables
  local i = track_focus
  local focus = track[track_focus].splice_focus
  local min_start = tape[track_focus].s
  local max_start = tape[track_focus].e - tape[track_focus].splice[track[track_focus].splice_focus].l
  local min_end = tape[track_focus].splice[track[track_focus].splice_focus].s + 0.1
  local max_end = tape[track_focus].e
  -- edit splice markers
  if n == (src == "enc" and 2 or 3) then
    -- edit window
    tape[i].splice[focus].s = util.clamp(tape[i].splice[focus].s + d / sens, min_start, max_start)
    if tape[i].splice[focus].s > min_start then
      tape[i].splice[focus].e = util.clamp(tape[i].splice[focus].e + d / sens, min_end, max_end)
    end
    local length = tape[i].splice[focus].e - tape[i].splice[focus].s
    splice_resize(i, focus, length)
    if src == "enc" then render_splice() end
  elseif n == (src == "enc" and 3 or 4) then
    -- edit endpoint
    tape[i].splice[focus].e = util.clamp(tape[i].splice[focus].e + d / sens, min_end, max_end)
    local length = tape[i].splice[focus].e - tape[i].splice[focus].s
    splice_resize(i, focus, length)
    if src == "enc" then render_splice() end
  end
  if src == "arc" then
    arc_render = util.wrap(arc_render + 1, 1, 10)
    if arc_render == 10 then render_splice() end
  end
end

function ui.tape_enc(n, d)
  if n == 1 then
    if shift == 1 then
      params:delta("output_level", d)
    end
  end
  if view_presets then
    if n == 2 then
      pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
    elseif n == 3 then
      pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
    end
  elseif view_track_send then
    if n == 2 and sends_focus < 5 then
      params:delta(sends_focus.."send_track5", d)
    elseif n == 3 and sends_focus < 6 then
      params:delta(sends_focus.."send_track6", d)
    end
  else
    if shift == 0 then
      if n == 2 then
        tape_action = util.clamp(tape_action + d, 1, #tape_actions)
      elseif n == 3 then
        params:delta(track_focus.."splice_length", d)
      end
    else
      edit_splices(n, d, "enc", 50)
    end
  end
  dirtyscreen = true
end

function ui.tape_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  -- preset view
  if view_presets then
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("PRESET LOADING")
    -- show pset names
    if #pset_list > 0 then
      local off = get_mid(pset_list[pset_focus])
      screen.level(12)
      screen.rect(64 - off, 28, off * 2 + 2, 10)
      screen.fill()
      screen.level(0)
      screen.move(64, 36)
      screen.text_center(pset_list[pset_focus])
      -- list right
      if pset_focus > 1 then
        screen.level(4)
        screen.move(64 - off - 14, 36)
        screen.text_right(pset_list[pset_focus - 1])
      end
      -- list left
      if pset_focus < #pset_list then
        screen.level(2)
        screen.move(64 + off + 14, 36)
        screen.text(pset_list[pset_focus + 1])
      end
    else
      screen.level(2)
      screen.move(64, 36)
      screen.text_center("NO   PSETS")
    end
    -- frame
    screen.level(10)
    screen.move(4, 18)
    screen.line_rel(120, 0)
    screen.move(4, 50)
    screen.line_rel(120, 0)
    screen.stroke()
    -- actions
    screen.level(pulse_key_mid)
    screen.move(4, 60)
    screen.text("bang!  <")
    screen.level(pulse_key_mid)
    screen.move(124, 60)
    screen.text_right(">  silent")
  -- track sends
  elseif view_track_send then
    screen.level(15)
    screen.move(4, 12)
    screen.text("TRACK "..sends_focus)
    screen.move(124, 12)
    screen.text_right("SENDS")
    -- send to track 5
    if sends_focus < 5 then
      screen.font_size(16)
      screen.level(15)
      screen.move(35, 40)
      screen.text_center(params:string(sends_focus.."send_track5"))
      screen.font_size(8)
      screen.level(3)
      screen.move(35, 54)
      screen.text_center(">   track   5")
    else
      screen.font_size(16)
      screen.level(3)
      screen.move(35, 40)
      screen.text_center("-")
    end
    -- send to track 6
    if sends_focus < 6 then
      screen.font_size(16)
      screen.level(15)
      screen.move(94, 40)
      screen.text_center(params:string(sends_focus.."send_track6"))
      screen.font_size(8)
      screen.level(3)
      screen.move(94, 54)
      screen.text_center(">   track   6")
    else
      screen.font_size(16)
      screen.level(3)
      screen.move(94, 40)
      screen.text_center("-")
    end
  else
    screen.level(15)
    screen.move(4, 12)
    screen.text("TRACK "..track_focus)
    screen.level(4)
    screen.move(32, 12)
    if track[track_focus].tempo_map == 1 then
      screen.text(">  resize")
    elseif track[track_focus].tempo_map == 2 then
      screen.text(">  repitch")
    end
    screen.level(15)
    screen.move(124, 12)
    screen.text_right("TAPE")
    screen.move(4, 60)
    screen.text("SPLICE "..track[track_focus].splice_focus)
    screen.level(4)
    screen.move(53, 60)
    if shift == 0 then
      screen.text_center(tape_actions[tape_action])
    else
      screen.text_center("set")
    end
    screen.level(15)
    screen.move(76, 60)
    screen.text("length")
    if shift == 0 then
      screen.level(track[track_focus].resize_val == (track[track_focus].tempo_map == 0 and tape[track_focus].splice[track[track_focus].splice_focus].l or tape[track_focus].splice[track[track_focus].splice_focus].beatnum) and 15 or 4)
      screen.move(124, 60)
      screen.text_right(track[track_focus].tempo_map == 0 and track[track_focus].resize_val.."s" or params:string(track_focus.."splice_length"))
    else
      screen.level(4)
      screen.move(110, 60)
      screen.text(">|")
    end

    if view_splice_info then
      screen.level(8)
      screen.move(4, 30)
      screen.text(">> "..str_format(tape[track_focus].splice[track[track_focus].splice_focus].name, 24))
      screen.level(4)
      screen.move(64, 45)
      screen.text_center("-- "..tape[track_focus].splice[track[track_focus].splice_focus].info.." --")
    else
      -- display buffer
      screen.level(6)
      local x_pos = 0
      for i, s in ipairs(waveform_samples[track_focus]) do
        local height = util.round(math.abs(s) * (14 / wave_gain[track_focus]))
        screen.move(util.linlin(0, 128, 5, 123, x_pos), 36 - height)
        screen.line_rel(0, 2 * height)
        screen.stroke()
        x_pos = x_pos + 1
      end
      -- update buffer
      if track[track_focus].rec == 1 then
        render_splice()
      end
      -- display position
      if track[track_focus].splice_focus == track[track_focus].splice_active then
        screen.level(15)
        if view_buffer then
          screen.move(math.floor(util.linlin(0, 1, 5, 123, track[track_focus].pos_clip)), 23)
        else
          screen.move(math.floor(util.linlin(0, 1, 5, 123, track[track_focus].pos_rel)), 23)
        end
        screen.line_rel(0, 27)
        screen.stroke()
      end
      -- display boundries
      screen.level(10)
      screen.move(4, 18)
      screen.line_rel(120, 0)
      screen.move(4, 23)
      screen.line_rel(120, 0)
      screen.move(4, 50)
      screen.line_rel(120, 0)
      screen.stroke()
      -- display splice markers
      local splice_start = tape[track_focus].splice[track[track_focus].splice_focus].s
      local splice_end = tape[track_focus].splice[track[track_focus].splice_focus].e
      local startpos = util.linlin(tape[track_focus].s, tape[track_focus].e, 5, 123, splice_start)
      local endpos = util.linlin(tape[track_focus].s, tape[track_focus].e, 5, 123, splice_end)
      screen.level(2)
      screen.rect(startpos, 18, endpos - startpos, 4)
      screen.fill()
      screen.level(15)
      screen.move(startpos, 18)
      screen.line_rel(0, 4)
      screen.move(endpos, 18)
      screen.line_rel(0, 4)
      screen.stroke()
      -- display position
      screen.level(15)
      screen.move(math.floor(util.linlin(0, 1, 5, 123, track[track_focus].pos_clip)), 18)
      screen.line_rel(0, 4)
      screen.stroke()
    end
  end
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_tape_delta(n, d)
  if n == 1 then
    arc_track_focus = util.clamp(arc_track_focus + d / 100, 1, 6)
    track_focus = math.floor(arc_track_focus)
    arc_splice_focus = track[track_focus].splice_focus
    render_splice()
    dirtygrid = true
  elseif n == 2 then
    arc_splice_focus = util.clamp(arc_splice_focus + d / 100, 1, 8)
    track[track_focus].splice_focus = math.floor(arc_splice_focus)
    render_splice()
    dirtygrid = true
  else
    edit_splices(n, d, "arc", 500)
  end
end

function ui.arc_tape_draw()
  a:all(0)
  -- draw track_focus
  for i = 1, 6 do
    local off = -13
    for j = 0, 5 do
      a:led(1, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(1, (i + (track_focus - 1) * 7 - 6) + 50 - arc_off, 15)
  end
  -- draw splice_focus
  for i = 1, 6 do
    local off = -20
    for j = 0, 7 do
      a:led(2, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(2, (i + (track[track_focus].splice_focus - 1) * 7 - 6) + 43 - arc_off, 15)
  end
  -- draw splice position
  local splice_s = tape[track_focus].splice[track[track_focus].splice_focus].s - tape[track_focus].s
  local splice_l = tape[track_focus].splice[track[track_focus].splice_focus].e - tape[track_focus].splice[track[track_focus].splice_focus].s
  local pos_startpoint = math.floor(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_s) * 58)
  local pos_endpoint = math.ceil(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * 58)
  a:led(3, -28 - arc_off, 6)
  a:led(3, 30 - arc_off, 6)
  for i = pos_startpoint, pos_startpoint + pos_endpoint do
    a:led(3, i + 1 - 29 - arc_off, 10)
  end
  -- draw splice size
  local win_startpoint = math.floor(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * -28)
  local win_endpoint = math.ceil(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * 28)
  a:led(4, -28 - arc_off, 6)
  a:led(4, 30 - arc_off, 6)
  for i = win_startpoint, win_endpoint do
    a:led(4, i + 1 - arc_off, 10)
  end
  a:refresh()
end

return ui
