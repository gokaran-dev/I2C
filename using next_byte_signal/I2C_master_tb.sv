`timescale 1ns / 1ps

module I2C_master_tb();
    
    logic clk;        
    logic clk_400;    
    logic rst_n;
    logic rw;
    logic start_txn;
    logic next_byte;
    logic [6:0] sub_addr;
    logic [7:0] data_in;
    
    logic [7:0] data_out;
    logic data_ready;
    logic busy;
    logic done;
    logic ack_error;
    logic SCL;
    tri   SDA;

    logic [3:0] state_out;
    logic [2:0] data_bit, addr_bit;
    logic [7:0] data_reg, addr_reg;
    logic last_addr_bit, last_data_bit;

    //to mimic the behaviour of a subordinate
    logic [7:0] received_addr_byte_tb;
    logic [7:0] internal_storage_tb; //subordinate's internal register
    logic [7:0] data_to_send_tb;     //data subordinate will send to master
    logic       address_match;
    logic [2:0] sub_bit_count;
    logic       sda_oe_tb;
    logic       sda_out_tb;
    logic       bit_to_send;

    pullup(SDA); //to model the pull up behaviour on SDA.
    

    assign SDA = sda_oe_tb ? sda_out_tb : 1'bz;

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
        .state_out(state_out),
        .data_bit(data_bit),
        .addr_bit(addr_bit),
        .data_reg(data_reg),
        .addr_reg(addr_reg),
        .last_data_bit(last_data_bit),
        .last_addr_bit(last_addr_bit)
    );
    

    initial
    begin
         clk = 0;
         clk_400 = 0;
    end
    
    //clocks for DUT and a 400KHz clock for subordinate.
    always #5 clk = ~clk; 
    always #1250 clk_400 = ~clk_400; 
    
 

    //RX_ADDRESS
    always @(posedge SCL or negedge rst_n) 
    begin
        if (!rst_n) 
            received_addr_byte_tb <= 8'h00;
        else 
        begin
            if (state_out == 4'd2) //if we are in the sending address state
                received_addr_byte_tb <= {received_addr_byte_tb[6:0], SDA};
        end
    end
    
    assign address_match = (received_addr_byte_tb[7:1] == sub_addr);

    //RX_DATA
    always @(posedge SCL or negedge rst_n) 
    begin
        if (!rst_n) 
            internal_storage_tb <= 8'h00;
        else 
        begin
            if (state_out == 4'd4) //when we are in the send data state
                internal_storage_tb <= {internal_storage_tb[6:0], SDA};
        end
    end

    //TX_DATA (Subordinate sends data to master)
    always @(negedge SCL or negedge rst_n)
    begin
        if (!rst_n) begin
            sub_bit_count <= 7;
        end else begin
            if (state_out == 4'd3 && address_match && rw == 1) begin 
                sub_bit_count <= 7;
            end else if (state_out == 4'd6) begin 
                bit_to_send <= data_to_send_tb[sub_bit_count];
                sub_bit_count <= sub_bit_count - 1;
            end
        end
    end

    //Subordinate Output Driver Logic
    always_comb
    begin
        sda_oe_tb = 1'b0;
        sda_out_tb = 1'bz;

        if (state_out == 4'd3 && address_match) begin //ACK the address
            sda_oe_tb = 1'b1;
            sda_out_tb = 1'b0;
        end else if (state_out == 4'd5) begin //ACK data received from master
             sda_oe_tb = 1'b1;
             sda_out_tb = 1'b0;
        end else if (state_out == 4'd6) begin //Send data bit to master
            sda_oe_tb = 1'b1;
            sda_out_tb = bit_to_send;
        end
    end

    
    initial begin
        $display("Starting I2C Master Write-then-Read System Test");
        rst_n = 1; start_txn = 0; next_byte = 0; rw = 0; sub_addr = 0; data_in = 0; clk_400 = 1;

        #100; rst_n = 0; #2500; rst_n = 1; #5000;

        //master writing to subordinate

        rw = 0;
        next_byte = 0; 
        sub_addr = 7'h01;
        data_in = 8'hAB;
        
        start_txn = 1; @(posedge clk_400); start_txn = 0;
        wait(done);
        #5000;
        $display("[%0t] Write transaction finished. Subordinate internal data is now: 0x%h", $time, internal_storage_tb);
        
        if (ack_error) begin
            $display("TEST FAILED! Write error. ACK Error detected.");
            $finish;
        end
        
        #20000;

        //master reading from subordinate
        $display("[%0t] READ PHASE: Master reading from address 0x01", $time);
        rw = 1;
        next_byte = 0; 
        sub_addr = 7'h01;
        data_to_send_tb = 8'hC3; 
        
        start_txn = 1; @(posedge clk_400); start_txn = 0;
        wait(done);
        #5000;
        $display("[%0t] Read transaction finished.", $time);
        

        if (ack_error == 0 && done == 1 && (internal_storage_tb == data_in) && (data_out == data_to_send_tb)) 
            $display("TEST PASSED: Master wrote 0x%h and correctly read back 0x%h.", data_in, data_out);
        else begin
            $display("TEST FAILED! ack_error=%b, done=%b", ack_error, done);           
            if (internal_storage_tb != data_in)
                $display(" WRITE MISMATCH! Expected subordinate to store 0x%h, but it stored 0x%h", data_in, internal_storage_tb);
            if (data_out != data_to_send_tb)
                $display("READ MISMATCH! Expected master to receive 0x%h, but it received 0x%h", data_to_send_tb, data_out);
        end
        
        #5000;
        $finish;
    end
    
endmodule

