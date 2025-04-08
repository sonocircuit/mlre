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
local tape_actions = {"populate", "load", "clear", "save", "copy", "paste", "-1dB", "+1dB", "rename", "format >", "format >>>"}
local tape_action = 2
local copy_src = {}
local length_action = 2
local length_actions = {": 2", "set", "x 2"}

-- p-macro variables
local pmac_pageNum = 1
local pmac_pageEnc = 0
local pmac_param_id = {{"cutoff", "vol", "detune", "lfo_depth"}, {"filter_q", "pan", "rate_slew", "lfo_rate"}}
local pmac_param_name = {{"cutoff", "vol", "detune", "lfo   depth"}, {"filter  q", "pan", "rate_slew", "lfo   rate"}}

-- arc variables
local arc_pageNum = 1
local arc_lfo_focus = 1
local arc_track_focus = 1
local arc_splice_focus = 1
local arc_wait = false
local off_viz = 0
local _1 = off_viz < 3 and 1 or 4
local _2 = off_viz < 3 and 2 or 3
local _3 = off_viz < 3 and 3 or 2
local _4 = off_viz < 3 and 4 or 1
local arc_enc_start = false
local arc_enc_dir = false
local arc_enc_mod = 1
local arc_mod_sens = 100
local arc_pmac_sens = 20
local arc_shortpress = false
local arc_keypresstimer = nil
local arc_highres = false
local mod_rate_clk = nil

local arc_pmac = {}
for i = 1, 4 do
  arc_pmac[i] = {}
  arc_pmac[i].viz = 1
  arc_pmac[i].smooth = filters.mean.new(20)
end

local arc_inc = {}
arc_inc.stop = 0
arc_inc.render = 0
for i = 1, 4 do
  arc_inc[i] = 0
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


---------------------- PARAMS -------------------------
function ui.arc_params()
  params:add_group("arc_params", "arc settings", 6)
  params:add_option("arc_orientation", "arc orientation", {"0°", "90°", "180°", "270°"}, 1)
  params:set_action("arc_orientation", function(val)
    off_viz = (val - 1) * 16
    _1 = val < 3 and 1 or 4
    _2 = val < 3 and 2 or 3
    _3 = val < 3 and 3 or 2
    _4 = val < 3 and 4 or 1
  end)

  params:add_option("arc_enc_1_start", "enc1 > start", {"off", "on"}, 2)
  params:set_action("arc_enc_1_start", function(mode) arc_enc_start = mode == 2 and true or false end)
  
  params:add_option("arc_enc_1_dir", "enc1 > direction", {"off", "on"}, 1)
  params:set_action("arc_enc_1_dir", function(mode) arc_enc_dir = mode == 2 and true or false end)
  
  params:add_option("arc_enc_1_mod", "enc1 > mod", {"off", "warble", "scrub"}, 3)
  params:set_action("arc_enc_1_mod", function(val) arc_enc_mod = val end)
  
  params:add_number("arc_mod_sens", "mod sensitivity", 1, 10, 4)
  params:set_action("arc_mod_sens", function(val) arc_mod_sens = 550 - val * 50 end) 

  params:add_number("arc_arc_pmac_sens", "p-macro sensitivity", 1, 10, 4)
  params:set_action("arc_arc_pmac_sens", function(val) arc_pmac_sens = 5 * val end)

  if arc_is then
    params:show("arc_params")
  else
    params:hide("arc_params")
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
  if z == 1 and n > 1 then
    pmac_pageEnc = pmac_pageEnc == 1 and 2 or 1
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
  pmac_exec(n, (d / arc_pmac_sens))
  arc_pmac[n].viz = math.floor(util.clamp(arc_pmac[n].smooth:next(d * 2), -42, 44))
end

function ui.arc_pmac_draw()
  a:all(0)
  for i = 1, 4 do
    local i = off_viz < 3 and i or 5 - i
    local pos = arc_pmac[i].viz
    if pos > 0 then
      for n = 1, pos do
        a:led(i, n - off_viz, 6)
      end
    else
      for n = 0, pos, -1 do
        a:led(i, n - off_viz, 6)
      end
    end
    a:led(i, pos - off_viz, 15)
    a:led(i, 1 - off_viz, 8)
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

