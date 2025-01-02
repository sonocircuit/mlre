-- mlre v2.2.0 @sonocircuit
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

-----------------------------------------------------------------------
-- TODO: stress-test silent load tempo transitions
-- TODO: code cleanup
-----------------------------------------------------------------------

norns.version.required = 231114

m = midi.connect()
a = arc.connect()
g = grid.connect()

local mu = require 'musicutil'
local lattice = require 'lattice'

local ui = include 'lib/ui_mlre'
local grd = include 'lib/grid_mlre'
local _lfo = include 'lib/lfo_mlre'
local scales = include 'lib/scales_mlre'
local _pattern = include 'lib/pattern_time_mlre'


--------- user variables --------
local pset_load = false -- if true default pset loaded at launch
local rotate_grid = false -- zero only. if true will rotate 90° CW
autofocus = true -- zero only. if true norns screen automatically changes to last used grid layout


--------- other variables --------
local mlre_path = _path.audio .. "mlre/"

-- constants
GRID_SIZE = 0
FADE_TIME = 0.01
TAPE_GAP = 1
SPLICE_GAP = 0.1
MAX_TAPELENGTH = 57
DEFAULT_SPLICELEN = 4
DEFAULT_BEATNUM = 4

-- ui variables
main_pageNum = 1
pmac_pageNum = 1
pmac_pageEnc = 0
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
mutes_active = false
cutview_hold = false
keyquant_edit = false

lfo_trksel = 1
lfo_dstview = 0
lfo_dstsel = 1

macro_slot_mode = 1

view_splice_info = false
view_track_send = false
sends_focus = 1

view_presets = false
pset_focus = 1
pset_list = {}
copy_ref = {}

view_batchload_options = false
batchload_path = ""
batchload_track = 1
batchload_numfiles = 8

-- arc variables
arc_pageNum = 1
arc_is = false
enc2_wait = false
arc_off = 0
scrub_sens = 100
pmac_sens = 20
tau = math.pi * 2

-- viz variables 
pulse_key_fast = 8
pulse_key_mid = 12
pulse_key_slow = 12
pulse_bar = false
pulse_beat = false

view_message = ""
popup_message = ""
popup_func = nil
popup_view = false

-- recording variables
local amp_threshold = 1
local armed_track = 1
local oneshot_rec = false
local transport_run = false
local autolength = false
local loop_pos = 1
local rec_dur = 0
local rec_autobackup = false
local rec_backup = false

-- misc variables
local current_scale = 1
local current_tempo = 90
local autorand_at_cycle = false
local rnd_stepcount = 16

-- silent load variables
local loadop = {}
loadop.params = {"sync", "tempo", "transition", "scale", "quant_rate", "time_signature", "loops", "reset_active", "reset_count", "pan", "send_t5", "send_t6", "detune", "transpose", "warble_state", "rev", "speed", "sel", "fade", "route_t5", "route_t6", "splice_active"}
loadop.set_param = {"reset_active", "reset_count", "pan", "send_t5", "send_t6", "detune", "transpose", "warble_state"}
loadop.param_default = {1, 4, 0, 0.5, 0.5, 0, 8, 1}
loadop.set_tab = {"rev", "speed", "sel", "fade", "route_t5", "route_t6"}
loadop.active = false

-- pattern page variables
local pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
local pattern_meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}

-- quantization variables
local quantize_events = {}
local event_q_options = {"off", "1/32", "1/24", "3/64", "1/16", "1/12", "3/32", "1/8", "1/6", "3/16", "1/4", "1/3", "3/8", "1/2"}
local event_q_values = {1/4, 1/32, 1/24, 3/64, 1/16, 1/12, 3/32, 1/8, 1/6, 3/16, 1/4, 1/3, 3/8, 1/2}
q_rate = 1/4

local snap_launch = 1
local splice_launch = 1
splice_queued = false
bar_val = 4
quantizing = false

-- snapshot/recall variables
snapshot_mode = false
punch_momentrary = false

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
eLFO = 15
eREC = 16

-- event funtions
function set_quantizer(idx)
  q_rate = event_q_values[idx] * 4
  if idx == 1 then
    if event_clock ~= nil then
      clock.cancel(event_clock)
      event_clock = nil
    end
    quantizing = false
  elseif not quantizing then
    event_clock = clock.run(quantizer)
    quantizing = true
  end
end

function quantizer()
  while true do
    clock.sync(q_rate)
    if #quantize_events > 0 then
      for _, e in ipairs(quantize_events) do
        if e.t ~= ePATTERN then event_record(e) end
        event_exec(e)
      end
      quantize_events = {}
    end
  end
end

function event(e)
  if quantizing and e.sync == nil then
    table.insert(quantize_events, e)
  else
    if e.t ~= ePATTERN then event_record(e) end
    event_exec(e)
  end
end

function event_record(e)
  for i = 1, 8 do
    pattern[i]:watch(e)
  end
  if recall_rec > 0 then
    if recall[recall_rec].active then
      table.insert(recall[recall_rec].event, e)
      recall[recall_rec].has_data = true
    end
  end
end

function loop_event(i, lstart, lend, sync)
  local e = {}
  e.t = eLOOP
  e.i = i
  e.loop = 1
  e.loop_start = lstart
  e.loop_end = lend
  e.sync = sync
  event(e)
end

-- exec function
function event_exec(e)
  if e.t == eCUT then
    cut_track(e.i, e.pos)
  elseif e.t == eSTART then
    start_track(e.i, e.pos)
  elseif e.t == eSTOP then
    stop_track(e.i)
  elseif e.t == eLOOP then
    set_loop(e.i, e.loop_start, e.loop_end)
  elseif e.t == eUNLOOP then
    clear_loop(e.i)
  elseif e.t == eSPEED then
    track[e.i].speed = e.speed
    update_rate(e.i)
  elseif e.t == eREV then
    track[e.i].rev = e.rev
    update_rate(e.i)
  elseif e.t == eMUTE then
    track[e.i].mute = e.mute
    set_level(e.i)
    get_mute_state()
  elseif e.t == eTRSP then
    params:set(e.i.."transpose", e.val)
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
    track[e.i].splice_focus = e.active
    track[e.i].beat_count = 0
    set_clip(e.i)
    render_splice()
    splice_queued = false
  elseif e.t == eROUTE then
    if e.ch == 5 then
      track[e.i].route_t5 = e.route
    else
      track[e.i].route_t6 = e.route
    end
    set_track_sends(e.i)
  elseif e.t == eLFO then
    if e.action == "lfo_on" then
      params:set("lfo_lfo_"..e.i, 2)
    elseif e.action == "lfo_off" then
      params:set("lfo_lfo_"..e.i, 1)
    end
  elseif e.t == eREC then
    track[e.i].rec = e.rec
    set_rec(e.i)
  elseif e.t == ePATTERN then
    if e.action == "stop" then
      pattern[e.i]:stop()
    elseif e.action == "start" then
      pattern[e.i]:start()
    elseif e.action == "rec_stop" then
      pattern[e.i]:rec_stop()
    end
  end
  dirtygrid = true
end


-- patterns
patterns_only = false
pattern_rec = false
pattern = {}
for i = 1, 8 do
  pattern[i] = _pattern.new("pattern "..i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() start_pulse(i) end
  --pattern[i].event_callback = function() start_pulse(i) end -- @arthur: uncomment for blinkenlights
  pattern[i].count_in = 1
  pattern[i].flash = false
end

function start_pulse(i)
  pattern[i].flash = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(1/15)
    pattern[i].flash = false
    dirtygrid = true
  end)
end

function recalc_time_factor()
  for i = 1, 8 do
    if pattern[i].tempo_map == true and pattern[i].bpm ~= nil then -- pattern tempo map default set to true.
      pattern[i].time_factor = pattern[i].bpm / current_tempo
    end
  end
end


-- recall
recall = {}
recall_rec = 0
for i = 1, 8 do
  recall[i] = {}
  recall[i].has_data = false
  recall[i].active = false
  recall[i].event = {}
end

function recall_exec(i)
  for _, e in pairs(recall[i].event) do
    event(e)
  end
end

local rstate = {}
for i = 1, 6 do
  rstate[i] = {}
  rstate[i].play = 0
  rstate[i].rec = 0
  rstate[i].mute = 0
  rstate[i].route_t5 = 0
  rstate[i].route_t6 = 0
  rstate[i].loop = 0
  rstate[i].loop_start = 1
  rstate[i].loop_end = 16
  rstate[i].splice_active = 1
  rstate[i].speed = 0
  rstate[i].rev = 0
  rstate[i].transpose = 0
  rstate[i].lfo_enabled = 0
end

function save_event_state()
  for i = 1, 6 do
    rstate[i].play = track[i].play
    rstate[i].rec = track[i].rec
    rstate[i].mute = track[i].mute
    rstate[i].route_t5 = track[i].route_t5
    rstate[i].route_t6 = track[i].route_t6
    rstate[i].loop = track[i].loop
    rstate[i].loop_start = track[i].loop_start
    rstate[i].loop_end = track[i].loop_end
    rstate[i].splice_active = track[i].splice_active
    rstate[i].speed = track[i].speed
    rstate[i].rev = track[i].rev
    rstate[i].transpose = track[i].transpose
    rstate[i].lfo_enabled = lfo[i].enabled
  end
end

function reset_event_state(sync)
  if punch_momentrary then
    for i = 1, 6 do
      if track[i].play ~= rstate[i].play then
        toggle_playback(i)
      end
      if track[i].rec ~= rstate[i].rec then
        local e = {t = eREC, i = i, rec = rstate[i].rec, sync = sync} event(e)
      end
      if track[i].mute ~= rstate[i].mute then
        local e = {t = eMUTE, i = i, mute = rstate[i].mute, sync = sync} event(e)
      end
      if track[i].route_t5 ~= rstate[i].route_t5 then
        local e = {t = eROUTE, i = i, ch = 5, route = rstate[i].route_t5, sync = sync} event(e)
      end
      if track[i].route_t6 ~= rstate[i].route_t6 then
        local e = {t = eROUTE, i = i, ch = 6, route = rstate[i].route_t6, sync = sync} event(e)
      end
      if rstate[i].loop == 1 then
        loop_event(i, rstate[i].loop_start, rstate[i].loop_end)
      elseif track[i].loop == 1 then
        local e = {t = eUNLOOP, i = i, sync = sync} event(e)
        track[i].loop_start = rstate[i].loop_start
        track[i].loop_end = rstate[i].loop_end
      end
      if track[i].splice_active ~= rstate[i].splice_active then
        local e = {t = eSPLICE, i = i, active = rstate[i].splice_active, sync = sync} event(e)
      end
      if track[i].speed ~= rstate[i].speed then
        local e = {t = eSPEED, i = i, speed = rstate[i].speed, sync = sync} event(e)
      end
      if track[i].rev ~= rstate[i].rev then
        local e = {t = eREV, i = i, rev = rstate[i].rev, sync = sync} event(e)
      end
      if track[i].transpose ~= rstate[i].transpose then
        local e = {t = eTRSP, i = i, val = rstate[i].transpose, sync = sync} event(e)
      end
      if lfo[i].enabled ~= rstate[i].lfo_enabled then
        local action = rstate[i].lfo_enabled == 1 and "lfo_on" or "lfo_off"
        local e = {t = eLFO, i = i, action = action, sync = sync} event(e)
      end
    end
  end
end


