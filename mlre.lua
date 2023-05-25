-- mlre v1.5.0 @sonocircuit
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

--- failstate @dan_derks
if tonumber(norns.version.update) < 220802 then
  norns.script.clear()
  norns.script.load('code/mlre/lib/fail_state.lua')
end

local a = arc.connect()
local g = grid.connect()
local m = midi.connect()

local fileselect = require 'fileselect'
local textentry = require 'textentry'
local mu = require 'musicutil'

local lfo = include 'lib/hnds_mlre'
local pattern_time = include 'lib/pattern_time_mlre'

local pset_load = false

local main_pageNum = 1
local trksel = 0
local dstview = 0
local pulse_key = 1
local flash_bar = false
local flash_beat = false
local quantize = 0
local oneshot_arm = 1
local oneshot_rec = false
local transport_run = false
local autolength = false
local pattern_rec = false
local loop_pos = 1
local rec_dur = 0
local route_adc = 1
local route_tape = 0

local tape_gap = 1
local max_tapelength = 57
local default_splicelength = 4
local default_beatnum = 4

local arc_pageNum = 1
local arc_is = false
local enc2_wait = false
local arc_off = 0
local arc_inc1 = 0
local arc_inc2 = 0
local arc_inc3 = 0
local arc_inc4 = 0
local arc_render = 0
local arc_lfo_focus = 1
local arc_track_focus = 1
local arc_splice_focus = 1
local scrub_sens = 100
local tau = math.pi * 2

local tape_pageNum = 1
local tape_actions = {"load", "clear", "save", "copy", "paste"}
local tape_action = 1
local copy_track = nil
local copy_splice = nil
local resize_values = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, max_tapelength}
local resize_options = {"1/4", "2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "8/4", "9/4", "10/4", "11/4", "12/4", "14/4", "16/4", "18/4", "20/4", "22/4", "24/4", "28/4", "32/4", "max"}

local pattern_playback = {"loop", "oneshot"}
local pattern_countin = {"beat", "bar"}
local pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
local pattern_meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}

local div = 16
local div_options = {"1bar", "1/2", "1/3", "1/4", "1/6", "1/8", "1/16", "1/32"}
local div_values = {1, 1/2, 1/3, 1/4, 1/6, 1/8, 1/16, 1/32}

-- for transpose scales
local scale_options = {"major", "natural minor", "harmonic minor", "melodic minor", "dorian", "phrygian", "lydian", "mixolydian", "locrian", "custom"}

local trsp_id = {
  {"-oct", "-min7", "-min6", "-perf5", "-perf4", "-min3", "-min2", "none", "maj2", "maj3", "perf4", "perf5", "maj6", "maj7", "oct"}, -- ionian / major
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-maj3", "-maj2", "none", "maj2", "min3", "perf4", "perf5", "min6", "min7", "oct"}, -- aeolian / natural minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-maj3", "-min2", "none", "maj2", "min3", "perf4", "perf5", "min6", "maj7", "oct"}, -- hamonic minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-min3", "-min2", "none", "maj2", "min3", "perf4", "perf5", "maj6", "maj7", "oct"}, -- melodic minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-min3", "-maj2", "none", "maj2", "min3", "perf4", "perf5", "maj6", "min7", "oct"}, -- dorian
  {"-oct", "-maj7", "-maj6", "-perf5", "-perf4", "-maj3", "-maj2", "none", "min2", "min3", "perf4", "perf5", "min6", "min7", "oct"}, -- phrygian
  {"-oct", "-min7", "-min6", "-dim5", "-perf4", "-min3", "-min2", "none", "maj2", "maj3", "dim5", "perf5", "maj6", "maj7", "oct"}, -- lydian
  {"-oct", "-min7", "-min6", "-perf5", "-perf4", "-min3", "-maj2", "none", "maj2", "maj3", "perf4", "perf5", "maj6", "min7", "oct"}, -- mixolydian
  {"-oct", "-maj7", "-maj6", "-perf5", "-dim5", "-maj3", "-maj2", "none", "min2", "min3", "perf4", "dim5", "min6", "min7", "oct"}, -- locrian
  {"-p4+2oct", "-2oct", "-p5+oct", "-p4+oct", "-oct", "-perf5", "-perf4", "none", "perf4", "perf5", "oct", "p4+oct", "p5+oct", "2oct", "p4+2oct"}, -- custom
}

local trsp_scale = {
  {-1200, -1000, -800, -700, -500, -300, -100, 0, 200, 400, 500, 700, 900, 1100, 1200}, -- ionian / major
  {-1200, -1000, -900, -700, -500, -400, -200, 0, 200, 300, 500, 700, 800, 1000, 1200}, -- aeolian / natural minor
  {-1200, -1000, -900, -700, -500, -400, -100, 0, 200, 300, 500, 700, 800, 1100, 1200}, -- hamonic minor
  {-1200, -1000, -900, -700, -500, -300, -100, 0, 200, 300, 500, 700, 900, 1100, 1200}, -- melodic minor
  {-1200, -1000, -900, -700, -500, -300, -200, 0, 200, 300, 500, 700, 900, 1000, 1200}, -- dorian
  {-1200, -1100, -900, -700, -500, -400, -200, 0, 100, 300, 500, 700, 800, 1000, 1200}, -- phrygian
  {-1200, -1000, -800, -600, -500, -300, -100, 0, 200, 400, 600, 700, 900, 1100, 1200}, -- lydian
  {-1200, -1000, -800, -700, -500, -300, -200, 0, 200, 400, 500, 700, 900, 1000, 1200}, -- mixolydian
  {-1200, -1100, -900, -700, -600, -400, -200, 0, 100, 300, 500, 600, 800, 1000, 1200}, -- locrain
  {-3100, -2400, -1900, -1700, -1200, -700, -500, 0, 500, 700, 1200, 1700, 1900, 2400, 3100}, -- custom
}

-- pages
local vREC = 1
local vCUT = 2
local vTRSP = 3
local vLFO = 4
local vENV = 5
local vPATTERNS = 6
local vCLIP = 7

local view_message = ""

-- events
local eCUT = 1
local eSTOP = 2
local eSTART = 3
local eLOOP = 4
local eSPEED = 5
local eREV = 6
local eMUTE = 7
local eTRSP = 8
local ePATTERN = 9
local eUNLOOP = 10
local eGATEON = 11
local eGATEOFF = 12
local eSPLICE = 13
local eROUTE = 14

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
  recall_watch(e)
end

local quantize_events = {}

function event(e)
  if quantize == 1 then
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
    clock.sync(div)
    if #quantize_events > 0 then
      for k, e in pairs(quantize_events) do
        if e.t ~= ePATTERN then event_record(e) end
        event_exec(e)
      end
      quantize_events = {}
    end
  end
end

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
  if view == vPATTERNS then dirtyscreen = true end
  if view == vCLIP and tape_pageNum == 1 then render_splice() end
end

-- exec function
function event_exec(e)
  if e.t == eCUT then
    if track[e.i].loop == 1 then -- clear loop and set playback window to the current clip start and endpoints
      track[e.i].loop = 0
      softcut.loop_start(e.i, clip[e.i].s) 
      softcut.loop_end(e.i, clip[e.i].e)
    end
    local cut = (e.pos / 16) * clip[e.i].l + clip[e.i].s
    local q = clip[e.i].l / 16
    if track[e.i].rev == 0 then
      softcut.position(e.i, cut)
    else
      softcut.position(e.i, cut + q)
    end
    if track[e.i].play == 0 then
      track[e.i].play = 1
      if track[e.i].rec == 1 then
        set_rec(e.i)
      end
      toggle_transport()
      if track[e.i].mute == 0 then
        softcut.level(e.i, track[e.i].level)
        set_track_route(e.i)
      end
    end
    if view < vLFO then dirtygrid = true end
  elseif e.t == eSTOP then
    stop_track(e.i)
  elseif e.t == eSTART then
    softcut.position(e.i, track[e.i].cut)
    track[e.i].play = 1
    if track[e.i].rec == 1 then
      set_rec(e.i)
    end
    toggle_transport()
    set_level(e.i)
    if view < vLFO then dirtygrid = true end
  elseif e.t == eLOOP then
    track[e.i].loop = 1
    track[e.i].loop_start = e.loop_start
    track[e.i].loop_end = e.loop_end
    local lstart = clip[e.i].s + (track[e.i].loop_start - 1) / 16 * clip[e.i].l
    local lend = clip[e.i].s + (track[e.i].loop_end) / 16 * clip[e.i].l
    softcut.loop_start(e.i, lstart)
    softcut.loop_end(e.i, lend)
    if view < vLFO then dirtygrid = true end
  elseif e.t == eUNLOOP then
    track[e.i].loop = 0
    softcut.loop_start(e.i, clip[e.i].s)
    softcut.loop_end(e.i, clip[e.i].e)
  elseif e.t == eSPEED then
    track[e.i].speed = e.speed
    update_rate(e.i)
    if view == vREC then dirtygrid = true end
  elseif e.t == eREV then
    track[e.i].rev = e.rev
    update_rate(e.i)
    if view < vLFO then dirtygrid = true end
  elseif e.t == eMUTE then
    track[e.i].mute = e.mute
    set_level(e.i)
  elseif e.t == eTRSP then
    params:set(e.i.."transpose", e.val)
    if view == vCUT then dirtygrid = true end
    if view == vTRSP then dirtygrid = true end
  elseif e.t == eGATEON then
    if params:get(e.i.."adsr_active") == 2 then
      env_gate_on(e.i)
    end
  elseif e.t == eGATEOFF then
    if params:get(e.i.."adsr_active") == 2 then
      env_gate_off(e.i)
    end
  elseif e.t == eSPLICE then
    track[e.i].splice_active = e.active
    set_clip(e.i)
    if view == vCLIP and tape_pageNum == 1 then
      render_splice()
      dirtygrid = true
    end
  elseif e.t == eROUTE then
    if e.ch == 5 then
      route[e.i].t5 = e.route
    else
      route[e.i].t6 = e.route
    end
    set_track_route(e.i)
    if view == vCLIP then dirtygrid = true end
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
local patterns_only = false
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

-- for tracks and clip settings
track = {}
for i = 1, 6 do
  track[i] = {}
  track[i].head = (i - 1) % 4 + 1
  track[i].play = 0
  track[i].sel = 0
  track[i].rec = 0
  track[i].oneshot = 0
  track[i].level = 1
  track[i].prev_level = 1
  track[i].mute = 0
  track[i].rate_slew = 0
  track[i].rec_level = 1
  track[i].pre_level = 0
  track[i].dry_level = 0
  track[i].send_t5 = 1
  track[i].send_t6 = 1
  track[i].loop = 0
  track[i].loop_start = 1
  track[i].loop_end = 16
  track[i].dur = 4
  track[i].splice_active = 1
  track[i].splice_focus = 1
  track[i].cut = tape_gap * i + (i - 1) * max_tapelength
  track[i].pos_abs = tape_gap * i + (i - 1) * max_tapelength
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
  track[i].detune = 0
  track[i].transpose = 0
  track[i].fade = 0
  track[i].side = 0
end

-- six slices of tape, one for each track
tape = {}
for i = 1, 6 do
  tape[i] = {}
  tape[i].s = tape_gap * i + (i - 1) * max_tapelength
  tape[i].e = tape[i].s + max_tapelength
  tape[i].splice = {}
  for j = 1, 8 do
    tape[i].splice[j] = {}
    tape[i].splice[j].s = tape[i].s + (default_splicelength + 0.01) * (j - 1)
    tape[i].splice[j].e = tape[i].splice[j].s + default_splicelength
    tape[i].splice[j].l = tape[i].splice[j].e - tape[i].splice[j].s
    tape[i].splice[j].name = "-"
    tape[i].splice[j].info = "length: "..string.format("%.2f", default_splicelength).."s"
    tape[i].splice[j].init_start = tape[i].splice[j].s
    tape[i].splice[j].init_len = default_splicelength
    tape[i].splice[j].beatnum = default_beatnum
    tape[i].splice[j].bpm = 60 
  end
end

-- six clips define the playback window, one for each track
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
  local q = calc_quant(i)
  local off = calc_quant_off(i, q)
  softcut.phase_quant(i, q)
  softcut.phase_offset(i, off)
  set_loop(i)
  update_rate(i)
end

function get_beatnum(length)
  local beatnum = util.round_up(length / clock.get_beat_sec(), 1)
  return beatnum
end

function set_loop(i)
  if track[i].loop == 1 then
    local e = {}
    e.t = eLOOP
    e.i = i
    e.loop = 1
    e.loop_start = track[i].loop_start
    e.loop_end = track[i].loop_end
    event(e)
    enc2_wait = false
  else
    track[i].loop = 0
  end
end

calc_quant = function(i)
  local q = (clip[i].l / 64)
  return q
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
  local new_length = length
  -- if no length argument recalculate
  if new_length == nil then
    if track[i].tempo_map == 0 then
      new_length = tape[i].splice[focus].beatnum
    elseif track[i].tempo_map == 1 then
      new_length = clock.get_beat_sec() * tape[i].splice[focus].beatnum
    elseif track[i].tempo_map == 2 then
      new_length = tape[i].splice[focus].l
    end
  end
  -- set splice variables
  if tape[i].splice[focus].s + new_length <= tape[i].e then
    tape[i].splice[focus].e = tape[i].splice[focus].s + new_length
    tape[i].splice[focus].l = new_length
    tape[i].splice[focus].bpm = 60 / new_length * tape[i].splice[focus].beatnum
    if track[i].splice_focus == track[i].splice_active then
      set_clip(i)
    end
    set_info(i, focus)
    --render_splice()
  else
    show_message("splice too long")
  end
