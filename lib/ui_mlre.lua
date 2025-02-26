-- ui for mlre

local ui = {}

local textentry = require 'textentry' 
local fileselect = require 'fileselect'
local filters = require 'filters'

-- keyquant page variables
local keyq_pageNum = 1
local keyq_page_params = {{"time_signature", "quant_rate"}, {"snap_launch", "splice_launch"}}
local keyq_page_names = {{"time   signature", "key  quantization"}, {"snapshot   launch", "splice   launch"}}

-- main page variables
local main_page_params_l = {"vol", "rec", "cutoff", "filter_type", "detune","rate_slew", "play_mode", "reset_active"}
local main_page_params_r = {"pan", "dub", "filter_q", "post_dry", "transpose", "level_slew", "start_launch", "reset_count"}
local main_page_names_l = {"volume", "rec   level", "cutoff", "filter   type", "detune", "rate   slew", "play   mode", "track   reset"}
local main_page_names_r = {"pan", "dub   level", "filter   q", "dry   level", "transpose", "level   slew", "track   launch", "reset   count"}

-- lfo page variables
local lfo_rate_params = {"lfo_clocked_lfo_", "lfo_free_lfo_"}
local lfo_page_params_l = {"lfo_depth_lfo_", "lfo_shape_lfo_", "lfo_mode_lfo_"}
local lfo_page_params_r = {"lfo_offset_lfo_", "lfo_phase_lfo_", "lfo_free_lfo_"}
local lfo_page_names_l = {"depth", "shape", "mode"}
local lfo_page_names_r = {"offset", "phase", "rate"}

-- pattern page variables
local patterns_page_params_l = {"patterns_meter", "patterns_countin"}
local patterns_page_params_r = {"patterns_barnum", "patterns_playback"}
local patterns_page_names_l = {"meter", "launch"}
local patterns_page_names_r = {"length", "play   mode"}

-- tape page variables
local tape_actions = {"populate", "load", "clear", "save", "copy", "paste", "rename", "format >", "format >>>"}
local tape_action = 2

-- p-macro variables
local pmac_pageNum = 1
local pmac_pageEnc = 0
local pmac_param_id = {{"cutoff", "vol", "detune", "lfo_depth"}, {"filter_q", "pan", "rate_slew", "lfo_rate"}}
local pmac_param_name = {{"cutoff", "vol", "detune", "lfo   depth"}, {"filter  q", "pan", "rate_slew", "lfo   rate"}}

-- arc variables
local arc_inc1 = 0
local arc_inc2 = 0
local arc_inc3 = 0
local arc_inc4 = 0
local arc_inc5 = 0
local arc_render = 0
local arc_lfo_focus = 1
local arc_track_focus = 1
local arc_splice_focus = 1

local arc_pmac = {}
for i = 1, 4 do
  arc_pmac[i] = {}
  arc_pmac[i].viz = 1
  arc_pmac[i].smooth = filters.mean.new(20)
end

local function display_message()
  if view_message ~= "" then
    screen.clear()
    screen.font_face(2)
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


---------------------- POPUP -------------------------
function ui.popup_key(n, z)
  if n > 1 and z == 1 then
    if n == 3 then popup_func() end
    popup_func = nil
    popup_view = false
  end
end

function ui.popup_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(10)
  screen.move(1, 24)
  screen.line_rel(128, 0)
  screen.move(1, 41)
  screen.line_rel(128, 0)
  screen.stroke()
  screen.level(15)
  screen.move(64, 35)
  screen.text_center(popup_message)
  screen.level(4)
  screen.move(64, 60)
  screen.text_center("are   you   sure  ?")
  screen.level(15)
  screen.move(20, 60)
  screen.text_center("no   <")
  screen.move(108, 60)
  screen.text_center(">   yes")
  screen.update()
end


---------------------- KEYQUANT MENU -------------------------

function ui.keyquant_key(n, z)
  if n > 1 and z == 1 then
    keyq_pageNum = util.wrap(keyq_pageNum + 1, 1, 2)
  end
  dirtyscreen = true
