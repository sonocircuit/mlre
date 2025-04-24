-- mlre v2.2.0 @sonocircuit
-- llllllll.co/t/mlre
--
-- an adaption of
-- mlr v2.2.4 @tehn
-- llllllll.co/t/mlr-norns
--
-- for docs go to:
-- >> github.com
--    /sonocircuit/mlre
--
--

norns.version.required = 231114

local mu = require 'musicutil'
local lattice = require 'lattice'

local ui = include 'lib/ui_mlre'
local cp = include 'lib/compat_mlre'
local grd = include 'lib/grid_mlre'
local _lfo = include 'lib/lfo_mlre'
local scales = include 'lib/scales_mlre'
local _pattern = include 'lib/pattern_time_mlre'

m = midi.connect()
a = arc.connect()
g = grid.connect()


--------- user variables --------
local pset_load = false -- if true default pset loaded at launch
cut_autofocus = true -- if true pressing a playhead key on the cut page will set track focus


--------- other variables --------
local mlre_path = _path.audio.."mlre/"
prev_path = nil

-- constants
GRID_SIZE = 0
FADE_TIME = 0.01
SPLICE_GAP = FADE_TIME * 2
TAPE_GAP = 1
MAX_TAPELENGTH = 57
DEFAULT_SPLICELEN = 4
DEFAULT_BEATNUM = 4

-- ui variables
main_pageNum = 1
lfo_pageNum = 1
env_pageNum = 1
patterns_pageNum = 1
track_focus = 1
lfo_focus = 1
env_focus = 1
wrb_focus = 1
pattern_focus = 1
autofocus = true

alt = 0
mod = 0
shift = 0
arc_is = false
mutes_active = false
cutview_hold = false
keyquant_edit = false
warble_edit = false

view_splice_info = false
view_track_send = false
sends_focus = 1

view_presets = false
pset_focus = 1
pset_list = {}
loadsesh = {}

view_batchload_options = false
batchload_path = ""
batchload_track = 1
batchload_numfiles = 8

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
local loop_pos = 1
local rec_dur = 0
local autobackup = false
local rec_backup = false
local rec_default_mode = 1
local rec_launch = 1
autolength = false

-- misc variables
local init_done = false
local current_scale = 1
local current_tempo = 90
local autorand_at_cycle = false
local rnd_stepcount = 16

-- silent load variables
local loadop = {}
loadop.active = false
loadop.sync = 1
loadop.tempo = 1
loadop.transition = 1
loadop.scale = 1
loadop.lfos = 1
loadop.quant_rate = 1
loadop.time_signature = 1
loadop.loops = 1
loadop.reset_active = 1
loadop.reset_count = 1
loadop.vol = 1
loadop.pan = 1
loadop.sends = 1
loadop.detune = 1
loadop.transpose = 1
loadop.warble_state = 1
loadop.rev = 1
loadop.sel = 1
loadop.fade = 1
loadop.splice_active = 1
loadop.params = {
  "sync", "tempo", "transition", "scale", "quant_rate", "time_signature", "loops", "reset_active", "reset_count",
  "vol", "pan", "sends", "detune", "transpose", "warble_state", "rev", "speed", "sel", "fade", "splice_active"
}
loadop.set_param = {"reset_active", "reset_count", "vol", "pan", "send_t5", "send_t6", "detune", "transpose", "warble_state"}
loadop.param_default = {1, 1, 1, 0, 0.5, 0.5, 0, 8, 1}
loadop.set_tab = {"rev", "speed", "sel", "fade", "route_t5", "route_t6"}

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

--------------------- EVENTS -----------------------

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
  if punch.rec > 0 then
    if punch[punch.rec].active then
      table.insert(punch[punch.rec].event, e)
      punch[punch.rec].has_data = true
    end
  end
end

function loop_event(i, lstart, lend, sync)
  local e = {t = eLOOP, i = i, loop_start = lstart, loop_end = lend, sync = sync} event(e)
end

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
    render_splice(e.i)
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
    if track[e.i].rec_enabled then
      track[e.i].rec = e.rec
      set_rec(e.i)
    end
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


--------------------- MACROS -----------------------

-- macro slots
mPTN = 1 -- pattern slot
mSNP = 2 -- snapshot slot
mPIN = 3 -- punch-in slot

kmac = {}
kmac.o = {}
kmac.z = {}
kmac.o.sec = 1
kmac.z.sec = 1
kmac.o.tog = false
kmac.z.tog = false
kmac.slot_focus = 0
kmac.kit_assign = false
kmac.pattern_edit = true

kmac.slot = {}
for s = 1, 4 do
  kmac.slot[s] = {}
  for i = 1, 8 do
    kmac.slot[s][i] = mPTN
  end
end

function macro_slot_defaults()
  if GRID_SIZE == 128 then
    for i = 1, 4 do
      kmac.slot[1][i] = mPTN
      kmac.slot[1][i + 4] = mSNP
      kmac.slot[2][i] = mPTN
      kmac.slot[2][i + 4] = mPIN
    end
  else
    for i = 1, 8 do
      kmac.slot[1][i] = mPTN
      kmac.slot[2][i] = mPIN
      kmac.slot[3][i] = mSNP
      kmac.slot[4][i] = mPIN
    end
  end
end

-- pattern macros
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
    clock.sleep(1/30)
    pattern[i].flash = false
    dirtygrid = true
  end)
end

function recalc_time_factor()
  local tempo = params:get("clock_tempo")
  for i = 1, 8 do
    if pattern[i].bpm ~= nil then
      pattern[i].time_factor = pattern[i].bpm / tempo
    end
  end
end

-- punch-in macros
punch = {}
punch.rec = 0
punch.override = false
for i = 1, 8 do
  punch[i] = {}
  punch[i].has_data = false
  punch[i].active = false
  punch[i].event = {}
end

local tmp = {}
for i = 1, 6 do
  tmp[i] = {}
  tmp[i].play = 0
  tmp[i].rec = 0
  tmp[i].mute = 0
  tmp[i].route_t5 = 0
  tmp[i].route_t6 = 0
  tmp[i].loop = 0
  tmp[i].loop_start = 1
  tmp[i].loop_end = 16
  tmp[i].splice_active = 1
  tmp[i].speed = 0
  tmp[i].rev = 0
  tmp[i].transpose = 0
  tmp[i].lfo_enabled = 0
end

function save_event_state()
  punch.override = false
  for i = 1, 6 do
    tmp[i].play = track[i].play
    tmp[i].rec = track[i].rec
    tmp[i].mute = track[i].mute
    tmp[i].route_t5 = track[i].route_t5
    tmp[i].route_t6 = track[i].route_t6
    tmp[i].loop = track[i].loop
    tmp[i].loop_start = track[i].loop_start
    tmp[i].loop_end = track[i].loop_end
    tmp[i].splice_active = track[i].splice_active
    tmp[i].speed = track[i].speed
    tmp[i].rev = track[i].rev
    tmp[i].transpose = track[i].transpose
    tmp[i].lfo_enabled = lfo[i].enabled
  end
end

function reset_event_state(sync)
  if not punch.override then
    for i = 1, 6 do
      if track[i].play ~= tmp[i].play then
        toggle_playback(i)
      end
      if track[i].rec ~= tmp[i].rec then
        local e = {t = eREC, i = i, rec = tmp[i].rec, sync = sync} event(e)
      end
      if track[i].mute ~= tmp[i].mute then
        local e = {t = eMUTE, i = i, mute = tmp[i].mute, sync = sync} event(e)
      end
      if track[i].route_t5 ~= tmp[i].route_t5 then
        local e = {t = eROUTE, i = i, ch = 5, route = tmp[i].route_t5, sync = sync} event(e)
      end
      if track[i].route_t6 ~= tmp[i].route_t6 then
        local e = {t = eROUTE, i = i, ch = 6, route = tmp[i].route_t6, sync = sync} event(e)
      end
      if tmp[i].loop == 1 then
        loop_event(i, tmp[i].loop_start, tmp[i].loop_end)
      elseif track[i].loop == 1 then
        local e = {t = eUNLOOP, i = i, sync = sync} event(e)
        track[i].loop_start = tmp[i].loop_start
        track[i].loop_end = tmp[i].loop_end
      end
      if track[i].splice_active ~= tmp[i].splice_active then
        local e = {t = eSPLICE, i = i, active = tmp[i].splice_active, sync = sync} event(e)
      end
      if track[i].speed ~= tmp[i].speed then
        local e = {t = eSPEED, i = i, speed = tmp[i].speed, sync = sync} event(e)
      end
      if track[i].rev ~= tmp[i].rev then
        local e = {t = eREV, i = i, rev = tmp[i].rev, sync = sync} event(e)
      end
      if track[i].transpose ~= tmp[i].transpose then
        local e = {t = eTRSP, i = i, val = tmp[i].transpose, sync = sync} event(e)
      end
      if lfo[i].enabled ~= tmp[i].lfo_enabled then
        local action = tmp[i].lfo_enabled == 1 and "lfo_on" or "lfo_off"
        local e = {t = eLFO, i = i, action = action, sync = sync} event(e)
      end
    end
  end
end

-- snapshot macros
local snapop = {}
snapop.rec = false
snapop.mute = false
snapop.rev = false
snapop.speed = false
snapop.transpose = false
snapop.loops = false
snapop.sends = false
snapop.splice = false
snapop.play_state = false
snapop.lfo_state = false

snap = {}
for i = 1, 8 do
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
  snap[i].speed = {}
  snap[i].rev = {}
  snap[i].transpose_val = {}
  snap[i].active_splice = {}
  snap[i].route_t5 = {}
  snap[i].route_t6 = {}
  snap[i].lfo_enabled = {}
  for j = 1, 6 do
    snap[i].rec[j] = 0
    snap[i].play[j] = 0
    snap[i].mute[j] = 0
    snap[i].loop[j] = 0
    snap[i].loop_start[j] = 1
    snap[i].loop_end[j] = 16
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
  end
  snap[n].data = true
end

function launch_snapshot(n, i)
  local beat_sync = snap_launch > 1 and (snap_launch == 3 and bar_val or 1) or (quantizing and q_rate or nil)
  if beat_sync ~= nil then
    clock.run(function()
      clock.sync(beat_sync)
      snapshot_exec(n, i, true)
    end)
  else
    snapshot_exec(n, i)
  end
end

