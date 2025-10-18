`timescale 1ns/1ps

module I2C_master (
    input  logic clk_400,
    input  logic rst_n,
    input  logic rw,
    input  logic start_txn,
    input  logic next_byte_1,
    input  logic [6:0] sub_addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic data_ready,
    output logic busy,
    output logic done,
    output logic ack_error,
    output logic SCL,
    //output logic [2:0] state_out, //only for debugging
   //output logic [2:0] data_bit, addr_bit, //this is only for debugging
    //output logic [7:0] addr_reg, data_reg, //only for debugging
    inout  tri   SDA
);

    logic scl_en, scl_reg;
    logic sda_oe, sda_out;
    logic [2:0] addr_bit, data_bit; 
    logic [7:0] addr_reg, data_reg;
    logic next_byte;
    
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
    assign state_out = state[2:0];
    
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
                end 
                
                START: begin
                    busy <= 1;
                    done <= 0;
                    sda_out <= 0;  //START: SDA goes low while SCL high
                    sda_oe <= 1; 
                    scl_en <= 1;   //Enable SCL toggling
                    data_reg <= 0;
                    addr_bit <= 7;
                    data_bit <= 7;
                    next_byte <= next_byte_1;
                end
                
                SEND_ADDR: begin
                    sda_oe  <= 1;

                    if (addr_bit == 7) 
                    begin
                        addr_reg <= {sub_addr, rw}; 
                    end
        
                    if (SCL == 0) 
                    begin //Update SDA when SCL is low
                        sda_out <= addr_reg[7];

                        if (addr_bit != 0) begin
                            addr_reg <= addr_reg << 1;
                            addr_bit <= addr_bit - 1;
                        end
                        else begin
                            //releasing SDA here instead of WAIT_ACK_ADDR for timing
                            sda_oe <= 0;
                        end
                    end
                end
                
                WAIT_ACK_ADDR: begin               
                    if (SCL == 1) 
                    begin  
                        if (SDA == 1) //NACK is sampled when SCL is HIGH
                        begin  
                            ack_error <= 1;
                        end                       
                    end
                end

                SEND_DATA: begin
                    sda_oe <= 1;

                    if (data_bit == 7) begin
                        data_reg <= data_in; 
                    end

                    if (SCL == 0) begin
                        sda_out <= data_reg[7];
                        
                        if (data_bit != 0) begin
                            data_reg <= data_reg << 1;
                            data_bit <= data_bit - 1;
                        end
                        else 
                        begin
                            //releasing it a state early to fix timing issues
                            sda_oe <= 0;
                        end
                    end
                end
                
                RECEIVE_DATA: begin
                    sda_oe <= 0;

                    if (SCL == 1) begin
                        data_reg[data_bit] <= SDA;
                        
                        if (data_bit == 0) begin
                            data_out <= data_reg;
                            data_ready <= 1;
                        end
                        else begin
                            data_bit <= data_bit - 1;
                        end
                    end
                end
                
                WAIT_ACK_DATA: begin                    
                    if (SCL == 1) 
                    begin
                        if (SDA == 1) begin  // NACK received when SCL is HIGH
                            ack_error <= 1;
                        end
                    end
                end
                
                MASTER_ACK: begin
                    sda_oe <= 1;
                    sda_out <= 0; //ACK
                    
                    if (SCL == 0) 
                    begin
                        next_byte <= next_byte - 1;
                        
                        if (next_byte) 
                        begin
                            data_bit <= 7;
                        end
                    end
                end
                    
                STOP: begin
                    sda_oe <= 1;
                    if (SCL == 1) 
                    begin  //STOP: SDA goes high while SCL high
                        sda_out <= 1;
                    end
                    
                    else 
                    begin
                        sda_out <= 0;  //Keep SDA low until SCL goes high
                    end
                    done <= 1;
                    busy <= 0;
                    scl_en <= 0;
                end
                    
                default: begin
                    scl_en <= 0;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start_txn) 
                    next_state = START;
            end

            START: begin
                if (SCL == 0)  //Wait for first SCL low
                    next_state = SEND_ADDR;
            end
            
            SEND_ADDR: begin
                if (addr_bit == 0 && SCL == 0)  //All bits sent, SCL is low, ready for ACK
                    next_state = WAIT_ACK_ADDR;
            end

            WAIT_ACK_ADDR: begin
               
                if (SCL == 1) 
                begin  
                    if (SDA == 1) 
                    begin  
                        next_state = STOP;
                    end
                    
                    else 
                    begin 
                        if (rw == 0) 
                        begin
                            next_state = SEND_DATA;
                        end
                        else 
                        begin
                            next_state = RECEIVE_DATA;
                        end
                    end
                end
            end
            
            SEND_DATA: begin            
                if (data_bit == 0 && SCL == 0)  
                    next_state = WAIT_ACK_DATA;
            end
            
            RECEIVE_DATA: begin
                if (data_bit == 0 && SCL == 0)  //Last bit sampled
                    next_state = MASTER_ACK;
            end
            
            WAIT_ACK_DATA: begin     
                if (SCL == 1) 
                begin  
                    if (SDA == 1) 
                    begin  
                        next_state = STOP;
                    end
                    else 
                    begin  
                        next_state = SEND_DATA;
                    end
                end
            end
            
            MASTER_ACK: begin
                if (SCL == 1) 
                begin  
                    if (next_byte)
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