pmac_perf_view = false
pmac_edit_view = false
pmac_focus = 1
pmac_enc = 1
pmac_encpage = 1
pmac_params = {"cutoff", "filter_q", "vol", "pan", "detune", "rate_slew"}
pmac_param_id = {{"cutoff", "vol", "detune", "lfo_depth"}, {"filter_q", "pan", "rate_slew", "lfo_rate"}}
pmac_param_name = {{"cutoff", "vol", "detune", "lfo   depth"}, {"filter  q", "pan", "rate_slew", "lfo   rate"}}

pmac = {}
pmac.d = {}
pmac.v = {}
for n = 1, 4 do -- four p-macro encoders
  pmac.d[n] = {} 
  pmac.d[n].clk = nil
  pmac.d[n].action = 0
  for i = 1, 6 do
    pmac.d[n][i] = {} -- delta multipliers per enc and track
    pmac.d[n][i].cutoff = 0
    pmac.d[n][i].filter_q = 0
    pmac.d[n][i].pan = 0
    pmac.d[n][i].vol = 0
    pmac.d[n][i].detune = 0
    pmac.d[n][i].rate_slew = 0
    pmac.d[n][i].lfo_depth = 0
    pmac.d[n][i].lfo_rate = 0
  end
end
for i = 1, 6 do -- param variables per track
  pmac.v[i] = {}
  pmac.v[i].cutoff = 12000
  pmac.v[i].filter_q = 2
  pmac.v[i].vol = 1
  pmac.v[i].pan = 0
  pmac.v[i].detune = 0
  pmac.v[i].rate_slew = 0
  pmac.v[i].lfo_depth = 0
  pmac.v[i].lfo_rate = 0
end

function pmac_save()
  for i = 1, 6 do
    pmac.v[i].cutoff = params:get(i.."cutoff")
    pmac.v[i].filter_q = params:get(i.."filter_q")
    pmac.v[i].vol = track[i].level
    pmac.v[i].pan = track[i].pan
    pmac.v[i].detune = track[i].detune
    pmac.v[i].rate_slew = track[i].rate_slew
    pmac.v[i].lfo_depth = params:get("lfo_depth_lfo_"..i)
    if lfo[i].mode == "free" then
      pmac.v[i].lfo_rate = params:get("lfo_free_lfo_"..i)
    else
      pmac.v[i].lfo_rate = params:get("lfo_clocked_lfo_"..i)
    end
  end
end

function pmac_recall()
  for i = 1, 6 do
    params:set(i.."cutoff", pmac.v[i].cutoff)
    params:set(i.."filter_q", pmac.v[i].filter_q)
    params:set(i.."vol", pmac.v[i].vol)
    params:set(i.."pan", pmac.v[i].pan)
    params:set(i.."detune", pmac.v[i].detune)
    params:set(i.."rate_slew", pmac.v[i].rate_slew)
    params:set("lfo_depth_lfo_"..i, pmac.v[i].lfo_depth)
    if lfo[i].mode == "free" then
      params:set("lfo_free_lfo_"..i, pmac.v[i].lfo_rate)
    else
      params:set("lfo_clocked_lfo_"..i, pmac.v[i].lfo_rate)
    end
  end
end

local p_inc = 0
function pmac_exec(n, d)
  -- delta track params
  for _, v in ipairs(pmac_params) do
    for i = 1, 6 do
      if pmac.d[n][i][v] ~= 0 then
        params:delta(i..v, d * pmac.d[n][i][v] * 0.01)
      end
    end
  end
  -- delta lfo params
  for i = 1, 6 do
    if pmac.d[n][i].lfo_depth > 0.01 or pmac.d[n][i].lfo_depth < -0.01 then
      params:delta("lfo_depth_lfo_"..i, d * pmac.d[n][i].lfo_depth * 0.01)
      grid_page(vLFO)
    end
    if pmac.d[n][i].lfo_rate ~= 0 then
      if lfo[i].mode == "free" then
        params:delta("lfo_free_lfo_"..i, d * pmac.d[n][i].lfo_rate * 0.01)
      else
        local delta = pmac.d[n][i].lfo_rate * 0.1 * d
        p_inc = util.wrap(p_inc + delta, 0, 64)
        if p_inc < 8 or p_inc > 56 then
          local inc = delta > 0 and 1 or -1
          params:delta("lfo_clocked_lfo_"..i, inc)
          p_inc = 32
        end
      end
    end
  end
  -- macro viz
  pmac.d[n].action = d
  dirtyscreen = true
  if pmac.d[n].clk ~= nil then
    clock.cancel(pmac.d[n].clk)
  end
  pmac.d[n].clk = clock.run(function()
    clock.sleep(0.1)
    pmac.d[n].action = 0
    dirtyscreen = true
  end)
end

function toggle_pmac_perf_view(z)
  if view ~= vTAPE then
    pmac_perf_view = z == 1 and true or false
    if z == 1 then
      pmac_save()
    else
      pmac_recall()
      ui.reset_pmac_arc()
    end
  end
end
  

-- randomize events
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
    local e = {} e.t = eSPEED e.i = i e.speed = math.random(-params:get("rnd_loct"), params:get("rnd_uoct"))
    event(e)
  end
  if params:get("rnd_cut") == 2 then
    params:set(i.. "cutoff", math.random(params:get("rnd_lcut"), params:get("rnd_ucut")) )
  end
  track[i].step_count = 0
end


--------------------- SNAPSHOTS -----------------------
local snap_set_rec = false
local snap_set_mute = false
local snap_set_rev = false
local snap_set_speed = false
local snap_set_trsp = false
local snap_set_loop = false
local snap_set_splice = false
local snap_play_state = false
local snap_cut_pos = false
local snap_reset_pos = false
local snap_set_lfo = false


snap = {}
for i = 1, 8 do -- 8 snapshot slots
  snap[i] = {}
  snap[i].data = false
  snap[i].active = false
  snap[i].queued = false
  snap[i].rec = {}
  snap[i].play = {}
  snap[i].mute = {}
  snap[i].loop = {}
  snap[i].loop_start = {}
  snap[i].loop_end = {}
  snap[i].cut = {}
  snap[i].speed = {}
  snap[i].rev = {}
  snap[i].transpose_val = {}
  snap[i].active_splice = {}
  snap[i].route_t5 = {}
  snap[i].route_t6 = {}
  snap[i].lfo_enabled = {}
  for j = 1, 6 do -- 6 tracks
    snap[i].rec[j] = 0
    snap[i].play[j] = 0
    snap[i].mute[j] = 0
    snap[i].loop[j] = 0
    snap[i].loop_start[j] = 1
    snap[i].loop_end[j] = 16
    snap[i].cut[j] = 1
    snap[i].speed[j] = 0
    snap[i].rev[j] = 0
    snap[i].transpose_val[j] = 8
    snap[i].active_splice[j] = 1
    snap[i].route_t5[j] = 0
    snap[i].route_t6[j] = 0
    snap[i].lfo_enabled[j] = 0
  end
end

function save_snapshot(n)
  for i = 1, 6 do
    softcut.query_position(i)
    snap[n].rec[i] = track[i].rec
    snap[n].play[i] = track[i].play
    snap[n].mute[i] = track[i].mute
    snap[n].loop[i] = track[i].loop
    snap[n].loop_start[i] = track[i].loop_start
    snap[n].loop_end[i] = track[i].loop_end
    snap[n].speed[i] = track[i].speed
    snap[n].rev[i] = track[i].rev
    snap[n].transpose_val[i] = params:get(i.."transpose")
    snap[n].active_splice[i] = track[i].splice_active
    snap[n].route_t5[i] = track[i].route_t5
    snap[n].route_t6[i] = track[i].route_t6
    snap[n].lfo_enabled[i] = lfo[i].enabled
    clock.run(function()
      clock.sleep(0.05) -- give get_pos() some time
      snap[n].cut[i] = track[i].cut
    end)
  end
  snap[n].data = true
end

function load_snapshot(snapshot, target)
  if target == "all" then
    for track = 1, 6 do
      launch_snapshot(snapshot, track)
    end
  else
    launch_snapshot(snapshot, target)
  end
end

function launch_snapshot(n, i)
  local beat_sync = snap_launch > 1 and (snap_launch == 3 and bar_val or 1) or (quantizing and q_rate or nil)
  if beat_sync ~= nil then
    clock.run(function()
      clock.sync(beat_sync)
      recall_snapshot(n, i, true)
    end)
  else
    recall_snapshot(n, i)
  end
end

function recall_snapshot(n, i, sync)
  -- flip the unflipped
  if mod == 1 and not track[i].loaded then
    load_track_tape(i) --TODO: only load what won't be set via snapshot. add bool as arg -> snapshot == true
  end
  -- load se snap
  if snap_set_rec then
    local e = {} e.t = eREC e.i = i e.rec = snap[n].rec[i] e.sync = sync event(e)
  end
  if snap_set_mute then
    local e = {} e.t = eMUTE e.i = i e.mute = snap[n].mute[i] e.sync = sync event(e)
  end
  if snap_set_rev then
    local e = {} e.t = eREV e.i = i e.rev = snap[n].rev[i] e.sync = sync event(e)
  end
  if snap_set_speed then
    local e = {} e.t = eSPEED e.i = i e.speed = snap[n].speed[i] e.sync = sync event(e)
  end
  if snap_set_trsp then
    local e = {} e.t = eTRSP e.i = i e.val = snap[n].transpose_val[i] e.sync = sync event(e)
  end
  if snap_set_route and snap[n].route_t5[i] ~= nil then
    local e = {} e.t = eROUTE e.i = i e.ch = 5 e.route = snap[n].route_t5[i] event(e)
    local e = {} e.t = eROUTE e.i = i e.ch = 6 e.route = snap[n].route_t6[i] event(e)
  end
  if snap_set_splice then
    if snap[n].active_splice[i] ~= track[i].splice_active then
      local e = {} e.t = eSPLICE e.i = i e.active = snap[n].active_splice[i] e.sync = sync event(e)
      track[i].splice_focus = snap[n].active_splice[i]
    end
  end
  if snap_set_loop then
    if snap[n].loop[i] == 1 then
      loop_event(i, snap[n].loop_start[i], snap[n].loop_end[i], sync)
    elseif snap[n].loop[i] == 0 then
      local e = {} e.t = eUNLOOP e.i = i e.sync = sync event(e)
    end
  end
  if snap_play_state then
    if snap[n].play[i] == 0 then
      local e = {} e.t = eSTOP e.i = i e.sync = sync event(e)
    else
      if snap_cut_pos then
        local e = {t = eSTART, i = i, pos = snap[n].cut[i], sync = sync} event(e)
      elseif snap_reset_pos then
        local cut = track[i].rev == 0 and clip[i].s or clip[i].e
        local s = clip[i].s + (track[i].loop_start - 1) / 16 * clip[i].l
        local e = clip[i].s + (track[i].loop_end) / 16 * clip[i].l
        local loop = track[i].rev == 0 and s or e
        local pos = track[i].loop == 0 and cut or loop
        local e = {t = eSTART, i = i, pos = pos, sync = sync} event(e)
      elseif track[i].play == 0 then
        local e = {t = eSTART, i = i, sync = sync} event(e)
      end
    end
  end
  if snap_set_lfo then
    local action = snap[n].lfo_enabled[i] == 1 and "lfo_on" or "lfo_off"
    local e = {t = eLFO, i = i, action = action , sync = sync} event(e)
  end
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
  track[i].route_t5 = 0
  track[i].route_t6 = 0
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
  track[i].detune = 0
  track[i].transpose = 0
  track[i].fade = 0
  track[i].loaded = true
  track[i].reset = false
  track[i].beat_count = 0
  track[i].beat_reset = 4
