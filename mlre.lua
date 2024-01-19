-- mlre v2.0.0 @sonocircuit
-- llllllll.co/t/mlre
--
-- an adaption of
-- mlr v2.2.4 @tehn
-- llllllll.co/t/21145
--
-- for docs go to:
-- >> github.com
--    /sonocircuit/mlre
--
-- or smb into:
-- >> code/mlre/docs
--

norns.version.required = 231114

m = midi.connect()
a = arc.connect()
g = grid.connect()

mu = require 'musicutil'
textentry = require 'textentry' 
fileselect = require 'fileselect'
lattice = require 'lattice'
--_lfo = require 'lfo'

ui = include 'lib/ui_mlre'
grd = include 'lib/grid_mlre'
_lfo = include 'lib/lfo_mlre'
scales = include 'lib/scales_mlre'
pattern_time = include 'lib/pattern_time_mlre'


--------- variables --------
pset_load = false
rotate_grid = false -- zero only. if true will rotate 90° CW

mlre_path = _path.audio .. "mlre/"

-- constants
GRID_SIZE = 0
FADE_TIME = 0.01
TAPE_GAP = 1
MAX_TAPELENGTH = 57
DEFAULT_SPLICELEN = 4
DEFAULT_BEATNUM = 4

-- ui
main_pageNum = 1
lfo_pageNum = 1
env_pageNum = 1
patterns_pageNum = 1
track_focus = 1
lfo_focus = 1
env_focus = 1
pattern_focus = 1
held_focus = 0

alt = 0
mod = 0
shift = 0
cutview_hold = false

lfo_trksel = 1
lfo_dstview = 0
lfo_dstsel = 1

-- viz variables 
pulse_key_fast = 1
pulse_key_mid = 1
pulse_key_slow = 1
pulse_bar = false
pulse_beat = false

view_message = ""

-- oneshot recording variables
amp_threshold = 1
armed_track = 1
oneshot_rec = false
transport_run = false
autolength = false
loop_pos = 1
rec_dur = 0

-- options variables
stop_all_active = true
macro_slot_mode = 1
loading_pset = false
current_scale = 1
autorand_at_cycle = false
rnd_stepcount = 16

-- arc variables
arc_pageNum = 1
arc_is = false
enc2_wait = false
arc_off = 0
arc_inc1 = 0
arc_inc2 = 0
arc_inc3 = 0
arc_inc4 = 0
arc_inc5 = 0
arc_render = 0
arc_lfo_focus = 1
arc_track_focus = 1
arc_splice_focus = 1
scrub_sens = 100
tau = math.pi * 2

-- main page variables
main_page_params_l = {"vol", "rec", "cutoff", "filter_type", "detune","rate_slew", "play_mode", "reset_active"}
main_page_params_r = {"pan", "dub", "filter_q", "post_dry", "transpose", "level_slew", "start_launch", "reset_count"}
main_page_names_l = {"volume", "rec   level", "cutoff", "filter   type", "detune", "rate   slew", "play   mode", "track   reset"}
main_page_names_r = {"pan", "dub   level", "filter   q", "dry   level", "transpose", "level   slew", "track   launch", "reset   count"}

 -- lfo page variables
lfo_rate_params = {"lfo_clocked_lfo_", "lfo_free_lfo_"}
lfo_page_params_l = {"lfo_depth_lfo_", "lfo_shape_lfo_", "lfo_mode_lfo_"}
lfo_page_params_r = {"lfo_offset_lfo_", "lfo_phase_lfo_", "lfo_free_lfo_"}
lfo_page_names_l = {"depth", "shape", "mode"}
lfo_page_names_r = {"offset", "phase", "rate"}

-- pattern page variables
patterns_page_params_l = {"patterns_meter", "patterns_countin"}
patterns_page_params_r = {"patterns_barnum", "patterns_playback"}
patterns_page_names_l = {"meter", "launch"}
patterns_page_names_r = {"length", "play   mode"}

-- tape page variables
tape_actions = {"load", "clear", "save", "copy", "paste"}
tape_action = 1
copy_track = nil
copy_splice = nil
resize_values = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, MAX_TAPELENGTH}
resize_options = {"1/4", "2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "8/4", "9/4", "10/4", "11/4", "12/4", "14/4", "16/4", "18/4", "20/4", "22/4", "24/4", "28/4", "32/4", "MAX"}

view_splice_info = false
view_track_send = false
sends_focus = 1

view_presets = false
pset_focus = 1
pset_list = {}

-- pattern page variables and tables
pattern_playback = {"loop", "oneshot"}
pattern_countin = {"beat", "bar"}
pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
pattern_meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}

-- key quantization variables and tables
quantize_events = {}
quantizing = false
quant_options = {"1bar", "1/2", "1/3", "1/4", "1/6", "1/8", "1/16", "1/32"}
quant_values = {1, 1/2, 1/3, 1/4, 1/6, 1/8, 1/16, 1/32}
q_rate = 16

-- key logic
held = {}
heldmax = {}
first = {}
second = {}
for i = 1, 8 do
  held[i] = 0
  heldmax[i] = 0
  first[i] = 0
  second[i] = 0
end


--------------------- EVENTS -----------------------

-- event variables
eCUT = 1
eSTOP = 2
eSTART = 3
eLOOP = 4
eSPEED = 5
eREV = 6
eMUTE = 7
eTRSP = 8
ePATTERN = 9
eUNLOOP = 10
eGATEON = 11
eGATEOFF = 12
eSPLICE = 13
eROUTE = 14

-- event funtions
function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
  recall_watch(e)
end

function event(e)
  if quantizing and e.sync == nil then
    table.insert(quantize_events, e)
  else
    if e.t ~= ePATTERN then
      event_record(e)
    end
    event_exec(e)
  end
end

function update_q_clock()
  while true do
    clock.sync(q_rate)
    if #quantize_events > 0 then
      for k, e in pairs(quantize_events) do
        if e.t ~= ePATTERN then event_record(e) end
        event_exec(e)
      end
      quantize_events = {}
    end
  end
end

function loop_event(i, lstart, lend)
  local e = {}
  e.t = eLOOP
  e.i = i
  e.loop = 1
  e.loop_start = lstart
  e.loop_end = lend
  event(e)
end

-- exec function
function event_exec(e)
  if e.t == eCUT then
    if track[e.i].loop == 1 then
      clear_loop(e.i)
    end
    local cut = (e.pos / 16) * clip[e.i].l + clip[e.i].s
    local q = track[e.i].rev == 1 and clip[e.i].l / 16 or 0
    softcut.position(e.i, cut + q)
    if track[e.i].play == 0 then
      track[e.i].play = 1
      track[e.i].beat_count = 0
      set_rec(e.i)
      set_level(e.i)
      toggle_transport()
    end
    dirtygrid = true
  elseif e.t == eSTOP then
    stop_track(e.i)
  elseif e.t == eSTART then
    softcut.position(e.i, track[e.i].cut)
    track[e.i].play = 1
    track[e.i].beat_count = 0
    set_rec(e.i)
    set_level(e.i)
    toggle_transport()
    dirtygrid = true
  elseif e.t == eLOOP then
    make_loop(e.i, e.loop_start, e.loop_end)
  elseif e.t == eUNLOOP then
    clear_loop(e.i)
  elseif e.t == eSPEED then
    track[e.i].speed = e.speed
    update_rate(e.i)
    grid_page(vREC)
  elseif e.t == eREV then
    track[e.i].rev = e.rev
    update_rate(e.i)
    dirtygrid = true
  elseif e.t == eMUTE then
    track[e.i].mute = e.mute
    set_level(e.i)
  elseif e.t == eTRSP then
    params:set(e.i.."transpose", e.val)
    grid_page(vCUT)
    grid_page(vTRSP)
  elseif e.t == eGATEON then
    if env[e.i].active then
      env_gate_on(e.i)
    end
  elseif e.t == eGATEOFF then
    if env[e.i].active then
      env_gate_off(e.i)
    end
  elseif e.t == eSPLICE then
    track[e.i].splice_active = e.active
    set_clip(e.i)
    render_splice()
    dirtygrid = true
  elseif e.t == eROUTE then
    if e.ch == 5 then
      track[e.i].t5 = e.route
    else
      track[e.i].t6 = e.route
    end
    set_track_sends(e.i)
    grid_page(vTAPE)
  elseif e.t == ePATTERN then
    if e.action == "stop" then
      pattern[e.i]:stop()
    elseif e.action == "start" then
      pattern[e.i]:start()
    elseif e.action == "rec_stop" then
      pattern[e.i]:rec_stop()
      pattern_rec = false
    elseif e.action == "rec_start" then
      pattern[e.i]:rec_start()
      pattern_rec = true
    elseif e.action == "clear" then
      pattern[e.i]:clear()
    elseif e.action == "overdub_on" then
      pattern[e.i]:set_overdub(1)
      pattern_rec = true
    elseif e.action == "overdub_off" then
      pattern[e.i]:set_overdub(0)
      pattern_rec = false
    elseif e.action == "overdub_undo" then
      pattern[e.i]:set_overdub(-1)
      pattern_rec = false
    end
  end
end

-- patterns and recall
patterns_only = false
pattern_rec = false
pattern = {}
for i = 1, 8 do
  pattern[i] = pattern_time.new("pattern "..i)
  pattern[i].process = event_exec
end

recall = {}
for i = 1, 8 do
  recall[i] = {}
  recall[i].recording = false
  recall[i].has_data = false
  recall[i].active = false
  recall[i].event = {}
end

function recall_watch(e)
  for i = 1, 8 do
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

function randomize(i)
  if params:get("rnd_transpose") == 2 then
    params:set(i.."transpose", math.random(1, 15))
  end
  if params:get("rnd_vol") == 2 then
    params:set(i.."vol", math.random(20, 100) / 100)
  end
  if params:get("rnd_pan") == 2 then
    params:set(i.."pan", (math.random() * 20 - 10) / 10)
  end
  if params:get("rnd_dir") == 2 then
    local e = {} e.t = eREV e.i = i e.rev = math.random(0, 1)
    event(e)
  end
  if params:get("rnd_loop") == 2 then
    local lstart = math.random(1, 15)
    local lend = autorand_at_cycle and math.random(lstart + 1, 16) or math.random(lstart, 16)
    loop_event(i, lstart, lend)
  end
  if params:get("rnd_speed") == 2 then
    local e = {} e.t = eSPEED e.i = i e.speed = math.random(- params:get("rnd_loct"), params:get("rnd_uoct"))
    event(e)
  end
  if params:get("rnd_cut") == 2 then
    params:set(i.. "cutoff", math.random(params:get("rnd_lcut"), params:get("rnd_ucut")) )
  end
  track[i].step_count = 0
end

--------------------- TRACK, TAPE AND CLIPS -----------------------

-- track variables
track = {}
for i = 1, 6 do
  track[i] = {}
  track[i].start_launch = 1
  track[i].play_mode = 1
  track[i].play = 0
  track[i].sel = 0
  track[i].rec = 0
  track[i].oneshot = 0
  track[i].level = 1
  track[i].prev_level = 1
  track[i].pan = 0
  track[i].mute = 0
  track[i].rate_slew = 0
  track[i].rec_level = 1
  track[i].pre_level = 0
  track[i].dry_level = 0
  track[i].t5 = 0
  track[i].t6 = 0
  track[i].send_t5 = 1
  track[i].send_t6 = 1
  track[i].loop = 0
  track[i].loop_start = 1
  track[i].loop_end = 16
  track[i].dur = 4
  track[i].splice_active = 1
  track[i].splice_focus = 1
  track[i].cut = TAPE_GAP * i + (i - 1) * MAX_TAPELENGTH
  track[i].pos_abs = TAPE_GAP * i + (i - 1) * MAX_TAPELENGTH
  track[i].pos_rel = 0
  track[i].pos_clip = 0
  track[i].pos_hi_res = 1
  track[i].pos_lo_res = 1
  track[i].pos_arc = 1
  track[i].pos_grid = 1
  track[i].step_count = 0
  track[i].speed = 0
  track[i].warble = 0
  track[i].rev = 0
  track[i].tempo_map = 0
  track[i].resize_val = 4
  track[i].detune = 0
  track[i].transpose = 0
  track[i].fade = 0
  track[i].loaded = true
  track[i].reset = false
  track[i].beat_count = 0
  track[i].beat_reset = 4
end