end

function splice_reset(i, focus) -- reset splice to default length
  local focus = focus or track[i].splice_focus
  -- reset variables
  tape[i].splice[focus].s = tape[i].splice[focus].init_start
  tape[i].splice[focus].l = tape[i].splice[focus].init_len
  tape[i].splice[focus].e = tape[i].splice[focus].s + tape[i].splice[focus].l
  tape[i].splice[focus].bpm = 60 / tape[i].splice[focus].l * tape[i].splice[focus].beatnum
  -- set clip
  if track[i].splice_focus == track[i].splice_active then
    set_clip(i) 
  end
  set_info(i, focus)
end

function clear_splice(i) -- clear focused splice
  local buffer = params:get(i.."buffer_sel")
  local start = tape[i].splice[track[i].splice_focus].s
  local length = tape[i].splice[track[i].splice_focus].l
  softcut.buffer_clear_region_channel(buffer, start, length)
  show_message("track "..i.." splice "..track[i].splice_focus.." cleared")
  render_splice()
end

function clear_tape(i) -- clear tape and reset splices
  local buffer = params:get(i.."buffer_sel")
  local start = tape[i].s
  softcut.buffer_clear_region_channel(buffer, start, max_tapelength)
  track[i].loop = 0
  reset_splices(i)
  show_message("track "..i.." tape cleared")
  render_splice()
  dirtygrid = true
end

function clear_buffers()
  softcut.buffer_clear()
  for i = 1, 6 do
    track[i].loop = 0
    reset_splices(i)
  end
  show_message("buffers cleared")
  render_splice()
  dirtygrid = true
end

function reset_splices(i)
  for j = 1, 8 do
    tape[i].splice[j] = {}
    tape[i].splice[j].s = tape[i].s + (default_splicelength + 0.01) * (j - 1)
    tape[i].splice[j].e = tape[i].splice[j].s + default_splicelength
    tape[i].splice[j].l = tape[i].splice[j].e - tape[i].splice[j].s
    tape[i].splice[j].init_start = tape[i].splice[j].s
    tape[i].splice[j].init_len = default_splicelength
    tape[i].splice[j].beatnum = default_beatnum
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
  if view == vCLIP and tape_pageNum == 2 then dirtyscreen = true end
end

function set_tempo_map(i)
  if track[i].tempo_map == 1 then
    for j = 1, 8 do
      splice_resize(i, j)
    end
  else
    for j = 1, 8 do
      splice_reset(i, j)
    end
  end
  if view == vCLIP and tape_pageNum == 1 then render_splice() end
end

-- snapshots
snapshot_mode = false
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

function load_snapshot(n)
  for i = 1, 6 do
    local e = {} e.t = eMUTE e.i = i e.mute = snap[n].mute[i] event(e)
    local e = {} e.t = eREV e.i = i e.rev = snap[n].rev[i] event(e)
    local e = {} e.t = eSPEED e.i = i e.speed = snap[n].speed[i] event(e)
    params:set(i.."transpose", snap[n].transpose_val[i])
    if snap[n].loop[i] == 1 then
      local e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = snap[n].loop_start[i]
      e.loop_end = snap[n].loop_end[i]
      event(e)
      enc2_wait = false
    elseif snap[n].loop[i] == 0 then
      track[i].loop = 0
      softcut.loop_start(i, clip[i].s)
      softcut.loop_end(i, clip[i].e)
    end
    if snap[n].play[i] == 0 then
      local e = {} e.t = eSTOP e.i = i event(e)
    else
      track[i].cut = snap[n].cut[i]
      local e = {} e.t = eSTART e.i = i event(e)
    end
  end
end

-- softcut functions
function set_rec(n) -- set softcut rec and pre levels
  if track[n].fade == 0 then
    if track[n].rec == 1 and track[n].play == 1 then
      softcut.pre_level(n, track[n].pre_level)
      softcut.rec_level(n, track[n].rec_level)
    else
      softcut.pre_level(n, 1)
      softcut.rec_level(n, 0)
    end
  elseif track[n].fade == 1 then
    if track[n].rec == 1 and track[n].play == 1 then
      softcut.pre_level(n, track[n].pre_level)
      softcut.rec_level(n, track[n].rec_level)
    else
      softcut.pre_level(n, track[n].pre_level)
      softcut.rec_level(n, 0)
    end
  end
  if view < vLFO and main_pageNum == 1 then dirtyscreen = true end
end

function toggle_rec(i) -- toggle recording and trigger chop function
  track[i].rec = 1 - track[i].rec
  set_rec(i)
  chop(i)
  if view == vREC then dirtygrid = true end
end

function set_level(n) -- set track volume and mute track
  if track[n].mute == 0 and track[n].play == 1 then
    softcut.level(n, track[n].level)
    set_track_route(n)
  else
    softcut.level(n, 0)
    softcut.level_cut_cut(n, 5, 0)
    softcut.level_cut_cut(n, 6, 0)
  end
  if view < vLFO and main_pageNum == 1 then dirtyscreen = true end
end

function set_buffer(n) -- select softcut buffer to record to
  if track[n].side == 1 then
    softcut.buffer(n, 2)
  else
    softcut.buffer(n, 1)
  end
end

function copy_buffer(i, src, dst) -- copy splice to the other buffer
  local n = track[i].splice_focus
  softcut.buffer_copy_mono(src, dst, tape[i].splice[n].s, tape[i].splice[n].s, tape[i].splice[n].l, 0.01)
  local dst_name = dst == 1 and "main" or "temp"
  show_message("splice copied to "..dst_name.." buffer")
end

-------- waveforms --------
local waveform_samples = {}
local wave_gain = 1
local view_buffer = false

function wave_render(ch, start, i, s)
  waveform_samples = {}
  waveform_samples = s
  waveviz_reel = false
  wave_gain = wave_getmax(waveform_samples)
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
  if view_buffer then
    local start = tape[track_focus].s
    local length = tape[track_focus].e - tape[track_focus].s
    local buffer = params:get(track_focus.."buffer_sel")
    softcut.render_buffer(buffer, start, length, 128)
  else
    local n = track[track_focus].splice_focus
    local start = tape[track_focus].splice[n].s
    local length = tape[track_focus].splice[n].e - tape[track_focus].splice[n].s
    local buffer = params:get(track_focus.."buffer_sel")
    softcut.render_buffer(buffer, start, length, 128)
  end
end

-- for track routing
route = {}
for i = 1, 6 do
  route[i] = {}
  route[i].t5 = 0
  route[i].t6 = 0
end

function set_track_route(i) -- internal softcut routing
  if route[i].t5 == 1 and track[i].play == 1 then
    softcut.level_cut_cut(i, 5, track[i].send_t5 * track[i].level)
  else
    softcut.level_cut_cut(i, 5, 0)
  end
  if route[i].t6 == 1 and track[i].play == 1 then
    softcut.level_cut_cut(i, 6, track[i].send_t6 * track[i].level)
  else
    softcut.level_cut_cut(i, 6, 0)
  end
end

function set_track_source() -- select audio source
  audio.level_adc_cut(route_adc == 1 and 1 or 0)
  audio.level_tape_cut(route_tape == 1 and 1 or 0)
end

function set_softcut_input(i) -- select softcut input
  if params:get(i.."input_options") == 1 then -- L&R
    softcut.level_input_cut(1, i, 0.7)
    softcut.level_input_cut(2, i, 0.7)
  elseif params:get(i.."input_options") == 2 then -- L IN
    softcut.level_input_cut(1, i, 1)
    softcut.level_input_cut(2, i, 0)
 elseif params:get(i.."input_options") == 3 then -- R IN
    softcut.level_input_cut(1, i, 0)
    softcut.level_input_cut(2, i, 1)
 elseif params:get(i.."input_options") == 4 then -- OFF
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
  if view < vLFO and main_pageNum == 2 then dirtyscreen = true end
end

-- for lfos (hnds_mlre)
local lfo_targets = {"none"}
for i = 1, 6 do
  table.insert(lfo_targets, i.."vol")
  table.insert(lfo_targets, i.."pan")
  table.insert(lfo_targets, i.."dub")
  table.insert(lfo_targets, i.."transpose")
  table.insert(lfo_targets, i.."rate_slew")
  table.insert(lfo_targets, i.."cutoff")
end

function lfo.process()
  for i = 1, 6 do
    local target = params:get(i.."lfo_target")
    local target_name = string.sub(lfo_targets[target], 2)
    local voice = string.sub(lfo_targets[target], 1, 1)
    if params:get(i.."lfo_state") == 2 then
      if target_name == "vol" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "pan" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, -1.0, 1.0))
      elseif target_name == "dub" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "transpose" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 1, 16))
      elseif target_name == "rate_slew" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 0, 1.0))
      elseif target_name == "cutoff" then
        params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, 20, 18000))
      end
    end
  end
  if view == 4 then dirtygrid = true end -- for blinkenlights (lfo slope on "on" grid key)
end

-- tape warble
local warble = {}
for i = 1, 6 do
  warble[i] = {}
  warble[i].freq = 8
  warble[i].counter = 1
  warble[i].slope = 0
  warble[i].active = false
end

function make_warble() -- warbletimer function
  for i = 1, 6 do
    -- make sine (from hnds)
    local slope = 1 * math.sin(((tau / 100) * (warble[i].counter)) - (tau / (warble[i].freq)))
    warble[i].slope = util.linlin(-1, 1, -1, 0, math.max(-1, math.min(1, slope))) * (params:get(i.."warble_depth") * 0.001)
    warble[i].counter = warble[i].counter + warble[i].freq
    -- activate warble
    if track[i].warble == 1 and track[i].play == 1 and math.random(100) <= params:get(i.."warble_amount") then
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

-- scale and transpose functions
function set_scale(n) -- set scale id, thanks zebra
  for i = 1, 6 do
    local p = params:lookup_param(i.."transpose")
    p.options = trsp_id[n]
    p:bang()
  end
  if view < vLFO and main_pageNum == 3 then dirtyscreen = true end
end

function set_transpose(i, x) -- transpose track
  track[i].transpose = trsp_scale[params:get("scale")][x] / 1200
  update_rate(i)
  if view < vLFO and main_pageNum == 3 then dirtyscreen = true end
end

-- transport functions
function toggle_playback(i)
  if track[i].play == 1 then
    local e = {}
    e.t = eSTOP
    e.i = i
    event(e)
  else
    local e = {}
    e.t = eSTART
    e.i = i
    event(e)
  end
end

function toggle_transport()
  if transport_run == false then
    if params:get("midi_trnsp") == 2 then
      m:start()
    end
    if params:get("clock_source") == 1 then
      clock.internal.start()
    end
    transport_run = true
  end
end

function stop_track(i)
  softcut.query_position(i)
  softcut.level(i, 0)
  softcut.level_cut_cut(i, 5, 0)
  softcut.level_cut_cut(i, 6, 0)
  track[i].play = 0
  trig[i].tick = 0
  set_rec(i)
  if view < vLFO then dirtygrid = true end
end

function get_pos(i, pos) -- get and store softcut position (callback)
  track[i].cut = pos
  if params:get(i.."play_mode") == 2 then
    if track[i].rev == 0 and track[i].pos_hi_res == 64 then
      track[i].cut = clip[i].s
      track[i].pos_arc = 1
    elseif track[i].rev == 1 and track[i].pos_hi_res == 1 then
      track[i].cut = clip[i].e
      track[i].pos_arc = 64
    end
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

-- threshold recording
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

function thresh_rec() -- start rec when threshold is reached
  local i = oneshot_arm
  if track[i].oneshot == 1 then
    track[i].rec = 1
    set_rec(i)
    rec_dur = 0
    if track[i].play == 0 then
      if track[i].rev == 0 then
        local e = {} e.t = eCUT e.i = i e.pos = 0 event(e)
      elseif track[i].rev == 1 then
        local e = {} e.t = eCUT e.i = i e.pos = 15 event(e)
      end
    end
  end
end

function update_dur(n) -- calculate duration of length when oneshot == 1
  oneshot_rec = false
  if track[n].oneshot == 1 then
    if track[n].tempo_map == 2 then
      track[n].dur = ((clock.get_beat_sec() * clip[n].l) / math.pow(2, track[n].speed + track[n].transpose + track[n].detune)) * (clip[n].bpm / 60)
    else
      track[n].dur = clip[n].l / math.pow(2, track[n].speed + track[n].transpose + track[n].detune)
    end
    if track[n].loop == 1 and track[n].play == 1 then
      local len = track[n].loop_end - track[n].loop_start + 1
      track[n].dur = (track[n].dur / 16) * len
    end
  end
end

function oneshot(dur) -- called by clock coroutine at threshold
  clock.sleep(dur) -- length of rec time specified by 'track[i].dur'
  if track[oneshot_arm].oneshot == 1 then
    track[oneshot_arm].rec = 0
    track[oneshot_arm].oneshot = 0
  end
  set_rec(oneshot_arm)
  if track[oneshot_arm].sel == 1 and params:get("auto_rand_rec") == 2 and oneshot_rec == true then --randomize track
    randomize(oneshot_arm)
  end
  tracktimer:stop()
  oneshot_rec = false
