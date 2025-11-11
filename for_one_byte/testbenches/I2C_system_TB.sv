`timescale 1ns/1ps

module I2C_system_TB;

    parameter SUB1_ADDR   = 7'b0000001;
    parameter SUB2_ADDR   = 7'b0000011;

    logic clk;
    logic rst_n;
    logic start_txn;
    logic rw;
    logic [6:0] sub_addr;
    logic [7:0] master_data_in;
    logic [7:0] sub1_data_in = 8'h00; 
    logic [7:0] sub2_data_in = 8'h00;

    logic  clk_400; 

    //I2C main signals
    logic [7:0] master_data_out;
    logic [7:0] sub1_data_out;
    logic [7:0] sub2_data_out;
    logic master_data_ready;
    logic master_busy;
    logic master_done;
    logic sub1_data_ready;
    logic sub2_data_ready;

    //fifo signals
    logic sub2_fifo_read_en;
    logic sub1_fifo_read_en;
    logic master_fifo_read_en;
    logic sub2_fifo_empty;
    logic sub1_fifo_empty;
    logic master_fifo_empty;
    logic [7:0] sub1_fifo_data_out;
    logic [7:0] sub2_fifo_data_out;
    logic [7:0] master_fifo_data_out;

    //Debugg signals
    /*
    logic       scl_en,scl_reg;
    logic       master_ack_error;
    logic [3:0] master_state;
    logic [2:0] master_addr_bit;
    logic [2:0] master_data_bit;
    logic [7:0] master_addr_reg;
    logic [7:0] master_data_reg;
    logic       master_last_addr_bit;
    logic       master_last_data_bit;

    logic [7:0] sub1_data_reg;
    logic [7:0] sub1_addr_reg;
    logic [3:0] sub1_state;
    logic [2:0] sub1_addr_bit;
    logic [2:0] sub1_data_bit;
    logic sub1_busy;
    logic sub1_done;
    logic sub1_last_addr_bit_done;
    logic sub1_last_data_bit_done;
    logic sub1_SCL_d;
    logic sub1_scl_negedge;

    logic [7:0] sub2_data_reg;
    logic [7:0] sub2_addr_reg;
    logic [3:0] sub2_state;
    logic [2:0] sub2_addr_bit;
    logic [2:0] sub2_data_bit;
    logic sub2_busy;
    logic sub2_done;
    logic sub2_last_addr_bit_done;
    logic sub2_last_data_bit_done;
    logic sub2_SCL_d;
    
    logic  sub2_fifo_full;
    logic  sub1_fifo_full;
    logic  master_fifo_full;
    */

    tri SDA;
    tri SCL; 

    pullup(SDA);
    pullup(SCL);
    
    I2C_system dut (
        .clk (clk),
        .rst_n (rst_n),
        .clk_400 (clk_400), //Connect to the clk_400 of DUT, otherwise FIFO will have problems
        
        //Naster
        .SDA (SDA),
        .SCL (SCL),
        .start_txn (start_txn),
        .rw (rw),
        .sub_addr (sub_addr),
        .master_data_in (master_data_in),
        .master_data_out (master_data_out),
        .master_data_ready (master_data_ready),
        .master_busy (master_busy),
        .master_done (master_done),

        //Subordinate 1
        .sub1_data_in (sub1_data_in),
        .sub1_data_out (sub1_data_out),
        .sub1_data_ready (sub1_data_ready),

        //Subordinate 2
        .sub2_data_in (sub2_data_in),
        .sub2_data_out (sub2_data_out),
        .sub2_data_ready (sub2_data_ready),
        
        //FIFO
        .sub2_fifo_read_en (sub2_fifo_read_en),
        .sub1_fifo_read_en (sub1_fifo_read_en),
        .master_fifo_read_en (master_fifo_read_en),
        .sub2_fifo_empty (sub2_fifo_empty),
        .sub1_fifo_empty (sub1_fifo_empty),
        .master_fifo_empty (master_fifo_empty),
        .sub1_fifo_data_out (sub1_fifo_data_out),
        .sub2_fifo_data_out (sub2_fifo_data_out),
        .master_fifo_data_out (master_fifo_data_out)
        
        //Debugging ports
        /*
        // Master debug ports
	.scl_en(scl_en),  
        .scl_reg(scl_reg), 
        .master_ack_error (master_ack_error),
        .master_state (master_state),
        .master_addr_bit (master_addr_bit),
        .master_data_bit (master_data_bit),
        .master_addr_reg (master_addr_reg),
        .master_data_reg (master_data_reg),
        .master_last_addr_bit (master_last_addr_bit),
        .master_last_data_bit (master_last_data_bit),
        
        // Subordinate 1 debug ports
        .sub1_data_reg (sub1_data_reg),
        .sub1_data_bit (sub1_data_bit),
        .sub1_addr_reg (sub1_addr_reg),
        .sub1_addr_bit (sub1_addr_bit),
        .sub1_busy (sub1_busy),
        .sub1_done (sub1_done),
        .sub1_state (sub1_state),
        .sub1_last_addr_bit_done (sub1_last_addr_bit_done),
        .sub1_last_data_bit_done (sub1_last_data_bit_done),
        .sub1_SCL_d (sub1_SCL_d),
        .sub1_scl_negedge (sub1_scl_negedge),

        // Subordinate 2 debug ports
        .sub2_data_reg (sub2_data_reg),
        .sub2_data_bit (sub2_data_bit),
        .sub2_addr_reg (sub2_addr_reg),
        .sub2_addr_bit (sub2_addr_bit),
        .sub2_busy (sub2_busy),
        .sub2_done (sub2_done),
        .sub2_state (sub2_state),
        .sub2_last_addr_bit_done (sub2_last_addr_bit_done),
        .sub2_last_data_bit_done (sub2_last_data_bit_done),
        .sub2_SCL_d (sub2_SCL_d)
        
        // FIFO debug ports
        .sub2_fifo_full (sub2_fifo_full),
        .sub1_fifo_full (sub1_fifo_full),
        .master_fifo_full (master_fifo_full) */
        
    );

    always #5 clk = ~clk;
    
    //initialization
    initial 
    begin
        clk = 0;
        rst_n = 1;
        start_txn = 0;
        rw  = 0;
        sub_addr = 0;
        master_data_in = 0;
        sub1_data_in = 8'h00; 
        sub2_data_in = 8'h00;
        sub1_fifo_read_en = 0;
        sub2_fifo_read_en = 0;
        master_fifo_read_en = 0;
    end
    
    initial 
    begin
        #20;
        rst_n = 0; 
        #50;
        rst_n = 1; 
        
        //waiting for clk_400 to become stable after reset
        repeat (2) @(posedge clk_400);
        
        wait (sub1_fifo_empty & sub2_fifo_empty & master_fifo_empty);
        $display("TB: All FIFOs confirmed empty.");


        //write AA to subordinate 1
        rw = 0;
        sub_addr = SUB1_ADDR;
        master_data_in = 8'hAA;

        //start transaction
        start_txn = 1;
        wait (master_busy == 1);
        @(posedge clk);
        start_txn = 0;

        //this means master is done, and the data is almost ready.
        wait (master_done == 1);
        
        //wait for data to be written to FIFO
        wait (sub1_fifo_empty == 0);
        
        //one clk cycle delay so data in FIFO is stable
        @(posedge clk_400); 
         
        //popping the FIFO data
        sub1_fifo_read_en = 1;
        @(posedge clk_400); 
        sub1_fifo_read_en = 0; 
        
        wait (sub1_fifo_empty == 1); 
        #3000;

        //write BB to subordinate 2
        rw = 0;
        sub_addr = SUB2_ADDR;
        master_data_in = 8'hBB;

        start_txn = 1;
        wait (master_busy == 1);
        @(posedge clk);
        start_txn = 0;


        wait (master_done == 1);
        wait (sub2_fifo_empty == 0);
        
        @(posedge clk_400); 

        sub2_fifo_read_en = 1;
        @(posedge clk_400); 
        sub2_fifo_read_en = 0; 
        
        wait (sub2_fifo_empty == 1);
        #3000; 

        //Read CC from subordinate 1
        rw = 1;
        sub_addr = SUB1_ADDR;
        sub1_data_in = 8'hCC;

        start_txn <= 1;
        wait (master_busy == 1);
        @(posedge clk);
        start_txn <= 0;

        wait (master_done == 1);
        wait (master_fifo_empty == 0);
        
        @(posedge clk_400);
        
        master_fifo_read_en = 1;
        @(posedge clk_400); 
        master_fifo_read_en = 0; 
        
        wait (master_fifo_empty == 1);
        #3000;

        //Read DD from subordinate 2
        rw = 1;
        sub_addr = SUB2_ADDR;
        sub2_data_in = 8'hDD; 
        
        @(posedge clk); 

        start_txn = 1;
        wait (master_busy == 1);
        @(posedge clk);
        start_txn = 0;

        wait (master_done == 1);
        wait (master_fifo_empty == 0);
        
        @(posedge clk_400); 
        
        master_fifo_read_en = 1;
        @(posedge clk_400); 
        master_fifo_read_en = 0; 
        
        wait (master_fifo_empty == 1);
        #3000; 

        $finish;
    end

endmodule