end

function ui.keyquant_enc(n, d)
  if n > 1 then
    params:delta(keyq_page_params[keyq_pageNum][n - 1], d)
  end
  dirtyscreen = true
end

function ui.keyquant_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center("QUANTIZATION")
  for i = 1, 2 do
    screen.level(keyq_pageNum == i and 15 or 4)
    screen.rect(120 + (i - 1) * 4, 6, 2, 6)
    screen.fill()
  end
  screen.font_size(16)
  screen.level(15)
  screen.move(30, 39)
  screen.text_center(params:string(keyq_page_params[keyq_pageNum][1]))
  screen.move(98, 39)
  screen.text_center(params:string(keyq_page_params[keyq_pageNum][2]))
  screen.font_size(8)
  screen.level(4)
  screen.move(30, 60)
  screen.text_center(keyq_page_names[keyq_pageNum][1])
  screen.move(98, 60)
  screen.text_center(keyq_page_names[keyq_pageNum][2])
  screen.update()
end

---------------------- PMAC PERF -------------------------
function ui.pmac_perf_key(n, z)
  if z == 1 then
    if n == 2 then
      params:set("slot_assign", macro_slot_mode == 2 and 3 or 2)
      show_message(macro_slot_mode == 2 and "pattern   slots" or "recall   slots")
    elseif n == 3 then
      pmac_pageEnc = 1 - pmac_pageEnc
    end
  end
end

function ui.pmac_perf_enc(n, d)
  if n == 1 and arc_is then
    if d > 0 then
      if arc_pageNum ~= 2 then
        arc_pageNum = 2
        show_message("arc  -  levels")
      end
    else
      if arc_pageNum ~= 1 then
        arc_pageNum = 1
        show_message("arc  -  play head")
      end
    end
  else
    local enc = n - 1 + pmac_pageEnc * 2
    pmac_exec(enc, d)
  end
  dirtyscreen = true
end

function ui.pmac_perf_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(64, 12)
  screen.text_center("P - MACROS")
  screen.font_size(24)
  for i = 1, 2 do
    local action = pmac.d[i + pmac_pageEnc * 2].action
    local xpos = i == 1 and 30 or 98
    screen.level(action == 0 and 1 or 15)
    if action > 0 then
      screen.move(xpos + 4, 42)
      screen.text_center(">>")
    elseif action < 0 then
      screen.move(xpos - 5, 42)
      screen.text_center("<<")
    else
      screen.move(xpos, 42)
      screen.text_center("< >")
    end
  end
  screen.font_size(8)
  screen.level(4)
  screen.move(30, 60)
  screen.text_center(pmac_pageEnc == 0 and "macro   1" or "macro   3")
  screen.move(98, 60)
  screen.text_center(pmac_pageEnc == 0 and "macro   2" or "macro   4")
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_pmac_delta(n, d)
  pmac_exec(n, (d / pmac_sens))
  arc_pmac[n].viz = math.floor(util.clamp(arc_pmac[n].smooth:next(d * 2), -42, 44))
end

function ui.arc_pmac_draw()
  a:all(0)
  for i = 1, 4 do
    local pos = arc_pmac[i].viz
    if pos > 0 then
      for n = 1, pos do
        a:led(i, n - arc_off, 6)
      end
    else
      for n = 0, pos, -1 do
        a:led(i, n - arc_off, 6)
      end
    end
    a:led(i, pos - arc_off, 15)
    a:led(i, 1 - arc_off, 8)
  end
  a:refresh()
end

function ui.pmac_arc_reset(i)
  arc_pmac[i].viz = 1
  for _ = 1, 20 do
    arc_pmac[i].smooth:next(1)
  end
end


---------------------- PMAC MENU -------------------------
function ui.pmac_edit_key(n, z)
  if z == 1 then
    local inc = n == 2 and -1 or 1
    pmac_pageNum = util.wrap(pmac_pageNum + inc, 1, 4)
  end