end

function count_length()
  rec_dur = rec_dur + 1
end

function loop_point() -- set loop start point (loop_pos) for chop function
  if track[oneshot_arm].oneshot == 1 then
    if track[oneshot_arm].rev == 1 then
      if track[oneshot_arm].pos_grid == 16 then
        loop_pos = 16
      else
        loop_pos = track[oneshot_arm].pos_grid
      end
    else
      if track[oneshot_arm].pos_grid == 1 then
        loop_pos = 1
      else
        loop_pos = track[oneshot_arm].pos_grid
      end
    end
  end
end

function chop(i) -- called when rec key is pressed
  if oneshot_rec == true and track[i].oneshot == 1 then
    if not autolength then -- set-loop mode
      local e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = math.min(loop_pos, track[i].pos_grid)
      e.loop_end = math.max(loop_pos, track[i].pos_grid)
      event(e)
      track[i].oneshot = 0
      enc2_wait = false
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
    if track[i].sel == 1 and params:get("auto_rand_rec") == 2 then --randomize selected tracks
      randomize(i)
    end
    oneshot_rec = false
  end
end

function randomize(i) -- randomize parameters
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
    local e = {}
    e.t = eLOOP
    e.i = i
    e.loop = 1
    e.loop_start = math.random(1, 15)
    if params:get("auto_rand_cycle") == 2 then
      e.loop_end = math.random(e.loop_start + 1, 16)
    else
      e.loop_end = math.random(e.loop_start, 16)
    end
    event(e)
    enc2_wait = false
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

-- envelopes
local env = {}
for i = 1, 6 do
  env[i] = {}
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
  if view == vENV then dirtygrid = true end
end

function env_set_value(i, val)
  params:set(i.."vol", val)
end

function env_get_value(i)
  env[i].prev_value = params:get(i.."vol")
end

function env_stop(i)
  if params:get(i.."play_mode") == 3 then
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
  if params:get(i.."adsr_active") == 2 then
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
  if view == vENV then dirtygrid = true end
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

-- interface
view = vREC
view_prev = view

v = {}
v.key = {}
v.enc = {}
v.redraw = {}
v.gridkey = {}
v.gridredraw = {}
v.arcdelta = {}
v.arcredraw = {}

viewinfo = {}
viewinfo[vREC] = 0
viewinfo[vLFO] = 0
viewinfo[vENV] = 0
viewinfo[vPATTERNS] = 0

-- why do these need to be globals?
track_focus = 1
lfo_focus = 1
env_focus = 1
pattern_focus = 1
alt = 0
alt2 = 0
k1_hold = 0
cutview_hold = false

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

function key(n, z)
  if n == 1 then
    k1_hold = z
    dirtyscreen = true
  else
    _key(n, z)
  end
end

function enc(n, d) _enc(n, d) end

function redraw() _redraw() end

function screenredraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function g.key(x, y, z) _gridkey(x, y, z) end

function gridredraw() _gridredraw() end

function a.delta(n, d) _arcdelta(n, d) end

function arcredraw() _arcredraw() end

function hardwareredraw()
  if dirtygrid then
    gridredraw()
    dirtygrid = false
  end
  if arc_is then arcredraw() end
end

function grid_connected()
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

set_view = function(x)
  if x == -1 then x = view_prev end
  view_prev = view
  view = x
  _key = v.key[x]
  _enc = v.enc[x]
  _redraw = v.redraw[x]
  _gridkey = v.gridkey[x]
  _gridredraw = v.gridredraw[x]
  _arcdelta = v.arcdelta[x]
  _arcredraw = v.arcredraw[x]
  dirtyscreen = true
  dirtygrid = true
end

function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

function pan_display(param) --TODO
  local pos_right = ""
  local pos_left = ""
  if param == 0 then
    pos_right = ""
    pos_left = ""
  elseif param < -0.01 then
    pos_right = ""
    pos_left = "< "
  elseif param > 0.01 then
    pos_right = " >"
    pos_left = ""
  end
  return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
end

function ledpulse()
  while true do
    clock.sleep(1/15)
    pulse_key = (pulse_key % 8) + 4
    for i = 1, 8 do
      if pattern[i].overdub == 1 then
        dirtygrid = true
      end
    end
    for i = 1, 6 do
      if track[i].oneshot == 1 then
        dirtygrid = true
      end
    end
  end
end

function barpulse()
  while true do
    clock.sync(4)
    flash_bar = true
    dirtygrid = true
    clock.run(
      function()
        clock.sleep(0.1)
        flash_bar = false
        dirtygrid = true
      end
    )
  end
end

function beatpulse()
  while true do
    clock.sync(1)
    flash_beat = true
    dirtygrid = true
    clock.run(
      function()
        clock.sleep(0.1)
        flash_beat = false
        dirtygrid = true
      end
    )
  end
end

function show_message(message)
  clock.run(
    function()
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
    end
  )
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

-- midi and crow
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

function build_midi_device_list()
  midi_devices = {}
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

function note_off(i)
  m:note_off(trig[i].midi_note, nil, trig[i].midi_ch)
  for _, a in pairs(trig[i].active_notes) do
    m:note_off(a, nil, trig[i].midi_ch)
  end
  trig[i].active_notes = {}
end

function send_trig(i)
  if params:get(i.."trig_out") > 1 and params:get(i.."trig_out") < 6 then
    crow.output[trig[i].out].action = "{ to(0, 0), to("..trig[i].amp..", "..trig[i].env_a.."), to(0, "..trig[i].env_d..", 'lin') }"
    crow.output[trig[i].out]()
  elseif params:get(i.."trig_out") == 6 then
    m:note_on(trig[i].midi_note, trig[i].midi_vel, trig[i].midi_ch)
    table.insert(trig[i].active_notes, trig[i].midi_note)
  end
end


