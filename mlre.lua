-- mlre v1.0.1 @sonocircuit
-- llllllll.co/t/????
--
-- an adaption of
-- mlr v2.2.4 @tehn
-- llllllll.co/t/21145
--
-- large chunks of code
-- and ideas borrowed
-- from @justmat
--
-- MIDI transport form @okyeron
--
-- thank you!
--
-- for docs go to:
-- github.com/sonocircuits/mlre
--
-- /////////
-- ////
-- ////////////
-- //////////
-- ///////
-- /
-- ////
-- //
-- /////////
-- ///
-- /
--
-- ////
-- /
--
-- /
--
--

local g = grid.connect()

local fileselect = require 'fileselect'
local textentry = require 'textentry'
local pattern_time = require 'pattern_time'

local TRACKS = 6
local FADE = 0.01
local pageNum = 1
local key1_hold = 0
local armrec = 0

-- for scales (comment in (remove --) for one of the options you wish to use)

--local scale = controlspec.new(-1.0,1.0,"lin", 0, 0,"",0.01) -- no quantization
local scale = controlspec.new(-1.0,1.0,"lin", 1/12, 0,"", 1/48) -- semitones
--local scale = controlspec.new(-1.0,1.0,"lin", 2/12, 0,"", 1/48) -- tones
--local scale = controlspec.new(-1.0,1.0,"lin", 3/12, 0,"", 1/36) -- minor thrids
--local scale = controlspec.new(-1.0,1.0,"lin", 4/12, 0,"", 1/36) -- major thrids
--local scale = controlspec.new(-1.0,1.0,"lin", 5/12, 0,"", 1/24) -- fourths
--local scale = controlspec.new(-1.0,1.0,"lin", 6/12, 0,"", 1/24) -- diminished fifths
--local scale = controlspec.new(-1.75,1.75,"lin", 7/12, 0,"", 1/24) -- fifths
--local scale = controlspec.new(-2.0,2.0,"lin", 8/12, 0,"", 1/24) -- minor sixths
--local scale = controlspec.new(-2.0,2.0,"lin", 9/12, 0,"", 1/24) -- major sixths
--local scale = controlspec.new(-2.0,2.0,"lin", 10/12, 0,"", 1/24) -- minor sevenths
--local scale = controlspec.new(-2.0,2.0,"lin", 11/12, 0,"", 1/24) -- major sevenths

local scale_options = {"none", "semitones", "minor", "major", "fifths"}
local scale_track = {"global", "none", "semitones", "minor", "major", "fifths"}

-- for lib/hnds
local lfo = include 'lib/hnds_mlre'

local lfo_targets = {"none"}
for i = 1, TRACKS do
  table.insert(lfo_targets, i .. "vol")
  table.insert(lfo_targets, i .. "pan")
  table.insert(lfo_targets, i .. "dub")
  table.insert(lfo_targets, i .. "transpose")
  table.insert(lfo_targets, i .. "rate_slew")
  table.insert(lfo_targets, i .. "cutoff")
end

-- softcut has ~350s per buffer
local CLIP_LEN_SEC = 45
local MAX_CLIPS = 7

local vREC = 1
local vCUT = 2
local vCLIP = 3
local vTIME = 15

-- events
local eCUT = 1
local eSTOP = 2
local eSTART = 3
local eLOOP = 4
local eSPEED = 5
local eREV = 6
local ePATTERN = 7

local quantize = 0
local quantizer

local function update_tempo()
  local t = params:get("clock_tempo")
  local d = params:get("quant_div")
  local interval = (60/t) / d
  --print("q > "..interval)
  quantizer.time = interval
  for i=1,TRACKS do
    if track[i].tempo_map == 1 then
      update_rate(i)
    end
  end
end

local prev_tempo = params:get("clock_tempo")
function clock_update_tempo()
  while true do
    clock.sync(1/24)
    local curr_tempo = params:get("clock_tempo")
    if prev_tempo ~= curr_tempo then
      prev_tempo = curr_tempo
      update_tempo()
    end
  end
end

function event_record(e)
  for i=1,4 do
    pattern[i]:watch(e)
  end
  recall_watch(e)
end

function event(e)
  if quantize == 1 then
    event_q(e)
  else
    if e.t ~= ePATTERN then event_record(e) end
    event_exec(e)
  end
end

local quantize_events = {}

function event_q(e)
  table.insert(quantize_events, e)
end

function event_q_clock()
  if #quantize_events > 0 then
    for k,e in pairs(quantize_events) do
      if e.t ~= ePATTERN then event_record(e) end
      event_exec(e)
    end
    quantize_events = {}
  end
end