end

function ui.pmac_edit_enc(n, d)
  if n == 1 then
    pmac_focus = util.clamp(pmac_focus + d, 1, 6)
  else
    local p = pmac_param_id[n - 1][pmac_pageNum]
    local inc = d > 0 and 1 or -1
    pmac.d[pmac_enc][pmac_focus][p] = util.clamp(pmac.d[pmac_enc][pmac_focus][p] + inc, -100, 100)
  end
  dirtyscreen = true
end

function ui.pmac_edit_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(4, 12)
  screen.text("P - MACRO  "..pmac_enc)
  screen.move(64, 12)
  screen.text_center((pmac_pageNum == 4 and "LFO  " or "T  ")..pmac_focus)
  for i = 1, 2 do
    screen.level(pmac_pageNum == i and 15 or 4)
    screen.rect(120 + (i - 1) * 4, 6, 2, 2)
    screen.fill()
    screen.level(pmac_pageNum == i + 2 and 15 or 4)
    screen.rect(120 + (i - 1) * 4, 10, 2, 2)
    screen.fill()
    screen.level(shift == 0 and 15 or 1)
    screen.font_size(16)
    screen.move(30 + 68 * (i - 1), 39)
    screen.text_center(pmac.d[pmac_enc][pmac_focus][pmac_param_id[i][pmac_pageNum]].."%")
    screen.font_size(8)
    screen.level(4)
    screen.move(30 + 68 * (i - 1), 60)
    screen.text_center(pmac_param_name[i][pmac_pageNum])
  end
  screen.update()
end


---------------------- MAIN VIEW -------------------------

function ui.main_key(n, z)
  if n == 2 and z == 1 then
    main_pageNum = util.wrap(main_pageNum - 1, 1, 8)
  elseif n == 3 and z == 1 then
    main_pageNum = util.wrap(main_pageNum + 1, 1, 8)
  end
end

function ui.main_enc(n, d)
  if n == 1 then
    track_focus = util.clamp(track_focus + d, 1, 6)
    dirtygrid = true
    dirtyscreen = true
  elseif n == 2 then
    params:delta(track_focus..main_page_params_l[main_pageNum], d)
  elseif n == 3 then
    if not (main_page_params_r[main_pageNum] == "post_dry" and params:get(track_focus.."filter_type") == 5) then
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
    screen.level(main_pageNum == i + 4 and 15 or 4)
    screen.rect(112 + (i - 1) * 4, 10, 2, 2)
    screen.fill()
  end
  -- param list
  screen.font_size(8)
  screen.level(4)
  screen.move(35, 54)
  if track[track_focus].mute == 1 and main_pageNum == 1 then
    screen.level(15)
    screen.text_center("[ muted ]")
  else
    screen.text_center(main_page_names_l[main_pageNum])
  end
  screen.level(4)
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
          local e = {t = eSTART, i = track_focus} event(e)
          if params:get(track_focus.."play_mode") == 3 then
            local e = {t = eGATEON, i = track_focus} event(e)
          end
        end
      end
      -- stop playback when enc stops
      if params:get(track_focus.."play_mode") == 3 then
        inc = (inc % 100) + 1
        clock.run(function()
          local prev_inc = inc
          clock.sleep(0.05)
          if prev_inc == inc then
            if params:get(track_focus.."adsr_active") == 2 then
              local e = {t = eGATEOFF, i = track_focus} event(e)
            else
              local e = {t = eSTOP, i = track_focus} event(e)
            end
          end
        end)
      end
      -- set direction
      if params:get("arc_enc_1_dir") == 2 then
        if d < -2 and track[track_focus].rev == 0 then
          local e = {t = eREV, i = track_focus, rev = 1} event(e)
        elseif d > 2 and track[track_focus].rev == 1 then
          local e = {t = eREV, i = track_focus, rev = 0} event(e)
        end
      end
      -- temp warble
      if (d > 10 or d < -10) and params:get("arc_enc_1_mod") == 2 then
        if track[track_focus].play == 1 then
          clock.run(function()
            local speedmod = d / 80
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
          end)
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
        loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end)
        if params:get(track_focus.."adsr_active") == 2 then
          local e = {t = eGATEON, i = track_focus} event(e)
        end
        clock.run(function()
          clock.sleep(0.4)
          enc2_wait = false
          arc_inc2 = 0
        end)
      end
      if track[track_focus].loop == 1 and alt == 1 then
        local e = {t = eUNLOOP, i = track_focus} event(e)
        if params:get(track_focus.."adsr_active") == 2 then
          local e = {t = eGATEOFF, i = track_focus} event(e)
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
          loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end)
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
          loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end)
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
            loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end)
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
    local arc_cut = math.floor(util.explin(20, 12000, 0, 1, params:get(track_focus.."cutoff")) * 48) + 41
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

