`timescale 1ns/1ps

module I2C_subordinate (
        input logic clk_400,
        input logic rst_n,
        input logic SCL,
        input logic next_byte_1,
        inout tri   SDA,
        
        input  logic [7:0] addr,
        input  logic [7:0] data_in,
        output logic [7:0] data_out,
        output logic data_ready,
        output logic done,
        output logic busy,
        output logic [2:0] addr_bit, 
        output logic [2:0] data_bit, 
        output logic [3:0] state_out,
        output logic [7:0] addr_reg, 
        output logic [7:0] data_reg,
        output logic ack_error,
        output logic SCL_d,
        output logic scl_posedge,
        output logic scl_negedge,
        output logic rw,
        output logic next_byte,
        output logic last_data_bit_done, 
        output logic last_addr_bit_done,
        output logic addr_match
    );

    typedef enum logic [3:0] {
            IDLE,
            START,
            ADDR_RX,
            ADDR_ACK,
            RECEIVE_DATA,
            SEND_DATA,
            SEND_DATA_ACK,
            WAIT_MASTER_ACK,
            STOP
        } state_t;
    
    state_t state, next_state; 
    assign state_out = state;
    
    logic sda_oe;
    logic sda_out;
    
    logic [6:0] my_addr = 7'b0000001;
    
    //Two stage synchronizer for SCL
    logic SCL_sync;
    
    assign SDA = sda_oe ? sda_out : 1'bz;

    //SCL synchronization and edge detection
    always_ff @(posedge clk_400) begin
        if (!rst_n) begin
            SCL_sync <= 1;
            SCL_d <= 1;
        end
        else begin
            SCL_sync <= SCL;
            SCL_d <= SCL_sync;
        end
    end
    
    assign scl_posedge = (SCL_sync == 1) && (SCL_d == 0);  
    assign scl_negedge = (SCL_sync == 0) && (SCL_d == 1);  

    always_ff @(posedge clk_400)
    begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    always_comb
    begin
        sda_oe  = 1'b0;
        sda_out = 1'b1;

        case(state)
            ADDR_ACK:
            begin
                if (addr_reg[7:1] == my_addr)
                begin
                    sda_oe  = 1'b1;
                    sda_out = 1'b0; //Drive ACK
                end
                else
                begin
                    sda_oe  = 1'b1;
                    sda_out = 1'b1; //Drive NACK
                end
            end

            SEND_DATA_ACK:
            begin
                sda_oe  = 1'b1;
                sda_out = 1'b0; //Drive ACK
            end

            SEND_DATA:
            begin
                sda_oe  = 1'b1;

                if (data_bit == 7)             
                    sda_out = data_in[7];

                else                  
                    sda_out = data_reg[data_bit]; 
            end
        endcase
    end
    
    always_ff @(posedge clk_400)
    begin
       if (!rst_n)
       begin
            data_bit <= 7;
            addr_bit <= 7;
            data_reg <= 0;
            addr_reg <= 0;
            data_out <= 0;
            data_ready <= 0;
            busy <= 0;
            done <= 0;
            rw <= 0;
            ack_error <= 0;   
            last_data_bit_done <= 0; 
            last_addr_bit_done <= 0;
       end
       else
       begin
            data_ready <= 0;    
            
            case (state)
                    IDLE: begin
                        busy <= 0;
                        done <= 0;
                        addr_bit <= 7;
                        data_bit <= 7;
                        addr_reg <= 0;
                        data_reg <= 0;
                        ack_error <= 0;
                        last_data_bit_done <= 0;
                        last_addr_bit_done <= 0;
                        addr_match <= 0;
                    end
                
                    START: begin
                        busy <= 1;
                        data_reg <= 0;
                        addr_reg <= 0;
                        addr_bit <= 7;
                        next_byte <= next_byte_1;
                        addr_match <= 0;
                    end
                                      
                    ADDR_RX: begin
                        if (scl_posedge)
                        begin
                            addr_reg <= {addr_reg[6:0], SDA};
                            if (addr_bit == 0)
                            begin
                                last_addr_bit_done <= 1;
                            end
                            else 
                                addr_bit <= addr_bit - 1;
                        end
                    end
                    
                    ADDR_ACK: begin
                        if (scl_negedge)
                        begin
                            if (addr_reg[7:1] == my_addr)
                            begin
                                addr_match <= 1;
                                rw <= addr_reg[0];
                            end
                            else
                            begin
                                addr_match <= 0;
                            end
                        end
                    end

                    SEND_DATA: begin       
                        if (scl_negedge)
                        begin
                            if (data_bit == 7)
                            begin
                                data_reg <= data_in;
                            end
                            
                            if (data_bit == 0)
                            begin
                                last_data_bit_done <= 1;
                            end
                            else
                            begin
                                data_bit <= data_bit - 1;
                            end           
                        end
                    end

                    RECEIVE_DATA: begin
                        if (scl_posedge)
                        begin
                            data_reg <= {data_reg[6:0], SDA};
                            if (data_bit == 0)
                            begin                               
                                data_ready <= 1;
                                last_data_bit_done <= 1;
                            end
                            else
                                data_bit <= data_bit - 1;
                        end
                    end

                    SEND_DATA_ACK: begin
                        data_out <= data_reg;
                        last_data_bit_done <= 0;
                            
                        if (scl_negedge)
                        begin
                            next_byte <= 0;
                        end
                        
                        if (scl_posedge)
                        begin
                            if (next_byte)
                            begin 
                                data_bit <= 7;
                            end
                        end 
                    end
                    
                    WAIT_MASTER_ACK: begin
                        if (scl_negedge && next_byte)
                            data_bit <= 7;  
                            
                        if (scl_posedge && SDA == 1)
                            ack_error <= 1;
                    end
                    
                    STOP: begin
                        busy <= 0;
                        done <= 1;
                    end
                    
                    
              endcase
       end
    end


    always_comb
    begin
        next_state = state;

        case(state)
            IDLE: begin
                if (SDA == 0 && SCL == 1)
                    next_state = START;
            end

            START: begin
                if (SCL == 0)
                    next_state = ADDR_RX;
            end
            
            ADDR_RX: begin
                if (scl_posedge && last_addr_bit_done)
                    next_state = ADDR_ACK;
            end

            ADDR_ACK: begin
                if (scl_negedge)
                begin
                    if (addr_reg[7:1] == my_addr)
                    begin
                        if (addr_reg[0] == 0)      //Master wants to write
                            next_state = RECEIVE_DATA;
                        else                       //Master wants to read
                            next_state = SEND_DATA;
                    end
                    else
                    begin
                        next_state = IDLE;
                    end
                end
            end
            
            SEND_DATA: begin
                if (scl_negedge && last_data_bit_done == 1)
                    next_state = WAIT_MASTER_ACK;  
            end
            
            RECEIVE_DATA: begin
                if (scl_posedge && last_data_bit_done)
                    next_state = SEND_DATA_ACK;   
            end
            
            SEND_DATA_ACK: begin
                if (scl_posedge)
                begin
                    if (next_byte)
                        next_state = RECEIVE_DATA;
                    else 
                        next_state = STOP;
                end
            end
            
            WAIT_MASTER_ACK: begin
                if (scl_posedge)
                begin
                    if (SDA == 0)
                    begin
                        if (next_byte)
                            next_state = SEND_DATA;
                        else 
                            next_state = STOP;
                    end
                    
                    else
                        next_state = STOP;
                end
            end
            
            STOP: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule
