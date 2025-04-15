--- timed pattern event recorder/player
-- @module lib.pattern
--
-- pattern sync for mlre @sonocircuit

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id)
  local i = {}
  setmetatable(i, pattern)
  i.id = id or "pattern"
  i.rec = 0
  i.play = 0
  i.overdub = 0
  i.overdub_undo = false
  i.prev_time = 0
  i.event = {}
  i.temp_event = {}
  i.time = {}
  i.temp_time = {}
  i.count = 0
  i.temp_count = 0
  i.step = 0
  i.time_factor = 1  
  i.bpm = nil
  i.loop = true
  i.clock_tick = 0
  i.synced = false
  i.sync_meter = 4/4
  i.sync_beatnum = 16
  i.num_ticks = 1024
  i.metro = metro.init(function() i:next_event() end, 1, 1)
  i.start_callback = function() end
  i.event_callback = function() end
  i.process = function(_) end
  i:init_sync_clock()
  return i
end

--- clear pattern and restore defaults
function pattern:clear()
  self:stop()
  self.rec = 0
  self.play = 0
  self.overdub = 0
  self.overdub_undo = false
  self.prev_time = 0
  self.event = {}
  self.temp_event = {}
  self.time = {}
  self.temp_time = {}
  self.count = 0
  self.temp_count = 0
  self.step = 0
  self.time_factor = 1
  self.clock_tick = 0
  self.loop = true
  self.bpm = nil
end

--- adjust the time factor
function pattern:set_time_factor(f)
  self.time_factor = f or 1
end

function pattern:set_ticks()
  self.num_ticks = self.sync_meter * self.sync_beatnum * 32
end

--- start recording
function pattern:rec_start()
  self.rec = 1
end

--- stop recording
function pattern:rec_stop()
  if self.rec == 1 then
    self.rec = 0
    if self.count ~= 0 then
      local t = self.prev_time
      self.prev_time = util.time()
      self.time[self.count] = self.prev_time - t
    end
  end
end

--- watch
function pattern:watch(e)
  if self.rec == 1 then
    self:rec_event(e)
  elseif self.overdub == 1 then
    self:overdub_event(e)
  end
end

--- record event
function pattern:rec_event(e)
  local c = self.count + 1
  if c == 1 then
    self.prev_time = util.time()
    self.bpm = clock.get_tempo()
    if self.synced then
      local pattern_length = self.sync_meter * self.sync_beatnum * clock.get_beat_sec()
      clock.run(function()
        clock.sleep(pattern_length)
        self:rec_stop()
        self:first()
        self.clock_tick = 0
        self.play = 1
      end)
    end
  else
    local t = self.prev_time
    self.prev_time = util.time()
    self.time[c - 1] = self.prev_time - t
  end
  self.count = c
  self.event[c] = e
end

--- add overdub event
function pattern:overdub_event(e)
  local c = self.step + 1
  local t = self.prev_time
  self.prev_time = util.time()
  local a = self.time[c - 1]
  self.time[c - 1] = self.prev_time - t
  table.insert(self.time, c, a - self.time[c - 1])
  table.insert(self.event, c, e)
  self.step = self.step + 1
  self.count = self.count + 1
end

--- stop this pattern
function pattern:stop()
  self.metro:stop()
  self.play = 0
  self.overdub = 0
  self.step = 0
  self.clock_tick = 0
  dirtygrid = true
end

--- start pattern
function pattern:start()
  if self.count > 0 then
    self:first()
    self.play = 1
    self.clock_tick = 0
  end
end

--- first event
function pattern:first()
  self.prev_time = util.time()
  self.process(self.event[1])
  self.start_callback()
  self.step = 1
  self.metro.time = self.time[1] * self.time_factor
  self.metro:start()
end

--- process next event
function pattern:next_event()
  self.prev_time = util.time()
  if self.step == self.count then
    if not self.synced then
      if self.loop then
        self:undo()
        self:first()
      else
        self:undo()
        self:stop()
      end
    end
  else
    self.step = self.step + 1
    self.process(self.event[self.step])
    self.event_callback()
    self.metro.time = self.time[self.step] * self.time_factor
    self.metro:start()
  end
end

--- set overdub
function pattern:set_overdub(s)
  if s == 1 and self.play == 1 and self.rec == 0 then
    self.overdub = 1
    self.temp_event = {table.unpack(self.event)}
    self.temp_time = {table.unpack(self.time)}
    self.temp_count = self.count
  elseif s == 0 then
    self.overdub = 0
    self.temp_event = {}
    self.temp_time = {}
    self.temp_count = 0
    self.overdub_undo = false
  elseif s == -1 then
    self.overdub = 0
    self.overdub_undo = true
  end
end

function pattern:undo()
  if self.overdub_undo then
    self.event = {table.unpack(self.temp_event)}
    self.time = {table.unpack(self.temp_time)}
    self.count = self.temp_count
    self.overdub_undo = false
  end
end

function pattern:init_sync_clock()
  self.sync_clock = clock.run(function()
    while true do
      clock.sync(1/32)
      if self.synced and self.play == 1 then
        self.clock_tick = (self.clock_tick + 1) % self.num_ticks
        if self.clock_tick == 0 then
          self:undo()
          if self.loop then
            self:first()
          else
            self:stop()
          end
        end
      end
    end
  end)
end

function pattern:cleanup()
  self:stop()
  clock.cancel(self.sync_clock)
  self.sync_clock = nil
end

return pattern
