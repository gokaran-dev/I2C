`timescale 1ns/1ps

module I2C_system_TB;

    // --- Parameters ---
    parameter SUB1_ADDR   = 7'b0000001;
    parameter SUB2_ADDR   = 7'b0000011;

    // --- Testbench Signals ---
    logic clk;
    logic rst_n;
    logic start_txn;
    logic rw;
    logic [6:0] sub_addr;
    logic [7:0] master_data_in;
    logic [7:0] sub1_data_in = 8'h00;
    logic [7:0] sub2_data_in = 8'h00;

    // DUT outputs
    wire [7:0] master_data_out;
    wire       master_data_ready;
    wire       master_busy;
    wire       master_done;
    wire       master_ack_error;
    wire [3:0] master_state;
    wire [2:0] master_addr_bit;
    wire [2:0] master_data_bit;
    wire [7:0] master_addr_reg;
    wire [7:0] master_data_reg;
    wire       master_last_addr_bit;
    wire       master_last_data_bit;

    // Sub1 outputs
    wire [7:0] sub1_data_out;
    wire [7:0] sub1_data_reg;
    wire [7:0] sub1_addr_reg;
    wire       sub1_data_ready;
    wire       sub1_busy;
    wire       sub1_done;
    wire [3:0] sub1_state;
    wire [2:0] sub1_addr_bit;
    wire [2:0] sub1_data_bit;
    wire sub1_last_addr_bit_done;
    wire sub1_last_data_bit_done;

    // Sub2 outputs
    wire [7:0] sub2_data_out;
    wire [7:0] sub2_data_reg;
    wire [7:0] sub2_addr_reg;
    wire       sub2_data_ready;
    wire       sub2_busy;
    wire       sub2_done;
    wire [3:0] sub2_state;
    wire [2:0] sub2_addr_bit;
    wire [2:0] sub2_data_bit;
    wire sub2_last_addr_bit_done;
    wire sub2_last_data_bit_done;

    // External I2C bus lines
    tri SDA;
    tri SCL;

    // Pull-ups for I2C open-drain lines
    pullup(SDA);
    //pullup(SCL);

    // Instantiate the DUT
    I2C_system dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .SDA                (SDA),
        .SCL                (SCL),

        // Master
        .start_txn          (start_txn),
        .rw                 (rw),
        .sub_addr           (sub_addr),
        .master_data_in     (master_data_in),
        .master_data_out    (master_data_out),
        .master_data_ready  (master_data_ready),
        .master_busy        (master_busy),
        .master_done        (master_done),
        .master_ack_error   (master_ack_error),
        .master_state       (master_state),
        .master_addr_bit    (master_addr_bit),
        .master_data_bit    (master_data_bit),
        .master_addr_reg    (master_addr_reg),
        .master_data_reg    (master_data_reg),
        .master_last_addr_bit(master_last_addr_bit),
        .master_last_data_bit(master_last_data_bit),

        // Subordinate 1
        .sub1_data_in       (sub1_data_in),
        .sub1_data_out      (sub1_data_out),
        .sub1_data_reg      (sub1_data_reg),
        .sub1_data_bit      (sub1_data_bit),
        .sub1_addr_reg      (sub1_addr_reg),
        .sub1_addr_bit      (sub1_addr_bit),
        .sub1_data_ready    (sub1_data_ready),
        .sub1_busy          (sub1_busy),
        .sub1_done          (sub1_done),
        .sub1_state         (sub1_state),
        .sub1_last_addr_bit_done(sub1_last_addr_bit_done),
        .sub1_last_data_bit_done(sub1_last_data_bit_done),

        // Subordinate 2
        .sub2_data_in       (sub2_data_in),
        .sub2_data_out      (sub2_data_out),
        .sub2_data_reg      (sub2_data_reg),
        .sub2_data_bit      (sub2_data_bit),
        .sub2_addr_reg      (sub2_addr_reg),
        .sub2_addr_bit      (sub2_addr_bit),
        .sub2_data_ready    (sub2_data_ready),
        .sub2_busy          (sub2_busy),
        .sub2_done          (sub2_done),
        .sub2_state         (sub2_state),
        .sub2_last_addr_bit_done(sub2_last_addr_bit_done),
        .sub2_last_data_bit_done(sub2_last_data_bit_done)
    );

    // --- 100 MHz Clock Generation ---
    always #5 clk = ~clk;

// --- Test Sequence ---
    initial begin
        // --- DUMPING & INITIALIZATION ---

        clk = 0;
        rst_n = 1;
        start_txn = 0;
        rw = 0;
        sub_addr = 0;
        master_data_in = 0;
        
        // --- RESET SEQUENCE ---
        #20;
        rst_n = 0; // Assert reset
        #50;
        rst_n = 1; // Release reset
        #50;
        $display("TB: Reset complete.");

        // === Write 0xAA to Subordinate 1 ===
        $display("TB: Starting write of 0xAA to Subordinate 1 (Addr: %h)", SUB1_ADDR);
        rw <= 0;
        sub_addr <= SUB1_ADDR;
        master_data_in <= 8'hAA;
        
        start_txn <= 1;
        wait (master_busy == 1); // Wait for master to start
        @(posedge clk);
        start_txn <= 0;
        
        // Wait for Sub1 to signal it has the data
        @(posedge sub1_data_ready);
        // Wait one more clock for the data to be latched to the 'data_out' register
        @(posedge clk); 
        $display("TB: Sub1 data is ready.");

        if (sub1_data_out == 8'hAA)
            $display("TB: SUCCESS - Sub1 received: %h", sub1_data_out);
        else
            $display("TB: FAILURE - Sub1 received: %h, Expected: %h", sub1_data_out, 8'hAA);

        // **FIX: REMOVED the first wait for master_done**
        // @(posedge master_done); 
        
        #200; // Delay between transactions

        // === Write 0xBB to Subordinate 2 ===
        $display("TB: Starting write of 0xBB to Subordinate 2 (Addr: %h)", SUB2_ADDR);
        rw <= 0;
        sub_addr <= SUB2_ADDR;
        master_data_in <= 8'hBB;
        
        start_txn <= 1;
        wait (master_busy == 1);
        @(posedge clk);
        start_txn <= 0;

        // Wait for Sub2 to signal it has the data
        @(posedge sub2_data_ready);
        // Wait one more clock for the data to be latched to the 'data_out' register
        @(posedge clk); 
        $display("TB: Sub2 data is ready.");

        if (sub2_data_out == 8'hBB)
            $display("TB: SUCCESS - Sub2 received: %h", sub2_data_out);
        else
            $display("TB: FAILURE - Sub2 received: %h, Expected: %h", sub2_data_out, 8'hBB);
        
        // Wait for the master to *fully* finish the second transaction
        @(posedge master_done);
        $display("TB: All tests complete.");
        $finish;
    end
endmodule