end

-- tape variables -> six slices of tape, one for each track
tp = {}
for i = 1, 6 do
  tp[i] = {}
  tp[i].input = 1 -- softcut input
  tp[i].side = 1 -- main or temp buffer (1, 2)
  tp[i].buffer = i -- selected tape buffer (1-6)
  tp[i].s = TAPE_GAP * i + (i - 1) * MAX_TAPELENGTH
  tp[i].e = tp[i].s + MAX_TAPELENGTH
  tp[i].qs = tp[i].s - 0.75 -- quarantine start
  tp[i].qe = tp[i].s - 0.25 -- quarantine end
  tp[i].event = {}
  tp[i].splice = {}
  for s = 1, 8 do
    tp[i].splice[s] = {}
    tp[i].splice[s].s = tp[i].s + (DEFAULT_SPLICELEN + FADE_TIME) * (s - 1)
    tp[i].splice[s].e = tp[i].splice[s].s + DEFAULT_SPLICELEN
    tp[i].splice[s].l = tp[i].splice[s].e - tp[i].splice[s].s
    tp[i].splice[s].name = ""
    tp[i].splice[s].info = "length: "..string.format("%.2f", DEFAULT_SPLICELEN).."s"
    tp[i].splice[s].init_start = tp[i].splice[s].s
    tp[i].splice[s].init_len = DEFAULT_SPLICELEN
    tp[i].splice[s].init_beatnum = DEFAULT_BEATNUM
    tp[i].splice[s].beatnum = DEFAULT_BEATNUM
    tp[i].splice[s].bpm = 60 
    tp[i].splice[s].resize = 4
  end
end

-- clip variables -> six clips define the active playback window, one for each track
clip = {}
for i = 1, 6 do
  clip[i] = {}
  clip[i].s = tp[i].splice[1].s
  clip[i].e = tp[i].splice[1].e
  clip[i].l = tp[i].splice[1].l
  clip[i].bpm = tp[i].splice[1].bpm 
end

function set_clip(i) 
  -- set playback window
  local s = track[i].splice_active
  clip[i].s = tp[i].splice[s].s
  clip[i].l = tp[i].splice[s].l
  clip[i].e = tp[i].splice[s].e
  clip[i].bpm = tp[i].splice[s].bpm
  -- set softcut
  softcut.loop_start(i, clip[i].s)
  softcut.loop_end(i, clip[i].e)
  local q = (clip[i].l / 64)
  local off = util.round((math.ceil(clip[i].s / q) * q) - clip[i].s, 0.001)
  softcut.phase_quant(i, q)
  softcut.phase_offset(i, off)
  if track[i].loop == 1 then
    set_loop(i, track[i].loop_start, track[i].loop_end)
  end
  update_rate(i)
  set_track_reset(i)
end

function init_splices(i) -- reset splices to default
  for s = 1, 8 do
    tp[i].splice[s] = {}
    tp[i].splice[s].s = tp[i].s + (DEFAULT_SPLICELEN + 0.01) * (s - 1)
    tp[i].splice[s].e = tp[i].splice[s].s + DEFAULT_SPLICELEN
    tp[i].splice[s].l = tp[i].splice[s].e - tp[i].splice[s].s
    tp[i].splice[s].init_start = tp[i].splice[s].s
    tp[i].splice[s].init_len = DEFAULT_SPLICELEN
    tp[i].splice[s].beatnum = DEFAULT_BEATNUM
    tp[i].splice[s].bpm = 60 
    tp[i].splice[s].name = ""
    set_info(i, s)
  end
  track[i].splice_active = 1
  set_clip(i)
end

function splice_resize(i, s, length)
  -- if no length argument recalculate
  if length == nil then
    if track[i].tempo_map == 0 then
      length = tp[i].splice[s].beatnum
    elseif track[i].tempo_map == 1 then
      length = beat_sec * tp[i].splice[s].beatnum
    elseif track[i].tempo_map == 2 then
      length = tp[i].splice[s].l
    end
  end
  -- set splice variables
  if tp[i].splice[s].s + length <= tp[i].e then
    tp[i].splice[s].e = tp[i].splice[s].s + length
    tp[i].splice[s].l = length
    tp[i].splice[s].bpm = 60 / length * tp[i].splice[s].beatnum
    if s == track[i].splice_active then
      set_clip(i)
    end
    set_info(i, s)
  else
    show_message("splice   too   long")
  end
end

function splice_reset(i, s) -- reset splice to saved default length
  local s = s or track[i].splice_focus
  -- reset variables
  tp[i].splice[s].s = tp[i].splice[s].init_start
  tp[i].splice[s].l = tp[i].splice[s].init_len
  tp[i].splice[s].e = tp[i].splice[s].s + tp[i].splice[s].l
  tp[i].splice[s].beatnum = tp[i].splice[s].init_beatnum
  tp[i].splice[s].bpm = 60 / tp[i].splice[s].l * tp[i].splice[s].beatnum
  -- set clip
  if s == track[i].splice_active then
    set_clip(i) 
  end
  set_info(i, s)
end

function mirror_splice(i, src, dst) -- copy splice to the other buffer
  local s = track[i].splice_focus
  softcut.buffer_copy_mono(src, dst, tp[i].splice[s].s - FADE_TIME, tp[i].splice[s].s - FADE_TIME, tp[i].splice[s].l + (FADE_TIME * 2), 0.01)
  render_splice()
end

function copy_splice_audio() -- copy to other destination
  if copy_ref.track ~= nil then
    local i = track_focus
    local s = track[i].splice_focus
    local ci = copy_ref.track
    local cs = copy_ref.splice
    local length = tp[i].splice[s].l
    local preserve = alt == 1 and 0.5 or 0
    if tp[i].splice[s].e + length <= tp[i].e then
      softcut.buffer_copy_mono(tp[ci].side, tp[i].side, tp[ci].splice[cs].s, tp[i].splice[s].s, length, FADE_TIME, preserve)
      tp[i].splice[s].e = tp[i].splice[s].s + length
      tp[i].splice[s].l = length
      tp[i].splice[s].init_start = tp[i].splice[s].s
      tp[i].splice[s].init_len = length
      tp[i].splice[s].beatnum = tp[ci].splice[cs].beatnum
      tp[i].splice[s].bpm = 60 / length * tp[ci].splice[cs].beatnum
      tp[i].splice[s].name = tp[ci].splice[cs].name
      tp[i].splice[s].resize = track[i].tempo_map > 1 and tp[i].splice[s].beatnum or math.ceil(length)
      splice_resize(i, s, length)
      render_splice()
      copy_ref = {}
    else
      show_message("out   of   boundries")
    end
  else
    show_message("clipboard   empty")
  end
end

function load_splice(i, s)
  if track[i].play == 0 then
    local e = {} e.t = eSPLICE e.i = i e.active = s event(e)
  else
    if splice_launch == 4 then
      if track[i].splice_active == s then
        splice_queued = false
        tp[i].event = {}
      else
        splice_queued = true
        tp[i].event = {t = eSPLICE, i = i, active = s, sync = true}
      end
    else
      local beat_sync = splice_launch > 1 and (splice_launch == 3 and bar_val or 1) or (quantizing and q_rate or nil)
      if beat_sync ~= nil then
        splice_queued = true
        clock.run(function()
          clock.sync(beat_sync)
          local e = {} e.t = eSPLICE e.i = i e.active = s e.sync = true event(e)
        end)
      else
        local e = {} e.t = eSPLICE e.i = i e.active = s event(e)
      end
    end
  end
end

function clear_splice() -- clear focused splice
  local i = track_focus
  local s = track[i].splice_focus
  local buffer = tp[i].side
  local start = tp[i].splice[s].s - FADE_TIME
  local length = tp[i].splice[s].l + (FADE_TIME * 2)
  softcut.buffer_clear_region_channel(buffer, start, length)
  render_splice()
  show_message("track    "..i.."    splice    "..s.."    cleared")
end

function set_tape(i, buffer) -- assign tape buffer
  local prev_start = tp[i].s
  tp[i].s = TAPE_GAP * buffer + (buffer - 1) * MAX_TAPELENGTH
  tp[i].e = tp[i].s + MAX_TAPELENGTH
  for s = 1, 8 do
    tp[i].splice[s].s = tp[i].splice[s].s + (tp[i].s - prev_start)
    tp[i].splice[s].e = tp[i].splice[s].s + tp[i].splice[s].l
  end
  set_clip(i)
  render_splice()
end

function clear_tape() -- clear tape
  local i = track_focus
  local buffer = tp[i].side
  local start = tp[i].s - FADE_TIME
  local length = MAX_TAPELENGTH + FADE_TIME
  softcut.buffer_clear_region_channel(buffer, start, length)
  track[i].loop = 0
  render_splice()
  show_message("track    "..i.."    tape    cleared")
  dirtygrid = true
end

function clear_buffers() -- clear both buffers
  softcut.buffer_clear()
  render_splice()
  show_message("buffers    cleared")
  dirtygrid = true
end

function format_splice(i, s) -- copy format to next splice
  local i = i or track_focus
  local s = s or track[i].splice_focus
  if s < 8 then
    local s_start = tp[i].splice[s].e + FADE_TIME
    local length = tp[i].splice[s].l
    if s_start + length <= tp[i].e then
      tp[i].splice[s + 1].s = s_start
      tp[i].splice[s + 1].l = length
      tp[i].splice[s + 1].e = s_start + length
      tp[i].splice[s + 1].init_start = s_start
      tp[i].splice[s + 1].init_len = tp[i].splice[s].l
      tp[i].splice[s + 1].beatnum = tp[i].splice[s].beatnum
      tp[i].splice[s + 1].bpm = tp[i].splice[s].bpm
      tp[i].splice[s + 1].resize = track[i].tempo_map > 1 and num_beats or math.ceil(length)
      set_info(i, s + 1)
    else
      show_message("splice  "..(s + 1).."   too   long")
    end
  end
end

function format_next_splices()
  local n = track[track_focus].splice_focus
  for s = n, 8 do
    format_splice(track_focus, s)
  end
end

function save_all_markers()
  for i = 1, 6 do
    for s = 1, 8 do
      tp[i].splice[s].init_len = tp[i].splice[s].l
      tp[i].splice[s].init_start = tp[i].splice[s].s
      tp[i].splice[s].init_beatnum = tp[i].splice[s].beatnum
    end
  end
end

function set_info(i, s)
  if track[i].tempo_map == 2 then
    tp[i].splice[s].info = "repitch factor: "..string.format("%.2f", current_tempo / tp[i].splice[s].bpm)
  else
    tp[i].splice[s].info = "length: "..string.format("%.2f", tp[i].splice[s].l).."s"
  end
  if view == vTAPE and view_splice_info then dirtyscreen = true end
end

function set_tempo_map(i)
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
  page_redraw(vTAPE)
end

function recalc_splices() -- called when tempo changes
  for i = 1, 6 do
    if track[i].tempo_map > 0 and (track[i].loaded or loadop.tempo_transition == 3) then
      for n = 1, 8 do
        splice_resize(i, n)
      end
      render_splice()
    end
  end
end


--------------------- SOFTCUT FUNCTIONS -----------------------

function toggle_rec(i)
  track[i].rec = 1 - track[i].rec
  local e = {} e.t = eREC e.i = i e.rec = track[i].rec event(e)
  if track[i].rec == 1 then
    backup_rec(i, "save")
  end
