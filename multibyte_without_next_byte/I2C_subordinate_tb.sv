`timescale 1ns / 1ps

// Testbench for the I2C_subordinate, using the I2C_master as a driver.
module I2C_subordinate_tb;

    // --- Signals ---
    logic clk;
    logic clk_400;
    logic rst_n;
    
    // --- I2C Bus ---
    logic SCL;
    tri   SDA;

    // --- Master Interface Signals (to drive the master) ---
    logic       master_rw;
    logic       master_start_txn;
    logic       master_next_byte;
    logic [6:0] master_sub_addr;
    logic [7:0] master_data_in; // Data for the master to write
    logic [7:0] master_data_out; // Data the master reads back
    logic       master_done;
    logic       master_ack_error;

    // --- Subordinate Interface Signals (to test the subordinate) ---
    logic [7:0] sub_data_to_send;  // Data for the subordinate to send on a read
    logic [7:0] sub_data_received; // Data the subordinate has received on a write
    logic       sub_data_is_ready;
    logic       sub_rw;

    // --- DEBUG SIGNALS ---
    logic [3:0] master_state_out;
    logic [7:0] master_data_reg,master_addr_reg;
    logic [3:0] sub_state_out;
    logic [7:0] sub_data_reg,sub_addr_reg;
    logic [2:0] master_addr_bit, master_data_bit;
    logic [2:0] sub_addr_bit;
    logic [2:0] sub_data_bit;
    logic sub_addr_match;
    logic sub_scl_posedge, sub_scl_negedge;
    logic sub_last_data_bit_done, sub_last_addr_bit_done;
    logic scl_d;
    logic sub_next_byte;


    // --- Instantiations ---

    pullup(SDA);

    // Instantiate the I2C_master to act as the bus driver
    I2C_master master_driver (
        .clk_400(clk_400),
        .rst_n(rst_n),
        .rw(master_rw),
        .start_txn(master_start_txn),
        .next_byte_1(master_next_byte),
        .sub_addr(master_sub_addr),
        .data_in(master_data_in),
        .data_out(master_data_out),
        .SCL(SCL),
        .SDA(SDA),
        .done(master_done),
        .ack_error(master_ack_error),
        // Connect debug ports
        .state_out(master_state_out),
        .data_reg(master_data_reg),
        .addr_reg(master_addr_reg),
        .data_bit(master_data_bit),
        .addr_bit(master_addr_bit)
    );

    // Instantiate the I2C_subordinate (the DUT)
    I2C_subordinate dut (
        .clk_400(clk_400),
        .rst_n(rst_n),
        .SCL(SCL),
        .SDA(SDA),
        .data_in(sub_data_to_send),
        .data_out(sub_data_received),
        .next_byte_1(master_next_byte),
        .data_ready(sub_data_is_ready),
        .rw(sub_rw),
        // Connect debug ports
        .state_out(sub_state_out),
        .data_reg(sub_data_reg),
        .addr_reg(sub_addr_reg),
        .data_bit(sub_data_bit),
        .addr_bit(sub_addr_bit),
        .addr_match(sub_addr_match),
        .scl_posedge(sub_scl_posedge),
        .scl_negedge(sub_scl_negedge),
        .last_addr_bit_done(sub_last_addr_bit_done),
        .last_data_bit_done(sub_last_data_bit_done),
        .SCL_d(scl_d),
        .next_byte(sub_next_byte)
    );

    // --- Clock Generation ---
    initial begin
        clk = 0;
        clk_400 = 0;
    end
    always #5 clk = ~clk;
    always #1250 clk_400 = ~clk_400;

    // --- Test Sequence ---
    initial begin
        $display("Starting I2C Subordinate Test (Write then Read)");

        // --- Initialization ---
        rst_n = 1'b1;
        master_start_txn = 1'b0;
        master_next_byte = 1'b0;
        master_rw = 1'b0;
        master_sub_addr = 7'h0;
        master_data_in = 8'h0;
        sub_data_to_send = 8'h0;

        // --- Reset ---
        #100;
        rst_n = 1'b0;
        #2500;
        rst_n = 1'b1;
        #5000;

        // --- PART 1: Master WRITE to Subordinate ---
        $display("[%0t] WRITE PHASE: Testing subordinate's receive logic.", $time);
        master_rw = 1'b0;
        master_next_byte = 1'b1;
        master_sub_addr = 7'h01;
        master_data_in = 8'hAB; // Master will send this data

        master_start_txn = 1'b1;
        @(posedge clk_400);
        master_start_txn = 1'b0;

        wait(master_done);
        #5000;
        
        // Verification for write phase
        if (master_ack_error) begin
            $display("--> TEST FAILED: Master reported ACK error during WRITE.");
            $finish;
        end
        if (sub_data_received !== 8'hAB) begin
            $display("--> TEST FAILED: Subordinate received 0x%h, expected 0xAB.", sub_data_received);
            $finish;
        end
        $display("Write phase successful. Subordinate correctly received 0x%h.", sub_data_received);

        #20000; // Delay between transactions

        // --- PART 2: Master READ from Subordinate ---
        $display("[%0t] READ PHASE: Testing subordinate's send logic.", $time);
        master_rw = 1'b1;
        master_next_byte = 1'b1;
        master_sub_addr = 7'h01;
        sub_data_to_send = 8'hC3; // Configure subordinate to send this data

        master_start_txn = 1'b1;
        @(posedge clk_400);
        master_start_txn = 1'b0;

        wait(master_done);
        #5000;

        // --- Final Verification ---
        if (master_ack_error == 0 && master_done == 1 && master_data_out == 8'hC3) begin
            $display("--> TEST PASSED: Subordinate correctly sent 0x%h to the master.", master_data_out);
        end else begin
            $display("--> TEST FAILED: ack_error=%b, done=%b", master_ack_error, master_done);
            if (master_data_out !== 8'hC3) begin
                $display("    --> DATA MISMATCH: Master received 0x%h, expected 0xC3.", master_data_out);
            end
        end

        #5000;
        $finish;
    end

    // --- Monitor for Debugging ---
    initial begin
        $monitor("[%0t ns] SCL=%b, SDA=%b | M_State: %d, M_DataReg: %h | S_State: %d, S_DataReg: %h",
                  $time, SCL, SDA, 
                  master_state_out, master_data_reg,
                  sub_state_out, sub_data_reg);
    end

endmodule