function snapshot_exec(n, i, sync)
  punch.override = true
  -- flip the unflipped
  if mod == 1 and not track[i].loaded then
    load_track_tape(i, true)
  end
  -- load se snap
  if snapop.rec then
    local e = {t = eREC, i = i, rec = snap[n].rec[i], sync = sync} event(e)
  end
  if snapop.mute then
    local e = {t = eMUTE, i = i, mute = snap[n].mute[i], sync = sync} event(e)
  end
  if snapop.rev then
    local e = {t = eREV, i = i, rev = snap[n].rev[i], sync = sync} event(e)
  end
  if snapop.speed then
    local e = {t = eSPEED, i = i, speed = snap[n].speed[i], sync = sync} event(e)
  end
  if snapop.transpose then
    local e = {t = eTRSP, i = i, val = snap[n].transpose_val[i], sync = sync} event(e)
  end
  if snapop.sends and snap[n].route_t5[i] ~= nil then
    local e = {t = eROUTE, i = i, ch = 5, route = snap[n].route_t5[i], sync = sync} event(e)
    local e = {t = eROUTE, i = i, ch = 6, route = snap[n].route_t6[i], sync = sync} event(e)
  end
  if snapop.splice then
    if snap[n].active_splice[i] ~= track[i].splice_active then
      local e = {t = eSPLICE, i = i, active = snap[n].active_splice[i], sync = sync} event(e)
    end
  end
  if snapop.loops then
    if snap[n].loop[i] == 1 then
      loop_event(i, snap[n].loop_start[i], snap[n].loop_end[i], sync)
    elseif snap[n].loop[i] == 0 then
      local e = {t = eUNLOOP, i = i, sync = sync} event(e)
    end
  end
  if snapop.play_state then
    if snap[n].play[i] == 0 then
      local e = {t = eSTOP, i = i, sync = sync} event(e)
    else
      local pos = track[i].rev == 0 and clip[i].cs or clip[i].ce
      local e = {t = eSTART, i = i, pos = pos, sync = sync} event(e)
    end
  end
  if snapop.lfo_state then
    local action = snap[n].lfo_enabled[i] == 1 and "lfo_on" or "lfo_off"
    local e = {t = eLFO, i = i, action = action , sync = sync} event(e)
  end
end

-- p-macros
local pmac_params = {"cutoff", "filter_q", "vol", "pan", "detune", "rate_slew"}
local pmac_perf_view = false
pmac_edit_view = false
pmac_focus = 1
pmac_enc = 1

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
for i = 1, 6 do -- store prev param variables per track 
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
    pmac.v[i].cutoff = track[i].cutoff
    pmac.v[i].filter_q = track[i].filter_q
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
    ui.pmac_arc_reset(n)
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
    end
  end
end

--------------------- MIDI / CROW TRIGS -----------------------

local trig = {}
for i = 1, 6 do
  trig[i] = {}
  trig[i].tick = 0
  trig[i].step = 0
  trig[i].count = 0
  trig[i].rec_step = 0
  trig[i].out = 1
  trig[i].pulse = false
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
    if trig[i].pulse then
      crow.output[ch].action = "pulse()"
    else
      crow.output[ch].action = "{ to(0, 0), to("..trig[i].amp..", "..trig[i].env_a.."), to(0, "..trig[i].env_d..", 'lin') }"
    end
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
  track[i].rec_oneshot = 0
  track[i].rec_thresh = 0
  track[i].rec_armed = 0
  track[i].rec_queued = 0
  track[i].rec_enabled = true
  track[i].rec_clock = nil
  track[i].onshot_clock = nil
  track[i].level = 1
  track[i].prev_level = 1
  track[i].pan = 0
  track[i].mute = 0
  track[i].rate_slew = 0
  track[i].rec_level = 1
  track[i].pre_level = 0
  track[i].dry_level = 0
  track[i].cutoff = 1
  track[i].cutoff_hz = 12000
  track[i].filter_q = 0.2
  track[i].filter_mode = 1
  track[i].route_t5 = 0
  track[i].route_t6 = 0
  track[i].send_t5 = 1
  track[i].send_t6 = 1
  track[i].loop = 0
  track[i].loop_start = 1
  track[i].loop_end = 16
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
  track[i].rate = 1
  track[i].speed = 0
  track[i].warble = 0
  track[i].wrbviz = 0
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
  tp[i].input = 1
  tp[i].side = 1
  tp[i].buffer = i
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
  -- clip
  clip[i].s = tp[i].splice[1].s
  clip[i].e = tp[i].splice[1].e
  clip[i].l = tp[i].splice[1].l
  clip[i].bpm = tp[i].splice[1].bpm
  -- current loop
  clip[i].cs = clip[i].s
  clip[i].ce = clip[i].e
  clip[i].cl = clip[i].ce - clip[i].cs
  -- grid cutpoints
  for x = 1, 16 do
    clip[i][x] = {}
    clip[i][x].s = clip[i].s + (clip[i].l / 16) * (x - 1)
    clip[i][x].e = clip[i].s + (clip[i].l / 16) * x
  end
end

function set_clip(i) 
  -- set playback window
  local s = track[i].splice_active
  clip[i].s = tp[i].splice[s].s
  clip[i].l = tp[i].splice[s].l
  clip[i].e = tp[i].splice[s].e
  clip[i].bpm = tp[i].splice[s].bpm
  -- set current loop
  clip[i].cs = clip[i].s
  clip[i].ce = clip[i].e
  clip[i].cl = clip[i].l
  -- set grid cutpoints
  for x = 1, 16 do
    clip[i][x].s = clip[i].s + (clip[i].l / 16) * (x - 1)
    clip[i][x].e = clip[i].s + (clip[i].l / 16) * x
  end
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

function splice_resize(i, s)
  local length = tp[i].splice[s].l
  if track[i].tempo_map == 0 then
    length = tp[i].splice[s].beatnum
  elseif track[i].tempo_map == 1 then
    length = beat_sec * tp[i].splice[s].beatnum
  end
  if track[i].tempo_map == 2 then
    tp[i].splice[s].bpm = 60 / length * tp[i].splice[s].beatnum
    if s == track[i].splice_active then
      set_clip(i)
    end
    set_info(i, s)
  else
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
end

function splice_resize_factor(i, s, factor)
  local length = tp[i].splice[s].l * factor
  local new_end = tp[i].splice[s].s + length
  if new_end <= tp[i].e and new_end > tp[i].s then
    tp[i].splice[s].e = tp[i].splice[s].s + length
    tp[i].splice[s].l = length
    tp[i].splice[s].bpm = 60 / length * tp[i].splice[s].beatnum
    if s == track[i].splice_active then
      set_clip(i)
    end
    set_info(i, s)
    render_splice()
  else
    show_message("reached   size   limit")
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
  render_splice()
end

function mirror_splice(i, s, src, dst) -- copy splice to the other buffer
  local start = tp[i].splice[s].s - FADE_TIME
  local length = tp[i].splice[s].l + SPLICE_GAP
  softcut.buffer_copy_mono(src, dst, start, start, length, FADE_TIME)
  render_splice(i)
end

function copy_splice_audio(i, s, src) -- copy to other destination
  if next(src) then
    local src_start = tp[src.i].splice[src.s].s
    local src_len = tp[src.i].splice[src.s].l
    -- if copying a track loop change start and length
    if track[src.i].splice_active == src.s and track[src.i].loop == 1 then
      src_start = clip[src.i].cs
      src_len = clip[src.i].cl
    end
    if tp[i].splice[s].e + src_len <= tp[i].e then
      local dst_start = (s == 1 and tp[i].splice[s].s or tp[i].splice[s - 1].e + SPLICE_GAP)
      local preserve = alt == 1 and 0.5 or 0
      softcut.buffer_copy_mono(tp[src.i].side, tp[i].side, src_start - FADE_TIME, dst_start - FADE_TIME, src_len + SPLICE_GAP, FADE_TIME, preserve)
      -- set splice data
      tp[i].splice[s].s = dst_start
      tp[i].splice[s].e = dst_start + src_len
      tp[i].splice[s].l = src_len
      tp[i].splice[s].init_start = dst_start
      tp[i].splice[s].init_len = src_len
      tp[i].splice[s].beatnum = track[src.i].loop == 1 and get_beatnum(src_len) or tp[src.i].splice[src.s].beatnum
      tp[i].splice[s].bpm = 60 / src_len * tp[i].splice[s].beatnum
      tp[i].splice[s].name = tp[src.i].splice[src.s].name
      tp[i].splice[s].resize = track[i].tempo_map > 1 and tp[i].splice[s].beatnum or math.ceil(src_len)
      if s == track[i].splice_active then
        set_clip(i)
      end
      set_info(i, s)
      render_splice()
    else
      show_message("splice   too   long")
    end
  else
    show_message("clipboard   empty")
  end
end

function increase_level_splice()
  local i = track_focus
  local s = track[i].splice_focus
  local start = tp[i].splice[s].s - FADE_TIME
  local length = tp[i].splice[s].l + SPLICE_GAP
  local level = util.dbamp(1) - 1
  softcut.buffer_copy_mono(tp[i].side, tp[i].side, start, start, length, FADE_TIME, level)
  render_splice()
end

function decrease_level_splice()
  local i = track_focus
  local s = track[i].splice_focus
  local start = tp[i].splice[s].s - FADE_TIME
  local length = tp[i].splice[s].l + SPLICE_GAP
  local level = util.dbamp(-1)
  softcut.buffer_clear_region_channel(tp[i].side, start, length, FADE_TIME, level)
  render_splice()
end

function set_active_splice(i, s)
  if track[i].play == 0 then
    local e = {t = eSPLICE, i = i, active = s} event(e)
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
          local e = {t = eSPLICE, i = i, active = s, sync = true} event(e)
        end)
      else
        local e = {t = eSPLICE, i = i, active = s} event(e)
      end
    end
  end
end

function clear_splice() -- clear focused splice
  local i = track_focus
  local s = track[i].splice_focus
  local buffer = tp[i].side
  local start = tp[i].splice[s].s - FADE_TIME
  local length = tp[i].splice[s].l + SPLICE_GAP
  tp[i].splice[s].name = ""
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
end

function clear_tape() -- clear tape
  local buffer = tp[track_focus].side
  local start = tp[track_focus].s - FADE_TIME
  local length = MAX_TAPELENGTH + FADE_TIME
  softcut.buffer_clear_region_channel(buffer, start, length)
  render_splice()
  for s = 1, 8 do
    tp[track_focus].splice[s].name = ""
  end
  show_message("track    "..track_focus.."    tape    cleared")
end

function clear_buffers() -- clear both buffers
  softcut.buffer_clear()
  render_splice()
  show_message("buffers    cleared")
end

function format_splice(i, s) -- copy format to next splice
  local i = i or track_focus
  local s = s or track[i].splice_focus
  if s < 8 then
    local s_start = tp[i].splice[s].e + SPLICE_GAP
    local length = tp[i].splice[s].l
    if s_start + length <= tp[i].e then
      tp[i].splice[s + 1].s = s_start
      tp[i].splice[s + 1].l = length
      tp[i].splice[s + 1].e = s_start + length
      tp[i].splice[s + 1].init_start = s_start
      tp[i].splice[s + 1].init_len = tp[i].splice[s].l
      tp[i].splice[s + 1].beatnum = tp[i].splice[s].beatnum
      tp[i].splice[s + 1].bpm = tp[i].splice[s].bpm
      tp[i].splice[s + 1].resize = tp[i].splice[s].resize
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
  for s = 1, 8 do
    splice_resize(i, s)
  end
  render_splice(i)
  page_redraw(vTAPE)
