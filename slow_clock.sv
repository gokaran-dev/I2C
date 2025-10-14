//generating exact 400 Khz of clock which is to be used in I2C_master and I2C_subordinate

`timescale 1ns / 1ps

module slow_clock(
        input  logic clk,
        input  logic rst_n,
        output logic clk_400
    );
    
    logic clk_10; //clock working at 10.4MHz
    logic locked;
    logic rst_n_pll;
    logic [4:0] count;
    
      clk_wiz_0 clock_PLL(
            .clk_out1(clk_10), 
            .resetn(rst_n), 
            .locked(locked),   //clock is safely latched when locked is HIGH
            .clk_in1(clk)     
        );
        
        //assign rst_n_pll = rst_n & locked;
        assign rst_n_pll = rst_n & locked;
        
        always_ff @(posedge clk_10)
        begin
            if (!rst_n_pll)
            begin
                count <= 0;
                clk_400 <= 0;
            end
            
            else
                count <= count + 1;
            
            if (count == 12)
            begin
                clk_400 <= ~clk_400;
                count <= 0;
            end
        end          
endmodule

