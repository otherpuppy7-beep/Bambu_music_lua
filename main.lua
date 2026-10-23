-- Caleb Rodekohr  G-code music maker for bambu P1/P2/X1/X2 3D printers     10/02/2026

-- for the list of bambu G-code commands see 
-- https://wiki.bambulab.com/en/p1/manual/extension-board-gcode-placeholder-reference
-- every thing else is standard marlen g-code.


function love.load()
    require 'midi_stuff.script_maker'
    GetCode(750,'V','/Users/caleb/Desktop/G-code Music/solo_turkey(2).mid','/Users/caleb/Desktop','My_Music')
    love.event.quit()
end