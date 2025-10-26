`timescale 1ns/1ps

module I2C_master (
    input  logic clk_400,
    input  logic rst_n,
    input  logic rw,
    input  logic start_txn,
    input  logic [7:0] next_byte_1, // Changed to 8-bit to be a counter
    input  logic [6:0] sub_addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic data_ready,
    output logic busy,
    output logic done,
    output logic ack_error,
    output logic SCL,
    output logic [3:0] state_out,
    output logic [2:0] data_bit, addr_bit,
    output logic [7:0] addr_reg, data_reg,
    output logic last_addr_bit,
    output logic last_data_bit,
    inout  tri   SDA
);

    logic scl_en, scl_reg;
    logic sda_oe, sda_out;
    // **FIX 1: next_byte MUST be a multi-bit counter to be decremented.**
    logic [7:0] next_byte;
    
    assign SDA = (sda_oe) ? sda_out : 1'bz; 
    
    typedef enum logic [3:0] {
        IDLE,
        START,
        SEND_ADDR,
        WAIT_ACK_ADDR,
        SEND_DATA,
        WAIT_ACK_DATA,
        RECEIVE_DATA,
        MASTER_ACK,
        STOP
    } state_t;

    state_t state, next_state;
    assign state_out = state[3:0];
    
    //SCL generation
    always_ff @(posedge clk_400) 
    begin
        if (!rst_n) begin
            scl_reg <= 1;
        end
        else if (!scl_en) begin
            scl_reg <= 1;
        end
        else begin
            scl_reg <= ~scl_reg;
        end
    end

    assign SCL = scl_reg;

    always_ff @(posedge clk_400) 
    begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_ff @(posedge clk_400) 
    begin
        if (!rst_n) begin
            addr_bit <= 7;
            data_bit <= 7;
            scl_en <= 0;
            addr_reg <= 0;
            data_reg <= 0;
            data_out <= 0;
            data_ready <= 0;
            busy <= 0;
            done <= 0;
            ack_error <= 0;
            sda_out <= 1;
            sda_oe <= 0;
            next_byte <= 0;
        end
        
        else 
        begin
            data_ready <= 0;
            
            case (state)  
                IDLE: begin
                    sda_out <= 1;
                    sda_oe  <= 1;
                    scl_en <= 0;
                    busy <= 0;
                    done <= 0;
                    ack_error <= 0;
                    addr_bit <= 7;
                    data_bit <= 7;
                    last_data_bit <= 0;
                    last_addr_bit <= 0;
                end 
                
                START: begin
                    busy <= 1;
                    done <= 0;
                    sda_out <= 0;
                    sda_oe <= 1; 
                    scl_en <= 1;
                    data_reg <= 0;
                    addr_bit <= 7;
                    data_bit <= 7;
                    last_addr_bit <= 0;
                    last_data_bit <= 0;
                    next_byte <= next_byte_1;
                end
                
                SEND_ADDR: begin
                    sda_oe  <= 1;
                    if (addr_bit == 7) 
                        addr_reg <= {sub_addr, rw}; 
   
                    if (SCL == 0) 
                    begin 
                        sda_out <= addr_reg[7];
                        if (addr_bit != 0) begin
                            addr_reg <= addr_reg << 1;
                            addr_bit <= addr_bit - 1;
                        end
                        else begin
                            last_addr_bit <= 1;
                            sda_oe <= 0; 
                        end
                    end
                end
                
                WAIT_ACK_ADDR: begin
                    if (SCL == 1) begin  
                        if (SDA == 1) 
                            ack_error <= 1;
                        
                        if (rw == 0)
                            data_reg <= data_in;                      
                    end
                end

                SEND_DATA: begin
                    sda_oe <= 1;
                    if (SCL == 0) begin
                        sda_out <= data_reg[7];
                        if (data_bit != 0) begin
                            data_reg <= data_reg << 1;
                            data_bit <= data_bit - 1;
                        end
                        else 
                        begin
                            last_data_bit <= 1;
                            sda_oe <= 0;
                        end
                    end
                end
                
                RECEIVE_DATA: begin
                    sda_oe <= 0;
                    if (SCL == 1) begin
                        data_reg <= {data_reg[6:0], SDA}; 
                        if (data_bit == 0) 
                        begin
                            data_ready <= 1;
                            last_data_bit <= 1; 
                        end                   
                        else   
                        begin
                            data_bit <= data_bit - 1;
                        end
                    end
                end
                
                WAIT_ACK_DATA: begin
                    if (SCL == 1) begin                      
                        if (SDA == 1) 
                            ack_error <= 1;
                    end
                    // **FIX 2: Add the missing counter decrement for WRITE operations.**
                    else begin // SCL is low, after ACK has been sampled.
                        if (next_byte > 0) begin
                            next_byte <= next_byte - 1;
                            data_bit <= 7;
                            last_data_bit <= 0;
                            data_reg <= data_in; // In a real multi-byte, you'd load new data here
                        end
                    end
                end
                
                MASTER_ACK: begin
                    sda_oe <= 1;
                    if (next_byte > 0) 
                        sda_out <= 0; // ACK
                    else 
                        sda_out <= 1; // NACK for the last byte
                    
                    if (SCL == 1)
                    begin
                        if (last_data_bit)
                            data_out <= data_reg;
                    end
                    else //at SCL == 0 
                    begin
                        if (next_byte > 0) begin
                           next_byte <= next_byte - 1;
                           data_bit <= 7;
                           last_data_bit <= 0;
                        end
                    end
                end
                       
                STOP: begin
                    sda_oe <= 1;
                    if (SCL == 1) 
                        sda_out <= 1;
                    else 
                        sda_out <= 0;
                    done <= 1;
                    busy <= 0;
                    scl_en <= 0;
                end
                       
                default:
                    scl_en <= 0;
            endcase
        end
    end

    // Combinational Logic Block for State Transitions
    always_comb 
    begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start_txn) 
                    next_state = START;
            end

            START: begin
                if (SCL == 0)
                    next_state = SEND_ADDR;
            end
            
            SEND_ADDR: begin
                if (SCL == 0 && last_addr_bit)
                    next_state = WAIT_ACK_ADDR;
            end

            WAIT_ACK_ADDR: begin
                if (SCL == 1) begin  
                    if (SDA == 1) 
                        next_state = STOP;
                    else 
                    begin 
                        if (rw == 0) 
                            next_state = SEND_DATA;
                        else 
                            next_state = RECEIVE_DATA;
                    end
                end
            end
            
            SEND_DATA: begin    
                if (last_data_bit && SCL == 0)  
                    next_state = WAIT_ACK_DATA;
            end
            
            RECEIVE_DATA: begin
                if (last_data_bit && SCL == 0)
                    next_state = MASTER_ACK;
            end
            
            WAIT_ACK_DATA: begin   
                if (SCL == 1) begin  
                    if (SDA == 1) 
                        next_state = STOP;
                    else 
                    begin
                        // **FIX 3: Base the decision on the counter value.**
                        if (next_byte > 0)  
                            next_state = SEND_DATA;
                        else
                            next_state = STOP;
                    end
                end
            end
            
            MASTER_ACK: begin
                if (SCL == 1) 
                begin  
                    if (next_byte > 0)
                        next_state = RECEIVE_DATA;
                    else
                        next_state = STOP;
                end
            end

            STOP: begin
                if (SCL == 1) 
                    next_state = IDLE;
            end

            default:  
                next_state = IDLE;
        endcase
    end
endmodule