function event_exec(e)
  if e.t == eCUT then
    if track[e.i].loop == 1 then
      track[e.i].loop = 0
      softcut.loop_start(e.i,clip[track[e.i].clip].s)
      softcut.loop_end(e.i,clip[track[e.i].clip].e)
    end
    local cut = (e.pos/16)*clip[track[e.i].clip].l + clip[track[e.i].clip].s
    softcut.position(e.i,cut)
    if track[e.i].play == 0 then
      track[e.i].play = 1
      ch_toggle(e.i, 1)
    end
  elseif e.t == eSTOP then
    track[e.i].play = 0
    --track[e.i].pos_grid = -1 --removes "glitch" where after "play" last grid button lights up(locks to last step if in "freeze" mode)
    ch_toggle(e.i, 0)
    dirtygrid = true
  elseif e.t == eSTART then
    track[e.i].play = 1
    ch_toggle(e.i, 1)
    dirtygrid = true
  elseif e.t == eLOOP then
    track[e.i].loop = 1
    track[e.i].loop_start = e.loop_start
    track[e.i].loop_end = e.loop_end
    local lstart = clip[track[e.i].clip].s + (track[e.i].loop_start-1)/16*clip[track[e.i].clip].l
    local lend = clip[track[e.i].clip].s + (track[e.i].loop_end)/16*clip[track[e.i].clip].l
    softcut.loop_start(e.i,lstart)
    softcut.loop_end(e.i,lend)
    dirtygrid = true
  elseif e.t == eSPEED then
    track[e.i].speed = e.speed
    update_rate(e.i)
    if view == vREC then dirtygrid = true end
  elseif e.t == eREV then
    track[e.i].rev = e.rev
    update_rate(e.i)
    if view == vREC then dirtygrid = true end
  elseif e.t == ePATTERN then
    if e.action == "stop" then pattern[e.i]:stop()
    elseif e.action == "start" then pattern[e.i]:start()
    elseif e.action == "rec_stop" then pattern[e.i]:rec_stop()
    elseif e.action == "rec_start" then pattern[e.i]:rec_start()
    elseif e.action == "clear" then pattern[e.i]:clear()
    end
  end
end

-- patterns
pattern = {}
for i = 1, 4 do
  pattern[i] = pattern_time.new()
  pattern[i].process = event_exec
end

-- recalls
recall = {}
for i = 1, 4 do
  recall[i] = {}
  recall[i].recording = false
  recall[i].has_data = false
  recall[i].active = false
  recall[i].event = {}
end

function recall_watch(e)
  for i = 1, 4 do
    if recall[i].recording == true then
      table.insert(recall[i].event, e)
      recall[i].has_data = true
    end
  end
end

function recall_exec(i)
  for _,e in pairs(recall[i].event) do
    event_exec(e)
  end
end

view = vREC
view_prev = view

v = {}
v.key = {}
v.enc = {}
v.redraw = {}
v.gridkey = {}
v.gridredraw = {}

viewinfo = {}
viewinfo[vREC] = 0
viewinfo[vCUT] = 0
viewinfo[vTIME] = 0

focus = 1
alt = 0
alt2 = 0

track = {}
for i = 1,TRACKS do
  track[i] = {}
  track[i].head = (i-1)%4+1
  track[i].play = 0
  track[i].sel = 0
  track[i].rec = 0
  track[i].oneshot = 0
  track[i].rec_level = 1
  track[i].pre_level = 0
  track[i].loop = 0
  track[i].loop_start = 0
  track[i].loop_end = 16
  track[i].clip = i
  track[i].pos = 0
  track[i].pos_grid = -1
  track[i].speed = 0
  track[i].rev = 0
  track[i].tempo_map = 0
end

set_clip_length = function(i, len)
  clip[i].l = len
  clip[i].e = clip[i].s + len
  local bpm = 60 / len
  while bpm < 60 do
    bpm = bpm * 2
    --print("bpm > "..bpm)
  end
  clip[i].bpm = bpm
end

clip_reset = function(i, length)
  set_clip_length(i, length)
  clip[i].name = "-"
end

clip = {}
for i = 1,MAX_CLIPS do
  clip[i] = {}
  clip[i].s = 2 + (i-1)*CLIP_LEN_SEC
  clip[i].name = "-"
  set_clip_length(i, 4)
end

calc_quant = function(i)
  local q = (clip[track[i].clip].l/16)
  --print("q > "..q)
  return q
end

calc_quant_off = function(i, q)
  local off = q
  while off < clip[track[i].clip].s do
    off = off + q
  end
  off = off - clip[track[i].clip].s
  --print("off > "..off)
  return off
end

set_clip = function(i, x)
  track[i].clip = x
  softcut.loop_start(i, clip[track[i].clip].s)
  softcut.loop_end(i, clip[track[i].clip].e)
  local q = calc_quant(i)
  local off = calc_quant_off(i, q)
  softcut.phase_quant(i, q)
  softcut.phase_offset(i, off)
end

set_rec = function(n)
  if track[n].rec == 1 then
    softcut.pre_level(n, track[n].pre_level)
    softcut.rec_level(n, track[n].rec_level)
  else
    softcut.pre_level(n, 1)
    softcut.rec_level(n, 0)
  end