-- init
function init()
  -- params for "globals"
  params:add_separator("global_params", "global")
  -- params for scales
  params:add_option("scale", "scale", scale_options, 1)
  params:set_action("scale", function(n) set_scale(n) end)
  -- params for rec threshold
  params:add_control("rec_threshold", "rec threshold", controlspec.new(-40, 6, 'lin', 0.01, -12, "dB"))
  -- macro params
  params:add_group("macro_params", "macros", 2)
  -- event recording slots
  params:add_option("slot_assign", "macro slots", {"split", "patterns only", "recall only"}, 1)
  params:set_action("slot_assign", function() dirtygrid = true end)
  -- recall mode
  params:add_option("recall_mode", "recall mode", {"manual recall", "snapshot"}, 2)
  params:set_action("recall_mode", function(x) snapshot_mode = x == 2 and true or false dirtygrid = true end)

  -- patterns params
  params:add_group("patterns", "patterns", 40)
  params:hide("patterns")
  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback"..i, "playback", pattern_playback, 1)
    params:set_action("patterns_playback"..i, function(mode) pattern[i].loop = mode == 1 and true or false end)

    params:add_option("patterns_countin"..i, "count in", pattern_countin, 1)
    params:set_action("patterns_countin"..i, function(mode) pattern[i].count_in = mode == 1 and 1 or 4 dirtygrid = true end)

    params:add_option("patterns_meter"..i, "meter", pattern_meter, 3)
    params:set_action("patterns_meter"..i, function(idx) pattern[i].sync_meter = pattern_meter_val[idx] end)

    params:add_number("patterns_barnum"..i, "length", 1, 16, 4, function(param) return param:get()..(pattern[i].sync_beatnum <= 4 and " bar" or " bars") end)
    params:set_action("patterns_barnum"..i, function(num) pattern[i].sync_beatnum = num * 4 dirtygrid = true end)
  end

  -- midi params
  params:add_group("midi_params", "midi settings", 2)
  -- midi device
  build_midi_device_list()
  params:add_option("global_midi_device", "midi device", midi_devices, 1)
  params:set_action("global_midi_device", function(val) m = midi.connect(val) end)
  -- send midi transport
  params:add_option("midi_trnsp","midi transport", {"off", "send", "receive"}, 1)

  -- global track control
  params:add_group("track_control", "track control", 59)
  params:add_separator("global_track_control", "global control")
  -- start all
  params:add_binary("start_all", "start all", "trigger", 0)
  params:set_action("start_all", function() startall() end)
  -- stop all
  params:add_binary("stop_all", "stop all", "trigger", 0)
  params:set_action("stop_all", function() stopall() end)

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
  params:add_group("randomization_params", "randomization", 17)
  params:add_option("auto_rand_rec","randomize @ oneshot rec", {"off", "on"}, 1)
  params:add_option("auto_rand_cycle","randomize @ step count", {"off", "on"}, 1)
  params:add_number("step_count", ">> step count", 1, 128, 16)

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
    params:add_group("track_group"..i, "track "..i, 43)

    params:add_separator("tape_params"..i, "track "..i.." tape")
    -- select buffer
    params:add_option(i.."buffer_sel", "buffer", {"main", "temp"}, 1)
    params:set_action(i.."buffer_sel", function(x) track[i].side = x - 1 set_buffer(i) end)
    -- play mode
    params:add_option(i.."play_mode", "play mode", {"loop", "oneshot", "gate"}, 1)
    -- tempo map
    params:add_option(i.."tempo_map_mode", "tempo-map", {"none", "resize", "repitch"}, 1)
    params:set_action(i.."tempo_map_mode", function(mode) track[i].tempo_map = mode - 1 set_tempo_map(i) if view == vREC then dirtygrid = true end end)
    -- track volume
    params:add_control(i.."vol", "vol", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."vol", function(x) track[i].level = x set_level(i) end)
    -- track pan
    params:add_control(i.."pan", "pan", controlspec.new(-1, 1, 'lin', 0, 0, ""), function(param) return pan_display(param:get()) end)
    params:set_action(i.."pan", function(x) softcut.pan(i, x) if view < vLFO and main_pageNum == 1 then dirtyscreen = true end end)
    -- record level
    params:add_control(i.."rec", "rec", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."rec", function(x) track[i].rec_level = x set_rec(i) end)
    -- overdub level
    params:add_control(i.."dub", "dub", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."dub", function(x) track[i].pre_level = x set_rec(i) end)
    -- detune
    params:add_number(i.."detune", "detune", -600, 600, 0, function(param) return param:get().." cents" end)
    params:set_action(i.."detune", function(cent) track[i].detune = cent / 1200 update_rate(i) if view < vLFO and main_pageNum == 3 then dirtyscreen = true end end)
    -- transpose
    params:add_option(i.."transpose", "transpose", trsp_id[1], 8)
    params:set_action(i.."transpose", function(x) set_transpose(i, x) end)
    -- rate slew
    params:add_control(i.."rate_slew", "rate slew", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."rate_slew", function(x) track[i].rate_slew = x softcut.rate_slew_time(i, x) if view < vLFO and main_pageNum == 3 then dirtyscreen = true end end)
    -- level slew
    params:add_control(i.."level_slew", "level slew", controlspec.new(0.1, 10.0, "lin", 0.1, 0.1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."level_slew", function(x) softcut.level_slew_time(i, x) if view < vLFO and main_pageNum == 3 then dirtyscreen = true end end)
    -- send level track 5
    params:add_control(i.."send_track5", "send track 5", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_track5", function(x) track[i].send_t5 = x set_track_route(i) end)
    params:hide(i.."send_track5")
    -- send level track 6
    params:add_control(i.."send_track6", "send track 6", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_track6", function(x) track[i].send_t6 = x set_track_route(i) end)
    params:hide(i.."send_track6")

    -- filter params
    params:add_separator("filter_params"..i, "track "..i.." filter")
    -- cutoff
    params:add_control(i.."cutoff", "cutoff", controlspec.new(20, 18000, 'exp', 1, 18000, "Hz"))
    params:set_action(i.."cutoff", function(x) softcut.post_filter_fc(i, x) if view < vLFO and main_pageNum == 2 then dirtyscreen = true end end)
    -- filter q
    params:add_control(i.."filter_q", "filter q", controlspec.new(0.1, 4.0, 'exp', 0.01, 2.0, ""))
    params:set_action(i.."filter_q", function(x) softcut.post_filter_rq(i, x) if view < vLFO and main_pageNum == 2 then dirtyscreen = true end end)
    -- filter type
    params:add_option(i.."filter_type", "type", {"low pass", "high pass", "band pass", "band reject", "off"}, 1)
    params:set_action(i.."filter_type", function(option) filter_select(i, option) end)
    -- post filter dry level
    params:add_control(i.."post_dry", "dry level", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action(i.."post_dry", function(x) track[i].dry_level = x softcut.post_filter_dry(i, x) if view < vLFO and main_pageNum == 2 then dirtyscreen = true end end)

    -- warble params
    params:add_separator("warble_params"..i, "track "..i.." warble")
    -- warble amount
    params:add_number(i.."warble_amount", "amount", 0, 100, 10, function(param) return (param:get().."%") end)
    -- warble depth
    params:add_number(i.."warble_depth", "depth", 0, 100, 12, function(param) return (param:get().."%") end)
    -- warble freq
    params:add_control(i.."warble_freq", "speed", controlspec.new(1.0, 10.0, "lin", 0.1, 6.0, ""))
    params:set_action(i.."warble_freq", function(val) warble[i].freq = val * 2 end)

    -- envelope params
    params:add_separator("envelope_params"..i, "track "..i.." envelope")

    params:add_option(i.."adsr_active", "envelope", {"off", "on"}, 1)
    params:set_action(i.."adsr_active", function() init_envelope(i) if view == vENV then dirtyscreen = true end end)
    -- env amplitude
    params:add_control(i.."adsr_amp", "max vol", controlspec.new(0, 1, 'lin', 0, 1, ""))
    params:set_action(i.."adsr_amp", function(val) env[i].max_value = val clamp_env_levels(i) if view == vENV then dirtyscreen = true end end)
    -- env init level
    params:add_control(i.."adsr_init", "min vol", controlspec.new(0, 1, 'lin', 0, 0, ""))
    params:set_action(i.."adsr_init", function(val) env[i].init_value = val clamp_env_levels(i) if view == vENV then dirtyscreen = true end end)
    -- env attack
    params:add_control(i.."adsr_attack", "attack", controlspec.new(0, 10, 'lin', 0.1, 0.2, "s"))
    params:set_action(i.."adsr_attack", function(val) env[i].attack = val * 10 if view == vENV then dirtyscreen = true end end)
    -- env decay
    params:add_control(i.."adsr_decay", "decay", controlspec.new(0, 10, 'lin', 0.1, 0.5, "s"))
    params:set_action(i.."adsr_decay", function(val) env[i].decay = val * 10 if view == vENV then dirtyscreen = true end end)
    -- env sustain
    params:add_control(i.."adsr_sustain", "sustain", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_sustain", function(val) env[i].sustain = val clamp_env_levels(i) if view == vENV then dirtyscreen = true end end)
    -- env release
    params:add_control(i.."adsr_release", "release", controlspec.new(0, 10, 'lin', 0.1, 1, "s"))
    params:set_action(i.."adsr_release", function(val) env[i].release = val * 10 if view == vENV then dirtyscreen = true end end)    

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
    params:set_action(i.."trig_out", function(num) trig[i].out = util.clamp(num - 1, 1, 4) build_menu(i) note_off(i) end)
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
    params:set_action(i.."midi_channel", function(num) note_off(i) trig[i].midi_ch = num end)
    -- midi note
    params:add_number(i.."midi_note", "midi note", 1, 127, 48, function(param) return mu.note_num_to_name(param:get(), true) end)
    params:set_action(i.."midi_note", function(num) note_off(i) trig[i].midi_note = num end)
    -- midi velocity
    params:add_number(i.."midi_vel", "midi velocity", 1, 127, 100)
    params:set_action(i.."midi_vel", function(num) trig[i].midi_vel = num end)
    -- input options
    params:add_option(i.."input_options", "input options", {"L+R", "L IN", "R IN", "OFF"}, 1)
    params:set_action(i.."input_options", function() set_softcut_input(i) end)
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

    softcut.fade_time(i, 0.01)
    softcut.level_slew_time(i, 0.1)
    softcut.rate_slew_time(i, 0)

    softcut.loop_start(i, clip[i].s)
    softcut.loop_end(i, clip[i].e)
    softcut.loop(i, 1)
    softcut.position(i, clip[i].s)

    set_clip(i)

  end

  -- params for modulation (hnds_mlre)
  params:add_separator("modulation_sep", "modulation")
  -- lfos
  for i = 1, 6 do lfo[i].lfo_targets = lfo_targets end
  lfo.init()
  
  -- params for splice resize
  for i = 1, 6 do
    params:add_option(i.."splice_length", i.." splice length", resize_options, 4)
    params:hide(i.."splice_length")
  end

  -- params for quant division
  params:add_option("quant_div", "quant div", div_options, 7)
  params:set_action("quant_div", function(d) div = div_values[d] * 4 end)
  params:hide("quant_div")

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
      sesh_data[i].route_t5 = route[i].t5
      sesh_data[i].route_t6 = route[i].t6
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
    end
    tab.save(sesh_data, norns.state.data.."sessions/"..number.."/"..name.."_session.data")
    print("finished writing pset:'"..name.."'")
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      -- load buffer content
      softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 1)
      -- load sesh data file
      local sesh_data = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")
      -- load data
      for i = 1, 6 do
        -- tape data
        tape[i].s = sesh_data[i].tape_s
        tape[i].e  = sesh_data[i].tape_e
        tape[i].splice = {table.unpack(sesh_data[i].tape_splice)}
        -- clip data
        clip[i].s = sesh_data[i].clip_s
        clip[i].e = sesh_data[i].clip_e
        clip[i].l = sesh_data[i].clip_l
        clip[i].bpm = sesh_data[i].clip_bpm
        -- route data
        route[i].t5 = sesh_data[i].route_t5
        route[i].t6 = sesh_data[i].route_t6
        set_track_route(i)
        -- track data
        track[i].splice_active = sesh_data[i].track_splice_active
        track[i].splice_focus = sesh_data[i].track_splice_focus
        track[i].sel = sesh_data[i].track_sel
        track[i].fade = sesh_data[i].track_fade
        track[i].warble = sesh_data[i].track_warble
        set_clip(i)
        -- set track state
        local e = {} e.t = eMUTE e.i = i e.mute = sesh_data[i].track_mute event(e)
        local e = {} e.t = eREV e.i = i e.rev = sesh_data[i].track_rev event(e)
        local e = {} e.t = eSPEED e.i = i e.speed = sesh_data[i].track_speed event(e)
        if track[i].play == 0 then
          stop_track(i)
        end
        if sesh_data[i].track_loop == 1 then
          local e = {}
          e.t = eLOOP
          e.i = i
          e.loop = 1
          e.loop_start = sesh_data[i].track_loop_start
          e.loop_end = sesh_data[i].track_loop_end
          event(e)
          enc2_wait = false
        elseif sesh_data[i].track_loop == 0 then
          track[i].loop = 0
          softcut.loop_start(i, clip[i].s)
          softcut.loop_end(i, clip[i].e)
        end
        set_rec(i)
      end
      -- load pattern, recall and snapshot data
      for i = 1, 8 do
        -- patterns
        pattern[i].count = sesh_data[i].pattern_count
        pattern[i].time = {table.unpack(sesh_data[i].pattern_time)}
        pattern[i].event = {table.unpack(sesh_data[i].pattern_event)}
        pattern[i].time_factor = sesh_data[i].pattern_time_factor
        pattern[i].synced = sesh_data[i].pattern_synced
        params:set("patterns_meter"..i, sesh_data[i].pattern_sync_meter)
        params:set("patterns_barnum"..i, sesh_data[i].pattern_sync_beatnum)
        params:set("patterns_playback"..i, sesh_data[i].pattern_loop)
        params:set("patterns_countin"..i, sesh_data[i].pattern_count_in)
        pattern[i].bpm = sesh_data[i].pattern_bpm
        pattern[i].tempo_map = sesh_data[i].pattern_tempo_map
        if pattern[i].tempo_map and pattern[i].bpm ~= nil then
          local newfactor = pattern[i].bpm / clock.get_tempo()
          pattern[i].time_factor = newfactor
        end
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "overdub_off"} event(e)
        if pattern[i].rec == 1 then
          local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        end
        -- recall
        recall[i].has_data = sesh_data[i].recall_has_data
        recall[i].event = {table.unpack(sesh_data[i].recall_event)}
        -- snapshots
        snap[i].data = sesh_data[i].snap_data
        snap[i].active = sesh_data[i].snap_active
        snap[i].play = {table.unpack(sesh_data[i].snap_play)}
        snap[i].mute = {table.unpack(sesh_data[i].snap_mute)}
        snap[i].loop = {table.unpack(sesh_data[i].snap_loop)}
        snap[i].loop_start = {table.unpack(sesh_data[i].snap_loop_start)}
        snap[i].loop_end = {table.unpack(sesh_data[i].snap_loop_end)}
        snap[i].cut = {table.unpack(sesh_data[i].snap_pos_grid)}
        snap[i].speed = {table.unpack(sesh_data[i].snap_speed)}
        snap[i].rev = {table.unpack(sesh_data[i].snap_rev)}
        snap[i].transpose_val = {table.unpack(sesh_data[i].snap_transpose_val)}
      end
      dirtyscreen = true
      dirtygrid = true
      print("finished reading pset:'"..pset_id.."'")
    end
  end

  params.action_delete = function(filename, name, number)
    norns.system_cmd("rm -r "..norns.state.data.."sessions/"..number.."/")
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
  ledcounter = clock.run(ledpulse)
  envcounter = clock.run(env_run)

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
      if val > util.dbamp(params:get("rec_threshold")) / 10 then
        loop_point()
        clock.run(oneshot, track[oneshot_arm].dur) -- when rec starts, clock coroutine starts
        tracktimer:start()
        thresh_rec()
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
  softcut.event_phase(phase)
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

  set_view(vREC)

  print("mlre loaded and ready. enjoy!")

end -- end of init

phase = function(n, x)
  -- calc softcut positon
  local pp = ((x - clip[n].s) / clip[n].l)
  local pc = ((x - tape[n].s) / max_tapelength)
  local g_pos = math.floor(pp * 16)
  local a_pos = math.floor(pp * 64)
  -- calc positions
  track[n].pos_abs = x -- absoulute position on buffer
  track[n].pos_hi_res = util.clamp(a_pos + 1 % 64, 1, 64) -- fine mesh for arc
  track[n].pos_lo_res = util.clamp(g_pos + 1 % 16, 1, 16) -- coarse mesh for grid
  if track[n].play == 1 then
    if track[n].pos_lo_res ~= track[n].pos_grid then
      track[n].pos_grid = track[n].pos_lo_res
    end
    if track[n].pos_arc ~= track[n].pos_hi_res then
      track[n].pos_arc = track[n].pos_hi_res
    end
    if track[n].pos_rel ~= pp then
      track[n].pos_rel = pp -- relative position within clip
    end
    if track[n].pos_clip ~= pc then
      track[n].pos_clip = pc -- relative position within allocated buffer space
    end
    -- display position
    if (view < vLFO or view == vCLIP) then
      dirtygrid = true
    end
    if view == vCLIP and tape_pageNum == 1 then
      dirtyscreen = true
    end
  end
  -- oneshot play_mode
  if params:get(n.."play_mode") == 2 and track[n].loop == 0 and track[n].play == 1 then
    if track[n].rev == 0 then
      if track[n].pos_hi_res == 64 then
        stop_track(n)
      end
    else
      if track[n].pos_hi_res == 1 then
        stop_track(n)
      end
    end
  end
  -- randomize at cycle
  if params:get("auto_rand_cycle") == 2 and track[n].sel == 1 and not oneshot_rec then
    if track[n].play == 1 then
      track[n].step_count = track[n].step_count + 1
      if track[n].step_count > params:get("step_count") * 4 then
        randomize(n)
      end
    end
  end
  -- turn notes off first
  if params:get(n.."trig_out") == 6 then
    note_off(n)
  end
  -- track 2 trigger
  if track[n].play == 1 then
    -- rec @step
    if params:get(n.."rec_at_step") > 1 then
      if track[n].rev == 0 then
        if track[n].pos_hi_res == trig[n].rec_step * 4 - 3 then
          toggle_rec(n)
        end
      else
        if track[n].pos_hi_res == trig[n].rec_step * 4 then
          toggle_rec(n)
        end
      end
    end
    -- trig @step mode
    if params:get(n.."trig_at_step") > 1 then
      if track[n].rev == 0 then
        if track[n].pos_hi_res == trig[n].step * 4 - 3 then
          send_trig(n)
        end
      else
        if track[n].pos_hi_res == trig[n].step * 4 then
          send_trig(n)
        end
      end
    end
    -- trig @count mode
    if params:get(n.."trig_at_count") > 1 then
      trig[n].tick = trig[n].tick + 1 -- count steps
      if trig[n].tick >= trig[n].count * 4 then
        send_trig(n)
        trig[n].tick = 0
      end
    end
  end
end

function update_rate(i)
  -- calc speed and update softcut rate
  local n = math.pow(2, track[i].speed + track[i].transpose + track[i].detune)
  if track[i].rev == 1 then n = -n end
  if track[i].tempo_map == 2 then
    local bpmmod = clock.get_tempo() / clip[i].bpm
    n = n * bpmmod
  end
  softcut.rate(i, n)
end

-------------------- norns UI ------------------

gridkey_nav = function(x, z)
  if z == 1 then
    if x == 1 then
      if alt == 1 then
        clear_splice(track_focus)
      else
        set_view(vREC)
      end
    elseif x == 2 then
      if alt == 1 then
        clear_tape(track_focus)
      else
        set_view(vCUT)
        cutview_hold = true
      end
    elseif x == 3 then
      if alt == 1 then
        clear_buffers()
        show_message("buffers cleared")
      else
        set_view(vTRSP)
      end
    elseif x == 4 and alt == 0 then
      if view == vLFO then
        set_view(vENV)
      else
        set_view(vLFO)
      end
    elseif x > 4 and x < (params:get("slot_assign") == 1 and 9 or 13) and params:get("slot_assign") ~= 3 then
      local i = x - 4
      if alt == 1 then
        local e = {t = ePATTERN, i = i, action = "rec_stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "stop"} event(e)
        local e = {t = ePATTERN, i = i, action = "clear"} event(e)
      elseif alt2 == 1 then
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
    elseif x > (params:get("slot_assign") == 3 and 4 or 8) and x < 13 and params:get("slot_assign") ~= 2 then
      local i = x - 4
      if snapshot_mode then
        if alt == 1 then
          snap[i].data = false
          snap[i].active = false
        elseif alt == 0 then
          if not snap[i].data then
            save_snapshot(i)
          elseif snap[i].data then
            load_snapshot(i)
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
    elseif x == 15 and alt == 0 and alt2 == 0 then
      quantize = 1 - quantize
      if quantize == 0 then
        clock.cancel(quantizer)
        clock.cancel(downbeat)
        clock.cancel(quater)
      else
        quantizer = clock.run(update_q_clock)
        downbeat = clock.run(barpulse)
        quater = clock.run(beatpulse)
      end
      elseif x == 16 then alt = 1 if view == vLFO then dirtyscreen = true end
      elseif x == 15 and alt == 1 then set_view(vCLIP)
        if tape_pageNum == 1 then render_splice() end
      elseif x == 15 and alt2 == 1 then set_view(vPATTERNS)
      elseif x == 14 and alt == 0 then alt2 = 1
      elseif x == 14 and alt == 1 then retrig()  -- set all playing tracks to pos 1
      elseif x == 13 and alt == 0 then stopall() -- stops all tracks
      elseif x == 13 and alt == 1 then altrun()  -- stops all running tracks and runs all stopped tracks if track[i].sel == 1
    end
  elseif z == 0 then
    if x == 2 then cutview_hold = false end
    if x == 16 then alt = 0 if view == vLFO then dirtyscreen = true end
    elseif x == 14 and alt == 0 then alt2 = 0 -- lock alt2 if alt2 released before alt is released
    elseif x > (params:get("slot_assign") == 3 and 4 or 8) and x < 13 and params:get("slot_assign") ~= 2 then
      if snapshot_mode then
        snap[x - 4].active = false
      else
        recall[x - 4].active = false
      end
    end
  end
  dirtygrid = true
end

gridredraw_nav = function()
  g:led(1, 1, 4) -- vREC
  g:led(2, 1, 3) -- vCUT
  g:led(3, 1, 2) -- vTRSP
  g:led(view, 1, 9) -- track_focus
  g:led(16, 1, alt == 1 and 15 or 9) -- alt
  g:led(15, 1, quantize == 1 and (flash_bar and 15 or (flash_beat and 10 or 7)) or 3) -- Q flash
  g:led(14, 1, alt2 == 1 and 9 or 2) -- mod
  for i = 1, (params:get("slot_assign") == 1 and 4 or 8) do
    if params:get("slot_assign") ~= 3 then
      if pattern[i].rec == 1 then
        g:led(i + 4, 1, 15)
      elseif pattern[i].overdub == 1 then
        g:led(i + 4, 1, pulse_key)
      elseif pattern[i].play == 1 then
        g:led(i + 4, 1, pattern[i].flash and 15 or 12)
      elseif pattern[i].count > 0 then
        g:led(i + 4, 1, 8)
      else
        g:led(i + 4, 1, 4)
      end
    end
  end
  for i = (params:get("slot_assign") == 1 and 5 or 1), 8 do
    if params:get("slot_assign") ~= 2 then
      local b = 3
      if snapshot_mode then
        if snap[i].active == true then
          b = 11
        elseif snap[i].data == true then
          b = 7
        end
      else
        if recall[i].recording == true then
          b = 15
        elseif recall[i].active == true then
          b = 11
        elseif recall[i].has_data == true then
          b = 7
        end
      end
      g:led(i + 4, 1, b)
    end
  end
end

---------------------- REC -------------------------

v.key[vREC] = function(n, z)
  if n == 2 and z == 1 then
    if k1_hold == 0 then
      viewinfo[vREC] = 1 - viewinfo[vREC]
    else
      if params:get("slot_assign") == 2 then
        params:set("slot_assign", 3)
        show_message("recall slots")
      elseif params:get("slot_assign") == 3 then
        params:set("slot_assign", 2)
        show_message("pattern slots")
      end
    end
    dirtyscreen = true
  elseif n == 3 and z == 1 then
    if k1_hold == 0 then
      main_pageNum = (main_pageNum % 3) + 1
    else
      if arc_is then
        arc_pageNum = (arc_pageNum % 3) + 1
        if arc_pageNum == 1 then
          show_message("arc - tape")
        elseif arc_pageNum == 2 then
          show_message("arc - levels")
        else
          show_message("arc - lfos")
        end
      end
    end
    dirtyscreen = true
  end
end

v.enc[vREC] = function(n, d)
  if n == 1 then
    if k1_hold == 0 then
      main_pageNum = util.clamp(main_pageNum + d, 1, 3)
    elseif k1_hold == 1 then
      params:delta("output_level", d)
    end
    dirtyscreen = true
  end
  if main_pageNum == 1 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(track_focus.."vol", d)
      elseif n == 3 then
        params:delta(track_focus.."pan", d)
      end
    else
      if n == 2 then
        params:delta(track_focus.."rec", d)
      elseif n == 3 then
        params:delta(track_focus.."dub", d)
      end
    end
  elseif main_pageNum == 2 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(track_focus.."cutoff", d)
      elseif n == 3 then
        params:delta(track_focus.."filter_q", d)
      end
    else
      if n == 2 then
        params:delta(track_focus.."filter_type", d)
      elseif n == 3 then
        if params:get(track_focus.."filter_type") == 5 then
          return
        else
          params:delta(track_focus.."post_dry", d)
        end
      end
    end
  elseif main_pageNum == 3 then
    if viewinfo[vREC] == 0 then
      if n == 2 then
        params:delta(track_focus.."detune", d)
      elseif n == 3 then
        params:delta(track_focus.."transpose", d)
        if (view == vCUT or view == vTRSP) then dirtygrid = true end
      end
    else
      if n == 2 then
        params:delta(track_focus.."rate_slew", d)
      elseif n == 3 then
        params:delta(track_focus.."level_slew", d)
      end
    end
  end
end

v.redraw[vREC] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("TRACK "..track_focus)
  local sel = viewinfo[vREC] == 0
  local mp = 98

  if main_pageNum == 1 then
    screen.level(15)
    screen.rect(mp + 3 ,11, 5, 5)
    screen.fill()
    screen.level(k1_hold == 1 and 0 or 15)
    screen.rect(mp + 5 ,13, 1, 1)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 11, 12, 4, 4)
    screen.rect(mp + 18, 12, 4, 4)
    screen.stroke()

    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(track_focus.."vol"))
    
    screen.move(70, 32)
    screen.text("L")
    screen.move(119, 32)
    screen.text_right("R")
    if params:get(track_focus.."pan") < -0.01 then
      screen.move(96, 32)
      screen.text_right(params:string(track_focus.."pan"))
    elseif params:get(track_focus.."pan") > 0.01 then
      screen.move(92, 32)
      screen.text(params:string(track_focus.."pan")) 
    else
      screen.move(94, 32)
      screen.text_center(params:string(track_focus.."pan"))
    end
    screen.move(10, 40)
    if track[track_focus].mute == 1 then
      screen.level(15)
      screen.text("[muted]")
    else
      screen.level(3)
      screen.text("volume")
    end
    screen.level(3)
    screen.move(70, 40)
    screen.text("pan")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(track_focus.."rec"))
    screen.move(70, 52)
    screen.text(params:string(track_focus.."dub"))
    screen.level(3)
    screen.move(10, 60)
    screen.text("rec level")
    screen.move(70, 60)
    screen.text("dub level")

  elseif main_pageNum == 2 then
    screen.level(15)
    screen.rect(mp + 10, 11, 5, 5)
    screen.fill()
    screen.level(k1_hold == 1 and 0 or 15)
    screen.rect(mp + 12 ,13, 1, 1)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 4, 12, 4, 4)
    screen.rect(mp + 18, 12, 4, 4)
    screen.stroke()

    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(track_focus.."cutoff"))
    screen.move(70, 32)
    screen.text(params:string(track_focus.."filter_q"))
    screen.level(3)
    screen.move(10, 40)
    screen.text("cutoff")
    screen.move(70, 40)
    screen.text("filter q")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(track_focus.."filter_type"))
    screen.move(70, 52)
    if params:get(track_focus.."filter_type") == 5 then
      screen.text("-")
    else
      screen.text(params:string(track_focus.."post_dry"))
    end
    screen.level(3)
    screen.move(10, 60)
    screen.text("type")
    screen.move(70, 60)
    screen.text("dry level")

  elseif main_pageNum == 3 then
    screen.level(15)
    screen.rect(mp + 17, 11, 5, 5)
    screen.fill()
    screen.level(k1_hold == 1 and 0 or 15)
    screen.rect(mp + 19 ,13, 1, 1)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 4, 12, 4, 4)
    screen.rect(mp + 11, 12, 4, 4)
    screen.stroke()

    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(track_focus.."detune"))
    screen.move(70, 32)
    screen.text(params:string(track_focus.."transpose"))
    screen.level(3)
    screen.move(10, 40)
    screen.text("detune")
    screen.move(70, 40)
    screen.text("transpose")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(track_focus.."rate_slew"))
    screen.move(70, 52)
    screen.text(params:string(track_focus.."level_slew"))
    screen.level(3)
    screen.move(10, 60)
    screen.text("rate slew")
    screen.move(70, 60)
    screen.text("level slew")
  end

  -- display messages
  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