end

function set_rec(i) -- set softcut rec and pre levels
  local fade = track[i].fade == 0 and 1 or track[i].pre_level
  if track[i].rec == 1 and track[i].play == 1 then
    softcut.pre_level(i, track[i].pre_level)
    softcut.rec_level(i, track[i].rec_level)
  else
    softcut.pre_level(i, fade)
    softcut.rec_level(i, 0)
  end
  page_redraw(vMAIN, 2)
end

function backup_rec(i, action)
  if rec_autobackup then
    if action == "save" then
      mirror_splice(i, 1, 2)
      rec_backup = true
    elseif action == "undo" and rec_backup then
      mirror_splice(i, 2, 1)
      show_message("undo   recording")
      if track[i].rec == 0 then
        rec_backup = false
      end
    end
  end
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
  if track[i].route_t5 == 1 and track[i].play == 1 then
    softcut.level_cut_cut(i, 5, track[i].send_t5 * track[i].level)
  else
    softcut.level_cut_cut(i, 5, 0)
  end
  if track[i].route_t6 == 1 and track[i].play == 1 then
    softcut.level_cut_cut(i, 6, track[i].send_t6 * track[i].level)
  else
    softcut.level_cut_cut(i, 6, 0)
  end
end

function get_mute_state()
  local count = 0
  for i = 1, 6 do
    if track[i].mute == 1 then
      count = count + 1
    end
  end
  mutes_active = count > 0 and true or false
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

function reset_pos(i)
  if track[i].loop == 0 then
    local cut = track[i].rev == 0 and clip[i].s or clip[i].e
    softcut.position(i, cut)
  else
    local lstart = clip[i].s + (track[i].loop_start - 1) / 16 * clip[i].l
    local lend = clip[i].s + (track[i].loop_end) / 16 * clip[i].l
    local cut = track[i].rev == 0 and lstart or lend
    softcut.position(i, cut)
  end
end

function set_track_reset(i)
  local val = params:get(i.."reset_count")
  track[i].beat_reset = val == 1 and tp[i].splice[track[i].splice_active].beatnum or val
end

function cut_track(i, pos)
  if track[i].oneshot == 1 then
    set_quarantine(i, false)
  end
  if track[i].loop == 1 then
    clear_loop(i)
  end
  local cut = (pos / 16) * clip[i].l + clip[i].s
  local q = track[i].rev == 1 and clip[i].l / 16 or 0
  softcut.position(i, cut + q)
  if track[i].play == 0 then
    track[i].play = 1
    track[i].beat_count = 0
    set_rec(i)
    set_level(i)
    toggle_transport()
  end
end

function start_track(i, pos)
  if track[i].oneshot == 1 then
    set_quarantine(i, false)
  end
  softcut.position(i, pos or track[i].cut)
  track[i].play = 1
  track[i].beat_count = 0
  set_rec(i)
  set_level(i)
  toggle_transport()
end

function stop_track(i)
  if track[i].oneshot == 1 then
    set_quarantine(i, true)
  end
  softcut.query_position(i)
  track[i].play = 0
  trig[i].tick = 0
  set_level(i)
  set_rec(i)
  dirtygrid = true
end

function set_loop(i, lstart, lend)
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

function set_quarantine(i, isolate)
  if isolate then
    track[i].pos_arc =  track[i].rev == 0 and 1 or 64
    track[i].pos_grid = track[i].rev == 0 and 1 or 16
    softcut.loop_start(i, tp[i].qs)
    softcut.loop_end(i, tp[i].qe)
  else
    if track[i].loop == 0 then
      clear_loop(i)
    else
      set_loop(i, track[i].loop_start, track[i].loop_end)
    end
  end
end

function set_track_source(option) -- select audio source
  audio.level_adc_cut(1)
  audio.level_eng_cut(option == 2 and 0 or 1)
  audio.level_tape_cut(option == 1 and 0 or 1)
end

function set_softcut_input(i) -- select softcut input
  if tp[i].input == 1 then -- L&R
    softcut.level_input_cut(1, i, 0.707)
    softcut.level_input_cut(2, i, 0.707)
  elseif tp[i].input == 2 then -- L IN
    softcut.level_input_cut(1, i, 1)
    softcut.level_input_cut(2, i, 0)
 elseif tp[i].input == 3 then -- R IN
    softcut.level_input_cut(1, i, 0)
    softcut.level_input_cut(2, i, 1)
 elseif tp[i].input == 4 then -- OFF
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
  local pc = ((pos - tp[i].s) / MAX_TAPELENGTH)
  local g_pos = math.floor(pp * 16)
  local a_pos = math.floor(pp * 64)
  -- calc positions
  track[i].pos_abs = pos -- absoulute position on buffer
  track[i].pos_hi_res = util.clamp(a_pos + 1 % 64, 1, 64) -- fine mesh for arc
  track[i].pos_lo_res = util.clamp(g_pos + 1 % 16, 1, 16) -- coarse mesh for grid
  -- if playing do stuff
  if track[i].play == 1 then
    -- set positions
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
    if (grido_view < vLFO or gridz_view < vLFO or grido_view == vTAPE) then
      dirtygrid = true
    end
    page_redraw(vTAPE)
    -- oneshot play_mode
    if track[i].play_mode == 2 and track[i].loop == 0 then
      local limit = track[i].rev == 0 and 64 or 1
      if track[i].pos_hi_res == limit then
        stop_track(i)
      end
    end
    -- queue splice load
    if next(tp[i].event) then
      local limit = track[i].rev == 0 and 64 or 1
      if track[i].pos_hi_res == limit then
        event(tp[i].event)
        tp[i].event = {}
        splice_queued = false
      end
    end
    -- randomize at cycle
    if autorand_at_cycle and track[i].sel == 1 and not oneshot_rec then
      track[i].step_count = track[i].step_count + 1
      if track[i].step_count > rnd_stepcount * 4 then
        randomize(i)
      end
    end
    -- rec @step / track 2 trigger
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
    -- trig @step mode / track 2 trigger
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
    -- trig @count mode / track 2 trigger
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
    local bpmmod = current_tempo / clip[i].bpm
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
      local start = tp[track_focus].s
      local length = tp[track_focus].e - tp[track_focus].s
      local buffer = tp[track_focus].side
      softcut.render_buffer(buffer, start, length, 128)
    else
      local n = track[track_focus].splice_focus
      local start = tp[track_focus].splice[n].s
      local length = tp[track_focus].splice[n].e - tp[track_focus].splice[n].s
      local buffer = tp[track_focus].side
      softcut.render_buffer(buffer, start, length, 128)
    end
  end
end


--------------------- SCALE AND TRANSPOSITION -----------------------
function set_scale(option) -- set scale id, thanks ezra
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
      local beat_sync = track[i].start_launch == 2 and 1 or bar_val
      local pos
      if track[i].loop == 0 then
        pos = track[i].rev == 0 and clip[i].s or clip[i].e
      else
        local s = clip[i].s + (track[i].loop_start - 1) / 16 * clip[i].l
        local e = clip[i].s + (track[i].loop_end) / 16 * clip[i].l
        pos = track[i].rev == 0 and s or e
      end
      clock.run(function() 
        clock.sync(beat_sync)
        local e = {t = eSTART, i = i, pos = pos, sync = true} event(e)
      end)
    end
  end
end

function toggle_transport()
  if transport_run == false then
    if params:get("midi_trnsp") == 2 then
      m:start()
    end
    transport_run = true
  end
end

function startall() -- start all tracks at the beginning
  for i = 1, 6 do
    local pos = track[i].rev == 0 and 0 or 15
    local e = {} e.t = eCUT e.i = i e.pos = pos event(e)
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
      local pos = track[i].rev == 0 and 0 or 15
      local e = {} e.t = eCUT e.i = i e.pos = pos event(e)
    end
  end
end


--------------------- ONESHOT RECORDING -----------------------

function arm_thresh_rec(i)
  if oneshot_rec then
    chop(i)
  else
    track[i].oneshot = 1 - track[i].oneshot
    for n = 1, 6 do
      if n ~= i then
        track[n].oneshot = 0
      end
    end
    if track[i].oneshot == 1 then
      armed_track = i
      -- calc duration
      if track[i].tempo_map == 2 then
        track[i].dur = ((beat_sec * clip[i].l) / math.pow(2, track[i].speed + track[i].transpose + track[i].detune)) * (clip[i].bpm / 60)
      else
        track[i].dur = clip[i].l / math.pow(2, track[i].speed + track[i].transpose + track[i].detune)
      end
      if track[i].loop == 1 and track[i].play == 1 then
        local len = track[i].loop_end - track[i].loop_start + 1
        track[i].dur = (track[i].dur / 16) * len
      end
      -- set autolength
      if alt == 1 then
        local e = {} e.t = eSTOP e.i = i event(e)
        autolength = true
      else
        autolength = false
      end
      -- enter quarantine if not playing
      if track[i].play == 0 then
        set_quarantine(i, true)
      end
      backup_rec(i, "save")
      amp_in[1]:start()
      amp_in[2]:start()
    else
      set_quarantine(i, false)
      amp_in[1]:stop()
      amp_in[2]:stop()
    end
  end
end

function rec_at_threshold(i)
  loop_pos = track[i].pos_grid
  rec_dur = 0
  if track[i].play == 0 then
    set_quarantine(i, false)
    local pos = track[i].rev == 0 and 0 or 15
    local cut = (pos / 16) * clip[i].l + clip[i].s
    local q = track[i].rev == 1 and clip[i].l / 16 or 0
    softcut.position(i, cut + q)
    track[i].play = 1
    track[i].beat_count = 0
    set_level(i)
    toggle_transport()
  end
  track[i].rec = 1
  set_rec(i)
  clock.run(oneshot_timer, track[armed_track].dur)
  tracktimer:start()
  amp_in[1]:stop()
  amp_in[2]:stop()
  oneshot_rec = true
  dirtygrid = true
end

function oneshot_timer(dur)
  clock.sleep(dur)
  track[armed_track].rec = 0
  track[armed_track].oneshot = 0
  set_rec(armed_track)
  tracktimer:stop()
  oneshot_rec = false
end

function chop(i)
  if oneshot_rec == true and track[i].oneshot == 1 then
    if autolength then
      -- get length of recording and stop timer
      tracktimer:stop()
      local length = rec_dur / 100
      -- set splice markers
      local beat_num = get_beatnum(length)
      local s = track[i].splice_active
      tp[i].splice[s].l = length
      tp[i].splice[s].e = tp[i].splice[s].s + length
      tp[i].splice[s].init_start = tp[i].splice[s].s
      tp[i].splice[s].init_len = length
      tp[i].splice[s].beatnum = beat_num
      tp[i].splice[s].bpm = 60 / length * beat_num
      -- set clip
      set_clip(i)
      set_info(i, s)
      track[i].oneshot = 0
      autolength = false
    else
      -- set loop points
      local lstart = math.min(loop_pos, track[i].pos_grid)
      local lend = math.max(loop_pos, track[i].pos_grid)
      loop_event(i, lstart, lend)
      track[i].oneshot = 0
    end
    -- stop rec
    track[i].rec = 0
    set_rec(i)
    oneshot_rec = false
  end
end


--------------------- LFOS -----------------------