end

held = {}
heldmax = {}
done = {}
first = {}
second = {}
for i = 1,8 do
  held[i] = 0
  heldmax[i] = 0
  done[i] = 0
  first[i] = 0
  second[i] = 0
end

key = function(n, z)
    if n == 1 then
    key1_hold = z
    else
  _key(n,z) end
end

enc = function(n, d) _enc(n, d) end

redraw = function() _redraw() end
g.key = function(x, y, z) _gridkey(x, y, z) end

set_view = function(x)
  if x == -1 then x = view_prev end
  view_prev = view
  view = x
  _key = v.key[x]
  _enc = v.enc[x]
  _redraw = v.redraw[x]
  _gridkey = v.gridkey[x]
  _gridredraw = v.gridredraw[x]
  redraw()
  dirtygrid = true
end

gridredraw = function()
  if not g then return end
  if dirtygrid == true then
    _gridredraw()
    dirtygrid = false
  end
end

function ch_toggle(i, x)
  softcut.play(i, x)
  softcut.rec(i, x)
end

function runall() --start all selected tracks (currently unused)
  for i = 1, TRACKS do
    if track[i].sel == 1 then
      e = {} e.t = eSTART e.i = i
    end
  event(e)
  end
end

function stopall() --stop all tracks tracks
  for i = 1, TRACKS do
      e = {} e.t = eSTOP e.i = i
  event(e)
  end
end

function altrun() --add alternative run function for selected tracks (see gridnav)
  for i = 1, TRACKS do
    if track[i].sel == 1 then
      if track[i].play == 1 then
        e = {} e.t = eSTOP e.i = i
      else
        e = {} e.t = eSTART e.i = i
      end
    elseif track[i].sel == 0 then
      return
    end
  event(e)
  end
end

function retrig() --add retrig function for playing tracks (see gridnav)
  for i = 1, TRACKS do
    if track[i].play == 1 then
      if track[i].rev == 0 then
        e = {} e.t = eCUT e.i = i e.pos = 0
      elseif track[i].rev == 1 then
        e = {} e.t = eCUT e.i = i e.pos = 15
      end
    event(e)
    end
  end
end

--play any track before using otherwise we get an error "attempt to index a nil value (local 'e')"
function osrec()
  for i = 1, TRACKS do
    if track[i].rec == 1 then
      if track[i].rev == 0 then
        e = {} e.t = eCUT e.i = i e.pos = 0
      elseif track[i].rev == 1 then
        e = {} e.t = eCUT e.i = i e.pos = 15
      end
    end
    event(e)
  end
end

function mstart() --MIDI START for selected tracks
  for i = 1, TRACKS do
    if track[i].sel == 1 then
      if track[i].rev == 0 then
        e = {} e.t = eCUT e.i = i e.pos = 0
      elseif track[i].rev == 1 then
        e = {} e.t = eCUT e.i = i e.pos = 15
      end
    end
  event(e)
  end
end

-- MIDI SETUP
local clk_midi = midi.connect()
clk_midi.event = function(data)
  local d = midi.to_msg(data)
  if d.type == "start" then
      clock.transport.start()
  --elseif d.type == "continue" then
      --clock.transport.start()
  end
  if d.type == "stop" then
    clock.transport.stop()
  end
end

function clock.transport.start()
  mstart()
end

function clock.transport.stop()
  stopall()
end

-- for hnds (TODO: tweek the min max values for the according target params)
function lfo.process()
  for i = 1, 6 do
    local target = params:get(i .. "lfo_target")
    local target_name = string.sub(lfo_targets[target], 2)
    local voice = string.sub(lfo_targets[target], 1, 1)
    if params:get(i .. "lfo") == 2 then
      if target_name == "vol" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "pan" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, -1.0, 1.0))
      elseif target_name == "dub" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "transpose" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 2.0, -2.0, 2.0))
      elseif target_name == "rate_slew" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "cutoff" then
      params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 20, 18000))
      end
    end
  end
end

--iniiiiiiit!
init = function()

--params for "globals"
  params:add_separator("global")

-- rec thesh set
  params:add_control("record_threshold","rec threshold",controlspec.new(1,1000,'exp',1,85,''))

-- params for scales
  params:add_option("scale","scale", scale_options,1)

-- params for quant division
  params:set_action("clock_tempo", function() update_tempo() end)
  params:add_option("quant_div", "quant div", {1, 2, 4, 8, 16, 32}, 4)
  params:set_action("quant_div",function() update_tempo() end)

