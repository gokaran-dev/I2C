`timescale 1ns/1ps

module I2C_subordinate #(parameter my_addr = 7'b0000001) (
    input logic clk_400,
    input logic rst_n,
    input logic SCL,
    inout tri   SDA,
    
    input  logic [7:0] data_in, //master reads from data in. like Inbox. dating coming to inbox must be read.
    output logic [7:0] data_out, //master writes here. Holds data after master has finished writing
    output logic data_ready
    
    //only for debugging
    /*output logic done,
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
    output logic addr_match */
);
    
   logic done;
   logic busy;
   logic [2:0] addr_bit; 
   logic [2:0] data_bit; 
   logic [3:0] state_out;
   logic [7:0] addr_reg; 
   logic [7:0] data_reg;
   logic ack_error;
   logic SCL_d;
   logic scl_posedge;
   logic scl_negedge;
   logic rw;
   logic last_data_bit_done;
   logic last_addr_bit_done;
   logic addr_match;
    
    //added data_valid stage so data_out is properly latched and a data_ready signal is generated one clk_400 later.  
    typedef enum logic [3:0] {
        IDLE,
        START,
        ADDR_RX,
        ADDR_ACK,
        RECEIVE_DATA,
        DATA_VALID,    
        SEND_DATA,
        SEND_DATA_ACK,
        WAIT_MASTER_ACK,
        STOP
    } state_t;
    
    state_t state, next_state; 
    assign state_out = state; 
    
    //SCL and SDA are coming from Master and therefore must be synced for subordinate
    logic SCL_sync, SDA_sync, SDA_d;

    logic start_cond;
    logic stop_cond;  
    
    //SDA falling while SCL is high
    assign start_cond = (SDA_sync == 1'b0) && (SDA_d == 1'b1) && (SCL_d == 1'b1);
    //SDA rising while SCL is high. I also ensure that we do not go to IDLE accidentally. 
    assign stop_cond  = (((SDA_sync == 1'b1) && (SDA_d == 1'b0) && (SCL_d == 1'b1)) && (state != SEND_DATA));
    
    
    logic sda_oe;
    logic sda_out;
    assign SDA = sda_oe ? sda_out : 1'bz;

    //SCL and SDA synchronization
    always_ff @(posedge clk_400, negedge rst_n) 
    begin
        if (!rst_n) 
        begin
            SCL_sync <= 1'b1; 
            SCL_d <= 1'b1;
            SDA_sync <= 1'b1; 
            SDA_d <= 1'b1; 
        end
        
        else 
        begin
            SCL_sync <= SCL; 
            SCL_d <= SCL_sync;           
            SDA_sync <= SDA; 
            SDA_d <= SDA_sync; 
        end
    end
    
    assign scl_posedge = (SCL_sync == 1'b1) && (SCL_d == 1'b0); 
    assign scl_negedge = (SCL_sync == 1'b0) && (SCL_d == 1'b1); 

    
    //since SDA is s shared signal, any FSM delay for its release or capture was breaking timing. So I took it out.
    always_comb
    begin
        //release SDA by default and set sda_out to 1, just in case.
        sda_oe  = 1'b0;
        sda_out = 1'b1;
        
        case(state) 
            ADDR_ACK:
                if (SCL_d == 1'b0) begin //drive wen SCL is low
                
                    if (addr_reg[7:1] == my_addr) 
                    begin
                        sda_oe  = 1'b1;
                        sda_out = 1'b0; //Drive ACK
                    end
                end
                
            SEND_DATA_ACK: begin
                if (SCL_d == 1'b0) 
                begin
                    sda_oe  = 1'b1;
                    sda_out = 1'b0; 
                end
             end
               
            SEND_DATA: begin
                    sda_oe  = 1'b1; 
                    sda_out = data_reg[7];
                end
        endcase
    end
    
    //FSM
    always_ff @(posedge clk_400, negedge rst_n) 
    begin
       if (!rst_n)
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
       
       else 
       begin
            state <= next_state; 
            
            //making sure data ready signal remains LOW by default
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
                    data_bit <= 7; 
                    addr_match <= 1'b0;
                end
                                       
                ADDR_RX: begin
                    if (scl_posedge)
                    begin
                    //building the transmitted address into an internal address register
                        addr_reg <= {addr_reg[6:0], SDA}; 
                                            
                        if (addr_bit == 0)
                            last_addr_bit_done <= 1'b1; 
                        else 
                            addr_bit <= addr_bit - 1;
                    end
                end
                
                ADDR_ACK: begin
                    last_addr_bit_done <= 1'b0; 
                    
                    if (scl_negedge)
                    begin
                        if (addr_reg[7:1] == my_addr)
                        begin
                            addr_match <= 1'b1;
                            rw <= addr_reg[0];
                            
                            //handling data_reg so its ready by the time we go to SEND_DATA or RECEIVE DATA
                            if (addr_reg[0] == 1'b1) //Master is reading from subordinate
                            begin
                                data_reg <= data_in;
                            end
                            
                            else  //Master is writing to subordinate
                            begin
                                data_reg <= 8'b0; 
                            end
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
                            last_data_bit_done <= 1'b1;
                        end
                        else
                            data_bit <= data_bit - 1;
                    end
                end
               
               //to properly load data_out and honour the timing
                DATA_VALID: begin
                    data_out <= data_reg;       
                    last_data_bit_done <= 1'b0; 
                end

                SEND_DATA: begin   
                    if (scl_negedge)
                    begin       
                        if (data_bit == 0)
                            last_data_bit_done <= 1'b1;
                        else
                        begin
                            data_reg <= {data_reg[6:0], 1'b0};
                            data_bit <= data_bit - 1;
                        end
                    end
                end

                SEND_DATA_ACK: begin                   
                    data_ready <= 1;                           
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

    //next state logic
    always_comb
    begin
        next_state = state; 

        if (stop_cond) 
        begin
            next_state = IDLE;
        end
        
        else 
        begin            
            case(state)
                IDLE: begin
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
                        if (addr_reg[7:1] == my_addr) 
                        begin
                            if (addr_reg[0] == 1'b0)
                                next_state = RECEIVE_DATA;
                            else
                                next_state = SEND_DATA;
                        end
                        
                        else //address didnt match, go to IDLE
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
                        next_state = DATA_VALID;   
                end
              
                DATA_VALID: begin
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