function gridkey_cutfocus(x, y, z)
  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z * 2 - 1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end
  local i = track_focus
  if z == 1 then
    if alt == 1 and alt2 == 0 then
      toggle_playback(i)
    elseif alt2 == 1 then -- "hold mode" as on cut page
      heldmax[y] = x
      local e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = x
      e.loop_end = x
      event(e)
      enc2_wait = false
    elseif held[y] == 1 then -- cut at pos
      first[y] = x
      local cut = x - 1
      local e = {} e.t = eCUT e.i = i e.pos = cut event(e)
      if params:get(i.."adsr_active") == 2 then
        local e = {} e.t = eGATEON e.i = i event(e)
      end
    elseif held[y] == 2 then -- second keypress
      second[y] = x
    end
  elseif z == 0 then
    if held[y] == 1 and heldmax[y] == 2 then -- if two keys held at release then loop
      local e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = math.min(first[y], second[y])
      e.loop_end = math.max(first[y], second[y])
      event(e)
      enc2_wait = false
    end
    if params:get(i.."play_mode") == 3 and track[i].loop == 0 and params:get(i.."adsr_active") == 1 then
      local e = {} e.t = eSTOP e.i = i event(e)
    end
    if params:get(i.."adsr_active") == 2 and track[i].loop == 0 then
      local e = {} e.t = eGATEOFF e.i = i event(e)
    end
  end
end

function gridredraw_cutfocus()
  if track[track_focus].loop == 1 then
    for x = math.floor(track[track_focus].loop_start), math.ceil(track[track_focus].loop_end) do
      g:led(x, 8, 4)
    end
  end
  if track[track_focus].play == 1 then
    g:led(track[track_focus].pos_grid, 8, 15)
  end
end

v.gridkey[vREC] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif y > 1 and y < 8 then
    local i = y - 1
    if z == 1 then
      if x > 2 and x < 7 then
        if track_focus ~= i then
          track_focus = i
          arc_track_focus = track_focus
          dirtyscreen = true
        end
        if alt == 1 and alt2 == 0 then
          track[i].tempo_map = util.wrap(track[i].tempo_map + 1, 0, 2)
          set_tempo_map(i)
        elseif alt == 0 and alt2 == 1 then
          params:set(track_focus.."buffer_sel", track[track_focus].side == 0 and 2 or 1)
        end
      elseif x == 1 and alt == 0 then
        toggle_rec(i)
      elseif x == 1 and alt == 1 then
        track[i].fade = 1 - track[i].fade
        set_rec(i)
      elseif x == 2 then
        track[i].oneshot = 1 - track[i].oneshot
        for n = 1, 6 do
          if n ~= i then
            track[n].oneshot = 0
          end
        end
        oneshot_arm = i
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
      elseif x == 16 and alt == 0 and alt2 == 0 then
        toggle_playback(i)
      elseif x == 16 and alt == 0 and alt2 == 1 then
        track[i].sel = 1 - track[i].sel
      elseif x == 16 and alt == 1 and alt2 == 0 then
        local n = 1 - track[i].mute
        local e = {} e.t = eMUTE e.i = i e.mute = n
        event(e)
      elseif x > 8 and x < 16 and alt == 0 then
        local n = x - 12
        local e = {} e.t = eSPEED e.i = i e.speed = n
        event(e)
      elseif x == 8 and alt == 0 then
        local n = 1 - track[i].rev
        local e = {} e.t = eREV e.i = i e.rev = n
        event(e)
      elseif x == 8 and alt == 1 then
        track[i].warble = 1 - track[i].warble
        update_rate(i)
      elseif x == 12 and alt == 1 then
        randomize(i)
      end
      dirtygrid = true
    end
  elseif y == 8 then -- cut for focused track
    gridkey_cutfocus(x, y, z)
  end
end