---------------------- WARBLE MENU -------------------------

function ui.wrbl_enc(n, d)
  if n == 2 then
    params:delta(wrb_focus.."warble_amount", d)
  elseif n == 3 then
    params:delta(wrb_focus.."warble_depth", d)
  end
  dirtyscreen = true
end

function ui.wrbl_redraw()
  screen.clear()
  screen.font_face(2)
  screen.font_size(8)
  screen.level(15)
  screen.move(4, 12)
  screen.text("TRACK "..wrb_focus)
  screen.move(124, 12)
  screen.text_right("WARBLE")
  screen.font_size(8)
  screen.level(4)
  screen.move(35, 54)
  screen.text_center("amount")
  screen.level(4)
  screen.move(94, 54)
  screen.text_center("intensity")
  screen.font_size(16)
  screen.level(15)
  screen.move(35, 40)
  screen.text_center(params:string(wrb_focus.."warble_amount"))
  screen.move(94, 40)
  screen.text_center(params:string(wrb_focus.."warble_depth"))
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
    params:delta(track_focus..main_page_params_r[main_pageNum], d)
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
  screen.text_center(params:string(track_focus..main_page_params_r[main_pageNum]))
  -- display messages
  display_message()
  screen.update()
end

function ui.arc_main_key(n, z)
  if z == 1 then
    arc_keypresstimer = clock.run(function()
      arc_shortpress = true
      clock.sleep(0.2)
      arc_shortpress = false
      arc_keypresstimer = nil
      toggle_pmac_perf_view(z)
      dirtyscreen = true
    end)
  else
    if arc_keypresstimer ~= nil then
      clock.cancel(arc_keypresstimer)
    end
    if arc_shortpress then
      local msg = {"arc  -  play head", "arc  -  levels"}
      arc_pageNum = arc_pageNum == 1 and 2 or 1
      show_message(msg[arc_pageNum])
    else
      toggle_pmac_perf_view(z)
      dirtyscreen = true
    end
  end
end