-- tape variables -> six slices of tape, one for each track
tape = {}
for i = 1, 6 do
  tape[i] = {}
  tape[i].input = 1
  tape[i].side = 1
  tape[i].s = TAPE_GAP * i + (i - 1) * MAX_TAPELENGTH
  tape[i].e = tape[i].s + MAX_TAPELENGTH
  tape[i].splice = {}
  for j = 1, 8 do
    tape[i].splice[j] = {}
    tape[i].splice[j].s = tape[i].s + (DEFAULT_SPLICELEN + 0.01) * (j - 1)
    tape[i].splice[j].e = tape[i].splice[j].s + DEFAULT_SPLICELEN
    tape[i].splice[j].l = tape[i].splice[j].e - tape[i].splice[j].s
    tape[i].splice[j].name = "-"
    tape[i].splice[j].info = "length: "..string.format("%.2f", DEFAULT_SPLICELEN).."s"
    tape[i].splice[j].init_start = tape[i].splice[j].s
    tape[i].splice[j].init_len = DEFAULT_SPLICELEN
    tape[i].splice[j].init_beatnum = DEFAULT_BEATNUM
    tape[i].splice[j].beatnum = DEFAULT_BEATNUM
    tape[i].splice[j].bpm = 60 
  end
end

-- clip variables -> six clips define the active playback window, one for each track
clip = {}
for i = 1, 6 do
  clip[i] = {}
  clip[i].s = tape[i].splice[1].s
  clip[i].e = tape[i].splice[1].e
  clip[i].l = tape[i].splice[1].l
  clip[i].bpm = tape[i].splice[1].bpm 
end

function set_clip(i) 
  -- set playback window
  clip[i].s = tape[i].splice[track[i].splice_active].s
  clip[i].l = tape[i].splice[track[i].splice_active].l
  clip[i].e = clip[i].s + clip[i].l
  clip[i].bpm = tape[i].splice[track[i].splice_active].bpm
  -- set softcut
  softcut.loop_start(i, clip[i].s)
  softcut.loop_end(i, clip[i].e)
  local q = (clip[i].l / 64)
  local off = calc_quant_off(i, q)
  softcut.phase_quant(i, q)
  softcut.phase_offset(i, off)
  if track[i].loop == 1 then
    make_loop(i, track[i].loop_start, track[i].loop_end)
  end
  update_rate(i)
end

calc_quant_off = function(i, q)
  local off = q
  while off < clip[i].s do
    off = off + q
  end
  off = off - clip[i].s
  return off
end

function splice_resize(i, focus, length)
  -- if no length argument recalculate
  if length == nil then
    if track[i].tempo_map == 0 then
      length = tape[i].splice[focus].beatnum
    elseif track[i].tempo_map == 1 then
      length = beat_sec * tape[i].splice[focus].beatnum
    elseif track[i].tempo_map == 2 then
      length = tape[i].splice[focus].l
    end
  end
  -- set splice variables
  if tape[i].splice[focus].s + length <= tape[i].e then
    tape[i].splice[focus].e = tape[i].splice[focus].s + length
    tape[i].splice[focus].l = length
    tape[i].splice[focus].bpm = 60 / length * tape[i].splice[focus].beatnum
    if track[i].splice_focus == track[i].splice_active then
      set_clip(i)
    end
    set_info(i, focus)
  else
    show_message("splice   too   long")
  end
end

function splice_reset(i, focus) -- reset splice to default length
  local focus = focus or track[i].splice_focus
  -- reset variables
  tape[i].splice[focus].s = tape[i].splice[focus].init_start
  tape[i].splice[focus].l = tape[i].splice[focus].init_len
  tape[i].splice[focus].e = tape[i].splice[focus].s + tape[i].splice[focus].l
  tape[i].splice[focus].beatnum = tape[i].splice[focus].init_beatnum
  tape[i].splice[focus].bpm = 60 / tape[i].splice[focus].l * tape[i].splice[focus].beatnum
  -- set clip
  if track[i].splice_focus == track[i].splice_active then
    set_clip(i) 
  end
  set_info(i, focus)
end

function clear_splice(i) -- clear focused splice
  local buffer = tape[i].side
  local start = tape[i].splice[track[i].splice_focus].s
  local length = tape[i].splice[track[i].splice_focus].l + FADE_TIME
  softcut.buffer_clear_region_channel(buffer, start, length)
  render_splice()
  show_message("track    "..i.."    splice    "..track[i].splice_focus.."    cleared")
end

function clear_tape(i) -- clear tape and reset splices
  local buffer = tape[i].side
  local start = tape[i].s
  softcut.buffer_clear_region_channel(buffer, start, MAX_TAPELENGTH)
  track[i].loop = 0
  init_splices(i)
  render_splice()
  show_message("track    "..i.."    tape    cleared")
  dirtygrid = true
end

function clear_buffers() -- clear both buffers and reset splices
  softcut.buffer_clear()
  for i = 1, 6 do
    track[i].loop = 0
    init_splices(i)
  end
  render_splice()
  show_message("buffers    cleared")
  dirtygrid = true
end

function init_splices(i)
  for j = 1, 8 do
    tape[i].splice[j] = {}
    tape[i].splice[j].s = tape[i].s + (DEFAULT_SPLICELEN + 0.01) * (j - 1)
    tape[i].splice[j].e = tape[i].splice[j].s + DEFAULT_SPLICELEN
    tape[i].splice[j].l = tape[i].splice[j].e - tape[i].splice[j].s
    tape[i].splice[j].init_start = tape[i].splice[j].s
    tape[i].splice[j].init_len = DEFAULT_SPLICELEN
    tape[i].splice[j].beatnum = DEFAULT_BEATNUM
    tape[i].splice[j].bpm = 60 
    tape[i].splice[j].name = "-"
    set_info(i, j)
  end
  track[i].splice_active = 1
  set_clip(i)
end

function set_info(i, n)
  if track[i].tempo_map == 2 then
    tape[i].splice[n].info = "repitch factor: "..string.format("%.2f", clock.get_tempo() / tape[i].splice[n].bpm)
  else
    tape[i].splice[n].info = "length: "..string.format("%.2f", tape[i].splice[n].l).."s"
  end
  if view == vTAPE and view_splice_info then dirtyscreen = true end
end

function set_tempo_map(i)
  clock.run(function()
    clock.sleep(0.2) -- delay splice setting for pset_loading (need to load tables first!)
    if track[i].tempo_map == 1 then
      for n = 1, 8 do
        splice_resize(i, n)
      end
    else
      for n = 1, 8 do
        splice_reset(i, n)
      end
    end
    render_splice()
  end)
  page_redraw(vTAPE)
end


--------------------- SNAPSHOTS -----------------------

snapshot_mode = false
snapshot_playback = false
snapshot_cut = false
snap = {}
for i = 1, 8 do -- 8 snapshot slots
  snap[i] = {}
  snap[i].data = false
  snap[i].active = false
  snap[i].play = {}
  snap[i].mute = {}
  snap[i].loop = {}
  snap[i].loop_start = {}
  snap[i].loop_end = {}
  snap[i].cut = {}
  snap[i].speed = {}
  snap[i].rev = {}
  snap[i].transpose_val = {}
  for j = 1, 6 do -- 6 tracks
    snap[i].play[j] = 0
    snap[i].mute[j] = 0
    snap[i].loop[j] = 0
    snap[i].loop_start[j] = 1
    snap[i].loop_end[j] = 16
    snap[i].cut[j] = 1
    snap[i].speed[j] = 0
    snap[i].rev[j] = 0
    snap[i].transpose_val[j] = 8
  end
end

function save_snapshot(n)
  for i = 1, 6 do
    softcut.query_position(i)
    snap[n].play[i] = track[i].play
    snap[n].mute[i] = track[i].mute
    snap[n].loop[i] = track[i].loop
    snap[n].loop_start[i] = track[i].loop_start
    snap[n].loop_end[i] = track[i].loop_end
    snap[n].speed[i] = track[i].speed
    snap[n].rev[i] = track[i].rev
    snap[n].transpose_val[i] = params:get(i.."transpose")
    clock.run(
      function()
        clock.sleep(0.05) -- give get_pos() some time
        snap[n].cut[i] = track[i].cut
      end
    )
  end
  snap[n].data = true
end

function load_snapshots(snapshot)
  for track = 1, 6 do
    load_snapshot(snapshot, track)
  end
end

function load_snapshot(n, i)
  local e = {} e.t = eMUTE e.i = i e.mute = snap[n].mute[i] event(e)
  local e = {} e.t = eREV e.i = i e.rev = snap[n].rev[i] event(e)
  local e = {} e.t = eSPEED e.i = i e.speed = snap[n].speed[i] event(e)
  local e = {} e.t = eTRSP e.i = i e.val = snap[n].transpose_val[i] event(e)
  if snap[n].loop[i] == 1 then
    loop_event(i, snap[n].loop_start[i], snap[n].loop_end[i])
  elseif snap[n].loop[i] == 0 then
    local e = {} e.t = eUNLOOP e.i = i event(e)
  end
  if snapshot_playback then
    if snap[n].play[i] == 0 then
      local e = {} e.t = eSTOP e.i = i event(e)
    else
      if snapshot_cut then track[i].cut = snap[n].cut[i] end
      local e = {} e.t = eSTART e.i = i event(e)
    end
  end
end


--------------------- SOFTCUT FUNCTIONS -----------------------

function toggle_rec(i) -- toggle recording and trigger chop function
  track[i].rec = 1 - track[i].rec
  set_rec(i)
  if track[i].rec == 1 then chop(i) end
  grid_page(vREC)
end

function set_rec(i) -- set softcut rec and pre levels
  if track[i].fade == 0 then
    if track[i].rec == 1 and track[i].play == 1 then
      softcut.pre_level(i, track[i].pre_level)
      softcut.rec_level(i, track[i].rec_level)
    else
      softcut.pre_level(i, 1)
      softcut.rec_level(i, 0)
    end
  elseif track[i].fade == 1 then
    if track[i].rec == 1 and track[i].play == 1 then
      softcut.pre_level(i, track[i].pre_level)
      softcut.rec_level(i, track[i].rec_level)
    else
      softcut.pre_level(i, track[i].pre_level)
      softcut.rec_level(i, 0)
    end
  end
  page_redraw(vMAIN, 2)
end

function set_level(i) -- set track volume and mute track
  if track[i].mute == 0 and track[i].play == 1 then
    softcut.level(i, track[i].level)
    set_track_sends(i)
  else
    softcut.level(i, 0)
    softcut.level_cut_cut(i, 5, 0)
    softcut.level_cut_cut(i, 6, 0)
  end
  page_redraw(vMAIN, 1)
end

function set_track_sends(i) -- internal softcut routing
  if track[i].t5 == 1 and track[i].play == 1 then
    softcut.level_cut_cut(i, 5, track[i].send_t5 * track[i].level)
  else
    softcut.level_cut_cut(i, 5, 0)
  end
  if track[i].t6 == 1 and track[i].play == 1 then
    softcut.level_cut_cut(i, 6, track[i].send_t6 * track[i].level)
  else
    softcut.level_cut_cut(i, 6, 0)
  end
end

function get_pos(i, pos) -- get and store softcut position (callback)
  track[i].cut = pos
  if track[i].play_mode == 2 then
    if track[i].rev == 0 and track[i].pos_hi_res == 64 then
      track[i].cut = clip[i].s
      track[i].pos_arc = 1
    elseif track[i].rev == 1 and track[i].pos_hi_res == 1 then
      track[i].cut = clip[i].e
      track[i].pos_arc = 64
    end
  end
end

function stop_track(i)
  softcut.query_position(i)
  track[i].play = 0
  trig[i].tick = 0
  set_level(i)
  set_rec(i)
  dirtygrid = true
end

function make_loop(i, lstart, lend)
  track[i].loop = 1
  track[i].loop_start = lstart
  track[i].loop_end = lend
  local s = clip[i].s + (lstart - 1) / 16 * clip[i].l
  local e = clip[i].s + (lend) / 16 * clip[i].l
  softcut.loop_start(i, s)
  softcut.loop_end(i, e)
  enc2_wait = false
  dirtygrid = true
end

function clear_loop(i)
  track[i].loop = 0
  softcut.loop_start(i, clip[i].s) 
  softcut.loop_end(i, clip[i].e)
end

function copy_buffer(i, src, dst) -- copy splice to the other buffer
  local n = track[i].splice_focus
  softcut.buffer_copy_mono(src, dst, tape[i].splice[n].s, tape[i].splice[n].s, tape[i].splice[n].l, 0.01)
  local dst_name = dst == 1 and "main" or "temp"
  show_message("splice   copied   to   "..dst_name.."   buffer")
end

function set_track_source(option) -- select audio source
  audio.level_adc_cut(option == 3 and 0 or 1)
  audio.level_eng_cut(option == 2 and 0 or 1)
  audio.level_tape_cut(option == 1 and 0 or 1)