end

function recalc_splices() -- called when tempo changes
  for i = 1, 6 do
    if track[i].tempo_map > 0 and (track[i].loaded or loadop.tempo == 3) then
      for s = 1, 8 do
        splice_resize(i, s)
      end
      render_splice(i)
    end
  end
end


--------------------- SOFTCUT FUNCTIONS -----------------------

function set_rec_enable(i, active)
  if active then
    track[i].rec_enabled = true
  else
    track[i].rec_enabled = false
    track[i].rec = 0
    track[i].rec_oneshot = 0
    track[i].rec_thresh = 0
    track[i].rec_armed = 0
    track[i].rec_queued = 0
    set_rec(i)
  end
end

function toggle_rec(i, oneshot)
  if oneshot_rec then
    chop_thresh_rec(i)
  else
    if track[i].rec_enabled then
      if rec_launch == 4 then
        track[i].rec_queued = 1 - track[i].rec_queued
        if track[i].rec_queued == 1 and track[i].rec_armed == 0 then
          track[i].rec_armed = 1
          track[i].rec_oneshot = rec_default_mode == 1 and (oneshot and 1 or 0) or (oneshot and 0 or 1)
          backup_rec(i, "save")
        else
          track[i].rec = 0
          set_rec(i)
        end
      else
        if track[i].rec == 0 and track[i].rec_armed == 0 then
          backup_rec(i, "save")
          track[i].rec_armed = 1
          track[i].rec_oneshot = rec_default_mode == 1 and (oneshot and 1 or 0) or (oneshot and 0 or 1)
          local beat_sync = rec_launch > 1 and (rec_launch == 3 and bar_val or 1) or (quantizing and q_rate or nil)
          if beat_sync ~= nil then
            track[i].rec_clock = clock.run(function()
              clock.sync(beat_sync)
              local e = {t = eREC, i = i, rec = 1, sync = true} event(e)
              run_oneshot_timer(i)
              track[i].rec_clock = nil
            end)
          else
            local e = {t = eREC, i = i, rec = 1} event(e)
            run_oneshot_timer(i)
          end
        else
          local e = {t = eREC, i = i, rec = 0} event(e)
          if track[i].rec_clock ~= nil then
            clock.cancel(track[i].rec_clock)
            track[i].rec_clock = nil
          end
          if track[i].oneshot_clock ~= nil then
            clock.cancel(track[i].oneshot_clock)
            track[i].oneshot_clock = nil
            end_oneshot(i)
          end
        end
      end
    end
  end
end

function set_rec(i)
  if track[i].rec_enabled then
    if track[i].rec == 1 and track[i].play == 1 then
      softcut.pre_level(i, track[i].pre_level)
      softcut.rec_level(i, track[i].rec_level)
    else
      local fade = track[i].fade == 0 and 1 or track[i].pre_level
      softcut.pre_level(i, fade)
      softcut.rec_level(i, 0)
      track[i].rec_armed = 0
      track[i].rec_queued = 0
      track[i].rec_oneshot = 0
    end
  else
    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)
  end
  page_redraw(vMAIN, 2)
end

function backup_rec(i, action)
  local s = track[i].splice_active
  if autobackup then
    if action == "save" then
      mirror_splice(i, s, 1, 2)
      rec_backup = true
    elseif action == "undo" and rec_backup then
      mirror_splice(i, s, 2, 1)
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

function get_pos(i, pos) -- softcut.query_position callback
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
  local pos = track[i].rev == 0 and clip[i].cs or clip[i].ce
  softcut.position(i, pos)
end

function set_track_reset(i)
  local val = params:get(i.."reset_count")
  track[i].beat_reset = val == 1 and tp[i].splice[track[i].splice_active].beatnum or val
end

function cut_track(i, pos)
  if track[i].rec_thresh == 1 then
    set_quarantine(i, false)
  end
  if track[i].loop == 1 then
    clear_loop(i)
  end
  local cut = track[i].rev == 0 and clip[i][pos].s or clip[i][pos].e
  softcut.position(i, cut)
  if track[i].play == 0 then
    track[i].play = 1
    track[i].beat_count = 0
    set_rec(i)
    set_level(i)
    toggle_transport()
  end
end

function start_track(i, pos)
  if track[i].rec_thresh == 1 then
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
  if track[i].rec_thresh == 1 then
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
  clip[i].cs = clip[i].s + (clip[i].l / 16) * (lstart - 1)
  clip[i].ce = clip[i].s + (clip[i].l / 16) * lend
  clip[i].cl = clip[i].ce - clip[i].cs
  softcut.loop_start(i, clip[i].cs)
  softcut.loop_end(i, clip[i].ce)
  dirtygrid = true
end

function clear_loop(i)
  track[i].loop = 0
  clip[i].cs = clip[i].s
  clip[i].ce = clip[i].e
  clip[i].cl = clip[i].l
  softcut.loop_start(i, clip[i].cs) 
  softcut.loop_end(i, clip[i].ce)
end

function chop_loop(i)
  if track[i].loop == 1 then
    local lend = track[i].loop_end - ((track[i].loop_end - track[i].loop_start + 1) / 2)
    if (lend - track[i].loop_start + 1) > 1/16 then
      loop_event(i, track[i].loop_start, lend)
    end
  end
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

function set_track_source(option)
  audio.level_adc_cut(1)
  audio.level_eng_cut(option == 2 and 0 or 1)
  audio.level_tape_cut(option == 1 and 0 or 1)
end

function set_softcut_input(i)
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
  track[i].filter_mode = option
  softcut.post_filter_lp(i, (option == 1 or option == 5) and 1 or 0) 
  softcut.post_filter_hp(i, option == 2 and 1 or 0) 
  softcut.post_filter_bp(i, option == 3 and 1 or 0) 
  softcut.post_filter_br(i, option == 4 and 1 or 0)
  if option == 5 then
    params:set(i.."cutoff", 0)
    set_djf(i, 0)
  elseif option < 5 then
    local val = util.explin(20, 12000, 0, 2, track[i].cutoff_hz) - 1
    params:set(i.."cutoff", val)
  end
  set_dry_level(i)
end

function set_cutoff(i, val)
  track[i].cutoff = val
  if track[i].filter_mode == 5 then
    set_djf(i, val)
  elseif track[i].filter_mode < 5 then
    local f = util.linexp(0, 2, 20, 12000, val + 1)
    softcut.post_filter_fc(i, f)
    track[i].cutoff_hz = f
  end
end

function set_djf(i, val)
  if val < -0.1 then -- lp
    local val = -val
    freq = util.linexp(0.1, 1, 12000, 80, val)
    softcut.post_filter_fc(i, freq)
    softcut.post_filter_lp(i, 1)
    softcut.post_filter_hp(i, 0)
  elseif val > 0.1 then -- hp
    freq = util.linexp(0.1, 1, 20, 8000, val)
    softcut.post_filter_fc(i, freq)
    softcut.post_filter_hp(i, 1)
    softcut.post_filter_lp(i, 0)
  else
    softcut.post_filter_fc(i, val > 0 and 20 or 12000)
    softcut.post_filter_lp(i, val > 0 and 0 or 1)
    softcut.post_filter_hp(i, val > 0 and 1 or 0)
  end
end

function set_filter_q(i, val) -- from ezra's softcut eq class (thank you!)
  track[i].filter_q = val 
  local x = 1 - val
  local rq = 2.15821131e-01 + (x * 2.29231176e-09) + (x * x * 3.41072934)
  softcut.post_filter_rq(i, rq)
end

function set_dry_level(i)
  if track[i].filter_mode < 5 then
    softcut.post_filter_dry(i, track[i].dry_level)
  elseif track[i].filter_mode == 6 then
    softcut.post_filter_dry(i, 1)
  else
    softcut.post_filter_dry(i, 0)
  end
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
    -- set hardware positions
    if track[i].pos_lo_res ~= track[i].pos_grid then
      track[i].pos_grid = track[i].pos_lo_res
      -- trig warble at low resolution
      if track[i].warble == 1 then
        trig_warble_event(i)
      end
    end
    if track[i].pos_arc ~= track[i].pos_hi_res then
      track[i].pos_arc = track[i].pos_hi_res
    end
    -- set screen positions
    track[i].pos_rel = pp -- relative position within clip
    track[i].pos_clip = pc -- relative position within allocated buffer space
    -- display position
    if (grido_view < vLFO or gridz_view < vLFO or grido_view == vTAPE) then
      dirtygrid = true
    end
    page_redraw(vTAPE)
    -- queue recording
    if track[i].rec_queued == 1 then
      if track[i].rev == 0 then
        local limit = track[i].loop == 0 and 64 or (math.floor(track[i].loop_end * 4))
        if track[i].pos_hi_res >= limit then
          track[i].rec_queued = 0
          track[i].rec = 1
          set_rec(i)
          run_oneshot_timer(i)
        end
      else
        local limit = track[i].loop == 0 and 1 or (math.floor(track[i].loop_start * 4 - 3))
        if track[i].pos_hi_res <= limit then
          track[i].rec_queued = 0
          track[i].rec = 1
          set_rec(i)
          run_oneshot_timer(i)
        end
      end
    end
    -- oneshot play_mode
    if track[i].play_mode == 2 and track[i].loop == 0 then
      local limit = track[i].rev == 0 and 64 or 1
      if track[i].pos_hi_res == limit then
        stop_track(i)
      end
    end
    -- queue splice load
    if next(tp[i].event) then
      if track[i].rev == 0 then
        local limit = track[i].loop == 0 and 64 or (math.floor(track[i].loop_end * 4))
        if track[i].pos_hi_res >= limit then
          event(tp[i].event)
          tp[i].event = {}
          splice_queued = false
        end
      else
        local limit = track[i].loop == 0 and 1 or (math.floor(track[i].loop_start * 4 - 3))
        if track[i].pos_hi_res <= limit then
          event(tp[i].event)
          tp[i].event = {}
          splice_queued = false
        end
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
      local recpos = track[i].rev == 0 and (trig[i].rec_step * 4 - 3) or (trig[i].rec_step * 4)
      if track[i].pos_hi_res == recpos then
        track[i].rec = 1 - track[i].rec
        set_rec(i)
      end
    end
    -- trig @step mode / track 2 trigger
    if trig[i].step > 0 then
      local steppos = track[i].rev == 0 and (trig[i].step * 4 - 3) or (trig[i].step * 4)
      if track[i].pos_hi_res == steppos then
        send_trig(i)
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
    n = n * (current_tempo / clip[i].bpm)
  end
  track[i].rate = n
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

