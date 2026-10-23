local start_string = 'G28 ; trigger the homing sequence\nG90 ; global position\nG0 Z128 F900 ;lower the build plate\n\n\nG91 ; relative movement\n\n; music starts here\n' 

return start_string