end

function set_softcut_input(i) -- select softcut input
  if tape[i].input == 1 then -- L&R
    softcut.level_input_cut(1, i, 0.707)
    softcut.level_input_cut(2, i, 0.707)
  elseif tape[i].input == 2 then -- L IN
    softcut.level_input_cut(1, i, 1)
    softcut.level_input_cut(2, i, 0)
 elseif tape[i].input == 3 then -- R IN
    softcut.level_input_cut(1, i, 0)
    softcut.level_input_cut(2, i, 1)
 elseif tape[i].input == 4 then -- OFF
    softcut.level_input_cut(1, i, 0)
    softcut.level_input_cut(2, i, 0)
  end
end

function filter_select(i, option)
  softcut.post_filter_lp(i, option == 1 and 1 or 0) 
  softcut.post_filter_hp(i, option == 2 and 1 or 0) 
  softcut.post_filter_bp(i, option == 3 and 1 or 0) 
  softcut.post_filter_br(i, option == 4 and 1 or 0)
  softcut.post_filter_dry(i, option == 5 and 1 or track[i].dry_level)
end

function phase_poll(i, pos)
  -- calc softcut positon
  local pp = ((pos - clip[i].s) / clip[i].l)
  local pc = ((pos - tape[i].s) / MAX_TAPELENGTH)
  local g_pos = math.floor(pp * 16)
  local a_pos = math.floor(pp * 64)
  -- calc positions
  track[i].pos_abs = pos -- absoulute position on buffer
  track[i].pos_hi_res = util.clamp(a_pos + 1 % 64, 1, 64) -- fine mesh for arc
  track[i].pos_lo_res = util.clamp(g_pos + 1 % 16, 1, 16) -- coarse mesh for grid
  if track[i].play == 1 then
    if track[i].pos_lo_res ~= track[i].pos_grid then
      track[i].pos_grid = track[i].pos_lo_res
    end
    if track[i].pos_arc ~= track[i].pos_hi_res then
      track[i].pos_arc = track[i].pos_hi_res
    end
    if track[i].pos_rel ~= pp then
      track[i].pos_rel = pp -- relative position within clip
    end
    if track[i].pos_clip ~= pc then
      track[i].pos_clip = pc -- relative position within allocated buffer space
    end
    -- display position
    grid_page(vLFO)
    grid_page(vTAPE)
    if (grido_view < vLFO or grido_view == vTAPE) then
      dirtygrid = true
    end
    if (gridz_view < vLFO or gridz_view == vTAPE) then
      dirtygrid = true
    end
    page_redraw(vTAPE)
  end
  -- oneshot play_mode
  if track[i].play_mode == 2 and track[i].loop == 0 and track[i].play == 1 then
    if track[i].rev == 0 then
      if track[i].pos_hi_res == 64 then
        stop_track(i)
      end
    else
      if track[i].pos_hi_res == 1 then
        stop_track(i)
      end
    end
  end
  -- randomize at cycle
  if autorand_at_cycle and track[i].sel == 1 and not oneshot_rec then
    if track[i].play == 1 then
      track[i].step_count = track[i].step_count + 1
      if track[i].step_count > rnd_stepcount * 4 then
        randomize(i)
      end
    end
  end
  -- track 2 trigger
  if track[i].play == 1 then
    -- rec @step
    if trig[i].rec_step > 0 then
      if track[i].rev == 0 then
        if track[i].pos_hi_res == trig[i].rec_step * 4 - 3 then
          toggle_rec(i)
        end
      else
        if track[i].pos_hi_res == trig[i].rec_step * 4 then
          toggle_rec(i)
        end
      end
    end
    -- trig @step mode
    if trig[i].step > 0 then
      if track[i].rev == 0 then
        if track[i].pos_hi_res == trig[i].step * 4 - 3 then
          send_trig(i)
        end
      else
        if track[i].pos_hi_res == trig[i].step * 4 then
          send_trig(i)
        end
      end
    end
    -- trig @count mode
    if trig[i].count > 0 then
      trig[i].tick = trig[i].tick + 1 -- count steps
      if trig[i].tick >= trig[i].count * 4 then
        send_trig(i)
        trig[i].tick = 0
      end
    end
  end
end

function update_rate(i)
  local n = math.pow(2, track[i].speed + track[i].transpose + track[i].detune)
  if track[i].rev == 1 then n = -n end
  if track[i].tempo_map == 2 then
    local bpmmod = clock.get_tempo() / clip[i].bpm
    n = n * bpmmod
  end
  softcut.rate(i, n)
end


--------------------- WAVEFORM VIZ -----------------------
waveform_samples = {}
wave_gain = {}
for i = 1, 6 do
  waveform_samples[i] = {}
  wave_gain[i] = {}
end
view_buffer = false

function wave_render(ch, start, i, s)
  waveform_samples[track_focus] = {}
  waveform_samples[track_focus] = s
  waveviz_reel = false
  wave_gain[track_focus] = wave_getmax(waveform_samples[track_focus])
  dirtyscreen = true
end

function wave_getmax(t)
  local max = 0
  for _,v in pairs(t) do
    if math.abs(v) > max then
      max = math.abs(v)
    end
  end
  return util.clamp(max, 0.4, 1)
end

function render_splice()
  if view == vTAPE and not (view_splice_info or view_presets) then 
    if view_buffer then
      local start = tape[track_focus].s
      local length = tape[track_focus].e - tape[track_focus].s
      local buffer = tape[track_focus].side
      softcut.render_buffer(buffer, start, length, 128)
    else
      local n = track[track_focus].splice_focus
      local start = tape[track_focus].splice[n].s
      local length = tape[track_focus].splice[n].e - tape[track_focus].splice[n].s
      local buffer = tape[track_focus].side
      softcut.render_buffer(buffer, start, length, 128)
    end
  end
end


--------------------- SCALE AND TRANSPOSITION -----------------------
function set_scale(option) -- set scale id, thanks zebra
  current_scale = option
  for i = 1, 6 do
    local p = params:lookup_param(i.."transpose")
    p.options = scales.id[option]
    p:bang()
  end
  page_redraw(vMAIN, 5)
end

function set_transpose(i, x) -- transpose track
  track[i].transpose = scales.val[current_scale][x] / 1200
  update_rate(i)
  page_redraw(vMAIN, 5)
  grid_page(vCUT)
  grid_page(vTRSP)
end


--------------------- TRANSPORT FUNCTIONS -----------------------

function toggle_playback(i)
  if track[i].play == 1 then
    local e = {t = eSTOP, i = i} event(e)
  else
    if track[i].start_launch == 1 then
      local e = {t = eSTART, i = i} event(e)
    else
      clock.run(function()
        local beats = track[i].start_launch == 2 and 1 or 4
        local cut = track[i].rev == 0 and 0 or 15
        clock.sync(beats)
        local e = {} e.t = eCUT e.i = i e.pos = cut e.sync = true event(e)
      end)
    end
  end
end



function toggle_transport()
  if transport_run == false then
    if params:get("midi_trnsp") == 2 then
      m:start()
    end
    if params:get("clock_source") == 1 then
      --clock.internal.start()
    end
    transport_run = true
  end
end

function startall() -- start all tracks at the beginning
  for i = 1, 6 do
    if track[i].rev == 0 then
      local e = {} e.t = eCUT e.i = i e.pos = 0 event(e)
    elseif track[i].rev == 1 then
      local e = {} e.t = eCUT e.i = i e.pos = 15 event(e)
    end
  end
  if params:get("midi_trnsp") == 2 and not transport_run then
    m:start()
  end
end

function stopall() -- stop all tracks and patterns / send midi stop if midi transport on
  for i = 1, 6 do
    local e = {} e.t = eSTOP e.i = i
    event(e)
  end
  for i = 1, 8 do
    pattern[i]:stop()
  end
  if params:get("midi_trnsp") == 2 then
    m:stop()
  end
  transport_run = false
end

function altrun() -- alt run function for selected tracks
  for i = 1, 6 do
    if track[i].sel == 1 then
      if track[i].play == 1 then
        local e = {} e.t = eSTOP e.i = i event(e)
      elseif track[i].play == 0 then
        local e = {} e.t = eSTART e.i = i event(e)
      end
    end
  end
end

function retrig() -- retrig function for playing tracks
  for i = 1, 6 do
    if track[i].play == 1 then
      if track[i].rev == 0 then
        local e = {} e.t = eCUT e.i = i e.pos = 0 event(e)
      elseif track[i].rev == 1 then
        local e = {} e.t = eCUT e.i = i e.pos = 15 event(e)
      end
    end
  end
end


--------------------- ONESHOT RECORDING -----------------------

function arm_thresh_rec(i) -- start poll if oneshot == 1
  if track[i].oneshot == 1 then
    amp_in[1]:start()
    amp_in[2]:start()
  else
    amp_in[1]:stop()
    amp_in[2]:stop()
  end
  if track[i].play == 0 then
    if track[i].rev == 0 then
      track[i].pos_arc = 1
      track[i].pos_grid = 1
    else
      track[i].pos_arc = 64
      track[i].pos_grid = 16
    end
  end
end

function rec_at_threshold() -- start rec when threshold is reached
  if track[armed_track].oneshot == 1 then
    track[armed_track].rec = 1
    set_rec(armed_track)
    rec_dur = 0
    if track[armed_track].play == 0 then
      if track[armed_track].rev == 0 then
        local e = {} e.t = eCUT e.i = armed_track e.pos = 0 event(e)
      elseif track[armed_track].rev == 1 then
        local e = {} e.t = eCUT e.i = armed_track e.pos = 15 event(e)
      end
    end
  end
end

function update_dur(i) -- calculate duration of length when oneshot == 1
  oneshot_rec = false
  if track[i].oneshot == 1 then
    if track[i].tempo_map == 2 then
      track[i].dur = ((beat_sec * clip[i].l) / math.pow(2, track[i].speed + track[i].transpose + track[i].detune)) * (clip[i].bpm / 60)
    else
      track[i].dur = clip[i].l / math.pow(2, track[i].speed + track[i].transpose + track[i].detune)
    end
    if track[i].loop == 1 and track[i].play == 1 then
      local len = track[i].loop_end - track[i].loop_start + 1
      track[i].dur = (track[i].dur / 16) * len
    end
  end
end

function oneshot(dur) -- called by clock coroutine at threshold
  clock.sleep(dur) -- length of rec time specified by 'track[i].dur'
  if track[armed_track].oneshot == 1 then
    track[armed_track].rec = 0
    track[armed_track].oneshot = 0
  end
  set_rec(armed_track)
  tracktimer:stop()
  oneshot_rec = false
end

function count_length()
  rec_dur = rec_dur + 1
end

function loop_point() -- set loop start point (loop_pos) for chop function
  if track[armed_track].oneshot == 1 then
    if track[armed_track].rev == 1 then
      if track[armed_track].pos_grid == 16 then
        loop_pos = 16
      else
        loop_pos = track[armed_track].pos_grid
      end
    else
      if track[armed_track].pos_grid == 1 then
        loop_pos = 1
      else
        loop_pos = track[armed_track].pos_grid
      end
    end
  end
end

function chop(i) -- called when rec key is pressed
  if oneshot_rec == true and track[i].oneshot == 1 then
    if not autolength then -- set-loop mode
      local lstart = math.min(loop_pos, track[i].pos_grid)
      local lend = math.max(loop_pos, track[i].pos_grid)
      loop_event(i, lstart, lend)
      track[i].oneshot = 0
    else -- autolength mode
      -- get length of recording and stop timer
      local length = rec_dur / 100
      tracktimer:stop()
      -- set splice markers
      tape[i].splice[track[i].splice_active].l = length
      tape[i].splice[track[i].splice_active].e = tape[i].splice[track[i].splice_active].s + length
      tape[i].splice[track[i].splice_active].init_start = tape[i].splice[track[i].splice_active].s
      tape[i].splice[track[i].splice_active].init_len = length
      tape[i].splice[track[i].splice_active].beatnum = get_beatnum(length)
      tape[i].splice[track[i].splice_active].bpm = 60 / length * get_beatnum(length)
      -- set clip
      set_clip(i)
      set_info(i, track[i].splice_active)
      track[i].oneshot = 0
      autolength = false
    end
    oneshot_rec = false
  end
end


--------------------- LFOS -----------------------

NUM_LFOS = 6
lfo_destination = {"volume", "pan", "dub level", "transpose", "detune", "rate slew", "cutoff"}
lfo_params = {"vol", "pan", "dub", "transpose", "detune", "rate_slew", "cutoff"}
lfo_min = {0, -1, 0, 1, -600, 0, 20}
lfo_max = {1, 1, 1, 15, 600, 1, 18000}
lfo_baseline = {'min', 'center', 'min', 'center', 'center', 'min', 'max'}
lfo_baseline_options = {'min', 'center', 'max'}