-- params for tracks 1-6
  params:add_separator("tracks")

  p = {}

  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)

  for i = 1,TRACKS do
    params:add_group("track "..i, 15)

  --softcut settings
    softcut.enable(i, 1)

  	softcut.level_input_cut(1, i, 1.0)
  	softcut.level_input_cut(2, i, 1.0)

    softcut.play(i, 0)
    softcut.rec(i, 0)

    softcut.level(i, 1)
    softcut.pan(i, 0)
    softcut.buffer(i, 1)

    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)

    softcut.fade_time(i, FADE)
    softcut.level_slew_time(i, 0.1)
    softcut.rate_slew_time(i, 0)

    softcut.pre_filter_dry(i, 0)
    softcut.post_filter_dry(i, 0)

    softcut.loop_start(i,clip[track[i].clip].s)
    softcut.loop_end(i,clip[track[i].clip].e)
    softcut.loop(i, 1)
    softcut.position(i, clip[track[i].clip].s)

    params:add_separator("tape / buffer")
    -- track volume
    params:add_control(i.."vol", i.." vol", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."vol", function(x) softcut.level(i,x) end)
    -- track pan
    params:add_control(i.."pan", i.." pan", controlspec.new(-1, 1, 'lin', 0, 0, ""))
    params:set_action(i.."pan", function(x) softcut.pan(i,x) end)
    -- record level
    params:add_control(i.."rec", i.." rec", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."rec", function(x) track[i].rec_level = x set_rec(i) end)
    -- overdub level
    params:add_control(i.."dub", i.." dub", controlspec.UNIPOLAR)
    params:set_action(i.."dub", function(x) track[i].pre_level = x set_rec(i) end)
    -- scale
    params:add_option(i.."t_scale", i.." scale", scale_track) -- to define
    --params:set_action(i.."scale", function() set_scale end)   -- to define
    -- transpose
    params:add_control(i.."transpose", i.." transpose", scale)
    params:set_action(i.."transpose", function() update_rate(i) end)
    -- transpose slew
    params:add_control(i.."rate_slew", i.." rate slew", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action(i.."rate_slew", function(x) softcut.rate_slew_time(i, x) end)
    -- level slew
    params:add_control(i.."level_slew", i.." level slew", controlspec.new(0.0, 10.0, "lin", 0.1, 0.1, ""))
    params:set_action(i.."level_slew", function(x) softcut.level_slew_time(i, x) end)
    -- add file
    params:add_file(i.."file", i.." file", "")
    params:set_action(i.."file", function(n) fileselect_callback(n,i) end)
    params:hide(i.."file") --never use this as present in CLIP page and don't need to midimap

    params:add_separator("filter")
    -- cutoff
    params:add_control(i.."cutoff", i.." cutoff", controlspec.new(20, 18000, 'exp', 1, 18000, "Hz"))
    params:set_action(i.."cutoff", function(x) softcut.post_filter_fc(i, x) softcut.post_filter_fc(i, x) end)
    -- filter q
    params:add_control(i.."filter_q", i.." filter q", controlspec.new(0.1, 4.0, 'exp', 0.01, 2.0, ""))
    params:set_action(i.."filter_q", function(x) softcut.post_filter_rq(i, x) softcut.post_filter_rq(i, x) end)
    -- low pass
    params:add_control(i.."low_pass", i.." lp level", controlspec.new(0, 1, 'lin', 0.01, 1, ""))
    params:set_action(i.."low_pass", function(x) softcut.post_filter_lp(i, x) softcut.post_filter_lp(i, x) end)
    -- high pass
    params:add_control(i.."high_pass", i.." hp level", controlspec.new(0, 1, 'lin', 0.01, 0, ""))
    params:set_action(i.."high_pass", function(x) softcut.post_filter_hp(i, x) softcut.post_filter_hp(i, x) end)
    
    update_rate(i)
    set_clip(i, i)
  end
  
-- params for modulation
  params:add_separator("modulation")

  -- for hnds
  for i = 1, 6 do
    lfo[i].lfo_targets = lfo_targets
  end

  lfo.init()

  quantizer = metro.init()
  quantizer.time = 0.125
  quantizer.count = -1
  quantizer.event = event_q_clock
  quantizer:start()

  --pattern_init()
  set_view(vREC)

  update_tempo()

  gridredrawtimer = metro.init(function() gridredraw() end, 0.02, -1)
  gridredrawtimer:start()
  dirtygrid = true

  grid.add = draw_grid_connected

  screenredrawtimer = metro.init(function() redraw() end, 0.1, -1)
  screenredrawtimer:start()

  params:bang()

  softcut.event_phase(phase)
  softcut.poll_start_phase()

  clock.run(clock_update_tempo)

end -- init end

-- poll callback
phase = function(n, x)
  local pp = ((x - clip[track[n].clip].s) / clip[track[n].clip].l)
  x = math.floor(pp * 16)
  if x ~= track[n].pos_grid then
    track[n].pos_grid = x
    if view == vCUT then dirtygrid = true end
    if view == vREC then dirtygrid = true end --(keep grid refreshing on REC page --> CUT focused track on bottom row)
  end
end

update_rate = function(i)
  local n = math.pow(2, track[i].speed + params:get(i.."transpose"))
  if track[i].rev == 1 then n = -n end
  if track[i].tempo_map == 1 then
    local bpmmod = params:get("clock_tempo") / clip[track[i].clip].bpm
    n = n * bpmmod
  end
  softcut.rate(i, n)
end

gridkey_nav = function(x, z)
  if z == 1 then
    if x == 1 then
      if alt == 1 then softcut.buffer_clear() end
      set_view(vREC)
    elseif x == 2 then set_view(vCUT)
    elseif x == 3 then set_view(vCLIP)
    --elseif x == 4 then
      --armrec = 1 - armrec
      --arm_rec()
    elseif x>4 and x<9 then
      local i = x - 4
      if alt == 1 then
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "clear"} event(e)
      elseif pattern[i].rec == 1 then
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "start"} event(e)
      elseif pattern[i].count == 0 then
        local e = {t = ePATTERN, i = i, action = "rec_start"} event(e)
      elseif pattern[i].play == 1 then
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
      else
        local e = {t = ePATTERN, i = i, action = "start"} event(e)
      end
    elseif x>8 and x<13 then
      local i = x-8
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
    elseif x == 15 and alt == 0 then
      quantize = 1 - quantize
      if quantize == 0 then quantizer:stop()
      else quantizer:start()
      end
    elseif x == 15 and alt == 1 then
      set_view(vTIME)
    elseif x == 16 then alt = 1
    elseif x == 14 and alt == 0 then alt2 = 1
    elseif x == 14 and alt == 1 then retrig()  --retrig all playing tracks to pos 1
    elseif x == 13 and alt == 0 then stopall() --stops all tracks
    elseif x == 13 and alt == 1 then altrun()  --stops all running tracks and runs all stopped tracks if track.sel == 1
    end
  elseif z == 0 then
    if x == 16 then alt = 0
    elseif x == 14 and alt == 0 then alt2 = 0 --lock alt2 if alt2 released before alt is released
    elseif x == 15 and view == vTIME then set_view(-1)
    elseif x>8 and x<13 then recall[x-8].active = false
    end
  end
  dirtygrid = true