function ui.arc_main_delta(n, d)
  local n = off_viz < 3 and n or 5 - n
  if arc_pageNum == 1 then
    -- enc 1:
    if n == 1 then
      -- start playback
      if arc_enc_start then
        if track[track_focus].play == 0 and (d > 2 or d < -2) then
          local e = {t = eSTART, i = track_focus} event(e)
          if track[track_focus].play_mode == 3 then
            local e = {t = eGATEON, i = track_focus} event(e)
          end
        end
      end
      -- stop playback when enc stops
      if track[track_focus].play_mode == 3 then
        arc_inc.stop = (arc_inc.stop % 100) + 1
        if detect_stop ~= nil then
          clock.cancel(detect_stop)
        end
        detect_stop = clock.run(function()
          local prev_inc = arc_inc.stop
          clock.sleep(0.05)
          if prev_inc == arc_inc.stop then
            if env[track_focus].active then
              local e = {t = eGATEOFF, i = track_focus} event(e)
            else
              local e = {t = eSTOP, i = track_focus} event(e)
            end
          end
          detect_stop = nil
        end)
      end
      -- set direction
      if arc_enc_dir then
        if d < -2 and track[track_focus].rev == 0 then
          local e = {t = eREV, i = track_focus, rev = 1} event(e)
        elseif d > 2 and track[track_focus].rev == 1 then
          local e = {t = eREV, i = track_focus, rev = 0} event(e)
        end
      end
      -- temp warble
      if arc_enc_mod == 2 then
        if (d > 4 or d < -4) and track[track_focus].play == 1 then
          local mod_rate = track[track_focus].rate + (d / arc_mod_sens)
          softcut.rate_slew_time(track_focus, 0.25)
          softcut.rate(track_focus, mod_rate)
          if mod_rate_clk ~= nil then
            clock.cancel(mod_rate_clk)
          end
          mod_rate_clk = clock.run(function()
            clock.sleep(0.4)
            update_rate(track_focus)
            softcut.rate_slew_time(track_focus, track[track_focus].rate_slew)
          end)
        end
      end
      -- scrub
      if arc_enc_mod == 3 then
        if (d > 2 or d < -2) and track[track_focus].play == 1 then
          arc_inc[n] = (arc_inc[n] % 10) + 1
          if arc_inc[n] == 1 then
            local new_pos = track[track_focus].pos_abs + (d / arc_mod_sens)
            softcut.position(track_focus, new_pos)
          end
        end
      end
    -- enc 2: activate loop or move loop window
    elseif n == 2 then
      if track[track_focus].loop == 0 and (d > 2 or d < -2) and alt == 0 then
        arc_wait = true
        loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end, true)
        if env[track_focus].active then
          local e = {t = eGATEON, i = track_focus} event(e)
        end
        clock.run(function()
          clock.sleep(0.4)
          arc_wait = false
          arc_inc[n] = 0
        end)
      end
      if track[track_focus].loop == 1 and alt == 1 then --TODO: add arc longpress
        local e = {t = eUNLOOP, i = track_focus} event(e)
        if env[track_focus].active then
          local e = {t = eGATEOFF, i = track_focus} event(e)
        end
      end
      if track[track_focus].loop == 1 and not arc_wait then
        arc_inc[n] = (arc_inc[n] % 20) + 1
        local new_loop_start = track[track_focus].loop_start + d / 200
        local new_loop_end = track[track_focus].loop_end + d / 200
        if math.abs(new_loop_start) - 1 <= track[track_focus].loop_end and math.abs(new_loop_end) <= 16 then
          track[track_focus].loop_start = util.clamp(new_loop_start, 1, 16.9)
        end
        if math.abs(new_loop_end) + 1 >= track[track_focus].loop_start and math.abs(new_loop_start) >= 1 then
          track[track_focus].loop_end = util.clamp(new_loop_end, 0.1, 16)
        end
        if arc_inc[n] == 20 and track[track_focus].play == 1 and pattern_rec then
          loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end, true)
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
      arc_inc[n] = (arc_inc[n] % 20) + 1
      local new_loop_start = track[track_focus].loop_start + d / 500
      if math.abs(new_loop_start) - 1 <= track[track_focus].loop_end then
        track[track_focus].loop_start = util.clamp(new_loop_start, 1, 16.9)
      end
      if track[track_focus].loop == 1 then
        if arc_inc[n] == 20 and track[track_focus].play == 1 and pattern_rec then
          loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end, true)
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
        arc_inc[n] = (arc_inc[n] % 20) + 1
        local new_loop_end = track[track_focus].loop_end + d / 500
        if math.abs(new_loop_end) + 1 >= track[track_focus].loop_start then
          track[track_focus].loop_end = util.clamp(new_loop_end, 0.1, 16)
        end
        if track[track_focus].loop == 1 then
          if arc_inc[n] == 20 and track[track_focus].play == 1 and pattern_rec then
            loop_event(track_focus, track[track_focus].loop_start, track[track_focus].loop_end, true)
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
        params:delta(track_focus.."filter_q", -d / 12)
      end
    end
  end
end