v.gridredraw[vREC] = function()
  g:all(0)
  g:led(3, track_focus + 1, 7)
  g:led(4, track_focus + 1, params:get(track_focus.."buffer_sel") == 1 and 7 or 3)
  g:led(5, track_focus + 1, params:get(track_focus.."buffer_sel") == 2 and 7 or 3)
  g:led(6, track_focus + 1, 3)
  for i = 1, 6 do
    local y = i + 1
    g:led(1, y, 3) -- rec
    if track[i].rec == 1 and track[i].fade == 1 then g:led(1, y, 15)  end
    if track[i].rec == 1 and track[i].fade == 0 then g:led(1, y, 15)  end
    if track[i].rec == 0 and track[i].fade == 1 then g:led(1, y, 6)  end
    if track[i].oneshot == 1 then g:led(2, y, pulse_key) end
    if track[i].tempo_map == 1 then g:led(6, y, 7) end
    if track[i].tempo_map == 2 then g:led(6, y, 12) end
    g:led(8, y, track[i].warble == 1 and 8 or 5) -- reverse playback
    if track[i].rev == 1 and track[i].warble == 0 then g:led(8, y, 11) end
    if track[i].rev == 1 and track[i].warble == 1 then g:led(8, y, 15) end
    g:led(16, y, 3) -- start/stop
    if track[i].play == 1 and track[i].sel == 1 then g:led(16, y, 15) end
    if track[i].play == 1 and track[i].sel == 0 then g:led(16, y, 10) end
    if track[i].play == 0 and track[i].sel == 1 then g:led(16, y, 5) end
    g:led(12, y, 3) -- speed = 1
    g:led(12 + track[i].speed, y, 9)
  end
  gridredraw_cutfocus()
  gridredraw_nav()
  g:refresh()
end

local inc = 0

v.arcdelta[vREC] = function(n, d)
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
        if view < vLFO then dirtygrid = true end
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
      if view < vLFO then dirtygrid = true end
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
      if view < vLFO then dirtygrid = true end
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
  elseif arc_pageNum == 3 then
    arcdelta_lfo(n, d)
  end
end

v.arcredraw[vREC] = function()
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
  elseif arc_pageNum == 3 then
    arcredraw_lfo()
  end
  a:refresh()
end

---------------------CUT-----------------------

v.key[vCUT] = v.key[vREC]
v.enc[vCUT] = v.enc[vREC]
v.redraw[vCUT] = v.redraw[vREC]
v.arcdelta[vCUT] = v.arcdelta[vREC]
v.arcredraw[vCUT] = v.arcredraw[vREC]

v.gridkey[vCUT] = function(x, y, z)
  if z == 1 and held[y] then heldmax[y] = 0 end
  held[y] = held[y] + (z * 2 - 1)
  if held[y] > heldmax[y] then heldmax[y] = held[y] end
  if y == 1 then gridkey_nav(x, z)
  elseif y == 8 and z == 1 then
    local i = track_focus
    if alt2 == 0 then
      if x >= 1 and x <=8 then local e = {} e.t = eTRSP e.i = i e.val = x event(e) end
      if x >= 9 and x <=16 then local e = {} e.t = eTRSP e.i = i e.val = x - 1 event(e) end
    elseif alt2 == 1 then
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
      elseif alt2 == 1 and y < 8 then -- "hold mode"
        heldmax[y] = x
        local e = {}
        e.t = eLOOP
        e.i = i
        e.loop = 1
        e.loop_start = x
        e.loop_end = x
        event(e)
        enc2_wait = false
      elseif y < 8 and held[y] == 1 then
        first[y] = x
        local cut = x - 1
        local e = {} e.t = eCUT e.i = i e.pos = cut event(e)
        if params:get(i.."adsr_active") == 2 then
          local e = {} e.t = eGATEON e.i = i event(e)
        end
      elseif y < 8 and held[y] == 2 then
        second[y] = x
      end
    elseif z == 0 then
      if y < 8 then 
        if held[y] == 1 and heldmax[y] == 2 then
          local e = {}
          e.t = eLOOP
          e.i = i
          e.loop = 1
          e.loop_start = math.min(first[y], second[y])
          e.loop_end = math.max(first[y], second[y])
          event(e)
          enc2_wait = false
        else
          if params:get(i.."play_mode") == 3 and track[i].loop == 0 and params:get(i.."adsr_active") == 1 then
            local e = {} e.t = eSTOP e.i = i event(e)
          end
          if params:get(i.."adsr_active") == 2 and track[i].loop == 0 then
            local e = {} e.t = eGATEOFF e.i = i event(e)
          end
        end
      end
    end
  end
end

v.gridredraw[vCUT] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    if track[i].loop == 1 then
      for x = math.floor(track[i].loop_start), math.ceil(track[i].loop_end) do
        g:led(x, i + 1, 4)
      end
    end
    if track[i].play == 1 then
      g:led(track[i].pos_grid, i + 1, track_focus == i and 15 or 10)
    end
  end
  g:led(8, 8, 6)
  g:led(9, 8, 6)
  if track[track_focus].transpose < 0 then
    g:led(params:get(track_focus.."transpose"), 8, 10)
  elseif track[track_focus].transpose > 0 then
    g:led(params:get(track_focus.."transpose") + 1, 8, 10)
  end
  g:refresh()
end

--------------------TRANSPOSE--------------------

v.key[vTRSP] = v.key[vREC]
v.enc[vTRSP] = v.enc[vREC]
v.redraw[vTRSP] = v.redraw[vREC]
v.arcdelta[vTRSP] = v.arcdelta[vREC]
v.arcredraw[vTRSP] = v.arcredraw[vREC]

v.gridkey[vTRSP] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z)
  elseif y > 1 and y < 8 then
    if z == 1 then
      local i = y - 1
      if track_focus ~= i then
        track_focus = i
        arc_track_focus = track_focus
        dirtyscreen = true
      end
      if alt == 0 and alt2 == 0 then
        if x >= 1 and x <=8 then local e = {} e.t = eTRSP e.i = i e.val = x event(e) end
        if x >= 9 and x <=16 then local e = {} e.t = eTRSP e.i = i e.val = x - 1 event(e) end
      end
      if alt == 1 and x > 7 and x < 10 then
        toggle_playback(i)
      end
      if alt2 == 1 then
        if x == 8 then
          local n = util.clamp(track[i].speed - 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
        elseif x == 9 then
          local n = util.clamp(track[i].speed + 1, -3, 3) local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
        end
      end
    end
  elseif y == 8 then -- cut for focused track
    gridkey_cutfocus(x, y, z)
  end
end

v.gridredraw[vTRSP] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    g:led(8, i + 1, track_focus == i and 10 or 6)
    g:led(9, i + 1, track_focus == i and 10 or 6)
    if track[i].transpose < 0 then
      g:led(params:get(i.."transpose"), i + 1, 10)
    elseif track[i].transpose > 0 then
      g:led(params:get(i.."transpose") + 1, i + 1, 10)
    end
  end
  gridredraw_cutfocus()
  g:refresh()
end

---------------------- LFO -------------------------

v.key[vLFO] = function(n, z)
  if n == 2 and z == 1 then
    viewinfo[vLFO] = 1 - viewinfo[vLFO]
  elseif n == 3 and z == 1 then
    lfo_focus = (lfo_focus % 6) + 1
    arc_lfo_focus = lfo_focus
  end
  dirtyscreen = true
end

v.enc[vLFO] = function(n, d)
  if n == 1 then
    if k1_hold == 0 then
      lfo_focus = util.clamp(lfo_focus + d, 1, 6)
      arc_lfo_focus = lfo_focus
    elseif k1_hold == 1 then
      params:delta("output_level", d)
    end
  end
  if viewinfo[vLFO] == 0 then
    if n == 2 then
      params:delta(lfo_focus.."lfo_freq", d)
    elseif n == 3 then
      params:delta(lfo_focus.."lfo_offset", d)
    end
  else
    if n == 2 then
      params:delta(lfo_focus.."lfo_target", d)
    elseif n == 3 then
      if alt == 0 then
        params:delta(lfo_focus.."lfo_shape", d)
      else
        params:delta(lfo_focus.."lfo_range", d)
      end
    end
  end
end

v.redraw[vLFO] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("LFO "..lfo_focus)
  local sel = viewinfo[vLFO] == 0

  screen.level(sel and 15 or 4)
  screen.move(10, 32)
  screen.text(params:string(lfo_focus.."lfo_freq"))
  screen.move(70, 32)
  screen.text(params:string(lfo_focus.."lfo_offset"))
  screen.level(3)
  screen.move(10, 40)
  screen.text("freq")
  screen.move(70, 40)
  screen.text("offset")

  screen.level(not sel and 15 or 4)
  screen.move(10, 52)
  screen.text(params:string(lfo_focus.."lfo_target"))
  screen.move(70, 52)
  if alt == 0 then
    screen.text(params:string(lfo_focus.."lfo_shape"))
  else
    screen.text(params:string(lfo_focus.."lfo_range"))
  end
  screen.level(3)
  screen.move(10, 60)
  screen.text("lfo target")
  screen.move(70, 60)
  if alt == 0 then
    screen.text("shape")
  else
    screen.text("range")
  end

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vLFO] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z) end
  if z == 1 then
    if y > 1 and y < 8 then
      local i = y - 1
      if lfo_focus ~= i then
        lfo_focus = i
        arc_lfo_focus = lfo_focus
      end
      if x == 1 then
        lfo[lfo_focus].active = 1 - lfo[lfo_focus].active
        if lfo[lfo_focus].active == 1 then
          params:set(lfo_focus .. "lfo_state", 2)
        else
          params:set(lfo_focus .. "lfo_state", 1)
        end
      end
      if x > 1 and x <= 16 then
        params:set(lfo_focus.."lfo_depth", (x - 2) * util.round_up((100 / 14), 0.1))
      end
    end
    if y == 8 then
      if x >= 1 and x <= 3 then
        if alt == 0 then
          params:set(lfo_focus.."lfo_shape", x)
        elseif alt == 1 then
          params:set(lfo_focus.."lfo_range", x)
        end
      end
      if x > 3 and x < 10 then
        trksel = 6 * (x - 4)
      end
      if x == 10 then
        params:set(lfo_focus.."lfo_target", 1)
      end
      if x > 10 and x <= 16 then
        dstview = 1
        params:set(lfo_focus.."lfo_target", trksel + x - 9)
      end
    end
  elseif z == 0 then
    if x > 10 and x <= 16 then
      dstview = 0
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

v.gridredraw[vLFO] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    g:led(1, i + 1, params:get(i.."lfo_state") == 2 and math.floor(util.linlin( -1, 1, 6, 15, lfo[i].slope)) or 3) --nice one mat!
    local range = math.floor(util.linlin(0, 100, 2, 16, params:get(i.."lfo_depth")))
    g:led(range, i + 1, 7)
    for x = 2, range - 1 do
      g:led(x, i + 1, 3)
    end
    g:led(i + 3, 8, 4)
    g:led(i + 10, 8, 4)
  end
  if alt == 0 then
    g:led(params:get(lfo_focus.."lfo_shape"), 8, 5)
  elseif alt == 1 then
    g:led(params:get(lfo_focus.."lfo_range"), 8, 5)
  end
  g:led(trksel / 6 + 4, 8, 12)
  if dstview == 1 then
    g:led((params:get(lfo_focus.."lfo_target") + 9) - trksel, 8, 12)
  end
  g:refresh()
end

v.arcdelta[vLFO] = function(n, d)
  arcdelta_lfo(n, d)
  if view == vLFO then dirtyscreen = true end
end

v.arcredraw[vLFO] = function()
  a:all(0)
  arcredraw_lfo()
  a:refresh()
end

function arcdelta_lfo(n, d)
  if n == 1 then
    params:delta(lfo_focus.."lfo_freq", d / 20)
  elseif n == 2 then
    params:delta(lfo_focus.."lfo_depth", d / 10)
    if params:get(lfo_focus.."lfo_depth") > 0 and params:get(lfo_focus.."lfo_state") ~= 2 then
      params:set(lfo_focus.."lfo_state", 2)
      lfo[lfo_focus].active = 1
    elseif params:get(lfo_focus.."lfo_depth") == 0 then
      params:set(lfo_focus.."lfo_state", 1)
      lfo[lfo_focus].active = 0
    end
  elseif n == 3 then
    params:delta(lfo_focus.."lfo_offset", d / 20)
  elseif n == 4 then
    arc_lfo_focus = util.clamp(arc_lfo_focus + d / 100, 1, 6)
    lfo_focus = math.floor(arc_lfo_focus)
  end
end

