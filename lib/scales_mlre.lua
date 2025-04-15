-- scales for mlre

--[[
Transposition steps are defined as cents in the trsp_scale table. The strings displayed on the screen are defined in the trsp_id table.
The index of the scale name specified in the scale_options table points to index of the trsp_id and trsp_scale. 
All scales consist of 15 entries: 1-7 transpose down; 8 no transposition; 9-15 transpose up). 
]]--

scales = {}

-- scale name: the stings are displayed as options to select a scale in the parameter menu.
scales.options = {"major", "natural minor", "harmonic minor", "melodic minor", "dorian", "phrygian", "lydian", "mixolydian", "locrian", "custom"}

-- scale id: the scale id is the string displayed as tranposition value
scales.id = {
  {"-oct", "-min7", "-min6", "-perf5", "-perf4", "-min3", "-min2", "none", "maj2", "maj3", "perf4", "perf5", "maj6", "maj7", "oct"}, -- major
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-maj3", "-maj2", "none", "maj2", "min3", "perf4", "perf5", "min6", "min7", "oct"}, -- natural minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-maj3", "-min2", "none", "maj2", "min3", "perf4", "perf5", "min6", "maj7", "oct"}, -- hamonic minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-min3", "-min2", "none", "maj2", "min3", "perf4", "perf5", "maj6", "maj7", "oct"}, -- melodic minor
  {"-oct", "-min7", "-maj6", "-perf5", "-perf4", "-min3", "-maj2", "none", "maj2", "min3", "perf4", "perf5", "maj6", "min7", "oct"}, -- dorian
  {"-oct", "-maj7", "-maj6", "-perf5", "-perf4", "-maj3", "-maj2", "none", "min2", "min3", "perf4", "perf5", "min6", "min7", "oct"}, -- phrygian
  {"-oct", "-min7", "-min6", "-dim5", "-perf4", "-min3", "-min2", "none", "maj2", "maj3", "dim5", "perf5", "maj6", "maj7", "oct"}, -- lydian
  {"-oct", "-min7", "-min6", "-perf5", "-perf4", "-min3", "-maj2", "none", "maj2", "maj3", "perf4", "perf5", "maj6", "min7", "oct"}, -- mixolydian
  {"-oct", "-maj7", "-maj6", "-perf5", "-dim5", "-maj3", "-maj2", "none", "min2", "min3", "perf4", "dim5", "min6", "min7", "oct"}, -- locrian
  {"-p4+2oct", "-2oct", "-p5+oct", "-p4+oct", "-oct", "-perf5", "-perf4", "none", "perf4", "perf5", "oct", "p4+oct", "p5+oct", "2oct", "p4+2oct"}, -- custom
}

-- scale value: the scale value is the cent value to transpose
scales.val = {
  {-1200, -1000, -800, -700, -500, -300, -100, 0, 200, 400, 500, 700, 900, 1100, 1200}, -- major
  {-1200, -1000, -900, -700, -500, -400, -200, 0, 200, 300, 500, 700, 800, 1000, 1200}, -- natural minor
  {-1200, -1000, -900, -700, -500, -400, -100, 0, 200, 300, 500, 700, 800, 1100, 1200}, -- hamonic minor
  {-1200, -1000, -900, -700, -500, -300, -100, 0, 200, 300, 500, 700, 900, 1100, 1200}, -- melodic minor
  {-1200, -1000, -900, -700, -500, -300, -200, 0, 200, 300, 500, 700, 900, 1000, 1200}, -- dorian
  {-1200, -1100, -900, -700, -500, -400, -200, 0, 100, 300, 500, 700, 800, 1000, 1200}, -- phrygian
  {-1200, -1000, -800, -600, -500, -300, -100, 0, 200, 400, 600, 700, 900, 1100, 1200}, -- lydian
  {-1200, -1000, -800, -700, -500, -300, -200, 0, 200, 400, 500, 700, 900, 1000, 1200}, -- mixolydian
  {-1200, -1100, -900, -700, -600, -400, -200, 0, 100, 300, 500, 600, 800, 1000, 1200}, -- locrain
  {-3100, -2400, -1900, -1700, -1200, -700, -500, 0, 500, 700, 1200, 1700, 1900, 2400, 3100}, -- custom
}


return scales
