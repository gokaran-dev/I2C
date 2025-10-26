`timescale 1ns/1ps

module I2C_system(
    input  logic       clk,
    input  logic       rst_n,

    // --- SCL and SDA are now top-level ports ---
    inout  tri         SDA,
    inout  tri         SCL, // Changed from wire to tri for potential multi-master/clock stretching (though not used here)

    // Master control interface
    input  logic       start_txn,
    input  logic       rw,
    input  logic [6:0] sub_addr,
    input  logic [7:0] master_data_in,
    output logic [7:0] master_data_out,
    output logic       master_data_ready,
    output logic       master_busy,
    output logic       master_done,
    output logic       master_ack_error,

    // Debug/monitor ports for observation (optional)
    output logic [3:0] master_state,
    output logic [2:0] master_addr_bit,
    output logic [2:0] master_data_bit,
    output logic [7:0] master_addr_reg,
    output logic [7:0] master_data_reg,
    output logic       master_last_addr_bit,
    output logic       master_last_data_bit,

    // Subordinate 1 data interface
    input  logic [7:0] sub1_data_in,
    output logic [7:0] sub1_data_out,
    output logic [7:0] sub1_data_reg, // Exposed internal reg for TB verification
    output logic [7:0] sub1_addr_reg, // Exposed internal reg for TB verification
    output logic       sub1_data_ready,
    output logic       sub1_busy,
    output logic       sub1_done,
    output logic [3:0] sub1_state,
    output logic [2:0] sub1_data_bit,
    output logic [2:0] sub1_addr_bit,
    output logic sub1_last_addr_bit_done,
    output logic sub1_last_data_bit_done,

    // Subordinate 2 data interface
    input  logic [7:0] sub2_data_in,
    output logic [7:0] sub2_data_out,
    output logic [7:0] sub2_data_reg, // Exposed internal reg for TB verification
    output logic [7:0] sub2_addr_reg, // Exposed internal reg for TB verification
    output logic       sub2_data_ready,
    output logic       sub2_busy,
    output logic       sub2_done,
    output logic [3:0] sub2_state,
    output logic [2:0] sub2_data_bit,
    output logic [2:0] sub2_addr_bit,
    output logic sub2_last_addr_bit_done,
    output logic sub2_last_data_bit_done
);
    
    // Internal 400kHz clock for I2C logic
    logic clk_400;
    
    // Instantiate clock divider
    slow_clock clk_gen (
        .clk(clk),
        .rst_n(rst_n),
        .clk_400(clk_400)
    );
        
    // Instantiate I2C Master (Single-Byte Version)
    I2C_master master_inst (
        .clk_400         (clk_400),
        .rst_n           (rst_n),
        .rw              (rw),
        .start_txn       (start_txn),
        //.next_byte_1     (1'b0), // **FIX: Tie off unused input**
        .sub_addr        (sub_addr),
        .data_in         (master_data_in),
        .data_out        (master_data_out),
        .data_ready      (master_data_ready),
        .busy            (master_busy),
        .done            (master_done),
        .ack_error       (master_ack_error),
        .SCL             (SCL), // Connect directly to top-level SCL
        .state_out       (master_state),
        .data_bit        (master_data_bit),
        .addr_bit        (master_addr_bit),
        .addr_reg        (master_addr_reg),
        .data_reg        (master_data_reg),
        .last_addr_bit   (master_last_addr_bit),
        .last_data_bit   (master_last_data_bit),
        .SDA             (SDA) // Connect directly to top-level SDA
    );

    // Instantiate I2C Subordinate 1 (Single-Byte Version)
    I2C_subordinate #(.my_addr(7'b0000001)) sub1_inst(
        .clk_400         (clk_400),
        .rst_n           (rst_n),
        .SCL             (SCL),
        .SDA             (SDA),
        .addr            (8'b0), // **FIX: Tie off unused input**
        .data_in         (sub1_data_in), // Used only when master reads
        .data_out        (sub1_data_out),// Holds received data after ACK
        .data_ready      (sub1_data_ready),
        .done            (sub1_done),
        .busy            (sub1_busy),
        .data_reg        (sub1_data_reg), // Connect internal reg for TB
        .addr_reg        (sub1_addr_reg), // Connect internal reg for TB
        .state_out       (sub1_state),
       // .next_byte_1     (1'b0), // **FIX: Tie off unused input**
        // Unconnected internal/debug ports:
        .addr_bit        (sub1_addr_bit), 
        .data_bit        (sub1_data_bit), 
        .ack_error       (),
        .SCL_d           (),
        .scl_posedge     (),
        .scl_negedge     (),
        .rw              (),
        //.next_byte       (), // Internal signal tied off inside module
        .last_data_bit_done(sub1_last_data_bit_done),
        .last_addr_bit_done(sub1_last_addr_bit_done),
        .addr_match      ()
    );

    // Instantiate I2C Subordinate 2 (Single-Byte Version)
    I2C_subordinate #(.my_addr(7'b0000011)) sub2_inst (
        .clk_400         (clk_400),
        .rst_n           (rst_n),
        .SCL             (SCL),
        .SDA             (SDA),
        .addr            (8'b0), // **FIX: Tie off unused input**
        .data_in         (sub2_data_in),
        .data_out        (sub2_data_out),
        .data_ready      (sub2_data_ready),
        .done            (sub2_done),
        .busy            (sub2_busy),
        .data_reg        (sub2_data_reg), // Connect internal reg for TB
        .addr_reg        (sub2_addr_reg), // Connect internal reg for TB
        .state_out       (sub2_state),
        //.next_byte_1     (1'b0), // **FIX: Tie off unused input**
        // Unconnected internal/debug ports:
        .addr_bit       (sub2_addr_bit), 
        .data_bit       (sub2_data_bit), 
        .ack_error       (),
        .SCL_d           (),
        .scl_posedge     (),
        .scl_negedge     (),
        .rw              (),
        //.next_byte       (), // Internal signal tied off inside module
        .last_data_bit_done(sub2_last_data_bit_done),
        .last_addr_bit_done(sub2_last_addr_bit_done),
        .addr_match      ()
    );

endmodule