function ui.arc_main_draw()
  a:all(0)
  if arc_pageNum == 1 then
    -- draw positon
    a:led(_1, 33 - off_viz, 8)
    a:led(_1, track[track_focus].pos_arc + 32 - off_viz, 15)
    -- draw loop
    a:led(_2, 33 - off_viz, 8)
    local startpoint = math.ceil(track[track_focus].loop_start * 4) - 3
    local endpoint = math.ceil(track[track_focus].loop_end * 4)
    for i = startpoint, endpoint do
      a:led(_2, i + 32 - off_viz, 8)
    end
    if track[track_focus].play == 1 and track[track_focus].loop == 1 then
      a:led(_2, track[track_focus].pos_arc + 32 - off_viz, 15)
    end
    -- draw loop start
    a:led(_3, 33 - off_viz, 8)
    for i = 0, 3 do
      a:led(_3, startpoint + 32 + i - off_viz, 10 - i * 3)
    end
    if track[track_focus].play == 1 and track[track_focus].loop == 1 then
      a:led(_3, track[track_focus].pos_arc + 32 - off_viz, 15)
    end
    -- draw loop end
    if cutview_hold then
      -- draw track_focus
      for i = 1, 6 do
        local off = -13
        for j = 0, 5 do
          a:led(_4, (i + off) + j * 7 - 7 - off_viz, 4)
        end
        a:led(_4, (i + (track_focus - 1) * 7 - 6) + 50 - off_viz, 15)
      end
    else
      a:led(_4, 33 - off_viz, 8)
      for i = 0, 3 do
        a:led(_4, endpoint + 32 - i - off_viz, 10 - i * 3)
      end
      if track[track_focus].play == 1 and track[track_focus].loop == 1 then
        a:led(_4, track[track_focus].pos_arc + 32 - off_viz, 15)
      end
    end
  elseif arc_pageNum == 2 then
    -- draw volume
    local arc_vol = math.floor(track[track_focus].level * 64)
    for i = 1, 64 do
      if i < arc_vol then
        a:led(_1, i - off_viz, 3)
      end
      a:led(_1, arc_vol - off_viz, 15)
    end
    -- draw pan
    local arc_pan = math.floor(track[track_focus].pan * 24)
    a:led(_2, 1 - off_viz, 7)
    a:led(_2, 25 - off_viz, 5)
    a:led(_2, -23 - off_viz, 5)
    if arc_pan > 0 then
      for i = 2, arc_pan do
        a:led(_2, i - off_viz, 4)
      end
    elseif arc_pan < 0 then
      for i = arc_pan + 2, 0 do
        a:led(_2, i - off_viz, 4)
      end
    end
    a:led(_2, arc_pan + 1 - off_viz, 15)
    -- draw cutoff
    if track[track_focus].filter_mode == 6 then
      -- 
    elseif track[track_focus].filter_mode == 5 then
      local arc_cut = math.floor(track[track_focus].cutoff * 24)
      a:led(_3, 1 - off_viz, 7)
      a:led(_3, 25 - off_viz, 5)
      a:led(_3, -23 - off_viz, 5)
      if arc_cut > 0 then
        for i = 2, arc_cut do
          a:led(_3, i - off_viz, 4)
        end
      elseif arc_cut < 0 then
        for i = arc_cut + 2, 0 do
          a:led(_3, i - off_viz, 4)
        end
      end
      a:led(_3, arc_cut + 1 - off_viz, 15)
    else
      local arc_cut = math.floor(util.explin(20, 12000, 0, 1, track[track_focus].cutoff_hz) * 48) + 41
      a:led(_3, 25 - off_viz, 5)
      a:led(_3, -23 - off_viz, 5)
      for i = -22, 24 do
        if i < arc_cut - 64 then
          a:led(_3, i - off_viz, 3)
        end
      end
      a:led(_3, arc_cut - off_viz, 15)
    end
    if cutview_hold then
      -- draw track_focus
      for i = 1, 6 do
        local off = -13
        for j = 0, 5 do
          a:led(_4, (i + off) + j * 7 - 7 - off_viz, 4)
        end
        a:led(_4, (i + (track_focus - 1) * 7 - 6) + 50 - off_viz, 15)
      end
    else
      -- draw filter_q
      arc_q = 49 - math.floor(track[track_focus].filter_q * 32)
      for i = 49, 17, -1 do
        if i > arc_q then
          a:led(_4, i - off_viz, 3)
        end
      end
      a:led(_4, 17 - off_viz, 7)
      a:led(_4, 49 - off_viz, 7)
      a:led(_4, 43 - off_viz, 7)
      a:led(_4, 37 - off_viz, 7)
      a:led(_4, arc_q - off_viz, 15)
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

function ui.arc_lfo_key(n, z)
  toggle_pmac_perf_view(z)
  dirtyscreen = true
end