end

gridredraw_nav = function()
  g:led(1, 1, 4)
  g:led(2, 1, 3)
  g:led(3, 1, 2)
  g:led(view, 1, 9)
  if armrec == 1 then g:led(4, 1, 9)
  else g:led(4, 1, 0) end
  if alt == 1 and alt2 == 0 then g:led(16, 1, 15)
  elseif alt == 0 then g:led(16, 1, 9) end
  if quantize == 1 then g:led(15, 1, 9)
  elseif quantize == 0 then g:led(15, 1, 3) end
  if alt2 == 1 then g:led(14, 1, 9)
  elseif alt2 == 0 then g:led(14, 1, 2) end
  for i = 1, 4 do
    if pattern[i].rec == 1 then g:led(i+4, 1, 15)
    elseif pattern[i].play == 1 then g:led(i+4, 1, 11)
    elseif pattern[i].count > 0 then g:led(i+4, 1, 7)
    else g:led(i+4, 1, 4) end
    local b = 4
    if recall[i].recording == true then b = 15
    elseif recall[i].active == true then b = 11
    elseif recall[i].has_data == true then b = 7 end
    g:led(i+8, 1, b)
  end
end

-------------------- REC -------------------------
v.key[vREC] = function(n, z)
  if n == 2 and z == 1 then
    viewinfo[vREC] = 1 - viewinfo[vREC]
    redraw()
  end
end

v.enc[vREC] = function(n, d)
  if n == 1 then
    if key1_hold == 0 then
      pageNum = util.clamp(pageNum+d, 1, 3)
    elseif key1_hold == 1 then
      params:delta("output_level", d)
    end
  end
  if pageNum == 1 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(focus.."vol", d)
      elseif n == 3 then
        params:delta(focus.."pan", d)
      end
    else
      if n == 2 then
        params:delta(focus.."rec", d)
      elseif n == 3 then
        params:delta(focus.."dub", d)
      end
    end
  elseif pageNum == 2 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(focus.."cutoff", d)
      elseif n == 3 then
        params:delta(focus.."filter_q", d)
      end
    else
      if n == 2 then
        params:delta(focus.."high_pass", d)
      elseif n == 3 then
        params:delta(focus.."low_pass", d)
      end
    end
 elseif pageNum == 3 then
   if viewinfo[vREC] == 0 then
     if n == 2 then
       params:delta(focus.."transpose", d)
     elseif n == 3 then return
       params:delta(focus.."t_scale", d)
     end
   else
     if n == 2 then
       params:delta(focus.."rate_slew", d)
     elseif n == 3 then
       params:delta(focus.."level_slew", d)
     end
   end
  end
  redraw()
end