function arcredraw_lfo()
  -- draw lfo freq
  local lfo_frq = math.floor(util.linlin(0.1, 10, 0, 1, params:get(lfo_focus.."lfo_freq")) * 48) + 41
  a:led (1, 25 - arc_off, 5)
  a:led (1, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < lfo_frq - 64 then
      a:led(1, i - arc_off, 3)
    end
  end
  a:led(1, lfo_frq - arc_off, 15)
  -- draw lfo lfo depth
  local lfo_dth = math.floor((params:get(lfo_focus.."lfo_depth") / 100) * 48) + 41
  a:led (2, 25 - arc_off, 5)
  a:led (2, -23 - arc_off, 5)
  for i = -22, 24 do
    if i < lfo_dth - 64 then
      a:led(2, i - arc_off, 3)
    end
  end
  a:led(2, lfo_dth - arc_off, 15)
  -- draw lfo offset
  local lfo_off = math.floor(params:get(lfo_focus.."lfo_offset") * 24)
  a:led (3, 1 - arc_off, 7)
  a:led (3, 25 - arc_off, 5)
  a:led (3, -23 - arc_off, 5)
  if lfo_off > 0 then
    for i = 2, lfo_off do
      a:led(3, i - arc_off, 4)
    end
  elseif lfo_off < 0 then
    for i = lfo_off + 2, 0 do
      a:led(3, i - arc_off, 4)
    end
  end
  a:led (3, lfo_off + 1 - arc_off, 15)
  -- draw lfo selection
  for i = 1, 6 do
    local off = -13
    for j = 0, 5 do
      a:led(4, (i + off) + j * 7 - 7 - arc_off, 4)
    end
    a:led(4, (i + (lfo_focus - 1) * 7 - 6) + 50 - arc_off, 15)
  end
  -- draw lfo targets
  local tar = params:get(lfo_focus.."lfo_target")
  local name = string.sub(lfo_targets[tar], 2)
  for i = 1, 6 do
    a:led(4, -i + 7 + 33 - arc_off, (tar >= i + (i - 1) * 5 + 1 and tar <= i + (i - 1) * 5 + 6) and 15 or 2) -- track num
  end
  a:led(4, -1 + 33 - arc_off, name == "vol" and 15 or 6)
  a:led(4, -2 + 33 - arc_off, name == "pan" and 15 or 6)
  a:led(4, -3 + 33 - arc_off, name == "dub" and 15 or 6)
  a:led(4, -4 + 33 - arc_off, name == "transpose" and 15 or 6)
  a:led(4, -5 + 33 - arc_off, name == "rate_slew" and 15 or 6)
  a:led(4, -6 + 33 - arc_off, name == "cutoff" and 15 or 6)
end

---------------------ENVELOPES-----------------------

v.key[vENV] = function(n, z)
  if n == 2 and z == 1 then
    viewinfo[vENV] = 1 - viewinfo[vENV]
  elseif n == 3 and z == 1 then
    env_focus = (env_focus % 6) + 1
    dirtygrid = true
  end
  dirtyscreen = true
end

v.enc[vENV] = function(n, d)
  if n == 1 then
    if k1_hold == 0 then
      env_focus = util.clamp(env_focus + d, 1, 6)
      dirtyscreen = true
    elseif k1_hold == 1 then
      --
    end
  end
  if k1_hold == 1 then
    if n == 2 then
      params:delta(env_focus.."adsr_amp", d)
    elseif n == 3 then
      params:delta(env_focus.."adsr_init", d)
    end
  else
    if viewinfo[vENV] == 0 then
      if n == 2 then
        params:delta(env_focus.."adsr_attack", d)
      elseif n == 3 then
        params:delta(env_focus.."adsr_decay", d)
      end
    else
      if n == 2 then
        params:delta(env_focus.."adsr_sustain", d)
      elseif n == 3 then
        params:delta(env_focus.."adsr_release", d)
      end
    end
  end
end

v.redraw[vENV] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("ENVELOPE "..env_focus)
  local sel = viewinfo[vENV] == 0

  if k1_hold == 0 then
    screen.level(sel and 15 or 4)
    screen.move(10, 32)
    screen.text(params:string(env_focus.."adsr_attack"))
    screen.move(70, 32)
    screen.text(params:string(env_focus.."adsr_decay"))
    screen.level(3)
    screen.move(10, 40)
    screen.text("attack")
    screen.move(70, 40)
    screen.text("decay")

    screen.level(not sel and 15 or 4)
    screen.move(10, 52)
    screen.text(params:string(env_focus.."adsr_sustain"))
    screen.move(70, 52)
    screen.text(params:string(env_focus.."adsr_release"))
    screen.level(3)
    screen.move(10, 60)
    screen.text("sustain")
    screen.move(70, 60)
    screen.text("release")
  else
    screen.level(15)
    screen.move(10, 32)
    screen.text(params:string(env_focus.."adsr_amp"))
    screen.move(70, 32)
    screen.text(params:string(env_focus.."adsr_init"))
    screen.level(3)
    screen.move(10, 40)
    screen.text("max level")
    screen.move(70, 40)
    screen.text("min level")
  end

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vENV] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z) end
  if z == 1 then
    if y > 1 and y < 8 then
      local i = y - 1
      if x == 1 then
        state = params:get(i.."adsr_active") == 1 and 2 or 1
        params:set(i.."adsr_active", state)
      elseif x == 2 then
        if env_focus ~= i then
          env_focus = i
        end
        if params:get(i.."adsr_active") == 2 then
          local e = {} e.t = eGATEON e.i = i event(e)
        end
      end
    end
  elseif z == 0 then
    if y > 1 and y < 8 then
      local i = y - 1
      if x == 2 then
        if params:get(i.."adsr_active") == 2 then
          local e = {} e.t = eGATEOFF e.i = i event(e)
        end
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

v.gridredraw[vENV] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 6 do
    g:led(1, i + 1, params:get(i.."adsr_active") == 2 and 10 or 3)
    local range = math.floor(util.linlin(1, 100, 2, 16, params:get(i.."vol") * 100))
    if params:get(i.."adsr_active") == 2 then
      g:led(range, i + 1, 7)
      for x = 2, range - 1 do
        g:led(x, i + 1, 3)
      end
    end
    g:led(2, i + 1, env_focus == i and 10 or 6)
  end
  g:refresh()
end

v.arcdelta[vENV] = function(n, d)
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

v.arcredraw[vENV] = function()
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

---------------------PATTERNS-----------------------

v.key[vPATTERNS] = function(n, z)
  if n == 2 and z == 1 then
    viewinfo[vPATTERNS] = 1 - viewinfo[vPATTERNS]
  elseif n == 3 and z == 1 then
    pattern_focus = (pattern_focus % 8) + 1
    dirtygrid = true
  end
  dirtyscreen = true
end

v.enc[vPATTERNS] = function(n, d)
  if n == 1 then
    pattern_focus = util.clamp(pattern_focus + d, 1, 8)
  end
  if viewinfo[vPATTERNS] == 0 then
    if pattern[pattern_focus].synced then
      if n == 2 then
        params:delta("patterns_meter"..pattern_focus, d)
      elseif n == 3 then
        params:delta("patterns_countin"..pattern_focus, d)
      end
    end
  else
    if n == 2 and pattern[pattern_focus].synced then
      params:delta("patterns_barnum"..pattern_focus, d)
    elseif n == 3 then
      params:delta("patterns_playback"..pattern_focus, d)
    end
  end
  dirtygrid = true
  dirtyscreen = true
end

v.redraw[vPATTERNS] = function()
  screen.clear()
  local sel = viewinfo[vPATTERNS] == 0
  screen.level(15)
  screen.move(10, 16)
  screen.text("PATTERN "..pattern_focus)
  screen.move(116, 16)
  screen.text_right(params:string("quant_div"))
  screen.level(4)
  screen.move(120, 16)
  screen.text("Q")
  
  screen.level(sel and 15 or 4)
  screen.move(10, 32)
  local idx = tab.key(pattern_meter_val, pattern[pattern_focus].sync_meter)
  screen.text(pattern[pattern_focus].synced and pattern_meter[idx] or "-")
  screen.move(70, 32)
  screen.text(pattern[pattern_focus].synced and (pattern[pattern_focus].count_in == 1 and "beat" or "bar") or "-")
  screen.level(3)
  screen.move(10, 40)
  screen.text("meter")
  screen.move(70, 40)
  screen.text("count in")

  screen.level(not sel and 15 or 4)
  screen.move(10, 52)
  screen.text(pattern[pattern_focus].synced and params:string("patterns_barnum"..pattern_focus) or "manual")
  screen.move(70, 52)
  screen.text(pattern[pattern_focus].loop and "loop" or "oneshot")
  screen.level(3)
  screen.move(10, 60)
  screen.text("length")
  screen.move(70, 60)
  screen.text("play mode")

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vPATTERNS] = function(x, y, z)
  if y == 1 then gridkey_nav(x, z) end
  if z == 1 then
    if x > 1 and x < 4 then
      if y > 2 and y < 6 then
        params:set("slot_assign", y - 2)
      elseif y == 6 then
        snapshot_mode = not snapshot_mode
      end
    elseif x > 4 and x < 13 then
      local i = x - 4
      -- set track_focus
      if y < 7 then
        if pattern_focus ~= i then
          pattern_focus = i
        end
      end
      -- set params
      if y == 2 then
        pattern[i].synced = not pattern[i].synced
      elseif y == 3 then
        if pattern[i].synced then 
          params:set("patterns_countin"..i, pattern[i].count_in == 1 and 2 or 1)
        end
      elseif y == 7 and pattern[pattern_focus].synced then
        params:set("patterns_barnum"..pattern_focus, i)
      elseif y == 8 and pattern[pattern_focus].synced then
        params:set("patterns_barnum"..pattern_focus, i + 8)
      end
    elseif x > 13 and x < 16 then
      if y > 2 and y < 7 then
        local val = (y - 2) + (x - 14) * 4
        params:set("quant_div", val)
      end
    end
  end
  dirtyscreen = true
  dirtygrid = true
end

v.gridredraw[vPATTERNS] = function()
  g:all(0)
  gridredraw_nav()
  for i = 1, 2 do
    local x = i + 1
    g:led(x, 3, params:get("slot_assign") == 1 and 10 or 4)
    g:led(x, 4, params:get("slot_assign") == 2 and 10 or 4)
    g:led(x, 5, params:get("slot_assign") == 3 and 10 or 4)
    g:led(x, 6, snapshot_mode and 4 or 10)
  end
  for i = 1, 8 do
    g:led(i + 4, 2, pattern[i].synced and 10 or 4)
    g:led(i + 4, 3, pattern[i].synced and (pattern[i].count_in == 4 and 6 or 2) or 0)
    g:led(i + 4, 4, pattern_focus == i and 8 or 0)
    g:led(i + 4, 5, pattern_focus == i and 8 or 0)
    g:led(i + 4, 7, pattern[pattern_focus].synced and (params:get("patterns_barnum"..pattern_focus) == i and 15 or 8) or 4)
    g:led(i + 4, 8, pattern[pattern_focus].synced and (params:get("patterns_barnum"..pattern_focus) == i + 8 and 15 or 8) or 4)
  end
  for i = 1, 2 do
    local x = i + 13
    for j = 1, 4 do
      local y = j + 2
      g:led(x, y, params:get("quant_div") == (y - 2) + (x - 14) * 4 and 10 or 4)
    end
  end
  g:refresh()
end

v.arcdelta[vPATTERNS] = function(n, d)
  -- do nothing yet
end

v.arcredraw[vPATTERNS] = function()
  a:all(0)
  -- nothing to see
  a:refresh()
end

---------------------CLIP-----------------------

function fileselect_callback(path, i)
  if path ~= "cancel" and path ~= "" then
    local ch, len = audio.file_info(path)
    local buffer = params:get(i.."buffer_sel")
    if ch > 0 and len > 0 then
      softcut.buffer_read_mono(path, 0, tape[i].splice[track[i].splice_focus].s, -1, 1, buffer)
      local max_length = tape[i].e - tape[i].splice[track[i].splice_focus].s
      local length = math.min(len / 48000, max_length)
      -- set splice   
      tape[i].splice[track[i].splice_focus].l = length
      tape[i].splice[track[i].splice_focus].e = tape[i].splice[track[i].splice_focus].s + length
      tape[i].splice[track[i].splice_focus].init_start = tape[i].splice[track[i].splice_focus].s
      tape[i].splice[track[i].splice_focus].init_len = length
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

function textentry_callback(txt)
  local buffer = params:get(track_focus.."buffer_sel")
  if txt then
    local start = tape[track_focus].splice[track[track_focus].splice_focus].s
    local length = tape[track_focus].splice[track[track_focus].splice_focus].l
    print("SAVE " .. _path.audio .. "mlre/" .. txt .. ".wav", start, length)
    util.make_dir(_path.audio .. "mlre")
    softcut.buffer_write_mono(_path.audio.."mlre/"..txt..".wav", start, length, buffer)
    tape[track_focus].splice[track[track_focus].splice_focus].name = txt
  else
    print("save cancel")
  end
  screenredrawtimer:start()
  dirtyscreen = true
end

local function truncateMiddle(str, maxLength, separator)
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

function edit_splices(n, d, src, sens)
  -- set local variables
  local render = false
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
    if arc_render == 10 then render = true end
    if render then
      render_splice()
      render = false
    end
  end
end

v.key[vCLIP] = function(n, z)
  if tape_pageNum < 3 then
    -- tape view
    if k1_hold == 0 then
      if n == 2 and z == 0 then
        if tape_actions[tape_action] == "load" then
          screenredrawtimer:stop()
          fileselect.enter(os.getenv("HOME").."/dust/audio", function(n) fileselect_callback(n, track_focus) end)
        elseif tape_actions[tape_action] == "clear" then
          clear_splice(track_focus)
        elseif tape_actions[tape_action] == "save" then
          screenredrawtimer:stop()
          textentry.enter(textentry_callback, "mlre-" .. (math.random(9000) + 1000))
        elseif tape_actions[tape_action] == "copy" then
          copy_track = track_focus
          copy_splice = track[track_focus].splice_focus
          show_message("copied to clipboard")
        elseif tape_actions[tape_action] == "paste" then
          local paste_track = track_focus
          local paste_splice = track[track_focus].splice_focus
          if copy_splice ~= nil then
            local src_ch = params:get(copy_track.."buffer_sel")
            local dst_ch = params:get(paste_track.."buffer_sel")
            local start_src = tape[copy_track].splice[copy_splice].s
            local start_dst = tape[paste_track].splice[paste_splice].s
            local length = tape[copy_track].splice[copy_splice].e - tape[copy_track].splice[copy_splice].s
            local preserve = alt == 1 and 0.5 or 0
            if tape[paste_track].splice[paste_splice].e + length <= tape[paste_track].e then
              softcut.buffer_copy_mono(src_ch, dst_ch, start_src, start_dst, length, 0.01, preserve)
              --tape[paste_track].splice[paste_splice] = {table.unpack(tape[copy_track].splice[copy_splice])}
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
              show_message("out of boundries")
            end
          else
            show_message("clipboard empty")
          end
        end
      elseif n == 3 and z == 1 then
        -- set barnum
        tape[track_focus].splice[track[track_focus].splice_focus].beatnum = resize_values[params:get(track_focus.."splice_length")]
        splice_resize(track_focus, track[track_focus].splice_focus)
        render_splice()
      end
    else
      if n == 2 and z == 1 then
        tape[track_focus].splice[track[track_focus].splice_focus].init_len = tape[track_focus].splice[track[track_focus].splice_focus].l
        tape[track_focus].splice[track[track_focus].splice_focus].init_start = tape[track_focus].splice[track[track_focus].splice_focus].s
        show_message("default markers set")
      elseif n == 3 and z == 1 then
        splice_reset(track_focus, track[track_focus].splice_focus)
        render_splice()
      end
    end
  end