function ui.arc_lfo_delta(n, d)
  local n = off_viz < 3 and n or 5 - n
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
      arc_inc[n] = (arc_inc[n] % 20) + 1
      if arc_inc[n] == 20 then
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
  a:led(_1, 25 - off_viz, 5)
  a:led(_1, -23 - off_viz, 5)
  for i = -22, 24 do
    if i < lfo_dth - 64 then
      a:led(_1, i - off_viz, 3)
    end
  end
  a:led(_1, lfo_dth - off_viz, 15)
  -- draw lfo offset
  local lfo_off = math.floor(lfo[lfo_focus].offset * 100 / ((lfo[lfo_focus].baseline == 'center' and 50 or 100)) * 24)
  a:led(_2, 1 - off_viz, 7)
  a:led(_2, 25 - off_viz, 5)
  a:led(_2, -23 - off_viz, 5)
  if lfo_off > 0 then
    for i = 2, lfo_off do
      a:led(_2, i - off_viz, 4)
    end
  elseif lfo_off < 0 then
    for i = lfo_off + 2, 0 do
      a:led(_2, i - off_viz, 4)
    end
  end
  a:led(_2, lfo_off + 1 - off_viz, 15)
  local min = lfo[lfo_focus].mode == 'clocked' and 1 or 0.1
  local max = lfo[lfo_focus].mode == 'clocked' and 22 or 300
  local val = lfo[lfo_focus].mode == 'clocked' and params:get("lfo_clocked_lfo_"..lfo_focus) or params:get("lfo_free_lfo_"..lfo_focus)
  local lfo_frq = lfo[lfo_focus].mode == 'clocked' and (math.floor(util.linlin(min, max, 0, 1, val) * 48) + 41) or (math.floor(util.explin(min, max, 0, 1, val) * 48) + 41)
  a:led(_3, 25 - off_viz, 5)
  a:led(_3, -23 - off_viz, 5)
  for i = -22, 24 do
    if i < lfo_frq - 64 then
      a:led(_3, i - off_viz, 3)
    end
  end
  a:led(_3, lfo_frq - off_viz, 15)
  -- draw lfo selection
  for i = 1, 6 do
    local off = -13
    for j = 0, 5 do
      a:led(_4, (i + off) + j * 7 - 7 - off_viz, 4)
    end
    a:led(_4, (i + (lfo_focus - 1) * 7 - 6) + 50 - off_viz, 15)
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

function ui.arc_env_key(n, z)
  toggle_pmac_perf_view(z)
  dirtyscreen = true
end

function ui.arc_env_delta(n, d)
  local n = off_viz < 3 and n or 5 - n
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
  local attack = math.floor(util.linlin(0, 100, 0, 1, env[env_focus].attack) * 48) + 41
  a:led (_1, 25 - off_viz, 5)
  a:led (_1, -23 - off_viz, 5)
  for i = -22, 24 do
    if i < attack - 64 then
      a:led(_1, i - off_viz, 3)
    end
  end
  a:led(_1, attack - off_viz, 15)
  -- draw adsr decay
  local decay = math.floor(util.linlin(0, 100, 0, 1, env[env_focus].decay) * 48) + 41
  a:led (_2, 25 - off_viz, 5)
  a:led (_2, -23 - off_viz, 5)
  for i = -22, 24 do
    if i < decay - 64 then
      a:led(_2, i - off_viz, 3)
    end
  end
  a:led(_2, decay - off_viz, 15)
  -- draw adsr sustain
  local sustain = math.floor(env[env_focus].sustain * 48) + 41
  a:led(_3, 25 - off_viz, 5)
  a:led(_3, -23 - off_viz, 5)
  for i = -22, 24 do
    if i < sustain - 64 then
      a:led(_3, i - off_viz, 3)
    end
  end
  a:led(_3, sustain - off_viz, 15)
  -- draw adsr release
  local release = math.floor(util.linlin(0, 100, 0, 1, env[env_focus].release) * 48) + 41
  a:led(_4, 25 - off_viz, 5)
  a:led(_4, -23 - off_viz, 5)
  for i = -22, 24 do
    if i < release - 64 then
      a:led(_4, i - off_viz, 3)
    end
  end
  a:led(_4, release - off_viz, 15)
  a:refresh()
end