v.redraw[vREC] = function()
  screen.clear()
  screen.level(15)
  screen.move(10,16)
  screen.text("TRACK "..focus)
  local sel = viewinfo[vREC] == 0

  if pageNum == 1 then
    screen.level(15)
    screen.move(112,16)
    screen.text("1/3")
    screen.level(sel and 15 or 4)
    screen.move(10,32)
    screen.text(params:string(focus.."vol"))
    screen.move(70,32)
    screen.text(params:string(focus.."pan"))
    screen.level(3)
    screen.move(10,40)
    screen.text("volume")
    screen.move(70,40)
    screen.text("pan")

    screen.level(not sel and 15 or 4)
    screen.move(10,52)
    screen.text(params:string(focus.."rec"))
    screen.move(70,52)
    screen.text(params:string(focus.."dub"))
    screen.level(3)
    screen.move(10,60)
    screen.text("rec level")
    screen.move(70,60)
    screen.text("dub level")

  elseif pageNum == 2 then
    screen.level(15)
    screen.move(110,16)
    screen.text("2/3")
    screen.level(sel and 15 or 4)
    screen.move(10,32)
    screen.text(params:string(focus.."cutoff"))
    screen.move(70,32)
    screen.text(params:string(focus.."filter_q"))
    screen.level(3)
    screen.move(10,40)
    screen.text("cutoff")
    screen.move(70,40)
    screen.text("filter q")

    screen.level(not sel and 15 or 4)
    screen.move(10,52)
    screen.text(params:string(focus.."high_pass"))
    screen.move(70,52)
    screen.text(params:string(focus.."low_pass"))
    screen.level(3)
    screen.move(10,60)
    screen.text("hp level")
    screen.move(70,60)
    screen.text("lp level")

  elseif pageNum == 3 then
    screen.level(15)
    screen.move(110,16)
    screen.text("3/3")
    screen.level(sel and 15 or 4)
    screen.move(10,32)
    screen.text(params:string(focus.."transpose"))
    screen.move(70,32)
    screen.text(params:string(focus.."t_scale"))
    screen.level(3)
    screen.move(10,40)
    screen.text("transpose")
    screen.move(70,40)
    screen.text("set scale")

    screen.level(not sel and 15 or 4)
    screen.move(10,52)
    screen.text(params:string(focus.."rate_slew"))
    screen.move(70,52)
    screen.text(params:string(focus.."level_slew"))
    screen.level(3)
    screen.move(10,60)
    screen.text("rate slew")
    screen.move(70,60)
    screen.text("level slew")
  end
  screen.update()
end

v.gridkey[vREC] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif y>1 and y<8 then
    if z == 1 then
      i = y-1
      if x>2 and x<7 then
        if alt == 1 then
          track[i].tempo_map = 1 - track[i].tempo_map
          update_rate(i)
        elseif focus ~= i then
          focus = i
          redraw()
        end
      elseif x == 1 and y<TRACKS+2 and alt == 0 then
        track[i].rec = 1 - track[i].rec
          set_rec(i)
          if track[i].oneshot == 1 and track[i].rec == 1 then
            osrec()
          end
      elseif x == 1 and y<TRACKS+2 and alt == 1 then
        track[i].oneshot = 1 - track[i].oneshot
      elseif x == 16 and y<TRACKS+2 and alt == 0 then
        if track[i].play == 1 then
          e = {}
          e.t = eSTOP
          e.i = i
          event(e)
        else
          e = {}
          e.t = eSTART
          e.i = i
          event(e)
        end
      elseif x == 16 and y<TRACKS+2 and alt == 1 then
        track[i].sel = 1 - track[i].sel
      elseif x>8 and x<16 and y<TRACKS+2 then
        local n = x-12
        e = {} e.t = eSPEED e.i = i e.speed = n
        event(e)
      elseif x == 8 and y<TRACKS+2 then
        local n = 1 - track[i].rev
        e = {} e.t = eREV e.i = i e.rev = n
        event(e)
      end
      dirtygrid = true
    end
  elseif y == 8 then
    if z == 1 and held[y] then heldmax[y] = 0 end
    held[y] = held[y] + (z*2-1)
    if held[y] > heldmax[y] then heldmax[y] = held[y] end
    local i = focus
    if z == 1 then
      if alt2 == 1 then --"freeze" function as on cut page (better to implement in event_exec(e)?? -> eFREEZ?)
        heldmax[y] = x
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = x
        e.loop_end = x
        event(e)
      elseif held[y] == 1 then
        first[y] = x
        local cut = x-1
        e = {} e.t = eCUT e.i = i e.pos = cut
        event(e)
      elseif held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if held[y] == 1 and heldmax[y] == 2 then
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = math.min(first[y], second[y])
        e.loop_end = math.max(first[y], second[y])
        event(e)
      end
    end
  end
end

