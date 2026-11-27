function love.conf(t)
  t.identity = "criadero-ambar"
  t.version = "11.5"
  t.console = false

  t.window.title = "Criadero de Ámbar"
  t.window.width = 1280
  t.window.height = 720
  t.window.minwidth = 960
  t.window.minheight = 540
  t.window.resizable = true
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.highdpi = true

  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.modules.audio = true
  t.modules.sound = true
end