function wave_render(ch, start, sec_smp, samples)
  waveform_samples[track_focus] = {}
  waveform_samples[track_focus] = samples
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

function render_splice(i)
  local focus = i or track_focus
  if view == vTAPE and not view_splice_info then 
    if view_buffer then
      local start = tp[track_focus].s
      local length = tp[track_focus].e - tp[track_focus].s
      local buffer = tp[track_focus].side
      softcut.render_buffer(buffer, start, length, 120)
    elseif focus == track_focus then
      local n = track[track_focus].splice_focus
      local start = tp[track_focus].splice[n].s
      local length = tp[track_focus].splice[n].e - tp[track_focus].splice[n].s
      local buffer = tp[track_focus].side
      softcut.render_buffer(buffer, start, length, 120)
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
      local pos = track[i].rev == 0 and clip[i].cs or clip[i].ce
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
      clock.link.start()
    end
    transport_run = true
  end
end

function startall(sync) -- start all tracks at the beginning
  for i = 1, 6 do
    local pos = track[i].rev == 0 and 1 or 16
    local e = {t = eCUT, i = i, pos = pos, sync = sync} event(e)
  end
  if params:get("midi_trnsp") == 2 and not transport_run then
    m:start()
    clock.link.start()
  end
end

function stopall(sync) -- stop all tracks and patterns / send midi stop if midi transport on
  for i = 1, 6 do
    local e = {t = eSTOP, i = i, sync = sync} event(e)
  end
  for i = 1, 8 do
    pattern[i]:stop()
  end
  if params:get("midi_trnsp") == 2 then
    m:stop()
    clock.link.stop()
  end
  transport_run = false
end

function reset_playheads() -- reset all playback positions
  for i = 1, 6 do
    if track[i].play == 1 then
      local pos = track[i].rev == 0 and 1 or 16
      local e = {t = eCUT, i = i, pos = pos} event(e)
    end
  end
end


--------------------- ONESHOT RECORDING -----------------------

function run_oneshot_timer(i)
  if track[i].oneshot_clock ~= nil then
    clock.cancel(track[i].oneshot_clock)
  end
  if track[i].rec_oneshot == 1 then
    local dur = math.abs(clip[i].cl / track[i].rate)
    track[i].oneshot_clock = clock.run(function()
      clock.sleep(dur)
      end_oneshot(i)
    end)
  end
end

function end_oneshot(i)
  track[i].rec = 0
  track[i].rec_armed = 0
  track[i].rec_queued = 0
  track[i].rec_thresh = 0
  track[i].rec_oneshot = 0
  set_rec(i)
  tracktimer:stop()
  oneshot_rec = false
  autolength = false
  if track[i].oneshot_clock ~= nil then
    clock.cancel(track[i].oneshot_clock)
  end
  track[i].oneshot_clock = nil
end

function arm_thresh_rec(i, alt)
  if oneshot_rec then
    chop_thresh_rec(i)
  else
    track[i].rec_thresh = 1 - track[i].rec_thresh
    for n = 1, 6 do
      if n ~= i then
        track[n].rec_thresh = 0
      end
    end
    if track[i].rec_thresh == 1 then
      armed_track = i
      -- set autolength
      if alt then
        stop_track(i)
        clear_loop(i)
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
    local pos = track[i].rev == 0 and clip[i].cs or clip[i].ce
    softcut.position(i, pos)
    track[i].play = 1
    track[i].beat_count = 0
    set_level(i)
    toggle_transport()
  end
  track[i].rec = 1
  track[i].rec_oneshot = 1
  set_rec(i)
  run_oneshot_timer(i)
  tracktimer:start()
  amp_in[1]:stop()
  amp_in[2]:stop()
  oneshot_rec = true
  dirtygrid = true
end

function chop_thresh_rec(i)
  if track[i].rec_thresh == 1 then
    if autolength then
      -- get length of recording
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
    else
      -- set loop points
      local lstart = math.min(loop_pos, track[i].pos_grid)
      local lend = math.max(loop_pos, track[i].pos_grid)
      loop_event(i, lstart, lend)
    end
    end_oneshot(i)
  end
end


--------------------- LFOS -----------------------
local lfo_dstname = {"volume", "pan", "dub   level", "transpose", "detune", "rate   slew", "cutoff"}
local lfo_dstparam = {"vol", "pan", "dub", "transpose", "detune", "rate_slew", "cutoff"}
local lfo_baseline = {'min', 'center', 'min', 'center', 'center', 'min', 'center'}
local lfo_baseline_options = {'min', 'center', 'max'}
local lfo_min = {0, -1, 0, 1, -600, 0, -1}
local lfo_max = {1, 1, 1, 15, 600, 1, 1}

lfo = {}
function init_lfos()
  for i = 1, 6 do
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

function set_lfo(i, destination, track, offset)
  if destination == 'none' then
    params:set("lfo_lfo_"..i, 1)
    lfo[i].track = nil
    lfo[i].destination = nil
    lfo[i].prev_val = nil
    lfo[i].slope = 0
    lfo[i].info = 'unassigned'
    lfo[i]:set('action', function(scaled, raw) end)
  else
    local n = tab.key(lfo_dstparam, destination)
    lfo[i].info = 'T'..track..'    '..lfo_dstname[n]
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
      params:set(track..lfo_dstparam[n], scaled)
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
    if offset ~= nil then
      params:set("lfo_offset_lfo_"..i, offset)
    end
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
end

function env_gate_off(i)
  env_get_value(i)
  env[i].gate = false
  env[i].a_is_running = false
  env[i].d_is_running = false
  env[i].r_is_running = true
  env[i].count = 0
  env[i].direction = 1
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

local wrb = {}

wrb.curves = {
  {1, 1, 2, 2, 2, 1, 3, 2, 2, 4, 1, 0, 0, 1, 2, 1, 0, 1, 2, 1, 0},
  {1, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 1, 2, 3, 2, 1, 1, 0},
  {1, 2, 3, 2, 1, 3, 5, 7, 8, 6, 4, 2, 1, 0, 1, 2, 3, 2, 1, 0},
  {1, 2, 3, 4, 5, 6, 7, 6, 5, 2, 0, 2, 7, 6, 2, 1, 3, 2, 1, 0},
  {1, 2, 3, 4, 5, 6, 7, 8, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0},
  {1, 2, 4, 6, 3, 2, 1, 1, 0, 0, 2, 5, 5, 4, 3, 2, 1, 0},
  {1, 1, 2, 3, 4, 2, 1, 0, 0, 0, 1, 1, 2, 3, 3, 1, 1, 0},
  {1, 2, 5, 7, 9, 6, 4, 2, 0, 1, 2, 0},
  {1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0},
  {1, 2, 0, 0, 1, 2, 3, 2, 3, 0, 1, 0},
  {1, 2, 3, 4, 3, 2, 1, 0},
  {1, 3, 6, 8, 5, 2, 1, 0},
  {1, 2, 1, 0, 1, 2, 1, 0},
  {1, 3, 6, 2, 1, 2, 0},
  {1, 2, 1, 3, 1, 0},
  {1, 2, 3, 2, 1, 0},
  {1, 3, 2, 1, 0},
  {1, 2, 3, 1, 0},
  {1, 4, 6, 3, 0},
  {2, 7, 9, 4, 0},
  {2, 4, 6, 8, 0},
  {1, 5, 2, 0},
  {1, 2, 1, 0},
  {1, 8, 2, 0}
}

for i = 1, 6 do
  wrb[i] = {}
  wrb[i].clk = nil
  wrb[i].idle = true
  wrb[i].amount = 0
  wrb[i].depth = 0
end