v.gridredraw[vREC] = function()
  g:all(0)
  g:led(3, focus+1, 7) g:led(4, focus+1, 7) g:led(5, focus+1, 3) g:led(6, focus+1, 3)
  for i = 1, TRACKS do
    local y = i+1
    g:led(1, y, 3) --rec
    if track[i].rec == 1 and track[i].oneshot == 1 then g:led(1, y, 15)  end
    if track[i].rec == 1 and track[i].oneshot == 0 then g:led(1, y, 10)  end
    if track[i].rec == 0 and track[i].oneshot == 1 then g:led(1, y, 5)  end
    if track[i].tempo_map == 1 then g:led(5, y, 7) g:led(6, y, 7)end -- tempo.map
    g:led(8, y, 3) --rev
    g:led(16, y, 3) --stop
    g:led(12, y, 3) --speed = 1
    g:led(12+track[i].speed, y, 9)
    if track[i].rev == 1 then g:led(8, y, 8) end
    if track[i].play == 1 and track[i].sel == 1 then g:led(16, y, 15) end
    if track[i].play == 1 and track[i].sel == 0 then g:led(16, y, 10) end
    if track[i].play == 0 and track[i].sel == 1 then g:led(16, y, 5) end
  end
  if track[focus].loop == 1 then
    for x = track[focus].loop_start, track[focus].loop_end do
      g:led(x, 8, 4)
    end
  end
  if track[focus].play == 1 then
    if track[focus].rev == 0 then
      g:led((track[focus].pos_grid+1)%16, 8, 15)
    elseif track[focus].rev == 1 then
      if track[focus].loop == 1 then
        g:led((track[focus].pos_grid+1)%16, 8, 15)
      else
        g:led((track[focus].pos_grid+2)%16, 8, 15)
      end
    end
  end
  gridredraw_nav()
  g:refresh();
end

--------------------CUT-----------------------
v.key[vCUT] = v.key[vREC]
v.enc[vCUT] = v.enc[vREC]
v.redraw[vCUT] = v.redraw[vREC]

v.gridkey[vCUT] = function(x, y, z)

  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z*2-1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end

  if y == 1 then gridkey_nav(x,z)
  elseif y == 8 then return
  else
    i = y-1
    if z == 1 then
      if focus ~= i then
        focus = i
        redraw()
      end
      if alt == 1 and y<TRACKS+2 then
        if track[i].play == 1 then
          e = {} e.t = eSTOP e.i = i
        else
          e = {} e.t = eSTART e.i = i
        end
        event(e)
      elseif alt2 == 1 and y<TRACKS+2 then
        --if track[i].play == 1 then
          heldmax[y] = x
          e = {}
          e.t = eLOOP
          e.i = i
          e.loop = 1
          e.loop_start = x
          e.loop_end = x
          event(e)
        --end
      elseif y<TRACKS+2 and held[y] == 1 then
        first[y] = x
        local cut = x-1
        e = {} e.t = eCUT e.i = i e.pos = cut
        event(e)
      elseif y<TRACKS+2 and held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if y<TRACKS+2 and held[y] == 1 and heldmax[y] == 2 then
        e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = math.min(first[y],second[y])
        e.loop_end = math.max(first[y],second[y])
        event(e)
      end
    end
  end
end

v.gridredraw[vCUT] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, TRACKS do
    if track[i].loop == 1 then
      for x=track[i].loop_start, track[i].loop_end do
        g:led(x, i+1, 4)
      end
    end
    --bugfix? when track rev then led was offset by one.
    if track[i].play == 1 then
      if track[i].rev == 0 then
        g:led((track[i].pos_grid+1)%16, i+1, 15)
      elseif track[i].rev == 1 then
        if track[i].loop == 1 then
          g:led((track[i].pos_grid+1)%16, i+1, 15) --if not added there is an offest of 1 when in loop and rev
        else
          g:led((track[i].pos_grid+2)%16, i+1, 15)
        end
      end
    end
  end
  g:refresh();
end

--------------------CLIP-----------------------
clip_actions = {"load", "clear", "save"}
clip_action = 1
clip_sel = 1
clip_clear_mult = 3

function fileselect_callback(path, c)
  print("FILESELECT "..c)
  if path ~= "cancel" and path ~= "" then
    local ch, len = audio.file_info(path)
    if ch > 0 and len > 0 then
      print("file > "..path.." "..clip[track[c].clip].s)
      print("file length > "..len/48000)
      --softcut.buffer_read_mono(path, 0, clip[track[clip_sel].clip].s, len/48000, 1, 1)
      softcut.buffer_read_mono(path, 0, clip[track[c].clip].s, CLIP_LEN_SEC, 1, 1)
      local l = math.min(len/48000, CLIP_LEN_SEC)
      set_clip_length(track[c].clip, l)
      clip[track[c].clip].name = path:match("[^/]*$") -- TODO: STRIP extension
      set_clip(c,track[c].clip)
      update_rate(c)
      params:set(c.."file",path)
    else
      print("not a sound file")
    end
    -- TODO re-set_clip any tracks with this clip loaded
    screenredrawtimer:start()
    redraw()
  end
end