function init_lfos()
  lfo = {}
  for i = 1, NUM_LFOS do
    --function LFO.new(shape, min, max, depth, mode, period, action, phase, baseline, callback)  
    lfo[i] = _lfo.new(
     'sine', -- shape
      0, -- min
      1, -- max
      0, -- depth
      'clocked', -- mode
      1/2, -- period
      function(scaled, raw) end, -- action
      0, --phase
      'min', --baseline
      function(enabled) end -- state_callback
    )
    lfo[i]:add_params("lfo_"..i, nil, "lfo "..i)
    lfo[i].track = nil
    lfo[i].destination = nil
    lfo[i].slope = 0
    lfo[i].info = 'unassigned'
  end
end

function set_lfo(i, track, destination)
  if destination == 'none' then
    params:set("lfo_lfo_"..i, 1)
    lfo[i].track = nil
    lfo[i].destination = nil
    lfo[i].prev_val = nil
    lfo[i].slope = 0
    lfo[i].info = 'unassigned'
    lfo[i]:set('action', function(scaled, raw) end)
  else
    local n = tab.key(lfo_params, destination)
    lfo[i].info = 'T'..track..'    '..lfo_destination[n]
    lfo[i].track = track
    lfo[i].destination = destination
    lfo[i].prev_val = nil
    params:lookup_param("lfo_min_lfo_"..i).controlspec.minval = lfo_min[n]
    params:lookup_param("lfo_min_lfo_"..i).controlspec.maxval = lfo_max[n]
    params:lookup_param("lfo_max_lfo_"..i).controlspec.minval = lfo_min[n]
    params:lookup_param("lfo_max_lfo_"..i).controlspec.maxval = lfo_max[n]
    params:lookup_param("lfo_min_lfo_"..i):bang()
    params:lookup_param("lfo_max_lfo_"..i):bang()
    params:set("lfo_min_lfo_"..i, lfo_min[n])
    params:set("lfo_max_lfo_"..i, lfo_max[n])
    params:set("lfo_baseline_lfo_"..i, tab.key(lfo_baseline_options, lfo_baseline[n]))
    lfo[i]:set('action', function(scaled, raw)
      params:set(track..lfo_params[n], scaled)
      lfo[i].slope = raw
      grid_page(vLFO)
    end)
    lfo[i]:set('state_callback', function(enabled)
      if not enabled and lfo[i].prev_val ~= nil then
        params:set(track..destination, lfo[i].prev_val)
      elseif enabled then
        lfo[i].prev_val = params:get(track..destination)
      end
    end)
  end
end


--------------------- ENVELOPES -----------------------

env = {}
for i = 1, 6 do
  env[i] = {}
  env[i].active = false
  env[i].gate = false
  env[i].trig = false
  env[i].attack = 0
  env[i].decay = 0
  env[i].sustain = 1
  env[i].release = 0
  env[i].a_is_running = false
  env[i].d_is_running = false
  env[i].r_is_running = false
  env[i].max_value = 1
  env[i].init_value = 0
  env[i].prev_value = 0
  env[i].count = 0
  env[i].direction = 0
  env[i].id = "env "..i
end

function env_gate_on(i)
  env_get_value(i)
  env[i].gate = true
  env[i].a_is_running = true
  env[i].count = 0
  env[i].direction = 1
  --print("gate on")
end

function env_gate_off(i)
  env_get_value(i)
  env[i].gate = false
  env[i].a_is_running = false
  env[i].d_is_running = false
  env[i].r_is_running = true
  env[i].count = 0
  env[i].direction = 1
  --print("gate off")
end

function env_increment(i, d)
  params:delta(i.."vol", d * 100)
  grid_page(vENV)
end

function env_set_value(i, val)
  params:set(i.."vol", val)
end

function env_get_value(i)
  env[i].prev_value = track[i].level
end

function env_stop(i)
  if track[i].play_mode == 3 then
    stop_track(i)
  end
  dirtygrid = true
end

--- make envelope
function env_run()
  while true do
    clock.sleep(1/10)
    for i = 1, 6 do
      env[i].count = env[i].count + env[i].direction
      if env[i].gate then
        if env[i].a_is_running then
          if env[i].attack == 0 then
            env_set_value(i, env[i].max_value)
            env_get_value(i)
            env[i].count = 0
            env[i].a_is_running = false
            env[i].d_is_running = true
          else
            local d = (env[i].max_value - env[i].prev_value) / env[i].attack
            env_increment(i, d)
            if env[i].count >= env[i].attack then
              env_get_value(i)
              env[i].count = 0
              env[i].a_is_running = false
              env[i].d_is_running = true
            end
          end
        end
        if env[i].d_is_running then
          if env[i].decay == 0 then
            env[i].direction = 0
            env[i].count = 0
            env[i].d_is_running = false
            env_set_value(i, env[i].sustain)
            env_get_value(i)
          else
            local d = -(env[i].prev_value - env[i].sustain) / env[i].decay
            env_increment(i, d)
            if env[i].count >= env[i].decay then
              env[i].direction = 0
              env[i].count = 0
              env[i].d_is_running = false
              env_set_value(i, env[i].sustain)
              env_get_value(i)
            end
          end
        end
      else
        if env[i].r_is_running then
          if env[i].release == 0 then
            env[i].direction = 0
            env[i].count = 0
            env[i].r_is_running = false
            env_set_value(i, env[i].init_value)
            env_stop(i)
          else
            local d = -(env[i].prev_value - env[i].init_value) / env[i].release
            env_increment(i, d)
            if env[i].count >= env[i].release then
              env[i].direction = 0
              env[i].count = 0
              env[i].r_is_running = false
              env[i].trig = false
              env_set_value(i, env[i].init_value)
              env_stop(i)
            end
          end
        end
      end
    end
  end
end

function init_envelope(i)
  if env[i].active then
    track[i].prev_level = track[i].level
    params:set(i.."vol", env[i].init_value)
  else
    env[i].gate = false
    env[i].a_is_running = false
    env[i].d_is_running = false
    env[i].r_is_running = false
    env[i].count = 0
    env[i].direction = 1
    params:set(i.."vol", track[i].prev_level)
  end
  grid_page(vENV)
end

function clamp_env_levels(i)
  if env[i].init_value >= env[i].max_value then
    params:set(i.."adsr_init", env[i].max_value)
  end
  if env[i].sustain >= env[i].max_value then
    params:set(i.."adsr_sustain", env[i].max_value)
  end
  if env[i].init_value >= env[i].sustain then
    params:set(i.."adsr_sustain", env[i].init_value)
  end
end


--------------------- TAPE WARBLE -----------------------

warble = {}
for i = 1, 6 do
  warble[i] = {}
  warble[i].active = false
  warble[i].freq = 8
  warble[i].counter = 1
  warble[i].slope = 0
  warble[i].amount = 0
  warble[i].depth = 0
end

function make_warble() -- warbletimer function
  for i = 1, 6 do
    -- make sine (from hnds)
    local slope = 1 * math.sin(((tau / 100) * (warble[i].counter)) - (tau / (warble[i].freq)))
    warble[i].slope = util.linlin(-1, 1, -1, 0, math.max(-1, math.min(1, slope))) * warble[i].depth
    warble[i].counter = warble[i].counter + warble[i].freq
    -- activate warble
    if track[i].warble == 1 and track[i].play == 1 and math.random(100) <= warble[i].amount then
      if not warble[i].active then
        warble[i].active = true
      end
    end
    -- make warble
    if warble[i].active then
      local n = math.pow(2, track[i].speed + track[i].transpose + track[i].detune)
      if track[i].rev == 1 then n = -n end
      if track[i].tempo_map == 2 then
        local bpmmod = clock.get_tempo() / clip[i].bpm
        n = n * bpmmod
      end
      local warble_rate = n * (1 + warble[i].slope)
      softcut.rate(i, warble_rate)
    end
    -- stop warble
    if warble[i].active and warble[i].slope > -0.001 then -- nearest value to zero
      warble[i].active = false
      update_rate(i) -- reset rate
    end
  end
end


--------------------- MIDI / CROW TRIGS -----------------------

trig = {}
for i = 1, 6 do
  trig[i] = {}
  trig[i].tick = 0
  trig[i].step = 0
  trig[i].count = 0
  trig[i].rec_step = 0
  trig[i].out = 1
  trig[i].amp = 8
  trig[i].env_a = 0
  trig[i].env_d = 1
  trig[i].active_notes = {}
  trig[i].midi_note = 48
  trig[i].midi_ch = 1
  trig[i].midi_vel = 100
end

midi_devices = {}
function build_midi_device_list()
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function midi_connected()
  build_midi_device_list()
end

function midi_disconnected()
  clock.run(
    function()
      clock.sleep(0.2)
      build_midi_device_list()
    end
  )
end

function send_trig(i)
  if trig[i].out > 1 and trig[i].out < 6 then
    local ch = trig[i].out - 1
    crow.output[ch].action = "{ to(0, 0), to("..trig[i].amp..", "..trig[i].env_a.."), to(0, "..trig[i].env_d..", 'lin') }"
    crow.output[ch]()
  elseif trig[i].out == 6 then
    m:note_on(trig[i].midi_note, trig[i].midi_vel, trig[i].midi_ch)
    table.insert(trig[i].active_notes, trig[i].midi_note)
    clock.run(function()
      clock.sleep(0.2)
      m:note_off(trig[i].midi_note, nil, trig[i].midi_ch)
    end)
  end
end

--------------------- CLOCK CALLBACKS -----------------------

function clock.tempo_change_handler(tempo)
  for i = 1, 6 do
    if track[i].tempo_map > 0 then
      for j = 1, 8 do
        splice_resize(i, j) -- resize clip according to tempo settings
      end
    end
  end
  for i = 1, 8 do
    if pattern[i].tempo_map == true and pattern[i].bpm ~= nil then -- pattern tempo map default set to true.
      pattern[i].time_factor = pattern[i].bpm / tempo
    end
  end
  render_splice()
  beat_sec = 60 / params:get("clock_tempo")
end

function clock.transport.start()
  if params:get("midi_trnsp") == 3 then
    local count_in = params:get("clock_source") == 3 and params:get("link_quantum") or 4
    clock.run(function()
      clock.sync(count_in)
      startall()
    end)
  end
end

function clock.transport.stop()
  if params:get("midi_trnsp") == 3 then
    stopall()
  end
end


--------------------- CLOCK COROUTINES -----------------------

function ledpulse_fast()
  pulse_key_fast = pulse_key_fast == 8 and 12 or 8
  for i = 1, 8 do
    if (pattern[i].rec == 1 or pattern[i].overdub == 1) then
      dirtygrid = true
    end
  end
  for i = 1, 6 do
    if track[i].oneshot == 1 then
      dirtygrid = true
    end
  end
end

function ledpulse_mid()
  pulse_key_mid = util.wrap(pulse_key_mid + 1, 4, 12)
  if view_presets then
    dirtyscreen = true
  end
end

function ledpulse_slow()
  pulse_key_slow = util.wrap(pulse_key_slow + 1, 4, 12)
  for i = 1, 6 do
    if ((track[i].mute and view == vREC) or (not track[i].loaded and view == vTAPE)) or view == vENV then
      dirtygrid = true
    end
  end
end

function ledpulse_bar()
  while true do
    clock.sync(4)
    pulse_bar = true
    dirtygrid = true
    clock.run(function()
      clock.sleep(1/30)
      pulse_bar = false
      dirtygrid = true
    end)
  end
end

function ledpulse_beat()
  while true do
    clock.sync(1)
    pulse_beat = true
    dirtygrid = true
    clock.run(
      function()
        clock.sleep(1/30)
        pulse_beat = false
        dirtygrid = true
      end
    )
  end
end

function track_reset()
  while true do
    clock.sync(1)
    for i = 1, 6 do
      if track[i].reset and track[i].play == 1 then
        track[i].beat_count = track[i].beat_count + 1
        if track[i].beat_count >= track[i].beat_reset then
          if track[i].loop == 0 then
            local cut = track[i].rev == 0 and clip[i].s or (clip[i].l + clip[i].s)
            softcut.position(i, cut)
          else
            local lstart = clip[i].s + (track[i].loop_start - 1) / 16 * clip[i].l
            local lend = clip[i].s + (track[i].loop_end) / 16 * clip[i].l
            local cut = track[i].rev == 0 and lstart or lend
            softcut.position(i, cut)
          end
          track[i].beat_count = 0
        end
      end
    end
  end
