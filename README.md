Welcome to the midi to g-code converter for Bambu labs 
P1/P2/X1 printers!

in order to understand what the options mean (and why the 
output file size is so big), you need to understand a bit 
about how this works. the normal way to do this is to 
convert each note in a midi file to there respective Htz
values, then use the M300 (motor tone) command to make
the sound. For printers that do not have the M300 command
available, you make a macro that tells the printer how 
to vibrate once, then loop that command as needed.

The problem is that Bambu will not alow M300, macros,
or loops! the way that this code works is each half 
vibration takes up a new line of code. this can get 
quite large when you have something like 256 Htz (middle C),
for one second.

================== user inputs ==================

there are 4 things to specify to make a note, you need 
frequency (from the midi file), displacement (∆X),
velocity (V), and acceleration (A). when given any one, 
you can solve for the other two with 
with some variants of the kinematic equations. 
This program will take one of those and solve for the other 2
in order to write the g-code.

==== Mode 1 (constant V)
this is the best way to do this, V also controls the 
volume and never fails to hit the note called for. the only 
problem is that as V gets large (about 800 mm/min and up),
the vibration can get so intense that the notes get a little
fuzzy. recommended 750 mm/min

==== Mode 2 (constant ∆X)
∆X controls volume, bigger ∆X, more sound. the problem is
that there is a cap on the acceleration, so if the notes 
get too high, the printer just won't be able to hit them.
to fix this, make ∆X smaller. It also does not help that 
the highest note that the printer can hit is not any 
real note, so it sounds horribly out of key. recommended 0.016 mm

==== Mode 3 (constant A)
largely useless. sometimes makes the wrong note for no 
good reason, but very safe for the printer.
recommended 80000 mm/s^2

====================== credits ======================

Bambu G-code wiki:
https://wiki.bambulab.com/en/p1/manual/extension-board-gcode-placeholder-reference

löve 2D.org
https://love2d.org/wiki/Main_Page

OneCompiler for lua (initial prototype/testing ideas):
https://onecompiler.com/lua