function textentry_callback(txt)
  if txt then
    local c_start = clip[track[clip_sel].clip].s
    local c_len = clip[track[clip_sel].clip].l
    print("SAVE " .. _path.audio .. "mlr/" .. txt .. ".wav", c_start, c_len)
    util.make_dir(_path.audio .. "mlr")
    softcut.buffer_write_mono(_path.audio.."mlr/"..txt..".wav", c_start, c_len, 1)
    clip[track[clip_sel].clip].name = txt
  else
    print("save cancel")
  end
  screenredrawtimer:start()
  redraw()
end

v.key[vCLIP] = function(n,z)
  if n == 2 and z == 0 then
    if clip_actions[clip_action] == "load" then
      screenredrawtimer:stop()
      fileselect.enter(os.getenv("HOME").."/dust/audio",
        function(n) fileselect_callback(n,clip_sel) end)
    elseif clip_actions[clip_action] == "clear" then
      local c_start = clip[track[clip_sel].clip].s * 48000
      print("clear_start: " .. c_start)
      --softcut.clear_range(c_start, CLIP_LEN_SEC * 48000) -- two minutes
      clip[track[clip_sel].clip].name = '-'
      redraw()
    elseif clip_actions[clip_action] == "save" then
      screenredrawtimer:stop()
      textentry.enter(textentry_callback, "mlr-" .. (math.random(9000)+1000))
    end
  elseif n == 3 and z == 1 then
    clip_reset(clip_sel, 60/params:get("clock_tempo")*(2^(clip_clear_mult-2)))
    set_clip(clip_sel, track[clip_sel].clip)
    update_rate(clip_sel)
  end
end

v.enc[vCLIP] = function(n,d)
  if n == 2 then
    clip_action = util.clamp(clip_action + d, 1, 3)
  elseif n == 3 then
    clip_clear_mult = util.clamp(clip_clear_mult+d, 1, 6)
  end
  redraw()
  dirtygrid=true
end

local function truncateMiddle (str, maxLength, separator)
  maxLength = maxLength or 30
  separator = separator or "..."

  if (maxLength < 1) then return str end
  if (string.len(str) <= maxLength) then return str end
  if (maxLength == 1) then return string.sub(str, 1, 1) .. separator end

  midpoint = math.ceil(string.len(str) / 2)
  toremove = string.len(str) - maxLength
  lstrip = math.ceil(toremove / 2)
  rstrip = toremove - lstrip

  return string.sub(str, 1, midpoint - lstrip) .. separator .. string.sub(str, 1 + midpoint + rstrip)
end

v.redraw[vCLIP] = function()
  screen.clear()
  screen.level(15)
  screen.move(10,16)
  screen.text("TRACK "..clip_sel)

  screen.move(10,52)
  screen.text(truncateMiddle(clip[track[clip_sel].clip].name, 18))
  screen.level(3)
  screen.move(10,60)
  screen.text("clip "..track[clip_sel].clip .. " " .. clip_actions[clip_action])

  screen.level(15)
  screen.move(100,52)
  screen.text(2^(clip_clear_mult-2))
  screen.level(3)
  screen.move(100,60)
  screen.text("resize")

  screen.update()
end

v.gridkey[vCLIP] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif z == 1 then
    if y < TRACKS+2 and x < MAX_CLIPS+1 then
    clip_sel = y-1
    if x ~= track[clip_sel].clip then
      set_clip(clip_sel, x)
    end
  end
    redraw()
    dirtygrid = true
  end
end

v.gridredraw[vCLIP] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, MAX_CLIPS do g:led(i, clip_sel+1, 4) end --changed to MAX_CLIPS instead of 16
  for i = 1, TRACKS do g:led(track[i].clip, i+1, 10) end
  g:refresh();
end

--------------------TIME--------------------
v.key[vTIME] = function(n, z)
  --print("I have no function yet")
end

v.enc[vTIME] = function(n, d)
  if n == 2 then
    params:delta("clock_tempo", d)
  elseif n == 3 then
    params:delta("quant_div", d)
  end
  redraw()
end

v.redraw[vTIME] = function()
  screen.clear()
  screen.level(15)
  screen.move(10,16)
  screen.text("TIME SETTINGS")
  if viewinfo[vTIME] == 0 then
    screen.move(10,50)
    screen.text(params:get("clock_tempo"))
    screen.move(70,50)
    screen.text(params:get("quant_div"))
    screen.level(3)
    screen.move(10,60)
    screen.text("tempo")
    screen.move(70,60)
    screen.text("quant div")
  end
  screen.update()
end

v.gridkey[vTIME] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z) end
end

v.gridredraw[vTIME] = function()
  g:all(0)
  gridredraw_nav()
  g:refresh();
end

function draw_grid_connected()
  dirtygrid = true
  gridredraw()
end

function cleanup()
  for i = 1, 4 do
    pattern[i]:stop()
    pattern[i] = nil
  end

  grid.add = function() end
end