function ui.update_lfo_param()
  if lfo_pageNum == 3 then
    lfo_page_params_r[lfo_pageNum] = lfo_rate_params[params:get("lfo_mode_lfo_"..lfo_focus)]
  end
end

function ui.lfo_key(n, z)
  if n == 2 and z == 1 then
    lfo_pageNum = util.wrap(lfo_pageNum - 1, 1, 3)
  elseif n == 3 and z == 1 then
    lfo_pageNum = util.wrap(lfo_pageNum + 1, 1, 3)
  end
  ui.update_lfo_param()
end

function ui.lfo_enc(n, d)
  if n == 1 then
    lfo_focus = util.clamp(lfo_focus + d, 1, 6)
    arc_lfo_focus = lfo_focus
    ui.update_lfo_param()
  elseif n == 2 then
    params:delta(lfo_page_params_l[lfo_pageNum]..lfo_focus, d)
    ui.update_lfo_param()
  elseif n == 3 then
    params:delta(lfo_page_params_r[lfo_pageNum]..lfo_focus, d)
  end
  dirtygrid = true
  dirtyscreen = true
end

function ui.lfo_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
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
  dirtygrid = true
  dirtyscreen = true
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
end

function ui.env_enc(n, d)
  if n == 1 then
    env_focus = util.clamp(env_focus + d, 1, 6)
    dirtyscreen = true
    dirtygrid = true
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
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
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

function ui.macro_key(n, z)
  if kmac.pattern_edit then
    if n == 2 and z == 1 then
      patterns_pageNum = util.wrap(patterns_pageNum - 1, 1, 2)
    elseif n == 3 and z == 1 then
      patterns_pageNum = util.wrap(patterns_pageNum + 1, 1, 2)
    end    
  end
end

function ui.macro_enc(n, d)
  if kmac.pattern_edit then
    if n == 1 then
      pattern_focus = util.clamp(pattern_focus + d, 1, 8)
    else
      if n == 2 and (pattern[pattern_focus].synced or patterns_pageNum == 2) then
        params:delta(patterns_page_params_l[patterns_pageNum]..pattern_focus, d)
      elseif n == 3 and (pattern[pattern_focus].synced or patterns_pageNum == 2) then
        params:delta(patterns_page_params_r[patterns_pageNum]..pattern_focus, d)
      end
    end
  end
  dirtygrid = true
  dirtyscreen = true
end