NUM_LFOS = 6
lfo_launch = 0
lfo_destination = {"volume", "pan", "dub   level", "transpose", "detune", "rate   slew", "cutoff"}
lfo_params = {"vol", "pan", "dub", "transpose", "detune", "rate_slew", "cutoff"}
lfo_min = {0, -1, 0, 1, -600, 0, 20}
lfo_max = {1, 1, 1, 15, 600, 1, 12000}
lfo_baseline = {'min', 'center', 'min', 'center', 'center', 'min', 'max'}
lfo_baseline_options = {'min', 'center', 'max'}

function init_lfos()
  lfo = {}
  for i = 1, NUM_LFOS do
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

function update_param_lfo_rate()
  ui.update_lfo_param()
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
  env[i].clock = nil
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
function env_run(i)
  while true do
    clock.sleep(1/10)
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

function init_envelope(i)
  if env[i].active then
    track[i].prev_level = track[i].level
    params:set(i.."vol", env[i].init_value)
    if env[i].clock ~= nil then
      clock.cancel(env[i].clock)
    end
    env[i].clock = clock.run(env_run, i)
  else
    env[i].gate = false
    env[i].a_is_running = false
    env[i].d_is_running = false
    env[i].r_is_running = false
    env[i].count = 0
    env[i].direction = 1
    params:set(i.."vol", track[i].prev_level)
    if env[i].clock ~= nil then
      clock.cancel(env[i].clock)
    end
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
  warble[i].clock = nil
end

function toggle_warble(i)
  if track[i].warble == 0 then
    if warble[i].clock ~= nil then
      clock.cancel(warble[i].clock)
    end
  else
    if warble[i].clock ~= nil then
      clock.cancel(warble[i].clock)
    end
    warble[i].clock = clock.run(make_warble, i)
  end
end

function make_warble(i) -- warbletimer function
  while true do
    clock.sleep(0.1)
    -- make sine (from hnds)
    local slope = 1 * math.sin(((tau / 100) * (warble[i].counter)) - (tau / (warble[i].freq)))
    warble[i].slope = util.linlin(-1, 1, -1, 0, math.max(-1, math.min(1, slope))) * warble[i].depth
    warble[i].counter = warble[i].counter + warble[i].freq
    -- activate warble
    if track[i].play == 1 and math.random(100) <= warble[i].amount then
      if not warble[i].active then
        warble[i].active = true
      end
    end
    -- make warble
    if warble[i].active then
      local n = math.pow(2, track[i].speed + track[i].transpose + track[i].detune)
      if track[i].rev == 1 then n = -n end
      if track[i].tempo_map == 2 then
        local bpmmod = current_tempo / clip[i].bpm
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
  clock.run(function()
    clock.sleep(0.2)
    build_midi_device_list()
  end)
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

function clock.tempo_change_handler()
  recalc_splices()
  recalc_time_factor()
  set_time_vars()
end

function clock.transport.start()
  if params:get("midi_trnsp") == 3 then
    startall()
  end
end

function clock.transport.stop()
  if params:get("midi_trnsp") == 3 then
    stopall()
  end
end

function set_time_vars()
  current_tempo = params:get("clock_tempo")
  beat_sec = 60 / params:get("clock_tempo")
end

--------------------- CLOCK COROUTINES -----------------------

function ledpulse_bar()
  while true do
    clock.sync(bar_val)
    pulse_bar = true
    dirtygrid = true
    pulse_key_mid = 12
    pulse_key_slow = 12
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
          if track[i].rec == 0 and track[i].loaded then
            reset_pos(i)
          end
          track[i].beat_count = 0
        end
      end
    end
  end
end

function tempo_transition(beats, dest_tempo)
  local delta_bpm = dest_tempo - current_tempo
  local beat_sync = beats / math.abs(delta_bpm)
  if delta_bpm > 0 then
    while current_tempo < dest_tempo do
      clock.sync(beat_sync)
      params:delta("clock_tempo", 1)
    end
  else
    while current_tempo > dest_tempo do
      clock.sync(beat_sync)
      params:delta("clock_tempo", -1)
    end
  end
end

--------------------- FILE CALLBACKS -----------------------
function get_length_audio(path)
  local ch, len = audio.file_info(path)
  local l = 0
  if ch > 0 and len > 0 then
    l = len / 48000
  end
  return l
end

function fileload_callback(path, i)
  if path ~= "cancel" and path ~= "" then
    -- set startpoint
    local s = track[i].splice_focus
    tp[i].splice[s].s = s == 1 and tp[i].s or (tp[i].splice[s - 1].e + FADE_TIME)
    local max_l = tp[i].e - tp[i].splice[s].s
    local file_l = get_length_audio(path)
    if file_l > 0 then
      local l = math.min(file_l, max_l)
      load_audio(path, i, s, l)
    else
      print("not a sound file")
    end
  end
  screenredrawtimer:start()
  render_splice()
  dirtyscreen = true
  dirtygrid = true
end

function batchload_callback(path, i)
  if path ~= "cancel" and path ~= "" then
    batchload_path = path
    batchload_track = i
  else
    view_batchload_options = false
  end
  screenredrawtimer:start()
  dirtyscreen = true
end

function load_audio(path, i, s, l)
  local buffer = tp[i].side
  local num_beats = get_beatnum(l)
  -- load audio
  softcut.buffer_read_mono(path, 0, tp[i].splice[s].s, l, 1, buffer)
  -- set splice   
  tp[i].splice[s].l = l
  tp[i].splice[s].e = tp[i].splice[s].s + l
  tp[i].splice[s].init_start = tp[i].splice[s].s
  tp[i].splice[s].init_len = l
  tp[i].splice[s].init_beatnum = num_beats
  tp[i].splice[s].beatnum = num_beats
  tp[i].splice[s].resize = track[i].tempo_map > 1 and num_beats or math.ceil(l)
  tp[i].splice[s].bpm = 60 / l * num_beats
  tp[i].splice[s].name = str_format(path:match("[^/]*$"), 24)
  if s == track[i].splice_active then  
    set_clip(i)
  end
  set_info(i, s)
  print("file: "..tp[i].splice[s].name.." "..string.format("%.2f", tp[i].splice[s].l))
  return tp[i].splice[s].e + FADE_TIME
end

function load_batch(path, i, s, n)
  local filepath = path:match("[^/]*$")
  local folder = path:match("(.*[/])")
  local files = util.scandir(folder)
  local filestart = 0
  local fileend = 0
  local s = s
  local splice_s = s == 1 and tp[i].s or (tp[i].splice[s - 1].e + FADE_TIME)
  -- get file index
  for index, filename in ipairs(files) do
    if filename == filepath then
      filestart = index
      fileend = index + n
      ::continue::
    end
  end
  ::continue::
  for f = filestart, fileend do
    if files[f] ~= nil and s <= 8 then
      -- file data
      local filepath = folder.."/"..files[f]
      local file_l = get_length_audio(filepath)
      if file_l > 0 then
        -- load splice
        if splice_s + file_l <= tp[i].e then
          tp[i].splice[s].s = splice_s
          splice_s = load_audio(filepath, i, s, file_l)
          s = s + 1
        else
          print(files[f].." too long - can't populate further")
          show_message("splice   "..s.."   too long")
          goto done
        end
      else
        print(files[f].." is not a sound file")
      end
    else
      print("no file - out of bounds")
    end
  end
  ::done::
  render_splice()
  dirtyscreen = true
  dirtygrid = true
end

function filerename_callback(txt)
  if txt then
    tp[track_focus].splice[track[track_focus].splice_focus].name = txt
  end
  screenredrawtimer:start()
  dirtyscreen = true
end

function filesave_callback(txt)
  if txt then
    local start = tp[track_focus].splice[track[track_focus].splice_focus].s
    local length = tp[track_focus].splice[track[track_focus].splice_focus].l
    local buffer = tp[track_focus].side
    softcut.buffer_write_mono(mlre_path .. txt .. ".wav", start, length, buffer)
    tp[track_focus].splice[track[track_focus].splice_focus].name = txt
    print("saved " .. mlre_path .. txt .. ".wav", start, length)
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
        local pset_id = string.sub(io.read(), 4, -1)
        table.insert(pset_list, pset_id)
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
      local newfactor = pattern[i].bpm / current_tempo
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
    -- remove conditionals eventually
    if loaded_sesh_data[i].snap_active_splice ~= nil then
      snap[i].active_splice = {table.unpack(loaded_sesh_data[i].snap_active_splice)}
    end
    if loaded_sesh_data[i].snap_rec ~= nil then
      snap[i].rec = {table.unpack(loaded_sesh_data[i].snap_rec)}
    end
    if loaded_sesh_data[i].snap_route_t5 ~= nil then
      snap[i].route_t5 = {table.unpack(loaded_sesh_data[i].snap_route_t5)}
      snap[i].route_t6 = {table.unpack(loaded_sesh_data[i].snap_route_t6)}
    end
    if loaded_sesh_data[i].snap_lfo_enabled ~= nil then
      snap[i].lfo_enabled = {table.unpack(loaded_sesh_data[i].snap_lfo_enabled)}
    end
    -- set pmac params
    if loaded_sesh_data.pmac_d ~= nil then
      pmac.d = deep_copy(loaded_sesh_data.pmac_d)
    end
  end
end

function save_loadop_config()
  local data = {}
  for _, v in ipairs(loadop.params) do
    data[v] = loadop[v]
  end
  tab.save(data, norns.state.lib.."load_options.data")
end

function load_loadop_config()
  local data = tab.load(norns.state.lib.."load_options.data")
  if data ~= nil then
    for _, v in ipairs(loadop.params) do
      if (v == "send_t5" or v == "send_t6" or v == "route_t5" or v == "route_t6") then
        params:set("loadop_sends", data[v])
      else
        params:set("loadop_"..v, data[v])
      end
    end
  end
end

function silent_load(number, pset_id)
  -- load sesh data file
  loaded_sesh_data = {}
  loaded_sesh_data = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")
  if loaded_sesh_data then
    if loaded_sesh_data.newerformat ~= nil then
      -- load audio to temp buffer
      softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 2)
      -- load pattern, recall and snapshot data
      load_patterns()
      -- set tempo
      if loadop.tempo > 1 and (current_tempo ~= loaded_sesh_data.tempo) then
        if loadop.tempo == 2 then
          params:set("clock_tempo", loaded_sesh_data.tempo)
        elseif loadop.tempo == 3 then
          tt_clk = clock.run(tempo_transition, loadop.transition, loaded_sesh_data.tempo)
        end
      end
      -- set scale
      if loadop.scale == 2 then
        params:set("scale", loaded_sesh_data.scale)
      end
      -- set quantization
      if loadop.quant_rate == 2 then
        params:set("quant_rate", loaded_sesh_data.quant_rate)
      end
      -- set time signature
      if loadop.time_signature == 2 then
        params:set("time_signature", loaded_sesh_data.time_signature)
      end
      -- flip load state and load stopped tracks
      loadop.active = true
      for i = 1, 6 do
        track[i].loaded = false
        if track[i].play == 0 then load_track_tape(i) end
      end
      clock.run(function() clock.sleep(0.1) render_splice() end)
      dirtygrid = true
      show_message("silent   load   "..pset_id)
      print("silent load: "..pset_id)
    else
      show_message("wrong   format  >  save   pset")
    end
  else
    print("error: no data loaded")
  end
end

function queue_track_tape(i)
  local beat_sync = loadop.sync > 1 and (loadop.sync == 3 and bar_val or 1) or (quantizing and q_rate or nil)
  if beat_sync ~= nil then
    clock.run(function()
      clock.sync(beat_sync)
      load_track_tape(i)
    end)
  else
    load_track_tape(i)
  end
