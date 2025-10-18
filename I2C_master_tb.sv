`timescale 1ns / 1ps

module I2C_master_tb();
   
    logic clk;       
    logic clk_400;   
    logic rst_n;
    logic rw;
    logic start_txn;
    logic next_byte; //currently testing only for 1 byte of data
    logic [6:0] sub_addr;
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic data_ready;
    logic busy;
    logic done;
    logic ack_error;
    logic SCL;
    tri   SDA;
    logic [2:0] state_out;
    //logic [2:0 data_bit,addr_bit; //these are for debugging only
    //logic [7:0] data_reg, addr_reg; //these are for debugging only 
     
    pullup(SDA); //no subordinate right now to keep SDA HIGH when inactive 
     
    I2C_master DUT(
        .clk_400(clk_400),
        .rst_n(rst_n),
        .rw(rw),
        .start_txn(start_txn),
        .next_byte_1(next_byte),
        .sub_addr(sub_addr),
        .data_in(data_in),
        .data_out(data_out),
        .data_ready(data_ready),
        .busy(busy),
        .done(done),
        .ack_error(ack_error),
        .SCL(SCL),
        .SDA(SDA),
        .state_out(state_out)
        //.data_bit(data_bit),
        //.addr_bit(addr_bit),
        //.data_reg(data_reg),
        //.addr_reg(addr_reg)
    );
    
    slow_clock clkgen (
        .clk(clk),
        .rst_n(rst_n),
        .clk_400(clk_400)
    );
    
    initial clk = 0;
    always #5 clk = ~clk; 
    
    initial begin
        rst_n = 0;
        start_txn = 0;
        next_byte = 0;
        rw = 1;
        sub_addr = 0;
        data_in = 0;
        #200;
        rst_n = 1;
    end
    

    initial begin
        @(posedge rst_n);
        #100; //wait some cycles after reset
        
        rw = 0;
        next_byte = 0;
        sub_addr = 7'b0000001;
        data_in = 8'b10000001;
        
        start_txn = 1;
        next_byte = 1;
        repeat (2) @(posedge clk_400); //ensures that txn is asserted for a few clock cycles to get properly latched. 
        start_txn = 0;
            
        wait(done);
        $display ("Transaction Completed in %0t", $time);
        $finish;
    end


endmodule
