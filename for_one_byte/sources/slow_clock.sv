//generating exact 400 Khz of clock which is to be used in I2C_master and I2C_subordinate

`timescale 1ns / 1ps

module slow_clock(
        input  logic clk,
        input  logic rst_n,
        output logic clk_400
    );
    
    logic rst_n_pll;
    logic [7:0] count;
      
      
        always_ff @(posedge clk)
        begin
            if (!rst_n)
            begin
                count <= 0;
                clk_400 <= 0;
            end
            
            else
                count <= count + 1;
            
            if (count == 124)
            begin
                clk_400 <= ~clk_400;
                count <= 0;
            end
        end          
endmodule

