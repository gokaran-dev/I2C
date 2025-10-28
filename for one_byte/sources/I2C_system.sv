`timescale 1ns/1ps

module I2C_system(
    input  logic clk,
    input  logic rst_n,   
    //output logic       clk_400, //use this pin to get clk_400 in TB

    inout  tri SDA,
    inout  tri SCL, 

    //Master
    input  logic start_txn,
    input  logic rw,
    output logic master_data_ready,
    //output logic master_busy, //Should be exposed for TB Verification 
    //output logic master_done, //Should be exposed for TB Verification 
    input  logic [6:0] sub_addr,
    input  logic [7:0] master_data_in,
    output logic [7:0] master_data_out,
    
    /*output logic       master_ack_error,
    output logic [3:0] master_state,
    output logic [2:0] master_addr_bit,
    output logic [2:0] master_data_bit,
    output logic [7:0] master_addr_reg,
    output logic [7:0] master_data_reg,
    output logic master_last_addr_bit,
    output logic master_last_data_bit,*/

    //Subordinate 1
    input  logic [7:0] sub1_data_in,
    output logic [7:0] sub1_data_out,
    output logic sub1_data_ready,
    
    /*output logic [7:0] sub1_data_reg,
    output logic [7:0] sub1_addr_reg,
    output logic [3:0] sub1_state,
    output logic [2:0] sub1_data_bit,
    output logic [2:0] sub1_addr_bit,
    output logic sub1_last_addr_bit_done,
    output logic sub1_last_data_bit_done,
    output logic sub1_scl_negedge,
    output logic sub1_busy,
    output logic sub1_done,*/

    // Subordinate 2
    input  logic [7:0] sub2_data_in,
    output logic [7:0] sub2_data_out,
    output logic       sub2_data_ready,
    
    /*output logic [7:0] sub2_data_reg,
    output logic [7:0] sub2_addr_reg,
    output logic [3:0] sub2_state,
    output logic [2:0] sub2_data_bit,
    output logic [2:0] sub2_addr_bit,
    output logic sub2_busy,
    output logic sub2_done,
    output logic sub2_last_addr_bit_done,
    output logic sub2_last_data_bit_done,
    output logic sub2_SCL_d,
    output logic sub1_SCL_d,*/
    
    //fifo
    input logic sub2_fifo_read_en,
    input logic sub1_fifo_read_en,
    input logic master_fifo_read_en,
    output logic sub2_fifo_empty,
    output logic sub1_fifo_empty,
    output logic master_fifo_empty,        
    output logic [7:0] sub1_fifo_data_out,
    output logic [7:0] sub2_fifo_data_out,
    output logic [7:0] master_fifo_data_out
    
    /*output logic sub2_fifo_full,
    output logic sub1_fifo_full,
    output logic master_fifo_full,*/
    
);
    
    logic clk_400; 
    //debug signals should be enabled in I2C_Master and I2C_subordinate modules
    
    //Master debug signals
    
  /*logic master_busy;
    logic master_done;
    logic master_ack_error;
    logic master_last_addr_bit;
    logic master_last_data_bit;
    logic [3:0] master_state;
    logic [2:0] master_addr_bit;
    logic [2:0] master_data_bit;
    logic [7:0] master_addr_reg;
    logic [7:0] master_data_reg;

    //Subordinate 1 debug signals
    logic [7:0] sub1_data_reg;
    logic [7:0] sub1_addr_reg;
    logic [3:0] sub1_state;
    logic [2:0] sub1_data_bit;
    logic [2:0] sub1_addr_bit;
    logic sub1_last_addr_bit_done;
    logic sub1_last_data_bit_done;
    logic sub1_scl_negedge;
    logic sub1_SCL_d;
    logic sub1_busy;
    logic sub1_done;

    //Subordinate 2 debug signals
    logic [7:0] sub2_data_reg;
    logic [7:0] sub2_addr_reg;
    logic [3:0] sub2_state;
    logic [2:0] sub2_data_bit;
    logic [2:0] sub2_addr_bit;
    logic sub2_last_addr_bit_done;
    logic sub2_last_data_bit_done;
    logic sub2_SCL_d;
    logic sub2_busy;
    logic sub2_done;

    // FIFO debug signals
    logic sub2_fifo_full;
    logic sub1_fifo_full;
    logic master_fifo_full;*/
    
    slow_clock clk_gen (
        .clk(clk),
        .rst_n(rst_n),
        .clk_400(clk_400)
    );
        
    I2C_master master(
        .clk_400 (clk_400),
        .rst_n (rst_n),
        .rw (rw),
        .start_txn (start_txn),
        .sub_addr (sub_addr),
        .data_in (master_data_in),
        .data_out (master_data_out),
        .data_ready (master_data_ready),
        .busy (master_busy),
        .done (master_done),
        .SDA (SDA),
        .SCL (SCL)
        
        //debugging signals 
      /*.state_out (master_state),
        .data_bit (master_data_bit),
        .addr_bit (master_addr_bit),
        .addr_reg (master_addr_reg),
        .data_reg (master_data_reg),
        .last_addr_bit (master_last_addr_bit),
        .last_data_bit (master_last_data_bit),
        .ack_error (master_ack_error)*/

    );
           
    Sync_FIFO master_FIFO(
        .clk(clk_400),
        .rst_n(rst_n),
        .write_en(master_data_ready),
        .read_en(master_fifo_read_en),
        .data_in(master_data_out),
        .data_out(master_fifo_data_out),
        .fifo_empty(master_fifo_empty)
        
        //.fifo_full(master_fifo_full)
    );

    
    I2C_subordinate #(.my_addr(7'b0000001)) sub1(
        .clk_400 (clk_400),
        .rst_n (rst_n),
        .SCL (SCL),
        .SDA (SDA),
        .data_in (sub1_data_in), 
        .data_out (sub1_data_out),
        .data_ready (sub1_data_ready)
        
        //debugging signals 
       /*.done (sub1_done),
        .busy (sub1_busy),
        .data_reg (sub1_data_reg), 
        .addr_reg (sub1_addr_reg), 
        .state_out(sub1_state),
        .addr_bit (sub1_addr_bit), 
        .data_bit (sub1_data_bit), 
        .ack_error(),
        .SCL_d (sub1_SCL_d),
        .scl_posedge (),
        .scl_negedge (sub1_scl_negedge),
        .rw (),
        .last_data_bit_done(sub1_last_data_bit_done),
        .last_addr_bit_done(sub1_last_addr_bit_done),
        .addr_match ()*/
    );
    
    Sync_FIFO sub1_FIFO(
        .clk(clk_400),
        .rst_n(rst_n),
        .write_en(sub1_data_ready),
        .read_en(sub1_fifo_read_en),
        .data_in(sub1_data_out),
        .data_out(sub1_fifo_data_out),
        .fifo_empty(sub1_fifo_empty)
        
        //.fifo_full(sub1_fifo_full)
    );


    I2C_subordinate #(.my_addr(7'b0000011)) sub2(
        .clk_400 (clk_400),
        .rst_n (rst_n),
        .SCL (SCL),
        .SDA (SDA),
        .data_in (sub2_data_in),
        .data_out (sub2_data_out),
        .data_ready (sub2_data_ready)
        
        //debugging signals
       /*.done (sub2_done),
        .busy (sub2_busy),
        .data_reg (sub2_data_reg), 
        .addr_reg (sub2_addr_reg), 
        .state_out (sub2_state),
        .addr_bit (sub2_addr_bit), 
        .data_bit (sub2_data_bit), 
        .ack_error (),
        .SCL_d (sub2_SCL_d),
        .scl_posedge (),
        .scl_negedge (),
        .rw (),
        .last_data_bit_done(sub2_last_data_bit_done),
        .last_addr_bit_done(sub2_last_addr_bit_done),
        .addr_match ()*/
    );
    
    Sync_FIFO sub2_FIFO (
        .clk(clk_400),
        .rst_n(rst_n),
        .write_en(sub2_data_ready),
        .read_en(sub2_fifo_read_en),
        .data_in(sub2_data_out),
        .data_out(sub2_fifo_data_out),
        .fifo_empty(sub2_fifo_empty)
        
        //.fifo_full(sub2_fifo_full)
    );

endmodule