function trig_warble_event(i)
  if wrb[i].idle then
    if math.random(400) < wrb[i].amount then
      wrb[i].idle = false
      local curve = wrb.curves[math.random(1, #wrb.curves)]
      local depth = math.random(wrb[i].depth - 8, wrb[i].depth) * 1.86e-04
      local t = math.random(22, 32) - math.floor(wrb[i].depth / 10)
      clock.run(function()
        for n = 1, #curve do
          local wrb_rate = track[i].rate * (1 - curve[n] * depth)
          softcut.rate(i, wrb_rate)
          track[i].wrbviz = curve[n]
          clock.sleep(1/t)
          if n == #curve then
            wrb[i].idle = true
            track[i].wrbviz = 0
          end
        end
      end)
    end
  end
end

--------------------- RAND -----------------------

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
    local e = {t = eREV, i = i, rev = math.random(0, 1)} event(e)
  end
  if params:get("rnd_loop") == 2 then
    local lstart = math.random(1, 15)
    local lend = autorand_at_cycle and math.random(lstart + 1, 16) or math.random(lstart, 16)
    loop_event(i, lstart, lend)
  end
  if params:get("rnd_speed") == 2 then
    local e = {t = eSPEED, i = i, speed = math.random(-params:get("rnd_loct"), params:get("rnd_uoct"))} event(e)
  end
  if params:get("rnd_cut") == 2 then
    params:set(i.. "cutoff", math.random(params:get("rnd_lcut"), params:get("rnd_ucut")) )
  end
  track[i].step_count = 0
end


--------------------- CLOCK CALLBACKS -----------------------

function tempo_change_callback()
  current_tempo = params:get("clock_tempo")
  beat_sec = 60 / params:get("clock_tempo")
  recalc_splices()
  recalc_time_factor()
end

function transport_start_callback()
  if params:get("midi_trnsp") == 3 then
    for i = 1, 6 do
      if track[i].sel == 1 then
        local pos = track[i].rev == 0 and clip[i].cs or clip[i].ce
        local e = {t = eSTART, i = i, pos = pos, sync = true} event(e)
      end
    end
  end
end

function transport_stop_callback()
  if params:get("midi_trnsp") == 3 then
    stopall(true)
  end
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
    clock.run(function()
      clock.sleep(1/30)
      pulse_beat = false
      dirtygrid = true
    end)
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
    tp[i].splice[s].s = s == 1 and tp[i].s or (tp[i].splice[s - 1].e + SPLICE_GAP)
    local max_l = tp[i].e - tp[i].splice[s].s
    local file_l = get_length_audio(path)
    if file_l > 0 then
      local l = math.min(file_l, max_l)
      load_audio(path, i, s, l)
      render_splice(i)
    else
      print("not a sound file")
    end
    prev_path = path
  end
  screenredrawtimer:start()
  dirtyscreen = true
end

function batchload_callback(path, i)
  if path ~= "cancel" and path ~= "" then
    batchload_path = path
    batchload_track = i
    prev_path = path
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
  return tp[i].splice[s].e + SPLICE_GAP
end

function load_batch(path, i, s, n)
  local filepath = path:match("[^/]*$")
  local folder = path:match("(.*[/])")
  local files = util.scandir(folder)
  local filestart = 0
  local fileend = 0
  local s = s
  local splice_s = s == 1 and tp[i].s or (tp[i].splice[s - 1].e + SPLICE_GAP)
  -- get file index
  for index, filename in ipairs(files) do
    if filename == filepath then
      filestart = index
      fileend = index + n
      goto continue
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
  render_splice(i)
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

function pset_write_callback(filename, name, number)
  -- save all markers
  save_all_markers()
  -- make directory
  os.execute("mkdir -p "..norns.state.data.."sessions/"..number.."/")
  -- save buffer content
  softcut.buffer_write_mono(norns.state.data.."sessions/"..number.."/"..name.."_buffer.wav", 0, -1, 1)
  -- save data in one big table
  local sesh = {}
  sesh.format_v22_0 = true
  sesh.tempo = current_tempo
  sesh.scale = current_scale
  sesh.quant_rate = params:get("quant_rate")
  sesh.time_signature = params:get("time_signature")
  sesh.pmac_d = deep_copy(pmac.d)
  sesh.kmac_slot = deep_copy(kmac.slot)
  sesh.track = {}
  for i = 1, 6 do
    sesh.track[i] = {}
    -- tape data
    sesh.track[i].tape_s = tp[i].s
    sesh.track[i].tape_e = tp[i].e
    sesh.track[i].tape_splice = {table.unpack(tp[i].splice)}
    -- track data
    sesh.track[i].buffer = tp[i].buffer
    sesh.track[i].rec_enabled = track[i].rec_enabled
    sesh.track[i].sel = track[i].sel
    sesh.track[i].fade = track[i].fade
    sesh.track[i].mute = track[i].mute
    sesh.track[i].cutoff = track[i].cutoff
    sesh.track[i].speed = track[i].speed
    sesh.track[i].rev = track[i].rev
    sesh.track[i].loop = track[i].loop
    sesh.track[i].loop_start = track[i].loop_start
    sesh.track[i].loop_end = track[i].loop_end
    sesh.track[i].splice_active = track[i].splice_active
    sesh.track[i].splice_focus = track[i].splice_focus
    sesh.track[i].tempo_map = params:get(i.."tempo_map_mode")
    sesh.track[i].route_t5 = track[i].route_t5
    sesh.track[i].route_t6 = track[i].route_t6
    sesh.track[i].send_t5 = track[i].send_t5
    sesh.track[i].send_t6 = track[i].send_t6
    -- silent load specific
    sesh.track[i].vol = track[i].level
    sesh.track[i].pan = track[i].pan
    sesh.track[i].transpose = params:get(i.."transpose")
    sesh.track[i].detune = params:get(i.."detune")
    sesh.track[i].reset_active = params:get(i.."reset_active")
    sesh.track[i].reset_count = params:get(i.."reset_count")
    sesh.track[i].warble_state = params:get(i.."warble_state")
    -- lfo data
    sesh.track[i].lfo_track = lfo[i].track
    sesh.track[i].lfo_destination = lfo[i].destination
    sesh.track[i].lfo_offset = params:get("lfo_offset_lfo_"..i)
  end
  sesh.macros = {}
  for i = 1, 8 do
    sesh.macros[i] = {}
    -- pattern data
    sesh.macros[i].pattern_count = pattern[i].count
    sesh.macros[i].pattern_time = {table.unpack(pattern[i].time)}
    sesh.macros[i].pattern_event = {table.unpack(pattern[i].event)}
    sesh.macros[i].pattern_time_factor = pattern[i].time_factor
    sesh.macros[i].pattern_synced = pattern[i].synced
    sesh.macros[i].pattern_sync_meter = params:get("patterns_meter"..i)
    sesh.macros[i].pattern_sync_beatnum = params:get("patterns_barnum"..i)
    sesh.macros[i].pattern_loop = params:get("patterns_playback"..i)
    sesh.macros[i].pattern_count_in = params:get("patterns_countin"..i)
    sesh.macros[i].pattern_bpm = pattern[i].bpm
    -- snapshot data
    sesh.macros[i].snap_data = snap[i].data
    sesh.macros[i].snap_rec = {table.unpack(snap[i].rec)}
    sesh.macros[i].snap_play = {table.unpack(snap[i].play)}
    sesh.macros[i].snap_mute = {table.unpack(snap[i].mute)}
    sesh.macros[i].snap_loop = {table.unpack(snap[i].loop)}
    sesh.macros[i].snap_loop_start = {table.unpack(snap[i].loop_start)}
    sesh.macros[i].snap_loop_end = {table.unpack(snap[i].loop_end)}
    sesh.macros[i].snap_speed = {table.unpack(snap[i].speed)}
    sesh.macros[i].snap_rev = {table.unpack(snap[i].rev)}
    sesh.macros[i].snap_transpose_val = {table.unpack(snap[i].transpose_val)}
    sesh.macros[i].snap_active_splice = {table.unpack(snap[i].active_splice)}
    sesh.macros[i].snap_route_t5 = {table.unpack(snap[i].route_t5)}
    sesh.macros[i].snap_route_t6 = {table.unpack(snap[i].route_t6)}
    sesh.macros[i].snap_lfo_enabled = {table.unpack(snap[i].lfo_enabled)}
    -- punch-in data
    sesh.macros[i].punch_has_data = punch[i].has_data
    sesh.macros[i].punch_event = punch[i].event
  end
  tab.save(sesh, norns.state.data.."sessions/"..number.."/"..name.."_session.data")
  -- rebuild pset list
  build_pset_list()
  print("saved preset: '"..name.."'")
end

function pset_read_callback(filename, silent, number)
  local loaded_file = io.open(filename, "r")
  if loaded_file and shift == 0 then
    -- get pset_id
    io.input(loaded_file)
    local pset_id = string.sub(io.read(), 4, -1)
    io.close(loaded_file)
    loadsesh = {}
    loadsesh = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")
    if next(loadsesh) then
      -- clear and load buffer
      softcut.buffer_clear_channel(2)
      softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 1)
      -- load sesh data file
      if loadsesh.format_v22_0 then
        -- set tempo
        if loadop.tempo > 1 then
          params:set("clock_tempo", loadsesh.tempo)
        end
        -- load data
        for i = 1, 6 do
          -- stop rec
          track[i].rec = 0
          set_rec(i)
          -- tape data
          tp[i].s = loadsesh.track[i].tape_s
          tp[i].e = loadsesh.track[i].tape_e
          tp[i].splice = {table.unpack(loadsesh.track[i].tape_splice)}
          -- route data
          track[i].route_t5 = loadsesh.track[i].route_t5
          track[i].route_t6 = loadsesh.track[i].route_t6
          set_track_sends(i)
          -- track data
          track[i].splice_active = loadsesh.track[i].splice_active
          track[i].splice_focus = loadsesh.track[i].splice_focus
          track[i].sel = loadsesh.track[i].sel
          track[i].fade = loadsesh.track[i].fade
          track[i].loop = loadsesh.track[i].loop
          track[i].loop_start = loadsesh.track[i].loop_start
          track[i].loop_end = loadsesh.track[i].loop_end
          -- set track state
          track[i].loaded = true
          track[i].mute = loadsesh.track[i].mute
          track[i].speed = loadsesh.track[i].speed
          track[i].rev = loadsesh.track[i].rev
          track[i].rev = loadsesh.track[i].rev
          -- set tempo map and clip
          params:set(i.."tempo_map_mode", loadsesh.track[i].tempo_map)
          set_tempo_map(i) -- needs it twice :shrug:
          set_clip(i)
          set_level(i)       
          -- set filter -- shite workaround... uhgh
          params:set(i.."cutoff", loadsesh.track[i].cutoff)
          -- set lfo params
          if loadsesh.track[i].lfo_track ~= nil then
            set_lfo(i, loadsesh.track[i].lfo_destination, loadsesh.track[i].lfo_track, loadsesh.track[i].lfo_offset)
          else
            set_lfo(i, "none")
          end
        end
        -- load macro data
        load_macros()
      else
        cp.load_data(loadsesh)
      end
      dirtyscreen = true
      dirtygrid = true
      show_message("loaded   preset:   "..pset_id)
      print("loaded preset: '"..pset_id.."'")        
    else
      print("can't fetch data")
    end
  end
end

function pset_delete_callback(filename, name, number)
  norns.system_cmd("rm -r "..norns.state.data.."sessions/"..number.."/")
  build_pset_list()
  print("deleted preset: '"..name.."'")
end

function load_macros()
  pmac.d = deep_copy(loadsesh.pmac_d)
  kmac.slot = deep_copy(loadsesh.kmac_slot)
  for i = 1, 8 do
    -- stop patterns
    pattern[i]:rec_stop()
    pattern[i]:set_overdub(0)
    pattern[i]:stop()
    -- load patterns
    pattern[i].count = loadsesh.macros[i].pattern_count
    pattern[i].time = {table.unpack(loadsesh.macros[i].pattern_time)}
    pattern[i].event = {table.unpack(loadsesh.macros[i].pattern_event)}
    pattern[i].time_factor = loadsesh.macros[i].pattern_time_factor
    pattern[i].synced = loadsesh.macros[i].pattern_synced
    params:set("patterns_meter"..i, loadsesh.macros[i].pattern_sync_meter)
    params:set("patterns_barnum"..i, loadsesh.macros[i].pattern_sync_beatnum)
    params:set("patterns_playback"..i, loadsesh.macros[i].pattern_loop)
    params:set("patterns_countin"..i, loadsesh.macros[i].pattern_count_in)
    pattern[i].bpm = loadsesh.macros[i].pattern_bpm
    if pattern[i].bpm ~= nil then
      pattern[i].time_factor = pattern[i].bpm / current_tempo
    end
    -- snapshots
    snap[i].data = loadsesh.macros[i].snap_data
    snap[i].play = {table.unpack(loadsesh.macros[i].snap_play)}
    snap[i].mute = {table.unpack(loadsesh.macros[i].snap_mute)}
    snap[i].loop = {table.unpack(loadsesh.macros[i].snap_loop)}
    snap[i].loop_start = {table.unpack(loadsesh.macros[i].snap_loop_start)}
    snap[i].loop_end = {table.unpack(loadsesh.macros[i].snap_loop_end)}
    snap[i].speed = {table.unpack(loadsesh.macros[i].snap_speed)}
    snap[i].rev = {table.unpack(loadsesh.macros[i].snap_rev)}
    snap[i].transpose_val = {table.unpack(loadsesh.macros[i].snap_transpose_val)}
    snap[i].rec = {table.unpack(loadsesh.macros[i].snap_rec)}
    snap[i].route_t5 = {table.unpack(loadsesh.macros[i].snap_route_t5)}
    snap[i].route_t6 = {table.unpack(loadsesh.macros[i].snap_route_t6)}
    snap[i].lfo_enabled = {table.unpack(loadsesh.macros[i].snap_lfo_enabled)}
    snap[i].active_splice = {table.unpack(loadsesh.macros[i].snap_active_splice)}
    -- punch-in
    punch[i].has_data = loadsesh.macros[i].punch_has_data
    punch[i].event = {table.unpack(loadsesh.macros[i].punch_event)}
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
      params:set("loadop_"..v, data[v])
    end
  end
end

function silent_load(number, pset_id)
  -- load sesh data file
  loadsesh = {}
  loadsesh = tab.load(norns.state.data.."sessions/"..number.."/"..pset_id.."_session.data")
  if next(loadsesh) then
    if loadsesh.format_v22_0 then
      -- load audio to temp buffer
      softcut.buffer_read_mono(norns.state.data.."sessions/"..number.."/"..pset_id.."_buffer.wav", 0, 0, -1, 1, 2)
      -- load pattern, punch-in and snapshot data
      load_macros()
      -- flip load state and load stopped tracks
      for i = 1, 6 do
        track[i].loaded = false
        if track[i].play == 0 then load_track_tape(i) end
      end
      -- set scale
      if loadop.scale == 2 then
        params:set("scale", loadsesh.scale)
      end
      -- set quantization
      if loadop.quant_rate == 2 then
        params:set("quant_rate", loadsesh.quant_rate)
      end
      -- set time signature
      if loadop.time_signature == 2 then
        params:set("time_signature", loadsesh.time_signature)
      end
      -- set tempo
      if loadop.tempo > 1 and (current_tempo ~= loadsesh.tempo) then
        if loadop.tempo == 2 then
          params:set("clock_tempo", loadsesh.tempo)
        elseif loadop.tempo == 3 then
          tt_clk = clock.run(tempo_transition, loadop.transition, loadsesh.tempo)
        end
      end
      -- set lfos
      if loadop.lfos == 2 then
        for i = 1, 6 do
          if loadsesh.track[i].lfo_track ~= nil then
            set_lfo(i, loadsesh.track[i].lfo_destination, loadsesh.track[i].lfo_track, loadsesh.track[i].lfo_offset)
          else
            set_lfo(i, "none")
          end
        end
      end
      loadop.active = true
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

function load_track_tape(i, with_snapshot)
  local snap = with_snapshot and true or false
  -- load and clear tape
  softcut.buffer_copy_mono(2, 1, tp[i].s - FADE_TIME, tp[i].s - FADE_TIME, MAX_TAPELENGTH + FADE_TIME, 0.01)
  -- tape data
  tp[i].s = loadsesh.track[i].tape_s
  tp[i].e = loadsesh.track[i].tape_e
  tp[i].splice = {table.unpack(loadsesh.track[i].tape_splice)}
  if tp[i].buffer ~= loadsesh.track[i].buffer then
    params:set(i.."tape_buffer", loadsesh.track[i].buffer, true)
  end
  if loadop.splice_active > 1 and not (snap and snapop.splice) then
    local num = loadop.splice_active == 2 and loadsesh.track[i].splice_active or 1
    track[i].splice_active = num
    track[i].splice_focus = num
  end
  -- track data
  for k, v in pairs(loadop.set_param) do
    if loadop[v] == 2 then
      params:set(i..v, loadsesh.track[i][v])
    elseif loadop[v] == 3 then
      params:set(i..v, loadop.param_default[k])
    end
  end
  for k, v in pairs(loadop.set_tab) do
    if not (snap and snapop[v]) then
      if loadop[v] == 2 then
        track[i][v] = loadsesh.track[i][v]
      elseif loadop[v] == 3 then
        track[i][v] = 0
      end
    end
  end
  if not (snap and snapop.loops) then
    if loadop.loops == 2 then
      track[i].loop = loadsesh.track[i].loop
      track[i].loop_start = loadsesh.track[i].loop_start
      track[i].loop_end = loadsesh.track[i].loop_end
    elseif loadop.loops == 2 then -- load
      clear_loop(i)
    end
  end
  -- set tempo map and clip
  params:set(i.."tempo_map_mode", loadsesh.track[i].tempo_map)
  set_tempo_map(i) -- needs it twice :shrug:
  set_clip(i)
  -- set levels
  set_rec_enable(i, loadsesh.track[i].rec_enabled)
  set_level(i)
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
  -- clear temp buffer
  --[[
    if loadop.active == false then
    print("all tracks loaded")
    clock.run(function()
      clock.sleep(0.5)
      print("cleared temp buffer")
      softcut.buffer_clear_channel(2)
    end)
  end
  --]]
  -- render
  render_splice(i)
  show_message("track  "..i.."   loaded")
end


--------------------- INIIIIIIIT -----------------------
function init()
  -- establish grid size
  if g.device then
    GRID_SIZE = g.device.cols * g.device.rows
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
  -- autofocus param
  params:add_option("page_autofocus", "autofocus", {"off", "on"}, 1)
  params:set_action("page_autofocus", function(mode) autofocus = mode == 2 and true or false end)
  if GRID_SIZE == 128 then params:hide("page_autofocus") end
  -- grid rotate
  params:add_option("grid_orientation", "grid orientation", {"0°", "90°"}, 1)
  params:set_action("grid_orientation", function(mode) g:rotation(mode - 1) end)
  if GRID_SIZE == 128 then params:hide("grid_orientation") end

  -- scale param
  params:add_option("scale", "scale", scales.options, 1)
  params:set_action("scale", function(option) set_scale(option) end)

  -- quantization params
  params:add_group("quantization_params", "quantization", 5)

  params:add_number("time_signature", "time signature", 2, 11, 4, function(param) return param:get().."/4" end)
  params:set_action("time_signature", function(val) bar_val = val end)

  params:add_option("quant_rate", "key quantization", event_q_options, 1)
  params:set_action("quant_rate", function(idx) set_quantizer(idx) end)

  params:add_option("snap_launch", "snapshot launch", {"manual", "beat", "bar"}, 1)
  params:set_action("snap_launch", function(mode) snap_launch = mode end)

  params:add_option("splice_launch", "splice launch", {"manual", "beat", "bar", "queue"}, 1)
  params:set_action("splice_launch", function(mode) splice_launch = mode end)

  params:add_option("rec_launch", "rec launch", {"manual", "beat", "bar", "queue"}, 1)
  params:set_action("rec_launch", function(mode) rec_launch = mode end)

  -- rec params
  params:add_group("rec_params", "recording", 6)

  params:add_option("rec_default", "rec key default", {"toggle", "one-shot"}, 1)
  params:set_action("rec_default", function(option) rec_default_mode = option end)

  params:add_option("rec_source", "rec source", {"adc/eng", "adc/tape", "adc/eng/tape"}, 1)
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
  params:set_action("rec_backup", function(mode) autobackup = mode == 2 and true or false end)

  -- macro params
  params:add_group("snap_params", "snapshots", 10)
  
  params:add_option("snap_active_splice", "active splice", {"ignore", "recall"}, 2)
  params:set_action("snap_active_splice", function(x) snapop.splice = x == 2 and true or false end)

  params:add_option("snap_playback_state", "playback", {"ignore", "recall"}, 2)
  params:set_action("snap_playback_state", function(x) snapop.play_state = x == 2 and true or false end)

  params:add_option("snap_loop_state", "loops", {"ignore", "recall"}, 2)
  params:set_action("snap_loop_state", function(x) snapop.loops = x == 2 and true or false end)
  
  params:add_option("snap_rec_state", "rec state", {"ignore", "recall"}, 2)
  params:set_action("snap_rec_state", function(x) snapop.rec = x == 2 and true or false end)

  params:add_option("snap_mute_state", "mute state", {"ignore", "recall"}, 2)
  params:set_action("snap_mute_state", function(x) snapop.mute = x == 2 and true or false end)

  params:add_option("snap_rev_state", "rev state", {"ignore", "recall"}, 2)
  params:set_action("snap_rev_state", function(x) snapop.rev = x == 2 and true or false end)

  params:add_option("snap_speed_state", "speed", {"ignore", "recall"}, 2)
  params:set_action("snap_speed_state", function(x) snapop.speed = x == 2 and true or false end)

  params:add_option("snap_transpose_state", "transposition", {"ignore", "recall"}, 2)
  params:set_action("snap_transpose_state", function(x) snapop.transpose = x == 2 and true or false end)

  params:add_option("snap_set_route", "track sends", {"ignore", "recall"}, 2)
  params:set_action("snap_set_route", function(x) snapop.sends = x == 2 and true or false end)

  params:add_option("snap_lfo_state", "lfo state", {"ignore", "recall"}, 2)
  params:set_action("snap_lfo_state", function(x) snapop.lfo_state = x == 2 and true or false end)


  -- silent load config
  params:add_group("loadop_config", "silent load", 28)

  params:add_binary("loadop_save", ">> save config", "trigger")
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

  params:add_option("loadop_lfos", "lfos", {"ignore", "load"}, 1)
  params:set_action("loadop_lfos", function(x) loadop.lfos = x end)
  params:set_save("loadop_lfos", false)

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

  params:add_option("loadop_vol", "volume", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_vol", function(x) loadop.vol = x end)
  params:set_save("loadop_vol", false)

  params:add_option("loadop_pan", "pan", {"ignore", "load", "reset"}, 1)
  params:set_action("loadop_pan", function(x) loadop.pan = x end)
  params:set_save("loadop_pan", false)

  params:add_option("loadop_rev", "rev", {"ignore", "load", "reset"}, 1)
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
    loadop.sends = x
    loadop.send_t5 = x
    loadop.send_t6 = x
    loadop.route_t5 = x
    loadop.route_t6 = x
  end)
  params:set_save("loadop_sends", false)

  params:add_option("loadop_warble_state", "warble state", {"ignore", "load", "reset"}, 1)
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

  -- track control params
  params:add_group("track_control_params", "track control", 64)

  params:add_binary("p_macro_menu_remote", "show p-macros", "momentary")
  params:set_action("p_macro_menu_remote", function(z)
    if init_done then
      toggle_pmac_perf_view(z)
      dirtyscreen = true
    end
  end)
  params:hide("p_macro_menu_remote")
  
  params:add_separator("midi_transport_control", "midi output")

  params:add_option("midi_trnsp","midi transport", {"off", "send", "receive"}, 1)

  params:add_option("midi_device", "midi out device", midi_devices, 1)
  params:set_action("midi_device", function(val) m = midi.connect(val) end)
  
  params:add_separator("global_track_control", "global track control")

  params:add_binary("start_all", "start all", "trigger", 0)
  params:set_action("start_all", function() startall() end)

  params:add_binary("stop_all", "stop all", "trigger", 0)
  params:set_action("stop_all", function() stopall() end)

  params:add_binary("reset_pos", "reset positions", "trigger", 0)
  params:set_action("reset_pos", function() reset_playheads() end)

  params:add_separator("control_focused_track", "focused track control")

  params:add_binary("track_focus_playback", "play", "trigger", 0)
  params:set_action("track_focus_playback", function() toggle_playback(track_focus) end)

  params:add_binary("track_focus_mute", "mute", "trigger", 0)
  params:set_action("track_focus_mute", function() local e = {t = eMUTE, i = track_focus, mute = (1 - track[track_focus].mute)} event(e) end)

  params:add_binary("rec_focus_enable", "rec", "trigger", 0)
  params:set_action("rec_focus_enable", function() toggle_rec(track_focus) end)

  params:add_binary("tog_focus_rev", "rev", "trigger", 0)
  params:set_action("tog_focus_rev", function() local e = {t = eREV, i = track_focus, rev = (1 - track[track_focus].rev)} event(e) end)

  params:add_binary("inc_focus_speed", "speed +", "trigger", 0)
  params:set_action("inc_focus_speed", function()
    local n = util.clamp(track[track_focus].speed + 1, -3, 3)
    local e = {t = eSPEED, i = track_focus, speed = n} event(e)
  end)

  params:add_binary("dec_focus_speed", "speed -", "trigger", 0)
  params:set_action("dec_focus_speed", function()
    local n = util.clamp(track[track_focus].speed - 1, -3, 3)
    local e = {t = eSPEED, i = track_focus, speed = n} event(e)
  end)

  params:add_binary("focus_track_rand", "randomize", "trigger", 0)
  params:set_action("focus_track_rand", function() randomize(track_focus) end)

  for i = 1, 6 do
    -- track control
    params:add_separator("track_control_params"..i, "track "..i.." control")
  
    params:add_binary(i.."track_playback", "playback", "trigger", 0)
    params:set_action(i.."track_playback", function() toggle_playback(i) end)

    params:add_binary(i.."track_mute", "mute", "trigger", 0)
    params:set_action(i.."track_mute", function() local e = {t = eMUTE, i = i, mute = (1 - track[i].mute)} event(e) end)

    params:add_binary(i.."tog_rec", "record", "trigger", 0)
    params:set_action(i.."tog_rec", function() toggle_rec(i) end)

    params:add_binary(i.."tog_rev", "reverse", "trigger", 0)
    params:set_action(i.."tog_rev", function() local e = {t = eREV, i = i, rev = (1 - track[i].rev)} event(e) end)

    params:add_binary(i.."inc_speed", "speed +", "trigger", 0)
    params:set_action(i.."inc_speed", function()
      local n = util.clamp(track[i].speed + 1, -3, 3)
      local e = {t = eSPEED, i = i, speed = n} event(e)
    end)

    params:add_binary(i.."dec_speed", "speed -", "trigger", 0)
    params:set_action(i.."dec_speed", function()
      local n = util.clamp(track[i].speed - 1, -3, 3)
      local e = {t = eSPEED, i = i, speed = n} event(e)
    end)

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
  ui.arc_params()

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

  -- track params
  params:add_separator("track_params", "tracks")

  audio.level_cut(1)
  audio.level_tape(1)

  for i = 1, 6 do
    params:add_group("track_group"..i, "track "..i, 51)

    -- track options
    params:add_separator("track_options_params"..i, "track "..i.." options")

    params:add_option(i.."input_options", "tape input", {"sum", "left", "right", "off"}, 1)
    params:set_action(i.."input_options", function(option) tp[i].input = option set_softcut_input(i) end)
    params:hide(i.."input_options")

    params:add_option(i.."rec_enable", "rec enable", {"off", "on"}, 2)
    params:set_action(i.."rec_enable", function(x) set_rec_enable(i, x == 2) grid_page(vREC) end)

    params:add_number(i.."tape_buffer", "track tape", 1, 6, i)
    params:set_action(i.."tape_buffer", function(x) tp[i].buffer = x set_tape(i, x) end)

    params:add_option(i.."tape_side", "tape side", {"main", "temp"}, 1)
    params:set_action(i.."tape_side", function(x) tp[i].side = x softcut.buffer(i, x) end)

    params:add_option(i.."play_mode", "play mode", {"loop", "oneshot", "gate"}, 1)
    params:set_action(i.."play_mode", function(option) track[i].play_mode = option page_redraw(vMAIN, 7) end)

    params:add_option(i.."tempo_map_mode", "tempo-map", {"none", "resize", "repitch"}, 1)
    params:set_action(i.."tempo_map_mode", function(mode) track[i].tempo_map = mode - 1 set_tempo_map(i) grid_page(vREC) end)

    params:add_option(i.."start_launch", "track launch", {"manual", "beat", "bar"}, 1)
    params:set_action(i.."start_launch", function(option) track[i].start_launch = option page_redraw(vMAIN, 7) end)

    params:add_option(i.."reset_active", "track reset", {"off", "on"}, 1)
    params:set_action(i.."reset_active", function(mode)
      track[i].reset = mode == 2 and true or false
      if mode == 2 then track[i].beat_count = 0 end
      page_redraw(vMAIN, 8)
    end)
 
    params:add_number(i.."reset_count", "reset count", 1, 128, 1, function(param) return param:get() == 1 and "track" or (param:get().." beats") end)
    params:set_action(i.."reset_count", function() set_track_reset(i) page_redraw(vMAIN, 8) end)
    
    -- track levels
    params:add_separator("track_level_params"..i, "track "..i.." levels")

    params:add_control(i.."vol", "volume", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."vol", function(x) track[i].level = x set_level(i) end)

    params:add_control(i.."pan", "pan", controlspec.new(-1, 1, 'lin', 0, 0, ""), function(param) return pan_display(param:get()) end)
    params:set_action(i.."pan", function(x) track[i].pan = x softcut.pan(i, x) page_redraw(vMAIN, 1) end)

    params:add_control(i.."rec", "rec level", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."rec", function(x) track[i].rec_level = x set_rec(i) end)

    params:add_control(i.."dub", "dub level", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."dub", function(x) track[i].pre_level = x set_rec(i) end)

    params:add_control(i.."rate_slew", "rate slew", controlspec.new(0, 2, 'lin', 0, 0, ""), function(param) return (round_form(param:get(), 0.01, "s")) end)
    params:set_action(i.."rate_slew", function(x) track[i].rate_slew = x softcut.rate_slew_time(i, x) page_redraw(vMAIN, 6) end)

    params:add_control(i.."level_slew", "level slew", controlspec.new(0, 2, "lin", 0, 0.1, ""), function(param) return (round_form(param:get(), 0.01, "s")) end)
    params:set_action(i.."level_slew", function(x) softcut.level_slew_time(i, x) page_redraw(vMAIN, 6) end)

    params:add_control(i.."send_t5", "track 5 send", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_t5", function(x) track[i].send_t5 = x set_track_sends(i) end)
    if i > 4 then params:hide(i.."send_t5") end

    params:add_control(i.."send_t6", "track 6 send", controlspec.new(0, 1, 'lin', 0, 0.5, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."send_t6", function(x) track[i].send_t6 = x set_track_sends(i) end)
    if i > 5 then params:hide(i.."send_t6") end

    -- track pitch
    params:add_separator("track_pitch_params"..i, "track "..i.." pitch")

    params:add_number(i.."detune", "detune", -600, 600, 0, function(param) return (round_form(param:get(), 1, "cents")) end)
    params:set_action(i.."detune", function(cent) track[i].detune = cent / 1200 update_rate(i) page_redraw(vMAIN, 5) end)

    params:add_option(i.."transpose", "transpose", scales.id[1], 8)
    params:set_action(i.."transpose", function(x) set_transpose(i, x) end)
    
    -- track filter
    params:add_separator("track_filter_params"..i, "track "..i.." filter")

    params:add_control(i.."cutoff", "cutoff", controlspec.new(-1, 1, 'lin', 0, 1, ""), function(param) return cutoff_display(i, param:get()) end)
    params:set_action(i.."cutoff", function(x) set_cutoff(i, x) page_redraw(vMAIN, 3) end)

    params:add_control(i.."filter_q", "filter q", controlspec.new(0, 1, 'lin', 0, 0.2, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."filter_q", function(x) set_filter_q(i, x) page_redraw(vMAIN, 3) end)

    params:add_option(i.."filter_type", "type", {"lp", "hp", "bp", "br", "dj", "off"}, 1)
    params:set_action(i.."filter_type", function(option) filter_select(i, option) page_redraw(vMAIN, 4) end)

    params:add_control(i.."post_dry", "dry level", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return dry_level_display(i, param:get()) end)
    params:set_action(i.."post_dry", function(x) track[i].dry_level = x set_dry_level(i) page_redraw(vMAIN, 4) end)

    -- track warble
    params:add_separator("warble_params"..i, "track "..i.." warble")

    params:add_option(i.."warble_state", "state", {"off", "on"}, 1)
    params:set_action(i.."warble_state", function(state) track[i].warble = state - 1 grid_page(vREC) end)
    
    params:add_number(i.."warble_amount", "amount", 1, 100, 20, function(param) return (param:get().."%") end)
    params:set_action(i.."warble_amount", function(val) wrb[i].amount = val end)
    
    params:add_number(i.."warble_depth", "intensity", 10, 100, 32, function(param) return (param:get().."%") end)
    params:set_action(i.."warble_depth", function(val) wrb[i].depth = val end)
    
    -- track envelope
    params:add_separator("envelope_params"..i, "track "..i.." envelope")

    params:add_option(i.."adsr_active", "envelope", {"off", "on"}, 1)
    params:set_action(i.."adsr_active", function(mode) env[i].active = mode == 2 and true or false init_envelope(i) grid_page(vENV) end)

    params:add_control(i.."adsr_amp", "max vol", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_amp", function(val) env[i].max_value = val clamp_env_levels(i) page_redraw(vENV, 3) end)

    params:add_control(i.."adsr_init", "min vol", controlspec.new(0, 1, 'lin', 0, 0, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_init", function(val) env[i].init_value = val clamp_env_levels(i) page_redraw(vENV, 3) end)

    params:add_control(i.."adsr_attack", "attack", controlspec.new(0, 10, 'lin', 0.1, 0.2, "s"))
    params:set_action(i.."adsr_attack", function(val) env[i].attack = val * 10 page_redraw(vENV, 1) page_redraw(vENV, 2) end)

    params:add_control(i.."adsr_decay", "decay", controlspec.new(0, 10, 'lin', 0.1, 0.5, "s"))
    params:set_action(i.."adsr_decay", function(val) env[i].decay = val * 10 page_redraw(vENV, 1) page_redraw(vENV, 2) end)

    params:add_control(i.."adsr_sustain", "sustain", controlspec.new(0, 1, 'lin', 0, 1, ""), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action(i.."adsr_sustain", function(val) env[i].sustain = val clamp_env_levels(i) page_redraw(vENV, 1) page_redraw(vENV, 2) end)

    params:add_control(i.."adsr_release", "release", controlspec.new(0, 10, 'lin', 0.1, 1, "s"))
    params:set_action(i.."adsr_release", function(val) env[i].release = val * 10 page_redraw(vENV, 1) page_redraw(vENV, 2) end)    

    -- track triggers
    params:add_separator(i.."trigger_params", "track "..i.." triggers")
 
    params:add_option(i.."rec_at_step", "rec@step", {"off", "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 1)
    params:set_action(i.."rec_at_step", function(num) trig[i].rec_step = num - 1 end)

    params:add_option(i.."trig_at_step", "trig@step", {"off", "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 1)
    params:set_action(i.."trig_at_step", function(num) trig[i].step = num - 1 end)

    params:add_option(i.."trig_at_count", "trig@count", {"off", "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"}, 1)
    params:set_action(i.."trig_at_count", function(num) trig[i].count = num - 1 end)

    params:add_option(i.."trig_out", "trig output", {"off", "crow 1", "crow 2", "crow 3", "crow 4", "midi"}, 1)
    params:set_action(i.."trig_out", function(num) trig[i].out = num build_trig_menu(i) end)

    params:add_option(i.."trig_type", "trig mode", {"pulse", "envelope"}, 1)
    params:set_action(i.."trig_type", function(mode) trig[i].pulse = mode == 1 and true or false build_trig_menu(i) end)

    params:add_control(i.."crow_amp", "amplitude", controlspec.new(0.1, 10, "lin", 0.1, 8, "v"))
    params:set_action(i.."crow_amp", function(val) trig[i].amp = val end)

    params:add_control(i.."crow_env_a", "attack", controlspec.new(0.00, 1, "lin", 0.01, 0.00, "s"))
    params:set_action(i.."crow_env_a", function(val) trig[i].env_a = val end)

    params:add_control(i.."crow_env_d", "decay", controlspec.new(0.01, 1, "lin", 0.01, 0.05, "s"))
    params:set_action(i.."crow_env_d", function(val) trig[i].env_d = val end)

    params:add_number(i.."midi_channel", "midi channel", 1, 16, 1)
    params:set_action(i.."midi_channel", function(num) trig[i].midi_ch = num end)

    params:add_number(i.."midi_note", "midi note", 1, 127, 48, function(param) return mu.note_num_to_name(param:get(), true) end)
    params:set_action(i.."midi_note", function(num) trig[i].midi_note = num end)

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

  -- lfo params
  params:add_separator("modulation_params", "modulation")
  init_lfos()

  -- callbacks
  arc.add = arc_connected
  arc.remove = arc_removed
  grid.add = grid_connected
  midi.add = midi_connected
  midi.remove = midi_disconnected
  params.action_write = pset_write_callback
  params.action_read = pset_read_callback
  params.action_delete = pset_delete_callback
  clock.tempo_change_handler = tempo_change_callback
  clock.transport.start = transport_start_callback
  clock.transport.stop = transport_stop_callback

  softcut.event_render(wave_render)
  softcut.event_phase(phase_poll)
  softcut.poll_start_phase()
  softcut.event_position(get_pos)

  -- amp polls
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
    
  -- metros
  hardwareredrawtimer = metro.init(hardwareredraw, 1/30, -1)
  hardwareredrawtimer:start()

  screenredrawtimer = metro.init(screenredraw, 1/15, -1)
  screenredrawtimer:start()

  tracktimer = metro.init(function() rec_dur = rec_dur + 1 end, 0.01, -1)
  tracktimer:stop()

  -- lattice
  vizclock = lattice:new()

  fastpulse = vizclock:new_sprocket{
    action = function(t)
      pulse_key_fast = pulse_key_fast == 8 and 12 or 8
      if pattern_rec or track[armed_track].rec_thresh == 1 or splice_queued then dirtygrid = true end
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
  clock.run(track_reset)
  clock.run(ledpulse_bar)
  clock.run(ledpulse_beat)

  -- set defaults
  set_view(vMAIN)
  set_gridview(vCUT, "z")
  set_gridview(vREC, "o")
  macro_slot_defaults()
  load_loadop_config()

  if pset_load then
    params:default()
  else
    params:bang()
  end

  init_done = true

  print("mlre loaded and ready. enjoy!")

end


--------------------- USER INTERFACE -----------------------
vMAIN = 0
vREC = 1
vCUT = 2
vTRSP = 3
vLFO = 4
vENV = 5
vMACRO = 6
vTAPE = 7

view = vMAIN
grido_view = vREC
gridz_view = vCUT

v = {}
v.key = {}
v.enc = {}
v.redraw = {}
v.arckey = {}
v.arcdelta = {}
v.arcredraw = {}
v.gridkey_o = {}
v.gridredraw_o = {}
v.gridkey_z = {}
v.gridredraw_z = {}

-- set grid page
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
  if pmac_edit_view and x ~= vMACRO then pmac_edit_view = false end
  grd.clear_keylogic()
  screen.ping()
  dirtyscreen = true
  dirtygrid = true
end

-- set norns page
function set_view(x)
  if x > 0 and x < 4 then x = vMAIN end
  view = x
  _key = v.key[x]
  _enc = v.enc[x]
  _redraw = v.redraw[x]
  _arckey = v.arckey[x]
  _arcdelta = v.arcdelta[x]
  _arcredraw = v.arcredraw[x]
  if pmac_perf_view and x == vTAPE then toggle_pmac_perf_view(0) end
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

function show_message(message)
  if msg_clock ~= nil then
    clock.cancel(msg_clock)
  end
  msg_clock = clock.run(function()
    view_message = message
    dirtyscreen = true
    local dur = string.len(message) > 20 and 1.6 or 0.8
    clock.sleep(dur)
    view_message = ""
    dirtyscreen = true
    msg_clock = nil
  end)
end

function key(n, z)
  if n == 1 then
    shift = z
    toggle_pmac_perf_view(z) 
  else
    if popup_view then
      ui.popup_key(n, z)
    elseif keyquant_edit then
      ui.keyquant_key(n, z)
    elseif pmac_perf_view then
      ui.pmac_perf_key(n, z)
    elseif pmac_edit_view then
      ui.pmac_edit_key(n, z)
    elseif warble_edit then
      -- do nothing
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
  elseif warble_edit then
    ui.wrbl_enc(n, d)
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
  elseif warble_edit then
    ui.wrbl_redraw()
  else
    _redraw()
  end
end

function a.key(n, z)
  _arckey(n, z)
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
  elseif view == vMACRO and patterns_pageNum == page then
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
    if GRID_SIZE == 256 then
      g:rotation(params:get("grid_orientation") - 1)
    end
  end
  dirtygrid = true
end

function arc_connected()
  arc_is = true
  params:show("arc_params")
  _menu.rebuild_params()
end

function arc_removed()
  arc_is = false
  params:hide("arc_params")
  _menu.rebuild_params()
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

v.arckey[vMAIN] = function(n, z)
  ui.arc_main_key(n, z)
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

v.arckey[vLFO] = function(n, z)
  ui.arc_lfo_key(n, z)
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

v.arckey[vENV] = function(n, z)
  ui.arc_env_key(n, z)
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

v.key[vMACRO] = function(n, z)
  ui.macro_key(n, z)
end

v.enc[vMACRO] = function(n, d)
  ui.macro_enc(n, d)
end

v.redraw[vMACRO] = function()
  ui.macro_redraw()
end

v.arckey[vMACRO] = function(n, z)
  ui.arc_main_key(n, z)
end

v.arcdelta[vMACRO] = function(n, d)
  ui.arc_main_delta(n, d)
end

v.arcredraw[vMACRO] = function()
  ui.arc_main_draw()
end

v.gridkey_o[vMACRO] = function(x, y, z)
  if GRID_SIZE == 128 then
    grd.macro_keys(x, y, z)
  elseif GRID_SIZE == 256 then
    grd.macro_keys(x, y, z, -1)
  end
end

v.gridredraw_o[vMACRO] = function()
  if GRID_SIZE == 128 then
    grd.macro_draw()
  elseif GRID_SIZE == 256 then
    grd.macro_draw(-1)
  end
end

v.gridkey_z[vMACRO] = function(x, y, z)
  grd.macro_keys(x, y, z, 8)
end

v.gridredraw_z[vMACRO] = function()
  grd.macro_draw(8)
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

v.arckey[vTAPE] = function(n, z)
  ui.arc_tape_key(n, z)
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

function build_trig_menu(i)
  local i = i or 1
  if trig[i].out == 1 then
    params:hide(i.."trig_type")
    params:hide(i.."crow_amp")
    params:hide(i.."crow_env_a")
    params:hide(i.."crow_env_d")
    params:hide(i.."midi_channel")
    params:hide(i.."midi_note")
    params:hide(i.."midi_vel")
  elseif trig[i].out > 1 and trig[i].out < 6 then
    params:show(i.."trig_type")
    if trig[i].pulse then
      params:hide(i.."crow_amp")
      params:hide(i.."crow_env_a")
      params:hide(i.."crow_env_d")
    else
      params:show(i.."crow_amp")
      params:show(i.."crow_env_a")
      params:show(i.."crow_env_d")
    end
    params:hide(i.."midi_channel")
    params:hide(i.."midi_note")
    params:hide(i.."midi_vel")
  else
    params:hide(i.."trig_type")
    params:hide(i.."crow_amp")
    params:hide(i.."crow_env_a")
    params:hide(i.."crow_env_d")
    params:show(i.."midi_channel")
    params:show(i.."midi_note")
    params:show(i.."midi_vel")
  end
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
  if param < -0.01 then
    return ("L < "..math.abs(util.round(param * 100, 1)))
  elseif param > 0.01 then
    return (math.abs(util.round(param * 100, 1)).." > R")
  else
    return "> <"
  end
end

function cutoff_display(i, param)
  if track[i].filter_mode == 6 then
    return "-"
  elseif track[i].filter_mode == 5 then
    if param < -0.1 then
      local p = math.abs(util.round(util.linlin(-1, -0.1, -100, -1, param), 1))
      return "lp < " ..p
    elseif param > 0.1 then
      local p = math.abs(util.round(util.linlin(0.1, 1, 1, 100, param), 1))
      return p.." > hp"
    else
      return "|"
    end
  else
    return (round_form(track[i].cutoff_hz, 1, " hz"))
  end
end

function dry_level_display(i, param)
  if track[i].filter_mode < 5 then
    return (round_form(param * 100, 1, "%"))
  else
    return "-"
  end
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
  vizclock:destroy()
  show_banner()
end