---------------------- MACRO VIEW ---------------------

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
    local txto = {}
    local txtz = {}
    local side = ""
    if kmac.slot_focus > 0 then
      txto = kmac.slot[kmac.slot_focus] -- display focused kit
      side = kmac.slot_focus % 2 == 0 and "SEC" or "MAIN"
    else
      txto = kmac.slot[kmac.o.sec] -- display active kit
      txtz = kmac.slot[kmac.z.sec + 2] -- display active kit
    end
    screen.level(15)
    screen.move(4, 12)
    screen.text("MACRO SLOTS")
    screen.move(124, 12)
    screen.text_right(side)
    screen.font_face(68)
    if (GRID_SIZE == 128 or kmac.slot_focus > 0) then
      for i = 1, 8 do
        local data = ((txto[i] == mPTN and pattern[i].count > 0) or (txto[i] == mSNP and snap[i].data) or (txto[i] == mPIN and punch[i].has_data)) and true or false
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
        screen.text_center(macro[txto[i]])
      end
    else
      for i = 1, 8 do
        local y_posa = y_pos - 7
        local y_posb = y_pos + 8
        local datao = ((txto[i] == mPTN and pattern[i].count > 0) or (txto[i] == mSNP and snap[i].data) or (txto[i] == mPIN and punch[i].has_data)) and true or false
        screen.level(15)
        screen.rect(x_pos + 14 * (i - 1) - 5, y_posa - 8, 12, 12)
        screen.stroke()
        if datao then
          screen.level(4)
          screen.rect(x_pos + 14 * (i - 1) - 5, y_posa - 8, 11, 11)
          screen.fill() 
        end
        screen.level(datao and 0 or 15)
        screen.move(x_pos + 14 * (i - 1), y_posa)
        screen.text_center(macro[txto[i]])

        local dataz = ((txtz[i] == mPTN and pattern[i].count > 0) or (txtz[i] == mSNP and snap[i].data) or (txtz[i] == mPIN and punch[i].has_data)) and true or false
        screen.level(15)
        screen.rect(x_pos + 14 * (i - 1) - 5, y_posb - 8, 12, 12)
        screen.stroke()
        if dataz then
          screen.level(4)
          screen.rect(x_pos + 14 * (i - 1) - 5, y_posb - 8, 11, 11)
          screen.fill() 
        end
        screen.level(dataz and 0 or 15)
        screen.move(x_pos + 14 * (i - 1), y_posb)
        screen.text_center(macro[txtz[i]])
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
      if shift == 1 then
        show_message("params   loaded")
      end
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
          copy_src.i = i
          copy_src.s = s
          show_message("ready   to   paste")
        elseif tape_actions[tape_action] == "paste" and z == 1 then
          copy_splice_audio(i, s, copy_src)
          copy_src = {}
        elseif tape_actions[tape_action] == "-1dB" and z == 1 then
          popupscreen("decrease   level   -1dB", decrease_level_splice)
        elseif tape_actions[tape_action] == "+1dB" and z == 1 then
          popupscreen("increase   level   +1dB", increase_level_splice)
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
        if length_action == 2 then
          tp[i].splice[s].init_len = tp[i].splice[s].l
          tp[i].splice[s].init_start = tp[i].splice[s].s
          tp[i].splice[s].init_beatnum = tp[i].splice[s].beatnum
          show_message("default   markers   set")
        else
          local factor = length_action == 1 and 0.5 or 2
          splice_resize_factor(i, s, factor)
        end
      elseif n == 3 and z == 1 then
        splice_reset(i, s)
      end
    end
  end
end