end


--------------------- FILE CALLBACKS -----------------------

function fileselect_callback(path, i)
  if path ~= "cancel" and path ~= "" then
    local ch, len = audio.file_info(path)
    local buffer = tape[i].side
    if ch > 0 and len > 0 then
      softcut.buffer_read_mono(path, 0, tape[i].splice[track[i].splice_focus].s, -1, 1, buffer)
      local max_length = tape[i].e - tape[i].splice[track[i].splice_focus].s
      local length = math.min(len / 48000, max_length)
      -- set splice   
      tape[i].splice[track[i].splice_focus].l = length
      tape[i].splice[track[i].splice_focus].e = tape[i].splice[track[i].splice_focus].s + length
      tape[i].splice[track[i].splice_focus].init_start = tape[i].splice[track[i].splice_focus].s
      tape[i].splice[track[i].splice_focus].init_len = length
      tape[i].splice[track[i].splice_focus].init_beatnum = get_beatnum(length)
      tape[i].splice[track[i].splice_focus].beatnum = get_beatnum(length)
      tape[i].splice[track[i].splice_focus].bpm = 60 / length * get_beatnum(length)
      tape[i].splice[track[i].splice_focus].name = path:match("[^/]*$")
      if track[i].splice_focus == track[i].splice_active then  
        set_clip(i)
      end
      set_info(i, track[i].splice_focus)
      print("file: "..path.." "..tape[i].splice[track[i].splice_focus].s.."s to "..tape[i].splice[track[i].splice_focus].s + length.."s")
    else
      print("not a sound file")
    end
  end
  screenredrawtimer:start()
  render_splice()
  dirtyscreen = true
  dirtygrid = true
end

function filesave_callback(txt)
  if txt then
    local start = tape[track_focus].splice[track[track_focus].splice_focus].s
    local length = tape[track_focus].splice[track[track_focus].splice_focus].l
    local buffer = tape[track_focus].side
    util.make_dir(_path.audio .. "mlre")
    softcut.buffer_write_mono(_path.audio.."mlre/"..txt..".wav", start, length, buffer)
    tape[track_focus].splice[track[track_focus].splice_focus].name = txt
    print("saved " .. _path.audio .. "mlre/" .. txt .. ".wav", start, length)
  else
    print("save cancel")
  end
  screenredrawtimer:start()
  dirtyscreen = true
end


--------------------- PSET MANAGEMENT -----------------------

function build_pset_list()
  local files_data = util.scandir(norns.state.data)
  pset_list = {}
  for i = 1, #files_data do
    if files_data[i]:match("^.+(%..+)$") == ".pset" then
      local loaded_file = io.open(norns.state.data..files_data[i], "r")
      if loaded_file then
        io.input(loaded_file)
        local pset_name = string.sub(io.read(), 4, -1)
        table.insert(pset_list, pset_name)
        io.close(loaded_file)
      end
    end
  end
end

function get_pset_num(name)
  local files_data = util.scandir(norns.state.data)
  for i = 1, #files_data do
    if files_data[i]:match("^.+(%..+)$") == ".pset" then
      local loaded_file = io.open(norns.state.data..files_data[i], "r")
      if loaded_file then
        io.input(loaded_file)
        local pset_id = string.sub(io.read(), 4, -1)
        if name == pset_id then
          local filename = norns.state.data..files_data[i]
          local pset_string = string.sub(filename, string.len(filename) - 6, -1)
          local number = pset_string:gsub(".pset", "")
          return util.round(number, 1) -- better to use tonumber?
        end
        io.close(loaded_file)
      end
    end
  end
end

function load_patterns()
  for i = 1, 8 do
    -- stop patterns
    pattern[i]:rec_stop()
    pattern[i]:set_overdub(0)
    pattern[i]:stop()
    -- load patterns
    pattern[i].count = loaded_sesh_data[i].pattern_count
    pattern[i].time = {table.unpack(loaded_sesh_data[i].pattern_time)}
    pattern[i].event = {table.unpack(loaded_sesh_data[i].pattern_event)}
    pattern[i].time_factor = loaded_sesh_data[i].pattern_time_factor
    pattern[i].synced = loaded_sesh_data[i].pattern_synced
    params:set("patterns_meter"..i, loaded_sesh_data[i].pattern_sync_meter)
    params:set("patterns_barnum"..i, loaded_sesh_data[i].pattern_sync_beatnum)
    params:set("patterns_playback"..i, loaded_sesh_data[i].pattern_loop)
    params:set("patterns_countin"..i, loaded_sesh_data[i].pattern_count_in)
    pattern[i].bpm = loaded_sesh_data[i].pattern_bpm
    pattern[i].tempo_map = loaded_sesh_data[i].pattern_tempo_map
    if pattern[i].tempo_map and pattern[i].bpm ~= nil then
      local newfactor = pattern[i].bpm / clock.get_tempo()
      pattern[i].time_factor = newfactor
    end
    -- recall
    recall[i].has_data = loaded_sesh_data[i].recall_has_data
    recall[i].event = {table.unpack(loaded_sesh_data[i].recall_event)}
    -- snapshots
    snap[i].data = loaded_sesh_data[i].snap_data
    snap[i].active = loaded_sesh_data[i].snap_active
    snap[i].play = {table.unpack(loaded_sesh_data[i].snap_play)}
    snap[i].mute = {table.unpack(loaded_sesh_data[i].snap_mute)}
    snap[i].loop = {table.unpack(loaded_sesh_data[i].snap_loop)}
    snap[i].loop_start = {table.unpack(loaded_sesh_data[i].snap_loop_start)}
    snap[i].loop_end = {table.unpack(loaded_sesh_data[i].snap_loop_end)}
    snap[i].cut = {table.unpack(loaded_sesh_data[i].snap_pos_grid)}
    snap[i].speed = {table.unpack(loaded_sesh_data[i].snap_speed)}
    snap[i].rev = {table.unpack(loaded_sesh_data[i].snap_rev)}
    snap[i].transpose_val = {table.unpack(loaded_sesh_data[i].snap_transpose_val)}
  end
end

function silent_load(number, pset_id)
  -- load sesh data file
  loaded_sesh_data = {}
  loaded_sesh_data = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")
  if loaded_sesh_data then
    -- load audio to temp buffer
    softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 2)
    -- load pattern, recall and snapshot data
    load_patterns()
    -- flip load state and load stopped tracks
    for i = 1, 6 do
      track[i].loaded = false
      if track[i].play == 0 then load_track_tape(i) end
    end
    clock.run(function() clock.sleep(0.1) render_splice() end)
    dirtygrid = true
  else
    print("error: no data loaded")
  end
end

function load_track_tape(i)
  -- tape data
  tape[i].s = loaded_sesh_data[i].tape_s
  tape[i].e  = loaded_sesh_data[i].tape_e
  tape[i].splice = {table.unpack(loaded_sesh_data[i].tape_splice)}
  -- track audio
  softcut.buffer_copy_mono(2, 1, tape[i].s, tape[i].s, MAX_TAPELENGTH, 0.01)
  -- track data
  track[i].loaded = true
  track[i].splice_active = 1
  track[i].splice_focus = 1
  track[i].sel = loaded_sesh_data[i].track_sel
  track[i].fade = loaded_sesh_data[i].track_fade
  track[i].warble = loaded_sesh_data[i].track_warble
  track[i].loop = 0
  track[i].loop_start = loaded_sesh_data[i].track_loop_start
  track[i].loop_end = loaded_sesh_data[i].track_loop_end
  track[i].speed = 0
  params:set(i.."transpose", 8)
  params:set(i.."tempo_map_mode", loaded_sesh_data[i].track_tempo_map)
  set_tempo_map(i)
  -- route data
  params:set(i.."send_track5", loaded_sesh_data[i].route_t5)
  params:set(i.."send_track6", loaded_sesh_data[i].route_t6)
  -- set levels
  set_level(i)
  set_rec(i)
  -- clear temp track
  softcut.buffer_clear_region_channel(2, tape[i].s - 0.5, MAX_TAPELENGTH + TAPE_GAP, 0.01, 0)
  show_message("track   loaded")
end