function ui.macro_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(4, 12)
  screen.text("K - MACRO")
  if kmac.pattern_edit and kmac.slot_focus == 0 then
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("PATTERN  "..pattern_focus)
    for i = 1, 2 do
      screen.level(patterns_pageNum == i and 15 or 4)
      screen.rect(120 + (i - 1) * 4, 6, 2, 6)
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
    if pattern[pattern_focus].synced or patterns_pageNum == 2 then
      screen.text_center(params:string(patterns_page_params_l[patterns_pageNum]..pattern_focus))
    else
      screen.text_center("-")
    end
    screen.move(94, 40)
    if pattern[pattern_focus].synced or patterns_pageNum == 2 then
      screen.text_center(params:string(patterns_page_params_r[patterns_pageNum]..pattern_focus))
    else
      screen.text_center("manual")
    end
  else
    local x_pos = 15
    local y_pos = 37
    local macro = {"PT", "SN", "PI"}
    local txta = {}
    local txtb = {}
    local num = ""
    local cntr = ""
    local side = ""
    if kmac.o.focus > 0 then
      txta = kmac.slot[kmac.o[kmac.o.focus]] -- display assigned kit of focused page
      num = kmac.o.focus
      cntr = "KIT  "..kmac.o[kmac.o.focus]
    elseif kmac.z.focus > 0 then
      txta = kmac.slot[kmac.z[kmac.z.focus]] -- display assigned kit of focused page
      num = kmac.z.focus
      cntr = "kit  "..kmac.z[kmac.z.focus]
    elseif kmac.slot_focus > 0 then
      txta = kmac.slot[kmac.slot_focus] -- display focused kit
      cntr = "KIT  "..kmac.slot_focus
      side = "EDIT"
    else
      txta = kmac.slot[kmac.o[kmac.key]] -- display active kit
      txtb = kmac.slot[kmac.z[kmac.key]] -- display active kit
      num = kmac.key
    end
    screen.move(38, 12)
    screen.text(num)
    screen.move(64, 12)
    screen.text_center(cntr)
    screen.move(124, 12)
    screen.text_right(side)
    screen.font_face(68)
    if (GRID_SIZE == 128 or kmac.o.focus > 0 or kmac.z.focus > 0 or kmac.slot_focus > 0) then
      for i = 1, 8 do
        local data = ((txta[i] == mPTN and pattern[i].count > 0) or (txta[i] == mSNP and snap[i].data) or (txta[i] == mPIN and recall[i].has_data)) and true or false
        screen.level(15)
        screen.rect(x_pos + 14 * (i - 1) - 5, y_pos - 8, 12, 12)
        screen.stroke()
        if data then
          screen.level(4)
          screen.rect(x_pos + 14 * (i - 1) - 5, y_pos - 8, 11, 11)
          screen.fill() 
        end
        screen.level(data and 0 or 15)
        screen.move(x_pos + 14 * (i - 1), y_pos)
        screen.text_center(macro[txta[i]])
      end
    else
      for i = 1, 8 do
        local y_posa = y_pos - 3
        local y_posb = y_pos + 3
        local dataa = ((txta[i] == mPTN and pattern[i].count > 0) or (txta[i] == mSNP and snap[i].data) or (txta[i] == mPIN and recall[i].has_data)) and true or false
        screen.level(15)
        screen.rect(x_pos + 14 * (i - 1) - 5, y_posa - 8, 12, 12)
        screen.stroke()
        if dataa then
          screen.level(4)
          screen.rect(x_pos + 14 * (i - 1) - 5, y_posa - 8, 11, 11)
          screen.fill() 
        end
        screen.level(dataa and 0 or 15)
        screen.move(x_pos + 14 * (i - 1), y_posa)
        screen.text_center(macro[txta[i]])

        local datab = ((txtb[i] == mPTN and pattern[i].count > 0) or (txtb[i] == mSNP and snap[i].data) or (txtb[i] == mPIN and recall[i].has_data)) and true or false
        screen.level(15)
        screen.rect(x_pos + 14 * (i - 1) - 5, y_posb - 8, 12, 12)
        screen.stroke()
        if datab then
          screen.level(4)
          screen.rect(x_pos + 14 * (i - 1) - 5, y_posb - 8, 11, 11)
          screen.fill() 
        end
        screen.level(datab and 0 or 15)
        screen.move(x_pos + 14 * (i - 1), y_posb)
        screen.text_center(macro[txtb[i]])
      end
    end
  end
  -- display messages
  display_message()
  screen.update()
end


---------------------- TAPE VIEW ------------------------