function edit_splices(n, d, src, sens)
  -- set local variables
  local i = track_focus
  local s = track[i].splice_focus
  local min_start = tp[i].s
  local max_start = tp[i].e - tp[i].splice[s].l
  local min_end = tp[i].splice[s].s + 0.1
  local max_end = tp[i].e
  local sens = arc_highres and (sens * 20) or sens
  -- edit splice markers
  if n == (src == "enc" and 2 or 3) then
    -- edit startpoint
    tp[i].splice[s].s = util.clamp(tp[i].splice[s].s + d / sens, min_start, max_start)
    if tp[i].splice[s].s > min_start then
      tp[i].splice[s].e = util.clamp(tp[i].splice[s].e + d / sens, min_end, max_end)
    end
  elseif n == (src == "enc" and 3 or 4) then
    -- edit length
    tp[i].splice[s].e = util.clamp(tp[i].splice[s].e + d / sens, min_end, max_end)
    tp[i].splice[s].l = tp[i].splice[s].e - tp[i].splice[s].s
    tp[i].splice[s].bpm = 60 / tp[i].splice[s].l * tp[i].splice[s].beatnum
  end
  -- update clip
  if s == track[i].splice_active then
    set_clip(i)
  end
  set_info(i, s)
  -- render splice
  if src == "enc" then
    render_splice()
  elseif src == "arc" then
    arc_inc.render = util.wrap(arc_inc.render + 1, 1, 10)
    if arc_inc.render == 10 then render_splice() end
  end
end

function ui.tape_enc(n, d)
  if n == 1 then
    if shift == 0 then
      track_focus = util.clamp(track_focus + d, 1, 6)
      arc_track_focus = track_focus
      arc_splice_focus = track[track_focus].splice_focus
      render_splice()
      dirtygrid = true
    else
      length_action = util.clamp(length_action + d, 1, 3)
    end
  else
    if view_batchload_options then
      batchload_numfiles = util.clamp(batchload_numfiles + d, 1, 8)
    elseif view_presets then
      pset_focus = util.clamp(pset_focus + d, 1, #pset_list)
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
          local i = track_focus
          local s = track[track_focus].splice_focus
          tp[i].splice[s].resize = util.clamp(tp[i].splice[s].resize + d, 1, 64)
          if track[i].tempo_map == 0 and tp[i].splice[s].resize > 57 then
            tp[i].splice[s].resize = 57
          end
        end
      else
        edit_splices(n, d, "enc", 50)
      end
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
    screen.text(shift == 0 and "preset  <" or "params  <")
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
      screen.text_center(length_actions[length_action])
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
      for i, s in ipairs(waveform_samples[track_focus]) do
        local height = util.round(math.abs(s) * (14 / wave_gain[track_focus]))
        screen.move(i + 4, 36 - height)
        screen.line_rel(0, 2 * height)
        screen.stroke()
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

function ui.arc_tape_key(n, z)
  arc_highres = z == 1 and true or false
end

function ui.arc_tape_delta(n, d)
  local n = off_viz < 3 and n or 5 - n
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
      a:led(_1, (i + off) + j * 7 - 7 - off_viz, 4)
    end
    a:led(_1, (i + (track_focus - 1) * 7 - 6) + 50 - off_viz, 15)
  end
  -- draw splice_focus
  for i = 1, 6 do
    local off = -20
    for j = 0, 7 do
      a:led(_2, (i + off) + j * 7 - 7 - off_viz, 4)
    end
    a:led(_2, (i + (track[track_focus].splice_focus - 1) * 7 - 6) + 43 - off_viz, 15)
  end
  -- draw splice position
  local splice_s = tp[track_focus].splice[track[track_focus].splice_focus].s - tp[track_focus].s
  local splice_l = tp[track_focus].splice[track[track_focus].splice_focus].e - tp[track_focus].splice[track[track_focus].splice_focus].s
  local pos_startpoint = math.floor(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_s) * 58)
  local pos_endpoint = math.ceil(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * 58)
  a:led(_3, -28 - off_viz, 6)
  a:led(_3, 30 - off_viz, 6)
  for i = pos_startpoint, pos_startpoint + pos_endpoint do
    a:led(_3, i + 1 - 29 - off_viz, 10)
  end
  -- draw splice size
  local win_startpoint = math.floor(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * -28)
  local win_endpoint = math.ceil(util.linlin(0, MAX_TAPELENGTH, 0, 1, splice_l) * 28)
  a:led(_4, -28 - off_viz, 6)
  a:led(_4, 30 - off_viz, 6)
  for i = win_startpoint, win_endpoint do
    a:led(_4, i + 1 - off_viz, 10)
  end
  a:refresh()
end

return ui
