# --- Configuration ---
# SET YOUR PROJECT NAME
set proj_name "I2C_Protocol"

# SET YOUR TARGET FPGA
set fpga_part "xc7z020clg484-1"

# List of DESIGN source files
set design_files [list \
    "slow_clock.sv" \
    "I2C_master.sv" \
    "I2C_subordinate.sv" \
    "Sync_FIFO.v" \
    "I2C_system.sv" \
]

# Your TESTBENCH file
set tb_file "I2C_system_TB.sv"

# --- Setup ---
puts "INFO: Creating project '$proj_name'..."
# Delete old project directory if it exists, to start fresh
if { [file isdirectory $proj_name] } {
    file delete -force $proj_name
}
create_project $proj_name . -part $fpga_part

# --- Add Sources ---
puts "INFO: Adding design sources..."
add_files -fileset sources_1 $design_files

puts "INFO: Adding simulation sources..."
add_files -fileset sim_1 $tb_file

# Set the top modules for synthesis and simulation
set_property top I2C_system [get_filesets sources_1]
set_property top I2C_system_TB [get_filesets sim_1]

# --- Run Synthesis ---
puts "INFO: Launching Synthesis..."
launch_runs synth_1
wait_on_run synth_1
puts "INFO: Synthesis complete."

# --- Capture Utilization Report ---
puts "INFO: Opening synthesized design to generate utilization report..."
open_run synth_1

# Step 1: Run the report and save it to a file.
report_utilization -file post_synth_utilization.rpt
puts "INFO: Utilization report saved to 'post_synth_utilization.rpt'."

# Step 2: Read that file's content into a variable for later.
set f [open "post_synth_utilization.rpt" r]
set util_report_string [read $f]
close $f
puts "INFO: Utilization data captured for later display."

# Close the design to free up memory
close_design

# --- Run Simulation ---
puts "INFO: Launching Post-Synthesis Functional Simulation..."
launch_simulation -mode post-synthesis -type functional

puts "INFO: Running simulation..."
# This command runs the simulation until $finish is called
run -all

puts "INFO: Simulation complete."

# --- [MODIFIED] Print Captured Utilization Report ---

# Helper proc to parse and print a utilization line
# It finds the Used, Available, and Util% from a report line
proc print_util_line {name line_text} {
    # Tries to match: | <text> | <Used> | <Fixed> | <Available> | <Util%> |
    if {[regexp {\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d\.]+)\s*\|} $line_text match used available util]} {
        # Success! Print in the new format
        puts [format "%-25s %s / %s (%s%%)" "${name}:" $used $available $util]
    } else {
        # Fallback if parsing fails (e.g., line was empty)
        puts [format "%-25s Not Found" "${name}:"]
    }
}

puts "\n=================================================="
puts "INFO: Post-Synthesis Utilization Summary:"
puts "=================================================="

# Initialize variables
set lut_line ""
set reg_line ""
set dsp_line ""
set bram_line ""

# Loop through each line of the report to find our key lines
foreach line [split $util_report_string "\n"] {
    if { [string match "*| Slice LUTs*" $line] } {
        set lut_line $line
    }
    if { [string match "*| Slice Registers*" $line] } {
        set reg_line $line
    }
    if { [string match "*| Block RAM Tile*" $line] } {
        set bram_line $line
    }
    if { [string match "*| DSPs*" $line] && ![string match "*3. DSP*" $line] } {
        set dsp_line $line
    }
}

# Call our helper function for each line we found
print_util_line "Slice LUTs" $lut_line
print_util_line "Slice Registers (FF)" $reg_line
print_util_line "Block RAM (BRAM)" $bram_line
print_util_line "DSPs" $dsp_line

puts "=================================================="
puts "INFO: Full utilization report is saved in 'post_synth_utilization.rpt'"


# --- Conditional Cleanup ---
# This checks if the script is running in BATCH mode ($tcl_interactive == 0)
# If running from the GUI, $tcl_interactive will be 1, and this block is skipped.
if { !$tcl_interactive } {
    puts "INFO: Batch mode detected. Closing project and exiting."
    close_sim
    close_project
    exit
} else {
    puts "INFO: GUI mode detected. Leaving simulation and project open for review."
}
