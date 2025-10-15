`timescale 1ns/1ps

module slow_clock_tb ();
    logic clk,rst_n,clk_400,clk_10;
    
    slow_clock DUT (
        .clk(clk),
        .rst_n(rst_n),
        .clk_400(clk_400),
        .clk_10(clk_10)
    );
    
    //signal initialization
    initial 
    begin
        clk = 0;
        rst_n = 1;
    end

    //clock generation
    always #5 clk = ~clk;
    
    //stimulus
    initial 
    begin
        #110 rst_n = 0; #30 rst_n = 1;
        
        #20000 $finish;        
    end
endmodule