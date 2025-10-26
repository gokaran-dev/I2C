`timescale 1ns/1ps

module I2C_subordinate #(parameter my_addr = 7'b0000001) (
    input logic clk_400,
    input logic rst_n,
    input logic SCL,
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
    
    // Add START and STOP condition detectors
    logic start_cond;
    logic stop_cond;  // START Condition: SDA falling while SCL is high
    assign start_cond = (SDA_sync == 1'b0) && (SDA_d == 1'b1) && (SCL_d == 1'b1);
    // STOP Condition: SDA rising while SCL is high
    assign stop_cond  = (SDA_sync == 1'b1) && (SDA_d == 1'b0) && (SCL_d == 1'b1);
    
    logic sda_oe;
    logic sda_out;
    
    logic SCL_sync, SDA_sync, SDA_d;
    logic start_cond;
    
    assign SDA = sda_oe ? sda_out : 1'bz;

    // SCL and SDA synchronization and edge detection
    always_ff @(posedge clk_400, negedge rst_n) begin
        if (!rst_n) begin
            SCL_sync <= 1'b1; SCL_d <= 1'b1;
            SDA_sync <= 1'b1; SDA_d <= 1'b1; 
        end
        else begin
            SCL_sync <= SCL; SCL_d <= SCL_sync;
            SDA_sync <= SDA; SDA_d <= SDA_sync; 
        end
    end
    
    assign scl_posedge = (SCL_sync == 1'b1) && (SCL_d == 1'b0); 
    assign scl_negedge = (SCL_sync == 1'b0) && (SCL_d == 1'b1); 
    assign start_cond = (SDA_sync == 1'b0) && (SDA_d == 1'b1) && (SCL_d == 1'b1);

    
    // Combinational SDA driver (Gated by SCL_d)
    always_comb
    begin
        sda_oe  = 1'b0;
        sda_out = 1'b1;
        case(state) 
            ADDR_ACK:
                if (SCL_d == 1'b0) begin // Only drive when SCL is LOW
                    if (addr_reg[7:1] == my_addr) begin
                        sda_oe  = 1'b1;
                        sda_out = 1'b0; // Drive ACK
                    end
                end
            SEND_DATA_ACK:
                if (SCL_d == 1'b0) begin
                    sda_oe  = 1'b1;
                    sda_out = 1'b0; // Drive ACK
                end
            SEND_DATA:
                begin
                    sda_oe  = 1'b1; 
                    if (data_bit == 7)
                        sda_out = data_in[7];
                    else
                        sda_out = data_reg[data_bit];
                end
            default: begin 
                sda_oe  = 1'b0;
                sda_out = 1'b1;
            end
        endcase
    end
    
    // Merged state and logic into a single always_ff block
    always_ff @(posedge clk_400, negedge rst_n) 
    begin
       if (!rst_n) // Asynchronous Reset
       begin
            state <= IDLE; 
            data_bit <= 7;
            addr_bit <= 7;
            data_reg <= 8'b0; 
            addr_reg <= 8'b0;
            data_out <= 8'b0;
            data_ready <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            rw <= 1'b0;
            ack_error <= 1'b0;   
            last_data_bit_done <= 1'b0; 
            last_addr_bit_done <= 1'b0;
            addr_match <= 1'b0; 
       end
       else // Synchronous Operation
       begin
            state <= next_state; 
            data_ready <= 1'b0;    
            
            case (state) 
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    addr_bit <= 7;
                    data_bit <= 7;
                    addr_reg <= 8'b0;
                    data_reg <= 8'b0;
                    ack_error <= 1'b0;
                    last_data_bit_done <= 1'b0;
                    last_addr_bit_done <= 1'b0;
                    addr_match <= 1'b0;
                end
            
                START: begin
                    last_addr_bit_done <= 0;
                    last_data_bit_done <= 0;
                    busy <= 1'b1;
                    data_reg <= 8'b0;
                    addr_reg <= 8'b0;
                    addr_bit <= 7;
                    data_bit <= 7; // Reset data bit counter
                    addr_match <= 1'b0;
                end
                                      
                ADDR_RX: begin
                    if (scl_posedge)
                    begin
                        addr_reg <= {addr_reg[6:0], SDA}; // Sample bit
                        if (addr_bit == 0)
                            last_addr_bit_done <= 1'b1; // Set flag
                        else 
                            addr_bit <= addr_bit - 1;
                    end
                end
                
                ADDR_ACK: begin
                    last_addr_bit_done <= 1'b0; // Reset flag
                    if (scl_negedge)
                    begin
                        if (addr_reg[7:1] == my_addr)
                        begin
                            addr_match <= 1'b1; // Set flag for output/debug
                            rw <= addr_reg[0];
                        end
                        else
                        begin
                            addr_match <= 1'b0;
                        end
                    end
                end

                RECEIVE_DATA: begin
                    if (scl_posedge)
                    begin
                        data_reg <= {data_reg[6:0], SDA};
                        if (data_bit == 0)
                        begin                       
                            //data_ready <= 1'b1;
                            last_data_bit_done <= 1'b1;
                        end
                        else
                            data_bit <= data_bit - 1;
                    end
                end

                SEND_DATA: begin    
                    if (scl_negedge)
                    begin
                        if (data_bit == 7)
                            data_reg <= data_in;
                        
                        if (data_bit == 0)
                            last_data_bit_done <= 1'b1;
                        else
                            data_bit <= data_bit - 1;
                    end
                end

                SEND_DATA_ACK: begin
                    data_out <= data_reg;
                    data_ready <= 1;
                    last_data_bit_done <= 1'b0; 
                    if (scl_posedge)
                        data_bit <= 7;
                end
                
                WAIT_MASTER_ACK: begin
                    last_data_bit_done <= 1'b0; 
                    if (scl_posedge && SDA == 1'b1)
                        ack_error <= 1'b1;
                    if (scl_negedge) 
                        data_bit <= 7;
                end
                
                STOP: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
                
                default: begin 
                    busy <= 1'b0;
                    done <= 1'b0;
                    addr_bit <= 7;
                    data_bit <= 7;
                end
                    
            endcase
       end
    end

    // Combinational State Transitions (FIXED)
    always_comb
    begin
        next_state = state; // Default: remain in current state

        // **FIX 1: A STOP condition is a global reset, overrides everything.**
        if (stop_cond) begin
            next_state = IDLE;
        end
        else begin
            // **Normal state transitions**
            case(state)
                IDLE: begin
                    // **FIX 2: A START condition is ONLY valid from IDLE.**
                    if (start_cond) 
                        next_state = START;
                end

                START: begin
                    if (SCL_d == 1'b0) 
                        next_state = ADDR_RX;
                end
                
                ADDR_RX: begin
                    if (last_addr_bit_done) 
                        next_state = ADDR_ACK;
                end

                ADDR_ACK: begin
                    if (scl_negedge)
                    begin
                        // Check stable addr_reg directly
                        if (addr_reg[7:1] == my_addr) 
                        begin
                            if (addr_reg[0] == 1'b0)
                                next_state = RECEIVE_DATA;
                            else
                                next_state = SEND_DATA;
                        end
                        else // Address mismatch
                        begin
                            next_state = IDLE;
                        end
                    end
                end
                
                SEND_DATA: begin
                    if (last_data_bit_done) 
                        next_state = WAIT_MASTER_ACK;  
                end
                
                RECEIVE_DATA: begin
                    if (last_data_bit_done)
                        next_state = SEND_DATA_ACK;   
                end
                
                SEND_DATA_ACK: begin
                    if (scl_negedge)
                        next_state = STOP;
                end
                
                WAIT_MASTER_ACK: begin
                    if (scl_posedge)
                       next_state = STOP;
                end
                
                STOP: begin
                     next_state = IDLE;
                end

                default: 
                    next_state = IDLE;

            endcase
        end
    end
endmodule