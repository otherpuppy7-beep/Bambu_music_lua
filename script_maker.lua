function GetCode(sz,mode,read_path,publish_path,file_name)
    local start = require 'midi_stuff.startup'
    require 'midi_stuff.sound'
    require 'midi_stuff.midi_reader'
    local vol = sz 

    local midi = read_path
    local notes, readError = readMidi(midi)
    if not notes then
        error('Could not read MIDI file: ' .. tostring(readError))
    end

    local gcode = {start}
    local previousEnd = 0
    for _, note in ipairs(notes) do
        local gap = note.start - previousEnd
        if gap > 0 then
            gcode[#gcode + 1] = pause(gap, 0.016)
        end

        gcode[#gcode + 1] = tone(note.frequency, note.duration, vol, mode)
        previousEnd = note.start + note.duration
    end

    local output, openError = io.open(publish_path..'/'..file_name..'.gcode', 'w')
    if not output then
        error('Could not create G-code file: ' .. tostring(openError))
    end

    local _, writeError = output:write(table.concat(gcode))
    output:close()
    if writeError then
        error('Could not write G-code file: ' .. tostring(writeError))
    end
end