end

v.enc[vCLIP] = function(n, d)
  if n == 1 then
    tape_pageNum = util.clamp(tape_pageNum + d, 1, 3)
    if tape_pageNum == 1 then render_splice() end
  end
  if tape_pageNum < 3 then
    if k1_hold == 0 then
      if n == 2 then
        tape_action = util.clamp(tape_action + d, 1, #tape_actions)
      elseif n == 3 then
        params:delta(track_focus.."splice_length", d)
      end
    else
      local src = "enc"
      local sens = 50
      edit_splices(n, d, src, sens)
    end
  elseif tape_pageNum == 3 then
    if n == 2 and track_focus < 5 then
      params:delta(track_focus.."send_track5", d)
    elseif n == 3 and track_focus < 6 then
      params:delta(track_focus.."send_track6", d)
    end
  end
  dirtyscreen = true
end

v.redraw[vCLIP] = function()
  screen.clear()
  screen.level(15)
  screen.move(10, 16)
  screen.text("TRACK "..track_focus)
  local mp = 98

  if tape_pageNum == 1 then
    screen.level(15)
    screen.rect(mp + 3 ,11, 5, 5)
    screen.fill()
    screen.level(k1_hold == 1 and 0 or 15)
    screen.rect(mp + 5 ,13, 1, 1)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 11, 12, 4, 4)
    screen.rect(mp + 18, 12, 4, 4)
    screen.stroke()

    screen.level(15)
    screen.move(10, 60)
    screen.text("SPLICE "..track[track_focus].splice_focus)
    screen.level(4)
    screen.move(57, 60)
    if k1_hold == 0 then
      screen.text_center(tape_actions[tape_action])
    else
      screen.text_center("set")
    end

    screen.level(15)
    screen.move(72, 60)
    screen.text("length")
    if k1_hold == 0 then
      screen.level(resize_values[params:get(track_focus.."splice_length")] == tape[track_focus].splice[track[track_focus].splice_focus].beatnum and 15 or 4)
      screen.move(120, 60)
      screen.text_right(params:string(track_focus.."splice_length"))
    else
      screen.level(4)
      screen.move(107, 60)
      screen.text(">|")
    end
    -- display buffer
    screen.level(6)
    local x_pos = 0
    for i, s in ipairs(waveform_samples) do
      local height = util.round(math.abs(s) * (12 / wave_gain))
      screen.move(util.linlin(0, 128, 11, 120, x_pos), 38 - height)
      screen.line_rel(0, 2 * height)
      screen.stroke()
      x_pos = x_pos + 1
    end
    screen.stroke()
    -- update buffer
    if track[track_focus].rec == 1 then
      render_splice()
    end
    -- display position
    if track[track_focus].splice_focus == track[track_focus].splice_active then
      screen.level(15)
      if view_buffer then
        screen.move(math.floor(util.linlin(0, 1, 11, 120, track[track_focus].pos_clip)), 27)
      else
        screen.move(math.floor(util.linlin(0, 1, 11, 120, track[track_focus].pos_rel)), 27)
      end
      screen.line_rel(0, 23)
      screen.stroke()
    end
    -- display boundries
    screen.level(10)
    screen.move(10, 22)
    screen.line_rel(110, 0)
    screen.move(10, 27)
    screen.line_rel(110, 0)
    screen.move(10, 51)
    screen.line_rel(110, 0)
    screen.stroke()
    
    -- display splice markers
    local splice_start = tape[track_focus].splice[track[track_focus].splice_focus].s
    local splice_end = tape[track_focus].splice[track[track_focus].splice_focus].e
    local startpos = util.linlin(tape[track_focus].s, tape[track_focus].e, 11, 120, splice_start)
    local endpos = util.linlin(tape[track_focus].s, tape[track_focus].e, 11, 120, splice_end)
    screen.level(2)
    screen.rect(startpos, 22, endpos - startpos, 4)
    screen.fill()
    screen.level(15)
    screen.move(startpos, 22)
    screen.line_rel(0, 4)
    screen.move(endpos, 22)
    screen.line_rel(0, 4)
    screen.stroke()
    -- display position
    screen.level(15)
    screen.move(math.floor(util.linlin(0, 1, 11, 120, track[track_focus].pos_clip)), 22)
    screen.line_rel(0, 4)
    screen.stroke()

  elseif tape_pageNum == 2 then
    screen.level(15)
    screen.rect(mp + 10, 11, 5, 5)
    screen.fill()
    screen.level(k1_hold == 1 and 0 or 15)
    screen.rect(mp + 12 ,13, 1, 1)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 4, 12, 4, 4)
    screen.rect(mp + 18, 12, 4, 4)
    screen.stroke()
    
    screen.level(15)
    screen.move(10, 60)
    screen.text("SPLICE "..track[track_focus].splice_focus)
    screen.level(4)
    screen.move(57, 60)
    if k1_hold == 0 then
      screen.text_center(tape_actions[tape_action])
    else
      screen.text_center("set")
    end

    screen.level(15)
    screen.move(72, 60)
    screen.text("length")
    if k1_hold == 0 then
      screen.level(resize_values[params:get(track_focus.."splice_length")] == tape[track_focus].splice[track[track_focus].splice_focus].beatnum and 15 or 4)
      screen.move(120, 60)
      screen.text_right(params:string(track_focus.."splice_length"))
    else
      screen.level(4)
      screen.move(107, 60)
      screen.text(">|")
    end

    screen.level(8)
    screen.move(10, 32)
    screen.text(">> "..truncateMiddle(tape[track_focus].splice[track[track_focus].splice_focus].name, 18))
    screen.level(4)
    screen.move(64, 46)
    screen.text_center("-- "..tape[track_focus].splice[track[track_focus].splice_focus].info.." --")
    screen.move(10, 60)

  elseif tape_pageNum == 3 then
    screen.level(15)
    screen.rect(mp + 17, 11, 5, 5)
    screen.fill()
    screen.level(k1_hold == 1 and 0 or 15)
    screen.rect(mp + 19 ,13, 1, 1)
    screen.fill()
    screen.level(6)
    screen.rect(mp + 4, 12, 4, 4)
    screen.rect(mp + 11, 12, 4, 4)
    screen.stroke()

    if track_focus < 5 then
      screen.level(15)
      screen.move(38, 32)
      screen.text_center(params:string(track_focus.."send_track5"))
      screen.level(3)
      screen.move(38, 42)
      screen.text_center("send level")
      screen.move(38, 50)
      screen.text_center("to track 5")
    else
      screen.level(3)
      screen.move(38, 42)
      screen.text_center("---")
    end

    if track_focus < 6 then
      screen.level(15)
      screen.move(90, 32)
      screen.text_center(params:string(track_focus.."send_track6"))
      screen.level(3)
      screen.move(90, 42)
      screen.text_center("send level")
      screen.move(90, 50)
      screen.text_center("to track 6")
    else
      screen.level(3)
      screen.move(90, 42)
      screen.text_center("---")
    end
  end

  if view_message ~= "" then
    screen.clear()
    screen.level(10)
    screen.rect(0, 25, 129, 16)
    screen.stroke()
    screen.level(15)
    screen.move(64, 25 + 10)
    screen.text_center(view_message)
  end

  screen.update()
end

v.gridkey[vCLIP] = function(x, y, z)

  if y == 1 then gridkey_nav(x, z)
  elseif y > 1 and y < 8 then
    local i = y - 1
    if x < 9 and z == 1 then
      track_focus = i
      arc_track_focus = track_focus
      track[track_focus].splice_focus = x
      arc_splice_focus = track[track_focus].splice_focus
      if alt == 1 and alt2 == 0 then
        local e = {} e.t = eSPLICE e.i = track_focus e.active = x event(e)
      elseif alt == 0 and alt2 == 1 then
        local src = track[track_focus].side == 0 and 1 or 2
        local dst = track[track_focus].side == 0 and 2 or 1
        copy_buffer(track_focus, src, dst)
      end
      render_splice()
    elseif x == 9 then
      track_focus = i
      arc_track_focus = track_focus
      view_buffer = z == 1 and true or false
      render_splice()
    elseif x == 10 and z == 1 then
      params:set(i.."buffer_sel", track[track_focus].side == 0 and 2 or 1)
      if track_focus == i then
        render_splice()
      end
    elseif x == 12 and z == 1 then
      local input = params:get(i.."input_options")
      if input == 1 then
        params:set(i.."input_options", 3)
      elseif input == 2 then
        params:set(i.."input_options", 4)
      elseif input == 3 then
        params:set(i.."input_options", 1)
      elseif input == 4 then 
        params:set(i.."input_options", 2)
      end
    elseif x == 13 and z == 1 then
      local input = params:get(i.."input_options")
      if input == 1 then
        params:set(i.."input_options", 2)
      elseif input == 2 then
        params:set(i.."input_options", 1)
      elseif input == 3 then
        params:set(i.."input_options", 4)
      elseif input == 4 then 
        params:set(i.."input_options", 3)
      end
    elseif x == 15 and z == 1 then
      if y < 6 then
        route[i].t5 = 1 - route[i].t5
        local e = {} e.t = eROUTE e.i = i e.ch = 5 e.route = route[i].t5 event(e)
      elseif y == 7 then
        route_adc = 1 - route_adc
        set_track_source()
      end
    elseif x == 16 and z == 1 then
      if y < 7 then
        route[i].t6 = 1 - route[i].t6
        local e = {} e.t = eROUTE e.i = i e.ch = 6 e.route = route[i].t6 event(e)
      elseif y == 7 then
        route_tape = 1 - route_tape
        set_track_source()
      end
    end
  elseif y == 8 then
    gridkey_cutfocus(x, y, z)
  end
  dirtyscreen = true
  dirtygrid = true
end

v.gridredraw[vCLIP] = function()
  g:all(0)
  gridredraw_nav()
  gridredraw_cutfocus()
  -- splice selection
  for i = 1, 8 do
    g:led(i, track_focus + 1, 2)
    for j = 1, 6 do
      if i == track[j].splice_active then
        g:led(i, j + 1, 12)
      elseif i == track[j].splice_focus then
        g:led(i, j + 1, 5)
      end
    end
  end
  -- buffer selection
  for i = 1, 6 do
    g:led(10, i + 1, track[i].side == 1 and 4 or 10)
  end
  -- input selection
  for i = 1, 6 do
    g:led(12, i + 1, (params:get(i.."input_options") == 1 or params:get(i.."input_options") == 2) and 8 or 4)
    g:led(13, i + 1, (params:get(i.."input_options") == 1 or params:get(i.."input_options") == 3) and 8 or 4)
  end
  -- routing
  for i = 1, 4 do
    local y = i + 1
    g:led(15, y, route[i].t5 == 1 and 9 or 2)
  end
  for i = 1, 5 do
    local y = i + 1
    g:led(16, y, route[i].t6 == 1 and 9 or 2)
  end
  g:led(15, 7, route_adc == 1 and 11 or 5)
  g:led(16, 7, route_tape == 1 and 11 or 5)
  g:refresh()
end

v.arcdelta[vCLIP] = function(n, d)
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
    local sens = 500
    local src = "arc"
    edit_splices(n, d, src, sens)
  end
end

v.arcredraw[vCLIP] = function()
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
  local pos_startpoint = math.floor(util.linlin(0, max_tapelength, 0, 1, splice_s) * 58)
  local pos_endpoint = math.ceil(util.linlin(0, max_tapelength, 0, 1, splice_l) * 58)
  a:led(3, -28 - arc_off, 6)
  a:led(3, 30 - arc_off, 6)
  for i = pos_startpoint, pos_startpoint + pos_endpoint do
    a:led(3, i + 1 - 29 - arc_off, 10)
  end
  -- draw splice size
  local win_startpoint = math.floor(util.linlin(0, max_tapelength, 0, 1, splice_l) * -28)
  local win_endpoint = math.ceil(util.linlin(0, max_tapelength, 0, 1, splice_l) * 28)
  a:led(4, -28 - arc_off, 6)
  a:led(4, 30 - arc_off, 6)
  for i = win_startpoint, win_endpoint do
    a:led(4, i + 1 - arc_off, 10)
  end
  a:refresh()
end

---------------------TIME TO TIDY UP A BIT-----------------------

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
end