function ui.tape_key(n, z)
  if view_batchload_options then
    if n > 1 and z == 1 then
      if n == 3 then
        local path = batchload_path
        local i = batchload_track
        local s = track[i].splice_focus
        local n = batchload_numfiles - 1
        load_batch(path, i, s, n)
      end
      view_batchload_options = false
    end
  elseif view_presets then
    if n == 2 and z == 1 then
      params:read(pset_focus)
      local msg = shift == 0 and "pset   loaded" or "params   loaded"
      show_message(msg)
      view_presets = false
    elseif n == 3 and z == 1 then
      local num = string.format("%0.2i", pset_focus)
      local pset_id = pset_list[pset_focus]
      silent_load(num, pset_id)
      view_presets = false
    end
  else
    -- tape view
    local i = track_focus
    local s = track[i].splice_focus
    if shift == 0 then
      if n == 2 then
        if tape_actions[tape_action] == "populate" and z == 1 then
          view_batchload_options = true
          screenredrawtimer:stop()
          fileselect.enter(_path.audio, function(path) batchload_callback(path, i) end, "audio")
          if prev_path ~= nil then
            fileselect.pushd(prev_path)
          end
        elseif tape_actions[tape_action] == "load" and z == 1 then
          screenredrawtimer:stop()
          fileselect.enter(_path.audio, function(path) fileload_callback(path, i) end, "audio")
          if prev_path ~= nil then
            fileselect.pushd(prev_path)
          end
        elseif tape_actions[tape_action] == "clear" and z == 1 then
          popupscreen("clear   splice", clear_splice)
        elseif tape_actions[tape_action] == "save" and z == 0 then
          screenredrawtimer:stop()
          textentry.enter(filesave_callback, tp[i].splice[s].name)
        elseif tape_actions[tape_action] == "copy" and z == 1 then
          copy_ref.track = i
          copy_ref.splice = s
          show_message("ready   to   paste")
        elseif tape_actions[tape_action] == "paste" and z == 1 then
          copy_splice_audio()
        elseif tape_actions[tape_action] == "rename" and z == 0 then
          screenredrawtimer:stop()
          textentry.enter(filerename_callback, tp[i].splice[s].name)
        elseif tape_actions[tape_action] == "format >" and z == 1 then
          popupscreen("format   next   splice", format_splice)
        elseif tape_actions[tape_action] == "format >>>" and z == 1 then
          popupscreen("format   consecutive   splices", format_next_splices)
        end
      elseif n == 3 and z == 1 then
        tp[i].splice[s].beatnum = tp[i].splice[s].resize
        splice_resize(i, s)
        render_splice()
      end
    else
      if n == 2 and z == 1 then
        tp[i].splice[s].init_len = tp[i].splice[s].l
        tp[i].splice[s].init_start = tp[i].splice[s].s
        tp[i].splice[s].init_beatnum = tp[i].splice[s].beatnum
        show_message("default   markers   set")
      elseif n == 3 and z == 1 then
        splice_reset(i, s)
        render_splice()
      end
    end
  end
end

