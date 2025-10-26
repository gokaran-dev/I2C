`timescale 1ns/1ps

module I2C_subordinate (
        input logic clk_400,
        input logic rst_n,
        input logic SCL,
        input logic next_byte_1, // Port remains, but logic is unused
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
        output logic next_byte, // Port remains, but logic is unused
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
    
    // Two-stage synchronizer for SCL
    logic SCL_sync;
    
    assign SDA = sda_oe ? sda_out : 1'bz;

    // SCL synchronization and edge detection
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
    
    assign    scl_posedge = (SCL_sync == 1) && (SCL_d == 0);  
    assign    scl_negedge = (SCL_sync == 0) && (SCL_d == 1);  

    always_ff @(posedge clk_400)
    begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end
    
    // Combinational block to instantly drive SDA
    always_comb
    begin
        // Default assignment: Do not drive the bus
        sda_oe  = 1'b0;
        sda_out = 1'b1;

        case(state)
            ADDR_ACK:
            begin
                if (addr_reg[7:1] == my_addr)
                begin
                    sda_oe  = 1'b1;
                    sda_out = 1'b0; // Drive ACK
                end
                else
                begin
                    sda_oe  = 1'b1;
                    sda_out = 1'b1; // Drive NACK
                end
            end

            SEND_DATA_ACK:
            begin
                sda_oe  = 1'b1;
                sda_out = 1'b0; // Drive ACK
            end

            SEND_DATA:
            begin
                sda_oe  = 1'b1;
                if (data_bit == 7)
                begin
                    sda_out = data_in[7];
                end
                else
                begin
                    sda_out = data_reg[data_bit];
                end
            end
        endcase
    end
    
    // Sequential Logic Block
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
            // **CHANGE**: Tie off unused output to a known value
            next_byte <= 1'b0; 
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
                    // **CHANGE**: Removed assignment that used next_byte_1
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
                        
                    // **CHANGE**: Reset data_bit unconditionally, as we always
                    // prepare for a new byte.
                    if (scl_posedge)
                    begin
                        data_bit <= 7;
                    end 
                end
                
                WAIT_MASTER_ACK: begin
                    // **CHANGE**: Reset data_bit unconditionally on negedge
                    if (scl_negedge)
                        data_bit <= 7;
                        
                    if (scl_posedge && SDA == 1)
                        ack_error <= 1;
                end
                
                STOP: begin
                    busy <= 0;
                    done <= 1;
                end
                
                default: begin
                    // No default action needed
                end
                    
              endcase
       end
    end

    // Combinational Logic Block (State Transitions)
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
                        if (addr_reg[0] == 0)
                            next_state = RECEIVE_DATA;
                        else
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
                // **CHANGE**: This is the key reactive change for WRITEs.
                // After acknowledging, always prepare to receive another byte.
                // The master will send a STOP when it is finished.
                if (scl_posedge)
                begin
                    next_state = RECEIVE_DATA;
                end
            end
            
            WAIT_MASTER_ACK: begin
                // **CHANGE**: This is the key reactive change for READs.
                // The decision to continue is based *only* on the master's
                // ACK/NACK signal on the SDA line.
                if (scl_posedge)
                begin
                    if (SDA == 0) // Master sent an ACK
                    begin
                        next_state = SEND_DATA; // Send another byte
                    end
                    else // Master sent a NACK
                    begin 
                        next_state = STOP; // Transaction is over
                    end
                end
            end
            
            STOP: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule

