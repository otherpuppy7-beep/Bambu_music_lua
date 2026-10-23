-- Returns note events with frequency in Hz and duration/start in seconds.
function readMidi(path)
    local file, openError = io.open(path, 'rb')
    if not file then
        return nil, openError
    end

    local data, readError = file:read('*a')
    file:close()
    if not data then
        return nil, readError
    end

    local function readByte(source, position, limit)
        if position > limit then
            error('readMidi: unexpected end of MIDI data', 0)
        end
        return source:byte(position)
    end

    local function readU16(source, position, limit)
        return readByte(source, position, limit) * 256
            + readByte(source, position + 1, limit)
    end

    local function readU32(source, position, limit)
        return readByte(source, position, limit) * 16777216
            + readByte(source, position + 1, limit) * 65536
            + readByte(source, position + 2, limit) * 256
            + readByte(source, position + 3, limit)
    end

    local function readVariableLength(source, position, limit)
        local value = 0
        for _ = 1, 4 do
            local byte = readByte(source, position, limit)
            position = position + 1
            value = value * 128 + byte % 128
            if byte < 128 then
                return value, position
            end
        end
        error('readMidi: invalid variable-length quantity', 0)
    end

    if #data < 14 or data:sub(1, 4) ~= 'MThd' then
        error('readMidi: invalid MIDI header', 0)
    end

    local headerLength = readU32(data, 5, #data)
    if headerLength < 6 or 8 + headerLength > #data then
        error('readMidi: invalid MIDI header length', 0)
    end

    local format = readU16(data, 9, #data)
    local trackCount = readU16(data, 11, #data)
    local division = readU16(data, 13, #data)
    if format > 1 then
        error('readMidi: only MIDI formats 0 and 1 are supported', 0)
    end
    if division == 0 or division >= 32768 then
        error('readMidi: SMPTE or invalid time division is not supported', 0)
    end

    local tracks = {}
    local position = 9 + headerLength
    while #tracks < trackCount do
        if position + 7 > #data then
            error('readMidi: missing MIDI track', 0)
        end

        local chunkType = data:sub(position, position + 3)
        local chunkLength = readU32(data, position + 4, #data)
        local chunkStart = position + 8
        local chunkEnd = chunkStart + chunkLength
        if chunkEnd > #data + 1 then
            error('readMidi: invalid MIDI chunk length', 0)
        end

        if chunkType == 'MTrk' then
            tracks[#tracks + 1] = data:sub(chunkStart, chunkEnd - 1)
        end
        position = chunkEnd
    end

    local noteEvents = {}
    local tempoEvents = {}
    local finalTick = 0

    for trackIndex, track in ipairs(tracks) do
        local trackPosition = 1
        local tick = 0
        local runningStatus
        local eventOrder = 0

        while trackPosition <= #track do
            local delta
            delta, trackPosition = readVariableLength(track, trackPosition, #track)
            tick = tick + delta
            eventOrder = eventOrder + 1

            local status = readByte(track, trackPosition, #track)
            trackPosition = trackPosition + 1
            local firstDataByte
            if status < 128 then
                if not runningStatus then
                    error('readMidi: data byte without running status', 0)
                end
                firstDataByte = status
                status = runningStatus
            elseif status < 240 then
                runningStatus = status
            else
                runningStatus = nil
            end

            if status == 255 then
                local metaType = readByte(track, trackPosition, #track)
                trackPosition = trackPosition + 1
                local length
                length, trackPosition = readVariableLength(track, trackPosition, #track)
                if trackPosition + length - 1 > #track then
                    error('readMidi: invalid MIDI meta-event length', 0)
                end
                if metaType == 81 and length == 3 then
                    local microsecondsPerQuarter = readByte(track, trackPosition, #track) * 65536
                        + readByte(track, trackPosition + 1, #track) * 256
                        + readByte(track, trackPosition + 2, #track)
                    if microsecondsPerQuarter == 0 then
                        error('readMidi: invalid zero tempo', 0)
                    end
                    tempoEvents[#tempoEvents + 1] = {
                        tick = tick,
                        tempo = microsecondsPerQuarter,
                        track = trackIndex,
                        order = eventOrder
                    }
                end
                trackPosition = trackPosition + length
            elseif status == 240 or status == 247 then
                local length
                length, trackPosition = readVariableLength(track, trackPosition, #track)
                if trackPosition + length - 1 > #track then
                    error('readMidi: invalid MIDI system-exclusive event length', 0)
                end
                trackPosition = trackPosition + length
            elseif status >= 128 and status < 240 then
                local messageType = math.floor(status / 16) * 16
                local channel = status % 16
                local dataLength = (messageType == 192 or messageType == 208) and 1 or 2
                local note = firstDataByte
                if not note then
                    note = readByte(track, trackPosition, #track)
                    trackPosition = trackPosition + 1
                end
                if note >= 128 then
                    error('readMidi: invalid MIDI channel data byte', 0)
                end

                local velocity
                if dataLength == 2 then
                    velocity = readByte(track, trackPosition, #track)
                    trackPosition = trackPosition + 1
                    if velocity >= 128 then
                        error('readMidi: invalid MIDI channel data byte', 0)
                    end
                end

                if messageType == 128 or messageType == 144 then
                    noteEvents[#noteEvents + 1] = {
                        tick = tick,
                        channel = channel,
                        note = note,
                        isOn = messageType == 144 and velocity > 0,
                        track = trackIndex,
                        order = eventOrder
                    }
                end
            else
                error('readMidi: unsupported MIDI event status', 0)
            end
        end
        if tick > finalTick then
            finalTick = tick
        end
    end

    table.sort(tempoEvents, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        if a.track ~= b.track then return a.track < b.track end
        return a.order < b.order
    end)

    local tempoSegments = {{ tick = 0, seconds = 0, tempo = 500000 }}
    for _, event in ipairs(tempoEvents) do
        local previous = tempoSegments[#tempoSegments]
        local seconds = previous.seconds
            + (event.tick - previous.tick) * previous.tempo / division / 1000000
        if event.tick == previous.tick then
            previous.tempo = event.tempo
        else
            tempoSegments[#tempoSegments + 1] = {
                tick = event.tick,
                seconds = seconds,
                tempo = event.tempo
            }
        end
    end

    local function tickToSeconds(targetTick)
        local segment = tempoSegments[1]
        for _, candidate in ipairs(tempoSegments) do
            if candidate.tick > targetTick then
                break
            end
            segment = candidate
        end
        return segment.seconds
            + (targetTick - segment.tick) * segment.tempo / division / 1000000
    end

    table.sort(noteEvents, function(a, b)
        if a.tick ~= b.tick then return a.tick < b.tick end
        if a.track ~= b.track then return a.track < b.track end
        return a.order < b.order
    end)

    local activeNotes = {}
    local notes = {}
    local function finishNote(startEvent, endTick)
        notes[#notes + 1] = {
            frequency = 440 * 2 ^ ((startEvent.note - 69) / 12),
            duration = tickToSeconds(endTick) - tickToSeconds(startEvent.tick),
            start = tickToSeconds(startEvent.tick)
        }
    end

    for _, event in ipairs(noteEvents) do
        local key = event.channel * 128 + event.note
        if event.isOn then
            local queue = activeNotes[key]
            if not queue then
                queue = {items = {}, head = 1, tail = 0}
                activeNotes[key] = queue
            end
            queue.tail = queue.tail + 1
            queue.items[queue.tail] = event
        else
            local queue = activeNotes[key]
            if queue and queue.head <= queue.tail then
                finishNote(queue.items[queue.head], event.tick)
                queue.items[queue.head] = nil
                queue.head = queue.head + 1
            end
        end
    end

    for _, queue in pairs(activeNotes) do
        while queue.head <= queue.tail do
            finishNote(queue.items[queue.head], finalTick)
            queue.head = queue.head + 1
        end
    end

    table.sort(notes, function(a, b)
        return a.start < b.start
    end)
    return notes
end