function edit_splices(n, d, src, sens)
  -- set local variables
  local i = track_focus
  local focus = track[track_focus].splice_focus
  local min_start = tp[track_focus].s
  local max_start = tp[track_focus].e - tp[track_focus].splice[focus].l
  local min_end = tp[track_focus].splice[focus].s + 0.1
  local max_end = tp[track_focus].e
  -- edit splice markers
  if n == (src == "enc" and 2 or 3) then
    -- edit window
    tp[i].splice[focus].s = util.clamp(tp[i].splice[focus].s + d / sens, min_start, max_start)
    if tp[i].splice[focus].s > min_start then
      tp[i].splice[focus].e = util.clamp(tp[i].splice[focus].e + d / sens, min_end, max_end)
    end
    local length = tp[i].splice[focus].e - tp[i].splice[focus].s
    splice_resize(i, focus, length)
    if src == "enc" then render_splice() end
  elseif n == (src == "enc" and 3 or 4) then
    -- edit endpoint
    tp[i].splice[focus].e = util.clamp(tp[i].splice[focus].e + d / sens, min_end, max_end)
    local length = tp[i].splice[focus].e - tp[i].splice[focus].s
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
    else
      track_focus = util.clamp(track_focus + d, 1, 6)
      arc_track_focus = track_focus
      arc_splice_focus = track[track_focus].splice_focus
      render_splice()
      dirtygrid = true
    end
  end
  if view_batchload_options then
    if n > 1 then
      batchload_numfiles = util.clamp(batchload_numfiles + d, 1, 8)
    end
  elseif view_presets then
    if n == 2 then
      pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
    elseif n == 3 then
      pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
    end
  elseif view_track_send then
    if n == 2 and sends_focus < 5 then
      params:delta(sends_focus.."send_t5", d)
    elseif n == 3 and sends_focus < 6 then
      params:delta(sends_focus.."send_t6", d)
    end
  else
    if shift == 0 then
      if n == 2 then
        tape_action = util.clamp(tape_action + d, 1, #tape_actions)
      elseif n == 3 then
        tp[track_focus].splice[track[track_focus].splice_focus].resize = util.clamp(tp[track_focus].splice[track[track_focus].splice_focus].resize + d, 1, 64)
        if track[track_focus].tempo_map == 0 and tp[track_focus].splice[track[track_focus].splice_focus].resize > 57 then
          tp[track_focus].splice[track[track_focus].splice_focus].resize = 57
        end
      end
    else
      edit_splices(n, d, "enc", 50)
    end
  end
  dirtyscreen = true
end

function ui.tape_redraw()
  local splice_focus = track[track_focus].splice_focus
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  -- preset view
  if view_batchload_options then
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("SELECT FILE COUNT")
    screen.level(8)
    screen.font_size(16)
    screen.move(64, 39)
    screen.text_center(batchload_numfiles)
    screen.font_size(8)
    screen.move(22, 56)
    screen.text_center("cancel")
    screen.move(104, 56)
    screen.text_center("load")
  elseif view_presets then
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
    screen.text(shift == 0 and "pset  <" or "params  <")
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
      screen.text_center(params:string(sends_focus.."send_t5"))
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
      screen.text_center(params:string(sends_focus.."send_t6"))
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
    screen.text("SPLICE "..splice_focus)
    screen.level(4)
    screen.move(52, 60)
    if shift == 0 then
      screen.text_center(tape_actions[tape_action])
    else
      screen.text_center("set")
    end
    screen.level(15)
    screen.move(76, 60)
    screen.text("length")
    if shift == 0 then
      screen.level(tp[track_focus].splice[splice_focus].resize == (track[track_focus].tempo_map == 0 and tp[track_focus].splice[splice_focus].l or tp[track_focus].splice[splice_focus].beatnum) and 15 or 4)
      screen.move(124, 60)
      local format = track[track_focus].tempo_map == 0 and "s" or "/4"
      screen.text_right(tp[track_focus].splice[splice_focus].resize..format)
    else
      screen.level(4)
      screen.move(110, 60)
      screen.text(">|")
    end

    if view_splice_info then
      screen.level(8)
      screen.move(4, 30)
      screen.text(">>  "..tp[track_focus].splice[splice_focus].name)
      screen.level(4)
      screen.move(64, 45)
      screen.text_center("--  "..tp[track_focus].splice[splice_focus].info.."  --")
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
      if splice_focus == track[track_focus].splice_active then
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
      local splice_start = tp[track_focus].splice[splice_focus].s
      local splice_end = tp[track_focus].splice[splice_focus].e
      local startpos = util.linlin(tp[track_focus].s, tp[track_focus].e, 5, 123, splice_start)
      local endpos = util.linlin(tp[track_focus].s, tp[track_focus].e, 5, 123, splice_end)
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
  dirtyscreen = true
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
  local splice_s = tp[track_focus].splice[track[track_focus].splice_focus].s - tp[track_focus].s
  local splice_l = tp[track_focus].splice[track[track_focus].splice_focus].e - tp[track_focus].splice[track[track_focus].splice_focus].s
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