--------------------- INIIIIIIIT -----------------------
function init()
  -- establish grid size
  if g.device then
    GRID_SIZE = g.device.cols * g.device.rows
    if GRID_SIZE == 256 and rotate_grid then
      g:rotation(1) -- 1 is 90°
    end
  end
  -- make directory
  if util.file_exists(mlre_path) == false then
    util.make_dir(mlre_path)
  end
  -- build pset list
  build_pset_list()
  -- params for "globals"
  params:add_separator("global_params", "global")
  -- params for scales
  params:add_option("scale", "scale", scales.options, 1)
  params:set_action("scale", function(option) set_scale(option) end)

  -- rec params
  params:add_group("rec_params", "recording", 3)
  -- rec source
  params:add_option("rec_source", "rec source", {"adc/eng", "adc/tape", "eng/tape", "adc/eng/tape"})
  params:set_action("rec_source", function(option) set_track_source(option) end)
  -- rec threshold
  params:add_control("rec_threshold", "rec threshold", controlspec.new(-40, 0, 'lin', 0.01, -12, "dB"))
  params:set_action("rec_threshold", function(val) amp_threshold = util.dbamp(val) / 10 end)
  -- rec slew
  params:add_control("rec_slew", "rec slew", controlspec.new(1, 10, 'lin', 0, 1, "ms"))
  params:set_action("rec_slew", function(val) for i = 1, 6 do softcut.recpre_slew_time(i, val * 0.001) end end)

  -- macro params
  params:add_group("macro_params", "macros", 3)
  -- event recording slots
  params:add_option("slot_assign", "macro slots", {"split", "patterns only", "recall only"}, 1)
  params:set_action("slot_assign", function(option) macro_slot_mode = option dirtygrid = true end)
  if GRID_SIZE == 256 then params:hide("slot_assign") end
  -- recall mode
  params:add_option("recall_mode", "recall mode", {"manual recall", "snapshot"}, 2)
  params:set_action("recall_mode", function(x) snapshot_mode = x == 2 and true or false dirtygrid = true end)
  -- snapshot option
  params:add_option("recall_playback_state", "playback state", {"ignore", "state only", "state & pos"}, 1)
  params:set_action("recall_playback_state", function(x)
    snapshot_playback = x > 1 and true or false
    snapshot_cut = x == 3 and true or false
    dirtygrid = true
  end)

  -- patterns params
  params:add_group("patterns", "patterns", 40)
  params:hide("patterns")
  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback"..i, "playback", pattern_playback, 1)
    params:set_action("patterns_playback"..i, function(mode) pattern[i].loop = mode == 1 and true or false end)

    params:add_option("patterns_countin"..i, "count in", pattern_countin, 2)
    params:set_action("patterns_countin"..i, function(mode) pattern[i].count_in = mode == 1 and 1 or 4 dirtygrid = true end)

    params:add_option("patterns_meter"..i, "meter", pattern_meter, 3)
    params:set_action("patterns_meter"..i, function(idx) pattern[i].sync_meter = pattern_meter_val[idx] end)

    params:add_number("patterns_barnum"..i, "length", 1, 32, 4, function(param) return param:get()..(pattern[i].sync_beatnum <= 4 and " bar" or " bars") end)
    params:set_action("patterns_barnum"..i, function(num) pattern[i].sync_beatnum = num * 4 dirtygrid = true end)
  end

  -- midi params
  params:add_group("midi_params", "midi settings", 2)
  -- midi device
  build_midi_device_list()
  params:add_option("global_midi_device", "midi out device", midi_devices, 1)
  params:set_action("global_midi_device", function(val) m = midi.connect(val) end)
  -- send midi transport
  params:add_option("midi_trnsp","midi transport", {"off", "send", "receive"}, 1)

  -- global track control
  params:add_group("track_control", "track control", 60)
  params:add_separator("global_track_control", "global control")
  -- start all
  params:add_binary("start_all", "start all", "trigger", 0)
  params:set_action("start_all", function() startall() end)
  -- stop all
  params:add_binary("stop_all", "stop all", "trigger", 0)
  params:set_action("stop_all", function() stopall() end)

  params:add_option("stopall_key", "stop all key", {"off", "on"}, 2)
  params:set_action("stopall_key", function(x) stop_all_active = x == 2 and true or false end)

  params:add_separator("control_focused_track", "focused track control")
  -- playback
  params:add_binary("track_focus_playback", "playback", "trigger", 0)
  params:set_action("track_focus_playback", function() toggle_playback(track_focus) end)
  -- mute
  params:add_binary("track_focus_mute", "mute", "trigger", 0)
  params:set_action("track_focus_mute", function() local i = track_focus local n = 1 - track[i].mute local e = {} e.t = eMUTE e.i = i e.mute = n event(e) end)
  -- record enable
  params:add_binary("rec_focus_enable", "record", "trigger", 0)
  params:set_action("rec_focus_enable", function() toggle_rec(track_focus) end)
  -- reverse
  params:add_binary("tog_focus_rev", "direction", "trigger", 0)
  params:set_action("tog_focus_rev", function() local i = track_focus local n = 1 - track[i].rev local e = {} e.t = eREV e.i = i e.rev = n event(e) end)
  -- speed +
  params:add_binary("inc_focus_speed", "speed +", "trigger", 0)
  params:set_action("inc_focus_speed", function() local i = track_focus local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e) end)
  -- speed -
  params:add_binary("dec_focus_speed", "speed -", "trigger", 0)
  params:set_action("dec_focus_speed", function() local i = track_focus local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e) end)
  -- randomize
  params:add_binary("focus_track_rand", "randomize", "trigger", 0)
  params:set_action("focus_track_rand", function() randomize(track_focus) end)

  for i = 1, 6 do
    -- track control
    params:add_separator("track_control_params"..i, "track "..i.." control")
    -- playback
    params:add_binary(i.."track_playback", "playback", "trigger", 0)
    params:set_action(i.."track_playback", function() toggle_playback(i) end)
    -- mute
    params:add_binary(i.."track_mute", "mute", "trigger", 0)
    params:set_action(i.."track_mute", function() local n = 1 - track[i].mute local e = {} e.t = eMUTE e.i = i e.mute = n event(e) end)
    -- record enable
    params:add_binary(i.."tog_rec", "record", "trigger", 0)
    params:set_action(i.."tog_rec", function() toggle_rec(i) end)
    -- reverse
    params:add_binary(i.."tog_rev", "reverse", "trigger", 0)
    params:set_action(i.."tog_rev", function() local n = 1 - track[i].rev local e = {} e.t = eREV e.i = i e.rev = n event(e) end)
    -- speed +
    params:add_binary(i.."inc_speed", "speed +", "trigger", 0)
    params:set_action(i.."inc_speed", function() local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e) end)
    -- speed -
    params:add_binary(i.."dec_speed", "speed -", "trigger", 0)
    params:set_action(i.."dec_speed", function() local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e) end)
    -- randomize
    params:add_binary(i.."track_rand", "randomize", "trigger", 0)
    params:set_action(i.."track_rand", function() randomize(i) end)    
  end

  -- randomize settings
  params:add_group("randomization_params", "randomization", 16)
  params:add_option("auto_rand_cycle","randomize @ step count", {"off", "on"}, 1)
  params:set_action("auto_rand_cycle", function(option) autorand_at_cycle = option == 2 and true or false end)
  params:add_number("rnd_step_count", ">> step count", 1, 128, 16)
  params:set_action("rnd_step_count", function(num) rnd_stepcount = num end)

  params:add_separator("randomize_track", "")
  params:add_option("rnd_transpose", "transpose", {"off", "on"}, 1)
  params:add_option("rnd_vol", "volume", {"off", "on"}, 1)
  params:add_option("rnd_pan", "pan", {"off", "on"}, 1)
  params:add_option("rnd_dir", "direction", {"off", "on"}, 2)
  params:add_option("rnd_loop", "loop", {"off", "on"}, 2)

  params:add_separator("randomize_speed", "")
  params:add_option("rnd_speed", "speed", {"off", "on"}, 2)
  params:add_number("rnd_uoct", "+ oct range", 0, 3, 2)
  params:add_number("rnd_loct", "- oct range", 0, 3, 2)

  params:add_separator("randomize_filter", "")
  params:add_option("rnd_cut", "cutoff", {"off", "on"}, 1)
  params:add_control("rnd_ucut", "upper freq", controlspec.new(20, 18000, 'exp', 1, 18000, "Hz"))
  params:add_control("rnd_lcut", "lower freq", controlspec.new(20, 18000, 'exp', 1, 20, "Hz"))

  -- arc settings
  params:add_group("arc_params", "arc settings", 5)
  params:add_option("arc_orientation", "arc orientation", {"horizontal", "vertical"}, 1)
  params:set_action("arc_orientation", function(val) arc_off = (val - 1) * 16 end)
  params:add_option("arc_enc_1_start", "enc1 > start", {"off", "on"}, 2)
  params:add_option("arc_enc_1_dir", "enc1 > direction", {"off", "on"}, 1)
  params:add_option("arc_enc_1_mod", "enc1 > mod", {"off", "warble", "scrub"}, 3)
  params:add_number("arc_srub_sens", "scrub sensitivity", 1, 10, 8)
  params:set_action("arc_srub_sens", function(val) scrub_sens = -50 * val + 550 end)

  -- params for tracks
  params:add_separator("track_params", "tracks")

  audio.level_cut(1)
  audio.level_tape(1)

  for i = 1, 6 do
    params:add_group("track_group"..i, "track "..i, 49)

    params:add_separator("track_options_params"..i, "track "..i.." options")
    -- select buffer
    params:add_option(i.."buffer_sel", "buffer", {"main", "temp"}, 1)
    params:set_action(i.."buffer_sel", function(x) tape[i].side = x softcut.buffer(i, x) end)
    -- play mode
    params:add_option(i.."play_mode", "play mode", {"loop", "oneshot", "gate"}, 1)
    params:set_action(i.."play_mode", function(option) track[i].play_mode = option page_redraw(vMAIN, 7) end)
    -- tempo map
    params:add_option(i.."tempo_map_mode", "tempo-map", {"none", "resize", "repitch"}, 1)
    params:set_action(i.."tempo_map_mode", function(mode) track[i].tempo_map = mode - 1 set_tempo_map(i) grid_page(vREC) end)
    -- play lauch
    params:add_option(i.."start_launch", "start launch", {"free", "beat", "bar"}, 1)
    params:set_action(i.."start_launch", function(option) track[i].start_launch = option page_redraw(vMAIN, 7) end)
    -- reset active
    params:add_option(i.."reset_active", "track reset", {"off", "on"}, 1)
    params:set_action(i.."reset_active", function(mode)
      track[i].reset = mode == 2 and true or false
      if num == 2 then
        track[i].beat_count = 0
      end
      page_redraw(vMAIN, 8)
    end)
    -- reset count
    params:add_number(i.."reset_count", "reset count", 2, 128, 4, function(param) return (param:get().." beats") end)
    params:set_action(i.."reset_count", function(val) track[i].beat_reset = val page_redraw(vMAIN, 8) end)
    
    params:add_separator("track_level_params"..i, "track "..i.." levels")
    -- track volume
    params:add_control(i.."vol", "volume", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."vol", function(x) track[i].level = x set_level(i) end)
    -- track pan
    params:add_control(i.."pan", "pan", controlspec.new(-1, 1, 'lin', 0, 0, ""), function(param) return pan_display(param:get()) end)
    params:set_action(i.."pan", function(x) track[i].pan = x softcut.pan(i, x) page_redraw(vMAIN, 1) end)
    -- record level
    params:add_control(i.."rec", "rec level", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."rec", function(x) track[i].rec_level = x set_rec(i) end)
    -- overdub level
    params:add_control(i.."dub", "dub level", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."dub", function(x) track[i].pre_level = x set_rec(i) end)
    -- rate slew
    params:add_control(i.."rate_slew", "rate slew", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."rate_slew", function(x) track[i].rate_slew = x softcut.rate_slew_time(i, x) page_redraw(vMAIN, 6) end)
    -- level slew
    params:add_control(i.."level_slew", "level slew", controlspec.new(0.1, 10.0, "lin", 0.1, 0.1, ""), function(param) return (round_form(param:get() * 10, 1, "%")) end)
    params:set_action(i.."level_slew", function(x) softcut.level_slew_time(i, x) page_redraw(vMAIN, 6) end)
    -- send level track 5
    params:add_control(i.."send_track5", "send trk 5", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_track5", function(x) track[i].send_t5 = x set_track_sends(i) end)
    if i > 4 then params:hide(i.."send_track5") end
    -- send level track 6
    params:add_control(i.."send_track6", "send trk 6", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_track6", function(x) track[i].send_t6 = x set_track_sends(i) end)
    if i > 5 then params:hide(i.."send_track6") end

    params:add_separator("track_pitch_params"..i, "track "..i.." pitch")
    -- detune
    params:add_number(i.."detune", "detune", -600, 600, 0, function(param) return (round_form(param:get(), 1, "cents")) end)
    params:set_action(i.."detune", function(cent) track[i].detune = cent / 1200 update_rate(i) page_redraw(vMAIN, 5) end)
    -- transpose
    params:add_option(i.."transpose", "transpose", scales.id[1], 8)
    params:set_action(i.."transpose", function(x) set_transpose(i, x) end)
   
    -- filter params
    params:add_separator("track_filter_params"..i, "track "..i.." filter")
    -- cutoff
    params:add_control(i.."cutoff", "cutoff", controlspec.new(20, 18000, 'exp', 1, 18000, ""), function(param) return (round_form(param:get(), 1, " hz")) end)
    params:set_action(i.."cutoff", function(x) softcut.post_filter_fc(i, x) page_redraw(vMAIN, 3) end)
    -- filter q
    params:add_control(i.."filter_q", "filter q", controlspec.new(0.1, 4.0, 'exp', 0.01, 2.0, ""))
    params:set_action(i.."filter_q", function(x) softcut.post_filter_rq(i, x) page_redraw(vMAIN, 3) end)
    -- filter type
    params:add_option(i.."filter_type", "type", {"lp", "hp", "bp", "br", "off"}, 1)
    params:set_action(i.."filter_type", function(option) filter_select(i, option) page_redraw(vMAIN, 4) end)
    -- post filter dry level
    params:add_control(i.."post_dry", "dry level", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."post_dry", function(x) track[i].dry_level = x softcut.post_filter_dry(i, x) page_redraw(vMAIN, 4) end)

    -- warble params
    params:add_separator("warble_params"..i, "track "..i.." warble")
    -- filter type
    params:add_option(i.."warble_state", "active", {"no", "yes"}, 1)
    params:set_action(i.."warble_state", function(option) track[i].warble = option - 1 grid_page(vREC) end)
    -- warble amount
    params:add_number(i.."warble_amount", "amount", 0, 100, 10, function(param) return (param:get().."%") end)
    params:set_action(i.."warble_amount", function(val) warble[i].amount = val end)
    -- warble depth
    params:add_number(i.."warble_depth", "depth", 0, 100, 12, function(param) return (param:get().."%") end)
    params:set_action(i.."warble_depth", function(val) warble[i].depth = val * 0.001 end)
    -- warble freq
    params:add_control(i.."warble_freq", "speed", controlspec.new(1.0, 10.0, "lin", 0.1, 6.0, ""))
    params:set_action(i.."warble_freq", function(val) warble[i].freq = val * 2 end)

    -- envelope params
    params:add_separator("envelope_params"..i, "track "..i.." envelope")

    params:add_option(i.."adsr_active", "envelope", {"off", "on"}, 1)
    params:set_action(i.."adsr_active", function(mode) env[i].active = mode == 2 and true or false init_envelope(i) grid_page(vENV) end)
    -- env amplitude
    params:add_control(i.."adsr_amp", "max vol", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_amp", function(val) env[i].max_value = val clamp_env_levels(i) page_redraw(vENV, 3) end)
    -- env init level
    params:add_control(i.."adsr_init", "min vol", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_init", function(val) env[i].init_value = val clamp_env_levels(i) page_redraw(vENV, 3) end)
    -- env attack
    params:add_control(i.."adsr_attack", "attack", controlspec.new(0, 10, 'lin', 0.1, 0.2, "s"))
    params:set_action(i.."adsr_attack", function(val) env[i].attack = val * 10 page_redraw(vENV, 1) end)
    -- env decay
    params:add_control(i.."adsr_decay", "decay", controlspec.new(0, 10, 'lin', 0.1, 0.5, "s"))
    params:set_action(i.."adsr_decay", function(val) env[i].decay = val * 10 page_redraw(vENV, 1) end)
    -- env sustain
    params:add_control(i.."adsr_sustain", "sustain", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_sustain", function(val) env[i].sustain = val clamp_env_levels(i) page_redraw(vENV, 2) end)
    -- env release
    params:add_control(i.."adsr_release", "release", controlspec.new(0, 10, 'lin', 0.1, 1, "s"))
    params:set_action(i.."adsr_release", function(val) env[i].release = val * 10 page_redraw(vENV, 2) end)    

    -- params for track to trigger
    params:add_separator(i.."trigger_params", "track "..i.." trigger")
    -- toggle rec @step
    params:add_option(i.."rec_at_step", "rec @step", {"off", "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 1)
    params:set_action(i.."rec_at_step", function(num) trig[i].rec_step = num - 1 end)
    -- trig @step
    params:add_option(i.."trig_at_step", "trig @step", {"off", "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 1)
    params:set_action(i.."trig_at_step", function(num) trig[i].step = num - 1 end)
    -- trig @count
    params:add_option(i.."trig_at_count", "trig @count", {"off", "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 1)
    params:set_action(i.."trig_at_count", function(num) trig[i].count = num - 1 end)
    -- trig output
    params:add_option(i.."trig_out", "trig output", {"off", "crow 1", "crow 2", "crow 3", "crow 4", "midi"}, 1)
    params:set_action(i.."trig_out", function(num) trig[i].out = num build_menu(i) end)
    -- crow amplitude
    params:add_control(i.."crow_amp", "amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
    params:set_action(i.."crow_amp", function(val) trig[i].amp = val end)
    -- crow attack
    params:add_control(i.."crow_env_a", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
    params:set_action(i.."crow_env_a", function(val) trig[i].env_a = val end)
    -- crow decay
    params:add_control(i.."crow_env_d", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.05, "s"))
    params:set_action(i.."crow_env_d", function(val) trig[i].env_d = val end)
    -- midi channel
    params:add_number(i.."midi_channel", "midi channel", 1, 16, 1)
    params:set_action(i.."midi_channel", function(num) trig[i].midi_ch = num end)
    -- midi note
    params:add_number(i.."midi_note", "midi note", 1, 127, 48, function(param) return mu.note_num_to_name(param:get(), true) end)
    params:set_action(i.."midi_note", function(num) trig[i].midi_note = num end)
    -- midi velocity
    params:add_number(i.."midi_vel", "midi velocity", 1, 127, 100)
    params:set_action(i.."midi_vel", function(num) trig[i].midi_vel = num end)
    
    -- input options
    params:add_option(i.."input_options", "input options", {"L+R", "L IN", "R IN", "OFF"}, 1)
    params:set_action(i.."input_options", function(option) tape[i].input = option set_softcut_input(i) end)
    params:hide(i.."input_options")

    -- softcut settings
    softcut.enable(i, 1)
    softcut.buffer(i, 1)

    softcut.play(i, 1)
    softcut.rec(i, 1)

    softcut.level(i, 1)
    softcut.pan(i, 0)

    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)

    softcut.fade_time(i, FADE_TIME)
    softcut.level_slew_time(i, 0.1)
    softcut.rate_slew_time(i, 0)

    softcut.loop_start(i, clip[i].s)
    softcut.loop_end(i, clip[i].e)
    softcut.loop(i, 1)
    softcut.position(i, clip[i].s)

    set_clip(i)

  end

  -- params for modulation (hnds_mlre)
  params:add_separator("modulation_params", "modulation")
  -- lfos
  init_lfos()
  
  -- params for splice resize
  for i = 1, 6 do
    params:add_option(i.."splice_length", i.." splice length", resize_options, 4)
    params:set_action(i.."splice_length", function(idx) track[i].resize_val = resize_values[idx] end)
    params:hide(i.."splice_length")
  end

  -- params for quant division
  params:add_option("quant_rate", "quantization rate", quant_options, 7)
  params:set_action("quant_rate", function(d) q_rate = quant_values[d] * 4 end)
  params:hide("quant_rate")

  -- pset callbacks
  params.action_write = function(filename, name, number)
    -- make directory
    os.execute("mkdir -p "..norns.state.data.."sessions/"..number.."/")
    -- save buffer content
    softcut.buffer_write_mono(norns.state.data.."sessions/"..number.."/"..name.."_buffer.wav", 0, -1, 1)
    -- save data in one big table
    local sesh_data = {}
    for i = 1, 8 do
      sesh_data[i] = {}
      -- pattern data
      sesh_data[i].pattern_count = pattern[i].count
      sesh_data[i].pattern_time = {table.unpack(pattern[i].time)}
      sesh_data[i].pattern_event = {table.unpack(pattern[i].event)}
      sesh_data[i].pattern_time_factor = pattern[i].time_factor
      sesh_data[i].pattern_synced = pattern[i].synced
      sesh_data[i].pattern_sync_meter = params:get("patterns_meter"..i)
      sesh_data[i].pattern_sync_beatnum = params:get("patterns_barnum"..i)
      sesh_data[i].pattern_loop = params:get("patterns_playback"..i)
      sesh_data[i].pattern_count_in = params:get("patterns_countin"..i)
      sesh_data[i].pattern_bpm = pattern[i].bpm
      sesh_data[i].pattern_tempo_map = pattern[i].tempo_map
      -- recall data
      sesh_data[i].recall_has_data = recall[i].has_data
      sesh_data[i].recall_event = recall[i].event
      -- snapshot data
      sesh_data[i].snap_data = snap[i].data
      sesh_data[i].snap_active = snap[i].active
      sesh_data[i].snap_play = {table.unpack(snap[i].play)}
      sesh_data[i].snap_mute = {table.unpack(snap[i].mute)}
      sesh_data[i].snap_loop = {table.unpack(snap[i].loop)}
      sesh_data[i].snap_loop_start = {table.unpack(snap[i].loop_start)}
      sesh_data[i].snap_loop_end = {table.unpack(snap[i].loop_end)}
      sesh_data[i].snap_pos_grid = {table.unpack(snap[i].cut)}
      sesh_data[i].snap_speed = {table.unpack(snap[i].speed)}
      sesh_data[i].snap_rev = {table.unpack(snap[i].rev)}
      sesh_data[i].snap_transpose_val = {table.unpack(snap[i].transpose_val)}
    end
    for i = 1, 6 do
      -- save default markers
      tape[i].splice[track[i].splice_focus].init_len = tape[i].splice[track[i].splice_focus].l
      tape[i].splice[track[i].splice_focus].init_start = tape[i].splice[track[i].splice_focus].s
      -- tape data
      sesh_data[i].tape_s = tape[i].s
      sesh_data[i].tape_e = tape[i].e
      sesh_data[i].tape_splice = {table.unpack(tape[i].splice)}
      -- clip data
      sesh_data[i].clip_s = clip[i].s
      sesh_data[i].clip_e = clip[i].e
      sesh_data[i].clip_l = clip[i].l
      sesh_data[i].clip_bpm = clip[i].bpm
      -- route data
      sesh_data[i].route_t5 = track[i].t5
      sesh_data[i].route_t6 = track[i].t6
      -- track data
      sesh_data[i].track_sel = track[i].sel
      sesh_data[i].track_fade = track[i].fade
      sesh_data[i].track_mute = track[i].mute
      sesh_data[i].track_speed = track[i].speed
      sesh_data[i].track_rev = track[i].rev
      sesh_data[i].track_warble = track[i].warble
      sesh_data[i].track_loop = track[i].loop
      sesh_data[i].track_loop_start = track[i].loop_start
      sesh_data[i].track_loop_end = track[i].loop_end
      sesh_data[i].track_splice_active = track[i].splice_active
      sesh_data[i].track_splice_focus = track[i].splice_focus
      sesh_data[i].track_tempo_map = params:get(i.."tempo_map_mode")
      -- lfo data
      sesh_data[i].lfo_track = lfo[i].track
      sesh_data[i].lfo_destination = lfo[i].destination
      sesh_data[i].lfo_offset = params:get("lfo_offset_lfo_"..i)
    end
    tab.save(sesh_data, norns.state.data.."sessions/"..number.."/"..name.."_session.data")
    -- rebuild pset list
    build_pset_list()
    print("finished writing pset:'"..name.."'")
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      -- clear temp buffer
      softcut.buffer_clear_channel(2)
      -- load buffer content
      softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 1)
      -- load sesh data file
      loaded_sesh_data = {}
      loaded_sesh_data = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")
      -- load data
      for i = 1, 6 do
        -- tape data
        tape[i].s = loaded_sesh_data[i].tape_s
        tape[i].e  = loaded_sesh_data[i].tape_e
        tape[i].splice = {table.unpack(loaded_sesh_data[i].tape_splice)}
        -- route data
        track[i].t5 = loaded_sesh_data[i].route_t5
        track[i].t6 = loaded_sesh_data[i].route_t6
        set_track_sends(i)
        -- track data
        track[i].loaded = true
        track[i].splice_active = loaded_sesh_data[i].track_splice_active
        track[i].splice_focus = loaded_sesh_data[i].track_splice_focus
        track[i].sel = loaded_sesh_data[i].track_sel
        track[i].fade = loaded_sesh_data[i].track_fade
        track[i].warble = loaded_sesh_data[i].track_warble
        track[i].loop = loaded_sesh_data[i].track_loop
        track[i].loop_start = loaded_sesh_data[i].track_loop_start
        track[i].loop_end = loaded_sesh_data[i].track_loop_end
        -- set track state
        track[i].mute = loaded_sesh_data[i].track_mute
        set_level(i)
        track[i].speed = loaded_sesh_data[i].track_speed
        track[i].rev = loaded_sesh_data[i].track_rev
        set_tempo_map(i)
        if track[i].play == 0 then
          stop_track(i)
        end
        set_rec(i)
        -- set lfo params
        if loaded_sesh_data[i].lfo_track ~= nil then
          set_lfo(i, loaded_sesh_data[i].lfo_track, loaded_sesh_data[i].lfo_destination)
          clock.run(function()
            clock.sleep(0.2)
            params:set("lfo_offset_lfo_"..i, loaded_sesh_data[i].lfo_offset)
          end)
        end
      end
      -- load pattern, recall and snapshot data
      load_patterns()
      dirtyscreen = true
      dirtygrid = true
      clock.run(function() clock.sleep(0.1) render_splice() end)
      print("finished reading pset:'"..pset_id.."'")
    end
  end

  params.action_delete = function(filename, name, number)
    norns.system_cmd("rm -r "..norns.state.data.."sessions/"..number.."/")
    build_pset_list()
    print("finished deleting pset:'"..name.."'")
  end

  -- metros
  hardwareredrawtimer = metro.init(function() hardwareredraw() end, 1/30, -1)
  hardwareredrawtimer:start()

  screenredrawtimer = metro.init(function() screenredraw() end, 1/15, -1)
  screenredrawtimer:start()

  warbletimer = metro.init(function() make_warble() end, 0.1, -1)
  warbletimer:start()

  tracktimer = metro.init(function() count_length() end, 0.01, -1)
  tracktimer:stop()

  -- clocks
  barpulse = clock.run(ledpulse_bar)
  beatpulse = clock.run(ledpulse_beat)
  quantizer = clock.run(update_q_clock)
  envcounter = clock.run(env_run)
  reset_clk = clock.run(track_reset)


  -- lattice
  vizclock = lattice:new()

  fastpulse = vizclock:new_sprocket{
    action = function(t) ledpulse_fast() end,
    division = 1/32,
    enabled = true
  }

  midpulse = vizclock:new_sprocket{
    action = function() ledpulse_mid() end,
    division = 1/24,
    enabled = true
  }

  slowpulse = vizclock:new_sprocket{
    action = function() ledpulse_slow() end,
    division = 1/12,
    enabled = true
  }

  vizclock:start()

  for i = 1, 8 do
    pattern[i]:init_clock()
  end

  -- threshold rec poll
  amp_in = {}
  local amp_src = {"amp_in_l", "amp_in_r"}
  for ch = 1, 2 do
    amp_in[ch] = poll.set(amp_src[ch])
    amp_in[ch].time = 0.01
    amp_in[ch].callback = function(val)
      if val > amp_threshold then
        loop_point()
        clock.run(oneshot, track[armed_track].dur) -- when rec starts, clock coroutine starts
        tracktimer:start()
        rec_at_threshold()
        oneshot_rec = true
        amp_in[ch]:stop()
      end
    end
  end

  -- callbacks
  arc.add = arc_connected
  arc.remove = arc_removed
  grid.add = grid_connected
  midi.add = midi_connected
  midi.remove = midi_disconnected

  softcut.event_render(wave_render)
  softcut.event_phase(phase_poll)
  softcut.poll_start_phase()
  softcut.event_position(get_pos)

  -- detect if arc is connected
  for v in pairs(arc.devices) do
    if arc.devices[v].name ~= nil then
      arc_is = true
    end
  end
  
  if pset_load then
    params:default()
  else
    params:bang()
  end

  for i = 1, 6 do
    stop_track(i) -- set all track levels to 0 post params:bang
  end

  set_view(vMAIN)
  set_gridview(vCUT, "z")
  set_gridview(vREC, "o")
 
  print("mlre loaded and ready. enjoy!")

end -- end of init


--------------------- USER INTERFACE -----------------------
vMAIN = 0
vREC = 1
vCUT = 2
vTRSP = 3
vLFO = 4
vENV = 5
vPATTERNS = 6
vTAPE = 7

view = vMAIN
view_prev = view

grido_view = vREC
gridz_view = vCUT

v = {}
v.key = {}
v.enc = {}
v.redraw = {}
v.arcdelta = {}
v.arcredraw = {}
v.gridkey_o = {}
v.gridredraw_o = {}
v.gridkey_z = {}
v.gridredraw_z = {}

viewinfo = {}
viewinfo[vREC] = 0
viewinfo[vLFO] = 0
viewinfo[vENV] = 0
viewinfo[vPATTERNS] = 0

-- set page and screen view
function set_gridview(x, pos)
  local pos = pos or "o"
  if pos == "o" then
    grido_view = x
    _gridkey_o = v.gridkey_o[x]
    _gridredraw_o = v.gridredraw_o[x]
  elseif pos == "z" then
    gridz_view = x
    _gridkey_z = v.gridkey_z[x]
    _gridredraw_z = v.gridredraw_z[x]
  end
  dirtyscreen = true
  dirtygrid = true
end

-- set screen view
function set_view(x)
  if x > 0 and x < 4 then x = 0 end
  view = x
  _key = v.key[x]
  _enc = v.enc[x]
  _redraw = v.redraw[x]
  _arcdelta = v.arcdelta[x]
  _arcredraw = v.arcredraw[x]
  dirtyscreen = true
end

function key(n, z)
  if n == 1 then
    shift = z
    dirtyscreen = true
  else
    _key(n, z)
  end
end

function enc(n, d)
  _enc(n, d)
end

function redraw()
  _redraw()
end

function a.delta(n, d)
  _arcdelta(n, d)
end

function arcredraw()
  _arcredraw()
end

function g.key(x, y, z)
  if GRID_SIZE == 128 then
    if y == 1 then
      grd.nav(x, z, "o") -- standard gridnav
    else
      _gridkey_o(x, y, z)
    end
  elseif GRID_SIZE == 256 then
    if y < 8 then
      _gridkey_o(x, y, z)
    elseif y == 8 then
      grd.nav(x, z, "o") -- top gridnav
    elseif y == 9 then
      grd.nav(x, z, "z") -- bottom gridnav
    elseif y > 9 then
      _gridkey_z(x, y, z)
    end
  end
end

function gridredraw()
  if GRID_SIZE == 128 then
    g:all(0)
    grd.drawnav(1)
    _gridredraw_o(1)
    g:refresh()
  elseif GRID_SIZE == 256 then
    g:all(0)
    grd.drawnav(8)
    grd.drawnav(9)
    _gridredraw_o()
    _gridredraw_z()
    g:refresh()
  end
end

function screenredraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function page_redraw(view, page)
  local view = view or 0
  local page = page or 0
  if view == vMAIN and main_pageNum == page then
    dirtyscreen = true
  elseif view == vLFO and lfo_pageNum == page then
    dirtyscreen = true
  elseif view == vENV and env_pageNum == page then
    dirtyscreen = true
  elseif view == vPATTERNS and patterns_pageNum == page then
    dirtyscreen = true
  elseif view == vTAPE then
    dirtyscreen = true
  end
end

function grid_page(view)
  local view = view or 1
  if (grido_view == view or gridz_view == view) then
    dirtygrid = true
  end
end

function hardwareredraw()
  if dirtygrid then
    gridredraw()
    dirtygrid = false
  end
  if arc_is then arcredraw() end
end

function grid_connected()
  if g.device then
    GRID_SIZE = g.device.cols * g.device.rows
  end
  dirtygrid = true
  hardwareredraw()
end

function arc_connected()
  hardwareredraw()
  arc_is = true
  build_menu(1)
end

function arc_removed()
  arc_is = false
  build_menu(1)
end


---------------------- MAIN VIEW PAGE -------------------------

v.key[vMAIN] = function(n, z)
  ui.main_key(n, z)
end

v.enc[vMAIN] = function(n, d)
  ui.main_enc(n, d)
end
  
v.redraw[vMAIN] = function()
  ui.main_redraw()
end

v.arcdelta[vMAIN] = function(n, d)
  ui.arc_main_delta(n, d)
end

v.arcredraw[vMAIN] = function()
  ui.arc_main_draw()
end


---------------------- REC PAGE -------------------------

v.gridkey_o[vREC] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.rec_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.rec_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vREC] = function()
  if GRID_SIZE == 128 then
    grd.rec_draw()
  elseif GRID_SIZE == 256 then
    grd.rec_draw(-1)
  end
end

v.gridkey_z[vREC] = function(x, y, z)
  grd.rec_keys(x, y, z, 8)
end

v.gridredraw_z[vREC] = function()
  grd.rec_draw(8)
end

---------------------CUT-----------------------

v.gridkey_o[vCUT] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.cut_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.cut_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vCUT] = function()
  if GRID_SIZE == 128 then
    grd.cut_draw()
  elseif GRID_SIZE == 256 then
    grd.cut_draw(-1)
  end
end

v.gridkey_z[vCUT] = function(x, y, z)
  grd.cut_keys(x, y, z, 8)
end

v.gridredraw_z[vCUT] = function()
  grd.cut_draw(8)
end

--------------------TRANSPOSE--------------------

v.gridkey_o[vTRSP] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.trsp_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.trsp_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vTRSP] = function()
  if GRID_SIZE == 128 then
    grd.trsp_draw()
  elseif GRID_SIZE == 256 then
    grd.trsp_draw(-1)
  end
end

v.gridkey_z[vTRSP] = function(x, y, z)
  grd.trsp_keys(x, y, z, 8)
end

v.gridredraw_z[vTRSP] = function()
  grd.trsp_draw(8)
end

---------------------- LFO -------------------------

v.key[vLFO] = function(n, z)
  ui.lfo_key(n, z)
end

v.enc[vLFO] = function(n, d)
  ui.lfo_enc(n, d)
end

v.redraw[vLFO] = function()
  ui.lfo_redraw()
end

v.arcdelta[vLFO] = function(n, d)
  ui.arc_lfo_delta(n, d)
end

v.arcredraw[vLFO] = function()
  ui.arc_lfo_draw()
end

v.gridkey_o[vLFO] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.lfo_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.lfo_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vLFO] = function()
  if GRID_SIZE == 128 then
    grd.lfo_draw()
  elseif GRID_SIZE == 256 then
    grd.lfo_draw(-1)
  end
end

v.gridkey_z[vLFO] = function(x, y, z)
  grd.lfo_keys(x, y, z, 8)
end

v.gridredraw_z[vLFO] = function()
  grd.lfo_draw(8)
end

---------------------ENVELOPES-----------------------

v.key[vENV] = function(n, z)
  ui.env_key(n, z)
end

v.enc[vENV] = function(n, d)
  ui.env_enc(n, d)
end

v.redraw[vENV] = function()
  ui.env_redraw()
end

v.arcdelta[vENV] = function(n, d)
  ui.arc_env_delta(n, d)
end

v.arcredraw[vENV] = function()
  ui.arc_env_draw()
end

v.gridkey_o[vENV] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.env_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.env_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vENV] = function()
  if GRID_SIZE == 128 then
    grd.env_draw()
  elseif GRID_SIZE == 256 then
    grd.env_draw(-1)
  end
end

v.gridkey_z[vENV] = function(x, y, z)
  grd.env_keys(x, y, z, 8)
end

v.gridredraw_z[vENV] = function()
  grd.env_draw(8)
end


---------------------PATTERNS-----------------------

v.key[vPATTERNS] = function(n, z)
  ui.patterns_key(n, z)
end

v.enc[vPATTERNS] = function(n, d)
  ui.patterns_enc(n, d)
end

v.redraw[vPATTERNS] = function()
  ui.patterns_redraw()
end

v.arcdelta[vPATTERNS] = function(n, d)
  ui.arc_pattern_delta(n, d)
end

v.arcredraw[vPATTERNS] = function()
  ui.arc_pattern_draw()
end

v.gridkey_o[vPATTERNS] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.pattern_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.pattern_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vPATTERNS] = function()
  if GRID_SIZE == 128 then
    grd.pattern_draw()
  elseif GRID_SIZE == 256 then
    grd.pattern_draw(-1)
  end
end

v.gridkey_z[vPATTERNS] = function(x, y, z)
  grd.pattern_keys(x, y, z, 8)
end

v.gridredraw_z[vPATTERNS] = function()
  grd.pattern_draw(8)
end


---------------------TAPE-----------------------

v.key[vTAPE] = function(n, z)
  ui.tape_key(n, z)
end

v.enc[vTAPE] = function(n, d)
  ui.tape_enc(n, d)
end

v.redraw[vTAPE] = function()
  ui.tape_redraw()
end

v.arcdelta[vTAPE] = function(n, d)
  ui.arc_tape_delta(n, d)
end

v.arcredraw[vTAPE] = function()
  ui.arc_tape_draw()
end

v.gridkey_o[vTAPE] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.tape_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.tape_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vTAPE] = function()
  if GRID_SIZE == 128 then
    grd.tape_draw()
  elseif GRID_SIZE == 256 then
    grd.tape_draw(-1)
  end
end

v.gridkey_z[vTAPE] = function(x, y, z)
  grd.tape_keys(x, y, z, 8)
end

v.gridredraw_z[vTAPE] = function()
  grd.tape_draw(8)
end

--------------------- UTILITIES -----------------------

function r()
  norns.script.load(norns.state.script)
end

function build_menu(i)
  if params:get(i.."trig_out") == 1 then
    params:hide(i.."crow_amp")
    params:hide(i.."crow_env_a")
    params:hide(i.."crow_env_d")
    params:hide(i.."midi_channel")
    params:hide(i.."midi_note")
    params:hide(i.."midi_vel")
  elseif params:get(i.."trig_out") > 1 and params:get(i.."trig_out") < 6 then
    params:show(i.."crow_amp")
    params:show(i.."crow_env_a")
    params:show(i.."crow_env_d")
    params:hide(i.."midi_channel")
    params:hide(i.."midi_note")
    params:hide(i.."midi_vel")
  else
    params:hide(i.."crow_amp")
    params:hide(i.."crow_env_a")
    params:hide(i.."crow_env_d")
    params:show(i.."midi_channel")
    params:show(i.."midi_note")
    params:show(i.."midi_vel")
  end
  if arc_is then
    params:show("arc_params")
  else
    params:hide("arc_params")
  end
  _menu.rebuild_params()
  dirtyscreen = true
end

function get_beatnum(length)
  local beatnum = util.round_up(length / beat_sec, 1)
  return beatnum
end

function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

function str_format(str, maxLength, separator)
  local maxLength = maxLength or 30
  local separator = separator or "..."
  str = string.sub(str, 1, -5)

  if (maxLength < 1) then return str end
  if (string.len(str) <= maxLength) then return str end
  if (maxLength == 1) then return string.sub(str, 1, 1) .. separator end

  local midpoint = math.ceil(string.len(str) / 2)
  local toremove = string.len(str) - maxLength
  local lstrip = math.ceil(toremove / 2)
  local rstrip = toremove - lstrip

  return string.sub(str, 1, midpoint - lstrip) .. separator .. string.sub(str, 1 + midpoint + rstrip)
end

function get_mid(str)
  local len = string.len(str) / 2
  local pix = len * 5
  return pix
end

function pan_display(param)
  local pos_right = ""
  local pos_left = ""
  if param < -0.01 then
    pos_right = ""
    pos_left = "L < "
    return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
  elseif param > 0.01 then
    pos_right = " > R"
    pos_left = ""
    return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
  else
    pos_right = ""
    pos_left = ""
    return "> <"
  end
end

function show_message(message)
  if msg_clock ~= nil then
    clock.cancel(msg_clock)
  end
  msg_clock = clock.run(function()
    view_message = message
    dirtyscreen = true
    if string.len(message) > 20 then
      clock.sleep(1.6) -- long display time
      view_message = ""
      dirtyscreen = true
    else
      clock.sleep(0.8) -- short display time
      view_message = ""
      dirtyscreen = true
    end
  end)
end

--------------------- TIME TO TIDY UP A BIT -----------------------

function cleanup()
  for i = 1, 8 do
    pattern[i]:stop()
    pattern[i] = nil
  end
  grid.add = function() end
  arc.add = function() end
  arc.remove = function() end
  midi.add = function() end
  midi.remove = function() end
  vizclock:destroy()
end
