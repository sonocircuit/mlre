-- display info if norns version does not match requirements
-- adapted form cc2 by @dan_derks
function redraw()
  screen.clear()
  screen.level(15)
  screen.move(64,32)
  screen.text_center('mlre requires norns 220802+')
  if tonumber(norns.version.update) < 220306 then
    screen.level(3)
    screen.move(64,50)
    screen.text_center('you must flash norns')
    screen.move(64,58)
    screen.text_center('with new image 220306')
  else
    screen.level(3)
    screen.move(64,50)
    screen.text_center('perform SYSTEM > UPDATE')
  end
  screen.update()
end
