--- timed pattern event recorder/player
-- @module lib.pattern
--
-- added pattern sync to sytem clock for mlre
-- 0.1.0 @sonocircuit

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id)
  local i = {}
  setmetatable(i, pattern)
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
  i.clock_tick = 0
  i.synced = false
  i.sync_meter = 4/4
  i.sync_beatnum = 16
  i.sync_clock = nil
  i.count_in = 1
  i.bpm = nil
  i.tempo_map = true
  i.loop = true
  i.flash = false
  i.id = id or "pattern"
  i.metro = metro.init(function() i:next_event() end, 1, 1)
  i.process = function(_) print("event") end
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
  print(self.id.." cleared")
end

--- adjust the time factor of this pattern.
function pattern:set_time_factor(f)
  self.time_factor = f or 1
end

--- start recording
function pattern:rec_start()
  --print(self.id.." rec start")
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
      --print(self.id.." rec stop")
    else
      print(self.id.." is empty")
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
      clock.run(
        function()
          clock.sleep(pattern_length)
          self:rec_stop()
          --self:start() -- replace with start commands
          self:first()
          self.clock_tick = 0
          self.play = 1
        end
      )
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
  --print(self.id.." stop")
end

--- pattern_sync coroutine
function pattern_sync(target)
  while true do
    clock.sync(1)
    if target.synced and target.play == 1 then
      target.clock_tick = (target.clock_tick + 1) % (target.sync_meter * target.sync_beatnum)
      if target.clock_tick == 0 then
        if target.loop then
          target:undo()
          target:first()
        else
          target:undo()
          target:stop()
        end
      end
    end
  end
end

-- start clocks (via main script init)
function pattern:init_clock()
  self.sync_clock = clock.run(pattern_sync, self)
end

--- start pattern
function pattern:start()
  if self.count > 0 then
    if self.synced then
      clock.run(
        function()
          clock.sync(self.count_in)
          if self.play == 1 then
            self:first()
            self.clock_tick = 0
            --print(self.id.." start")
          end
        end
      )
      self.play = 1
      dirtygrid = true
    else
      self:first()
      self.play = 1
      --print(self.id.." start")
    end
  end
end

--- first event
function pattern:first()
  self.prev_time = util.time()
  self.process(self.event[1])
  self.step = 1
  self.metro.time = self.time[1] * self.time_factor
  self.metro:start()
  -- first step indicator
  self.flash = true
  dirtygrid = true
  clock.run(
    function()
      clock.sleep(0.1)
      self.flash = false
      dirtygrid = true
    end
  )
  --print(self.id.." step "..self.step)
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
    --print(self.id.." step "..self.step)
    self.process(self.event[self.step])
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
    print(self.id.." undo")
  end
end

return pattern