end

function load_track_tape(i)
  -- load and clear tape
  softcut.buffer_copy_mono(2, 1, tp[i].s - FADE_TIME, tp[i].s - FADE_TIME, MAX_TAPELENGTH + FADE_TIME, 0.01)
  softcut.buffer_clear_region_channel(2, tp[i].s - 0.5, MAX_TAPELENGTH + 0.5, 0.01, 0)
  -- tape data
  tp[i].s = loaded_sesh_data[i].tape_s
  tp[i].e = loaded_sesh_data[i].tape_e
  tp[i].splice = {table.unpack(loaded_sesh_data[i].tape_splice)}
  if tp[i].splice[1].resize == nil then -- TODO: remove once psets have been re-saved.
    for j = 1, 8 do
      tp[i].splice[j].resize = 4
    end
  end
  if tp[i].buffer ~= loaded_sesh_data[i].track_buffer then
    params:set(i.."tape_buffer", loaded_sesh_data[i].track_buffer, true) -- silent (no need to re-calc splice markers as saved like og)
  end
  if loadop.splice_active > 1 then
    local num = loadop.splice_active == 2 and loaded_sesh_data[i].track_splice_active or 1
    track[i].splice_active = num
    track[i].splice_focus = num
  end
  -- track data
  for k, v in pairs(loadop.set_param) do
    if loadop[v] == 2 then -- load from pset data
      local t = "track_"..v
      params:set(i..v, loaded_sesh_data[i][t])
    elseif loadop[v] == 3 then -- reset to default
      params:set(i..v, loadop.param_default[k])
    end
  end
  
  for k, v in pairs(loadop.set_tab) do
    if loadop[v] == 2 then -- load from pset data
      local t = "track_"..v
      track[i][v] = loaded_sesh_data[i][t]
    elseif loadop[v] == 3 then -- reset to default
      track[i][v] = 0
    end
  end

  if loadop.loops == 3 or loaded_sesh_data[i].track_loop == 0 then -- reset
    clear_loop(i)
  elseif loadop.loops == 2 then -- load
    track[i].loop = loaded_sesh_data[i].track_loop
    track[i].loop_start = loaded_sesh_data[i].track_loop_start
    track[i].loop_end = loaded_sesh_data[i].track_loop_end
  end
  -- set tempo map and clip
  params:set(i.."tempo_map_mode", loaded_sesh_data[i].track_tempo_map)
  set_tempo_map(i)
  set_clip(i)
  -- set levels
  set_level(i)
  set_rec(i)
  -- reset pos and counter
  reset_pos(i)
  track[i].beat_count = 0
  track[i].loaded = true
  -- check for unloaded tracks
  local count = 0
  for n = 1, 6 do
    if not track[n].loaded then
      count = count + 1
    end
  end
  loadop.active = count > 0 and true or false
  -- render
  clock.run(function() clock.sleep(0.1) render_splice() end)
  -- msg
  show_message("track  "..i.."   loaded")
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
  -- detect arc
  if a.device then
    arc_is = true
  end

  -- set time variables
  current_tempo = params:get("clock_tempo")
  beat_sec = 60 / current_tempo

  -- make directory
  if util.file_exists(mlre_path) == false then
    util.make_dir(mlre_path)
  end

  -- build lists
  build_pset_list()
  build_midi_device_list()

  -- params for "globals"
  params:add_separator("global_params", "global")
  -- params for scales
  params:add_option("scale", "scale", scales.options, 1)
  params:set_action("scale", function(option) set_scale(option) end)

  -- quantization params
  params:add_group("quantization_params", "quantization", 4)

  params:add_number("time_signature", "time signature", 2, 9, 4, function(param) return param:get().."/4" end)
  params:set_action("time_signature", function(val) bar_val = val end)

  params:add_option("quant_rate", "key quantization", event_q_options, 1)
  params:set_action("quant_rate", function(idx) set_quantizer(idx) end)

  params:add_option("snap_launch", "snapshot launch", {"manual", "beat", "bar"}, 1)
  params:set_action("snap_launch", function(mode) snap_launch = mode end)

  params:add_option("splice_launch", "splice launch", {"manual", "beat", "bar", "queue"}, 1)
  params:set_action("splice_launch", function(mode) splice_launch = mode end)

  -- rec params
  params:add_group("rec_params", "recording", 5)
  
  params:add_option("rec_source", "rec source", {"adc/eng", "adc/tape", "adc/eng/tape"})
  params:set_action("rec_source", function(option) set_track_source(option) end)
  
  params:add_control("rec_threshold", "rec threshold", controlspec.new(-40, 0, 'lin', 0.01, -12, "dB"))
  params:set_action("rec_threshold", function(val) amp_threshold = util.dbamp(val) / 10 end)
  
  params:add_control("rec_slew", "rec slew", controlspec.new(1, 10, 'lin', 0, 1, "ms"))
  params:set_action("rec_slew", function(val) for i = 1, 6 do softcut.recpre_slew_time(i, val * 0.001) end end)

  params:add_option("rec_filter", "rec pre filter", {"off", "on"}, 2)
  params:set_action("rec_filter", function(option)
    local dry_level = option == 1 and 1 or 0
    local lp_level = option == 1 and 0 or 1
    for i = 1, 6 do
      softcut.pre_filter_dry(i, dry_level)
      softcut.pre_filter_lp(i, lp_level)
    end
  end)

  params:add_option("rec_backup", "auto-backup", {"off", "on"})
  params:set_action("rec_backup", function(mode) rec_autobackup = mode == 2 and true or false end)

  
  -- macro params
  params:add_group("macro_params", "macros", 14)
  
  params:add_option("slot_assign", "macro slots", {"split", "patterns only", "recall only"}, 1)
  params:set_action("slot_assign", function(option) macro_slot_mode = option dirtygrid = true end)
  if GRID_SIZE == 256 then params:hide("slot_assign") end
  
  params:add_option("recall_mode", "recall mode", {"punch-in", "snapshot"}, 2)
  params:set_action("recall_mode", function(x) snapshot_mode = x == 2 and true or false dirtygrid = true end)
  params:hide("recall_mode")

  params:add_option("punchin_mode", "punch-in mode", {"momentary", "latch"}, 1)
  params:set_action("punchin_mode", function(x) punch_momentrary = x == 1 and true or false dirtygrid = true end)
  params:hide("punchin_mode")

  params:add_separator("snapshot_options", "snapshot options")

  params:add_option("recall_playback_state", "playback", {"ignore", "state only", "state & pos", "state & reset"}, 1)
  params:set_action("recall_playback_state", function(x)
    snap_play_state = x > 1 and true or false
    snap_cut_pos = x == 3 and true or false
    snap_reset_pos = x == 4 and true or false
    dirtygrid = true
  end)

  params:add_option("recall_active_splice", "active splice", {"ignore", "recall"}, 2)
  params:set_action("recall_active_splice", function(x) snap_set_splice = x == 2 and true or false end)

  params:add_option("recall_loop_state", "loops", {"ignore", "recall"}, 2)
  params:set_action("recall_loop_state", function(x) snap_set_loop = x == 2 and true or false end)
  
  params:add_option("recall_rec_state", "rec state", {"ignore", "recall"}, 2)
  params:set_action("recall_rec_state", function(x) snap_set_rec = x == 2 and true or false end)

  params:add_option("recall_mute_state", "mute state", {"ignore", "recall"}, 2)
  params:set_action("recall_mute_state", function(x) snap_set_mute = x == 2 and true or false end)

  params:add_option("recall_rev_state", "rev state", {"ignore", "recall"}, 2)
  params:set_action("recall_rev_state", function(x) snap_set_rev = x == 2 and true or false end)

  params:add_option("recall_speed_state", "speed", {"ignore", "recall"}, 2)
  params:set_action("recall_speed_state", function(x) snap_set_speed = x == 2 and true or false end)

  params:add_option("recall_transpose_state", "transposition", {"ignore", "recall"}, 2)
  params:set_action("recall_transpose_state", function(x) snap_set_trsp = x == 2 and true or false end)

  params:add_option("recall_set_route", "track sends", {"ignore", "recall"}, 2)
  params:set_action("recall_set_route", function(x) snap_set_route = x == 2 and true or false end)

  params:add_option("recall_lfo_state", "lfo state", {"ignore", "recall"}, 2)
  params:set_action("recall_lfo_state", function(x) snap_set_lfo = x == 2 and true or false end)

  -- silent load config
  params:add_group("loadop_config", "silent load", 26)

  params:add_binary("loadop_save", ">> save options", "trigger")
  params:set_action("loadop_save", function() save_loadop_config() end)

  params:add_separator("loadop_globals", "global params")

  params:add_option("loadop_sync", "track load sync", {"manual", "beat", "bar"}, 1)
  params:set_action("loadop_sync", function(x) loadop.sync = x end)
  params:set_save("loadop_sync", false)

  params:add_option("loadop_tempo", "tempo", {"ignore", "load", "transition"}, 1)
  params:set_action("loadop_tempo", function(x)
    loadop.tempo = x
    if x == 3 then
      params:show("loadop_transition")
    else
      params:hide("loadop_transition")
    end
    _menu.rebuild_params()
    dirtyscreen = true
  end)
  params:set_save("loadop_tempo", false)

  params:add_number("loadop_transition", "transition", 2, 16, 4, function(param) return param:get().." beats" end)
  params:set_action("loadop_transition", function(x) loadop.transition = x end)
  params:set_save("loadop_transition", false)

  params:add_option("loadop_quant_rate", "key quantization", {"ignore", "load"}, 1)
  params:set_action("loadop_quant_rate", function(x) loadop.quant_rate = x end)
  params:set_save("loadop_quant_rate", false)

  params:add_option("loadop_time_signature", "time signature", {"ignore", "load"}, 1)
  params:set_action("loadop_time_signature", function(x) loadop.time_signature = x end)
  params:set_save("loadop_time_signature", false)

  params:add_option("loadop_scale", "scale", {"ignore", "load"}, 1)
  params:set_action("loadop_scale", function(x) loadop.scale = x end)
  params:set_save("loadop_scale", false)

  params:add_separator("loadop_tracks", "track params")

  params:add_option("loadop_reset_active", "track reset", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_reset_active", function(x) loadop.reset_active = x end)
  params:set_save("loadop_reset_active", false)

  params:add_option("loadop_reset_count", "reset count", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_reset_count", function(x) loadop.reset_count = x end)
  params:set_save("loadop_reset_count", false)

  params:add_option("loadop_loops", "track loops", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_loops", function(x) loadop.loops = x end)
  params:set_save("loadop_loops", false)

  params:add_option("loadop_pan", "pan", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_pan", function(x) loadop.pan = x end)
  params:set_save("loadop_pan", false)

  params:add_option("loadop_rev", "direction", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_rev", function(x) loadop.rev = x end)
  params:set_save("loadop_rev", false)

  params:add_option("loadop_speed", "speed", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_speed", function(x) loadop.speed = x end)
  params:set_save("loadop_speed", false)

  params:add_option("loadop_detune", "detune", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_detune", function(x) loadop.detune = x end)
  params:set_save("loadop_detune", false)

  params:add_option("loadop_transpose", "transpose", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_transpose", function(x) loadop.transpose = x end)
  params:set_save("loadop_transpose", false)

  params:add_option("loadop_sends", "sends", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_sends", function(x)
    loadop.send_t5 = x
    loadop.send_t6 = x
    loadop.route_t5 = x
    loadop.route_t6 = x
  end)
  params:set_save("loadop_sends", false)

  params:add_option("loadop_warble_state", "warble", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_warble_state", function(x) loadop.warble_state = x end)
  params:set_save("loadop_warble_state", false)

  params:add_option("loadop_sel", "track select", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_sel", function(x) loadop.sel = x end)
  params:set_save("loadop_sel", false)

  params:add_option("loadop_fade", "track fade", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_fade", function(x) loadop.fade = x end)
  params:set_save("loadop_fade", false)

  params:add_option("loadop_splice_active", "active splice", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_splice_active", function(x) loadop.splice_active = x end)
  params:set_save("loadop_splice_active", false)

  params:add_separator("loadop_remote", "remote control")

  params:add_binary("loadop_silent_load", ">> silent load", "trigger")
  params:set_action("loadop_silent_load", function()
    local num = string.format("%0.2i", pset_focus)
    local pset_id = pset_list[pset_focus]
    silent_load(num, pset_id)
  end)

  params:add_binary("loadop_inc_pset", "> inc pset", "trigger")
  params:set_action("loadop_inc_pset", function()
    pset_focus = util.clamp(pset_focus + 1, 1, #pset_list)
    show_message("selected   "..pset_list[pset_focus])
  end)

  params:add_binary("loadop_dec_pset", "< dec pset", "trigger")
  params:set_action("loadop_dec_pset", function()
    pset_focus = util.clamp(pset_focus - 1, 1, #pset_list)
    show_message("selected   "..pset_list[pset_focus])
  end)

  -- midi params
  params:add_group("track_control_params", "track control", 63)
  
  params:add_separator("midi_transport_control", "midi output")

  params:add_option("midi_trnsp","midi transport", {"off", "send", "receive"}, 1)

  params:add_option("midi_device", "midi out device", midi_devices, 1)
  params:set_action("midi_device", function(val) m = midi.connect(val) end)
  
  params:add_separator("global_track_control", "global track control")
  -- start all
  params:add_binary("start_all", "start all", "trigger", 0)
  params:set_action("start_all", function() startall() end)
  -- restart all
  params:add_binary("restart_all", "restart all", "trigger", 0)
  params:set_action("restart_all", function() retrig() end)
  -- stop all
  params:add_binary("stop_all", "stop all", "trigger", 0)
  params:set_action("stop_all", function() stopall() end)

  params:add_separator("control_focused_track", "focused track control")
  -- playback
  params:add_binary("track_focus_playback", "playback", "trigger", 0)
  params:set_action("track_focus_playback", function() toggle_playback(track_focus) end)
  -- mute
  params:add_binary("track_focus_mute", "mute", "trigger", 0)
  params:set_action("track_focus_mute", function()
    local i = track_focus
    local n = 1 - track[i].mute
    local e = {} e.t = eMUTE e.i = i e.mute = n event(e)
  end)
  -- record enable
  params:add_binary("rec_focus_enable", "record", "trigger", 0)
  params:set_action("rec_focus_enable", function() toggle_rec(track_focus) end)
  -- reverse
  params:add_binary("tog_focus_rev", "direction", "trigger", 0)
  params:set_action("tog_focus_rev", function()
    local i = track_focus
    local n = 1 - track[i].rev
    local e = {} e.t = eREV e.i = i e.rev = n event(e)
  end)
  -- speed +
  params:add_binary("inc_focus_speed", "speed +", "trigger", 0)
  params:set_action("inc_focus_speed", function()
    local i = track_focus
    local n = util.clamp(track[i].speed + 1, -3, 3)
    local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
  end)
  -- speed -
  params:add_binary("dec_focus_speed", "speed -", "trigger", 0)
  params:set_action("dec_focus_speed", function()
    local i = track_focus
    local n = util.clamp(track[i].speed - 1, -3, 3)
    local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
  end)
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
    params:set_action(i.."track_mute", function()
      local n = 1 - track[i].mute
      local e = {} e.t = eMUTE e.i = i e.mute = n event(e) end)
    -- record enable
    params:add_binary(i.."tog_rec", "record", "trigger", 0)
    params:set_action(i.."tog_rec", function() toggle_rec(i) end)
    -- reverse
    params:add_binary(i.."tog_rev", "reverse", "trigger", 0)
    params:set_action(i.."tog_rev", function()
      local n = 1 - track[i].rev
      local e = {} e.t = eREV e.i = i e.rev = n event(e)
    end)
    -- speed +
    params:add_binary(i.."inc_speed", "speed +", "trigger", 0)
    params:set_action(i.."inc_speed", function()
      local n = util.clamp(track[i].speed + 1, -3, 3)
      local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
    end)
    -- speed -
    params:add_binary(i.."dec_speed", "speed -", "trigger", 0)
    params:set_action(i.."dec_speed", function()
      local n = util.clamp(track[i].speed - 1, -3, 3)
      local e = {} e.t = eSPEED e.i = i e.speed = n event(e)
    end)
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
  params:add_control("rnd_ucut", "upper freq", controlspec.new(20, 12000, 'exp', 1, 12000, "Hz"))
  params:add_control("rnd_lcut", "lower freq", controlspec.new(20, 12000, 'exp', 1, 20, "Hz"))

  -- arc settings
  params:add_group("arc_params", "arc settings", 6)
  params:add_option("arc_orientation", "arc orientation", {"horizontal", "vertical"}, 1)
  params:set_action("arc_orientation", function(val) arc_off = (val - 1) * 16 end)
  params:add_option("arc_enc_1_start", "enc1 > start", {"off", "on"}, 2)
  params:add_option("arc_enc_1_dir", "enc1 > direction", {"off", "on"}, 1)
  params:add_option("arc_enc_1_mod", "enc1 > mod", {"off", "warble", "scrub"}, 3)
  params:add_number("arc_srub_sens", "scrub sensitivity", 1, 10, 6)
  params:set_action("arc_srub_sens", function(val) scrub_sens = -50 * val + 550 end)
  params:add_number("arc_pmac_sens", "p-macro sensitivity", 1, 10, 2)
  params:set_action("arc_pmac_sens", function(val) pmac_sens = 5 * val end)

  -- patterns params
  params:add_group("patterns", "patterns", 40)
  params:hide("patterns")
  for i = 1, 8 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("patterns_playback"..i, "playback", {"loop", "oneshot"}, 1)
    params:set_action("patterns_playback"..i, function(mode) pattern[i].loop = mode == 1 and true or false end)

    params:add_option("patterns_countin"..i, "launch", {"manual", "beat", "bar"}, 1)
    params:set_action("patterns_countin"..i, function(mode) pattern[i].count_in = mode dirtygrid = true end)

    params:add_option("patterns_meter"..i, "meter", pattern_meter, 3)
    params:set_action("patterns_meter"..i, function(idx) pattern[i].sync_meter = pattern_meter_val[idx] pattern[i]:set_ticks() end)

    params:add_number("patterns_barnum"..i, "length", 1, 32, 4, function(param) return param:get()..(pattern[i].sync_beatnum <= 4 and " bar" or " bars") end)
    params:set_action("patterns_barnum"..i, function(num) pattern[i].sync_beatnum = num * 4 pattern[i]:set_ticks() end)
  end

  -- params for tracks
  params:add_separator("track_params", "tracks")

  audio.level_cut(1)
  audio.level_tape(1)

  for i = 1, 6 do
    params:add_group("track_group"..i, "track "..i, 50)

    params:add_separator("track_options_params"..i, "track "..i.." options")
    -- input options
    params:add_option(i.."input_options", "tape input", {"sum", "left", "right", "off"}, 1)
    params:set_action(i.."input_options", function(option) tp[i].input = option set_softcut_input(i) end)
    params:hide(i.."input_options")
    -- set tape buffer
    params:add_number(i.."tape_buffer", "tape buffer", 1, 6, i)
    params:set_action(i.."tape_buffer", function(x) tp[i].buffer = x set_tape(i, x) end)
    -- select buffer side
    params:add_option(i.."buffer_sel", "tape side", {"main", "temp"}, 1)
    params:set_action(i.."buffer_sel", function(x) tp[i].side = x softcut.buffer(i, x) end)
    -- play mode
    params:add_option(i.."play_mode", "play mode", {"loop", "oneshot", "gate"}, 1)
    params:set_action(i.."play_mode", function(option) track[i].play_mode = option page_redraw(vMAIN, 7) end)
    -- tempo map
    params:add_option(i.."tempo_map_mode", "tempo-map", {"none", "resize", "repitch"}, 1)
    params:set_action(i.."tempo_map_mode", function(mode) track[i].tempo_map = mode - 1 set_tempo_map(i) grid_page(vREC) end)
    -- play lauch
    params:add_option(i.."start_launch", "track launch", {"manual", "beat", "bar"}, 1)
    params:set_action(i.."start_launch", function(option) track[i].start_launch = option page_redraw(vMAIN, 7) end)
    -- reset active
    params:add_option(i.."reset_active", "track reset", {"off", "on"}, 1)
    params:set_action(i.."reset_active", function(mode)
      track[i].reset = mode == 2 and true or false
      if mode == 2 then track[i].beat_count = 0 end
      page_redraw(vMAIN, 8)
    end)
    -- reset count
    params:add_number(i.."reset_count", "reset count", 1, 128, 1, function(param) return param:get() == 1 and "track" or (param:get().." beats") end)
    params:set_action(i.."reset_count", function() set_track_reset(i) page_redraw(vMAIN, 8) end)
    
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
    params:add_control(i.."send_t5", "track 5 send", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_t5", function(x) track[i].send_t5 = x set_track_sends(i) end)
    if i > 4 then params:hide(i.."send_t5") end
    -- send level track 6
    params:add_control(i.."send_t6", "track 6 send", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_t6", function(x) track[i].send_t6 = x set_track_sends(i) end)
    if i > 5 then params:hide(i.."send_t6") end

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
    params:add_control(i.."cutoff", "cutoff", controlspec.new(20, 12000, 'exp', 1, 12000, ""), function(param) return (round_form(param:get(), 1, " hz")) end)
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
    params:set_action(i.."warble_state", function(option) track[i].warble = option - 1 toggle_warble(i) grid_page(vREC) end)
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
    params:set_action(i.."adsr_attack", function(val) env[i].attack = val * 10 page_redraw(vENV, 1) page_redraw(vENV, 2) end)
    -- env decay
    params:add_control(i.."adsr_decay", "decay", controlspec.new(0, 10, 'lin', 0.1, 0.5, "s"))
    params:set_action(i.."adsr_decay", function(val) env[i].decay = val * 10 page_redraw(vENV, 1) page_redraw(vENV, 2) end)
    -- env sustain
    params:add_control(i.."adsr_sustain", "sustain", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_sustain", function(val) env[i].sustain = val clamp_env_levels(i) page_redraw(vENV, 1) page_redraw(vENV, 2) end)
    -- env release
    params:add_control(i.."adsr_release", "release", controlspec.new(0, 10, 'lin', 0.1, 1, "s"))
    params:set_action(i.."adsr_release", function(val) env[i].release = val * 10 page_redraw(vENV, 1) page_redraw(vENV, 2) end)    

    -- params for track to trigger
    params:add_separator(i.."trigger_params", "track "..i.." triggers")
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
        
    -- init softcut
    softcut.enable(i, 1)
    softcut.buffer(i, 1)

    softcut.play(i, 1)
    softcut.rec(i, 1)

    softcut.level(i, 1)
    softcut.pan(i, 0)
    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)

    softcut.fade_time(i, FADE_TIME)
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
  
  -- pset callbacks
  params.action_write = function(filename, name, number)
    -- save all markers
    save_all_markers()
    -- make directory
    os.execute("mkdir -p "..norns.state.data.."sessions/"..number.."/")
    -- save buffer content
    softcut.buffer_write_mono(norns.state.data.."sessions/"..number.."/"..name.."_buffer.wav", 0, -1, 1)
    -- save data in one big table
    local sesh_data = {}
    sesh_data.newerformat = true
    sesh_data.tempo = current_tempo
    sesh_data.scale = current_scale
    sesh_data.quant_rate = params:get("quant_rate")
    sesh_data.time_signature = params:get("time_signature")
    sesh_data.pmac_d = deep_copy(pmac.d)
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
      sesh_data[i].snap_rec = {table.unpack(snap[i].rec)}
      sesh_data[i].snap_play = {table.unpack(snap[i].play)}
      sesh_data[i].snap_mute = {table.unpack(snap[i].mute)}
      sesh_data[i].snap_loop = {table.unpack(snap[i].loop)}
      sesh_data[i].snap_loop_start = {table.unpack(snap[i].loop_start)}
      sesh_data[i].snap_loop_end = {table.unpack(snap[i].loop_end)}
      sesh_data[i].snap_pos_grid = {table.unpack(snap[i].cut)}
      sesh_data[i].snap_speed = {table.unpack(snap[i].speed)}
      sesh_data[i].snap_rev = {table.unpack(snap[i].rev)}
      sesh_data[i].snap_transpose_val = {table.unpack(snap[i].transpose_val)}
      sesh_data[i].snap_active_splice = {table.unpack(snap[i].active_splice)}
      sesh_data[i].snap_route_t5 = {table.unpack(snap[i].route_t5)}
      sesh_data[i].snap_route_t6 = {table.unpack(snap[i].route_t6)}
      sesh_data[i].snap_lfo_enabled = {table.unpack(snap[i].lfo_enabled)}
    end
    for i = 1, 6 do
      -- tape data
      sesh_data[i].tape_s = tp[i].s
      sesh_data[i].tape_e = tp[i].e
      sesh_data[i].tape_splice = {table.unpack(tp[i].splice)}
      -- clip data
      sesh_data[i].clip_s = clip[i].s
      sesh_data[i].clip_e = clip[i].e
      sesh_data[i].clip_l = clip[i].l
      sesh_data[i].clip_bpm = clip[i].bpm
      -- track data
      sesh_data[i].track_buffer = tp[i].buffer
      sesh_data[i].track_sel = track[i].sel
      sesh_data[i].track_fade = track[i].fade
      sesh_data[i].track_mute = track[i].mute
      sesh_data[i].track_speed = track[i].speed
      sesh_data[i].track_rev = track[i].rev
      sesh_data[i].track_loop = track[i].loop
      sesh_data[i].track_loop_start = track[i].loop_start
      sesh_data[i].track_loop_end = track[i].loop_end
      sesh_data[i].track_splice_active = track[i].splice_active
      sesh_data[i].track_splice_focus = track[i].splice_focus
      sesh_data[i].track_tempo_map = params:get(i.."tempo_map_mode")
      sesh_data[i].track_route_t5 = track[i].route_t5
      sesh_data[i].track_route_t6 = track[i].route_t6
      sesh_data[i].track_send_t5 = track[i].send_t5
      sesh_data[i].track_send_t6 = track[i].send_t6
      -- lfo data
      sesh_data[i].lfo_track = lfo[i].track
      sesh_data[i].lfo_destination = lfo[i].destination
      sesh_data[i].lfo_offset = params:get("lfo_offset_lfo_"..i)
      -- silent load specific
      sesh_data[i].track_pan = track[i].pan
      sesh_data[i].track_transpose = params:get(i.."transpose")
      sesh_data[i].track_detune = params:get(i.."detune")
      sesh_data[i].track_reset_active = params:get(i.."reset_active")
      sesh_data[i].track_reset_count = params:get(i.."reset_count")
      sesh_data[i].track_warble_state = params:get(i.."warble_state")
    end
    tab.save(sesh_data, norns.state.data.."sessions/"..number.."/"..name.."_session.data")
    -- rebuild pset list
    build_pset_list()
    print("finished writing pset:'"..name.."'")
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file and shift == 0 then
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
      if next(loaded_sesh_data) then
        -- set tempo
        if loaded_sesh_data.tempo ~= nil and loadop.tempo > 1 then
          params:set("clock_tempo", loaded_sesh_data.tempo)
        end
        -- load data
        for i = 1, 6 do
          -- tape data
          tp[i].s = loaded_sesh_data[i].tape_s
          tp[i].e  = loaded_sesh_data[i].tape_e
          tp[i].splice = {table.unpack(loaded_sesh_data[i].tape_splice)}
          if tp[i].splice[1].resize == nil then -- TODO: remove once psets have been re-saved.
            for j = 1, 8 do
              tp[i].splice[j].resize = 4
            end
          end
          -- route data
          if loaded_sesh_data.newerformat ~= nil then
            track[i].route_t5 = loaded_sesh_data[i].track_route_t5
            track[i].route_t6 = loaded_sesh_data[i].track_route_t6
          else
            track[i].route_t5 = 0
            track[i].route_t6 = 0
          end
          set_track_sends(i)
          -- track data
          track[i].loaded = true
          track[i].splice_active = loaded_sesh_data[i].track_splice_active
          track[i].splice_focus = loaded_sesh_data[i].track_splice_focus
          track[i].sel = loaded_sesh_data[i].track_sel
          track[i].fade = loaded_sesh_data[i].track_fade
          track[i].loop = loaded_sesh_data[i].track_loop
          track[i].loop_start = loaded_sesh_data[i].track_loop_start
          track[i].loop_end = loaded_sesh_data[i].track_loop_end
          -- set track state
          track[i].mute = loaded_sesh_data[i].track_mute
          set_level(i)
          track[i].speed = loaded_sesh_data[i].track_speed
          track[i].rev = loaded_sesh_data[i].track_rev
          clock.run(function() clock.sleep(0.1) set_tempo_map(i) end)
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
        -- load pattern, recall, snapshot and performance macro data
        load_patterns()
        dirtyscreen = true
        dirtygrid = true
        clock.run(function() clock.sleep(0.1) render_splice() end)
        print("finished reading pset:'"..pset_id.."'")
      else
        print("can't fetch data")
      end
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

  tracktimer = metro.init(function() rec_dur = rec_dur + 1 end, 0.01, -1)
  tracktimer:stop()


  -- lattice
  vizclock = lattice:new()

  fastpulse = vizclock:new_sprocket{
    action = function(t)
      pulse_key_fast = pulse_key_fast == 8 and 12 or 8
      if pattern_rec or track[armed_track].oneshot == 1 or splice_queued then dirtygrid = true end
    end,
    division = 1/32,
    enabled = true
  }

  midpulse = vizclock:new_sprocket{
    action = function(t)
      pulse_key_mid = util.wrap(pulse_key_mid + 1, 5, 12)
      if view_presets then dirtyscreen = true end
      if loadop.active then dirtygrid = true end
    end,
    division = 1/16,
    enabled = true
  }

  slowpulse = vizclock:new_sprocket{
    action = function(t)
      pulse_key_slow = util.wrap(pulse_key_slow + 1, 5, 12)
      if mutes_active or view == vENV then dirtygrid = true end
    end,
    division = 1/8,
    enabled = true
  }

  vizclock:start()

  -- clocks
  reset_clk = clock.run(track_reset)
  barpulse = clock.run(ledpulse_bar)
  beatpulse = clock.run(ledpulse_beat)

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
      if val > amp_threshold and not oneshot_rec then
        rec_at_threshold(armed_track)
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
 
  -- load silent load config
  load_loadop_config()

  for i = 1, 6 do
    stop_track(i) -- set all track levels to 0 post params:bang
  end

  set_view(vMAIN)
  set_gridview(vCUT, "z")
  set_gridview(vREC, "o")

  if pset_load then
    params:default()
  else
    params:bang()
  end
 
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
  if pmac_edit_view and x ~= vPATTERNS then pmac_edit_view = false end
  if pmac_perf_view and x == vTAPE then pmac_perf_view = false end
  grd.clear_keylogic()
  screen.ping()
  dirtyscreen = true
  dirtygrid = true
end

-- set screen view
function set_view(x)
  if x > 0 and x < 4 then x = vMAIN end
  view = x
  _key = v.key[x]
  _enc = v.enc[x]
  _redraw = v.redraw[x]
  _arcdelta = v.arcdelta[x]
  _arcredraw = v.arcredraw[x]
  dirtyscreen = true
  dirtygrid = true
end

function popupscreen(msg, func)
  popup_message = msg
  popup_func = func
  if popup_func ~= nil then
    popup_view = true
    dirtyscreen = true
  end
end

function key(n, z)
  if n == 1 then
    shift = z
    toggle_pmac_perf_view(z)
  else
    if popup_view then
      ui.popup_key(n, z)
    elseif keyquant_edit then
      -- do nothing
    elseif pmac_perf_view then
      ui.pmac_perf_key(n, z)
    elseif pmac_edit_view then
      ui.pmac_edit_key(n, z)
    else
      _key(n, z)
    end
  end
  dirtyscreen = true
end

function enc(n, d)
  if popup_view then
    -- do nothing
  elseif keyquant_edit then
    ui.keyquant_enc(n, d)
  elseif pmac_perf_view then
    ui.pmac_perf_enc(n, d)
  elseif pmac_edit_view then
    ui.pmac_edit_enc(n, d)
  else
    _enc(n, d)
  end
end

function redraw()
  if popup_view then
    ui.popup_redraw()
  elseif keyquant_edit then
    ui.keyquant_redraw()
  elseif pmac_perf_view then
    ui.pmac_perf_redraw()
  elseif pmac_edit_view then
    ui.pmac_edit_redraw()
  else
    _redraw()
  end
end

function a.delta(n, d)
  if pmac_perf_view then
    ui.arc_pmac_delta(n, d)
  else
    _arcdelta(n, d)
  end
end

function arcredraw()
  if pmac_perf_view then
    ui.arc_pmac_draw()
  else
    _arcredraw()
  end
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
  dirtygrid = true
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
  build_menu()
end

function arc_removed()
  arc_is = false
  build_menu()
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
  ui.arc_main_delta(n, d)
end

v.arcredraw[vPATTERNS] = function()
  ui.arc_main_draw()
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
  local i = i or 1
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

function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
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

function show_banner()
  local banner = {
    {1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1},
    {1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0},
    {1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0},
    {1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1},
  }
  local hi = GRID_SIZE == 256 and 7 or 3
  local lo = GRID_SIZE == 256 and 10 or 6
  g:all(0)
  for x = 1, 16 do
    for y = hi, lo do
      g:led(x, y, banner[y - hi + 1][x] * 4)
    end
  end
  g:refresh()
end

--------------------- TIME TO TIDY UP A BIT -----------------------

function cleanup()
  for i = 1, 8 do
    pattern[i]:cleanup()
    pattern[i] = nil
  end
  clock.cancel(reset_clk)
  clock.cancel(barpulse)
  clock.cancel(beatpulse)
  grid.add = function() end
  arc.add = function() end
  arc.remove = function() end
  midi.add = function() end
  midi.remove = function() end
  vizclock:destroy()
  show_banner()
end
