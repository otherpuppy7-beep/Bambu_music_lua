require 'trig'

function tone(Htz,duration,sz,mode)
    local times = math.floor((math.abs(Htz*duration))) -- Htz [1/s] * t[s] = iterations [-].
    if mode == '∆X' then
        local sz = sz -- no need for pythagorean thm here - user 'already' did it
        local g_code = 'G1 X'..sz..' Y'..sz..'\nG1 X-'..sz..' Y-'..sz..' ; vibrate once slightly\n'
        local speed = (math.abs(norm(Htz*sz,Htz*sz)))*60 -- Htz [1/s] * sz [mm] * 60 [sec/min] = feed [mm/min]
        local str = 'G1 F'..speed..'\n' -- set the travel speed for the tone
        for i = 1,times do
            str = str..g_code -- append that section of code for each vibration
            -- there ought to be a nicer way to do that, but I can't find it.
        end
        return str
    elseif mode == 'A' then
        local str = ''
        local acl = sz
        local time = (1/Htz)/2 -- duration for one half vibration
        local vel = math.abs(acl*time)*60 --vel [mm/min] by V = A*∆t
        local dx = norm((0.5*acl*(time^2)),(0.5*acl*(time^2))) -- using the pythagorean thm for ∆X
        local g_code = 'G1 X'..dx..'\nG1 X-'..dx..' ; vibrate once slightly\n'
        local str = '\nG1 F'..vel..' ; tone: '..Htz..' Htz\n' -- set the travel speed for the tone
        for i = 1,times do
            str = str..g_code -- append that section of code for each vibration
            -- there ought to be a nicer way to do that, but I can't find it.
        end
        return str
    elseif mode == 'V' then -- constant velocity
        local time = (1/Htz) -- duration for one half vibration
        local dx = norm((0.5*(sz/60)*time),(0.5*(sz/60)*time)) -- use pythagorean thm
        local str = 'G1 F'..sz..'\n'
        local g_code = 'G1 X'..dx..' Y'..dx..'\nG1 X-'..dx..' Y-'..dx..' ; vibrate once slightly\n'
        for i = 1,times do
            str = str..g_code -- append that section of code for each vibration
            -- there ought to be a nicer way to do that, but I can't find it.
        end
        return str
    end
end



function pause(duration,sz)
    -- move slowly for this duration: only do one vibration
    local g_code = 'G1 X'..sz..'\nG1 X-'..sz..' ; vibrate once slightly\n'
    local speed = ((2*sz)/duration)*60 -- sz [mm]/(t [sec]* 60 [sec/min]) = feed [mm/min]
    local str = '\nF'..speed..' ; pause: '..duration..' sec\n'..g_code..'\n'
    return str
end