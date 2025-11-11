`timescale 1ns/1ps

module I2C_master (
    input  logic clk_400,
    input  logic rst_n,
    input  logic rw,
    input  logic start_txn,
    input  logic [6:0] sub_addr,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic data_ready,
    inout  tri   SCL,
    inout  tri   SDA,
    output logic busy,
    output logic done
    
    //only for debugging
    /*output logic scl_en,
    output logic scl_reg,
    output logic ack_error,
    output logic [3:0] state_out,
    output logic [2:0] data_bit, addr_bit,
    output logic [7:0] addr_reg, data_reg,
    output logic last_addr_bit,
    output logic last_data_bit*/
);
    logic ack_error;
    logic [3:0] state_out;
    logic [2:0] data_bit, addr_bit;
    logic [7:0] addr_reg, data_reg;
    logic last_addr_bit;
    logic last_data_bit;

    //while SCL is produced by Master, its FSM must be in sync with subordinate.
    //Therefore we add 2 step synchronizers for SCL signal, similar to subordinate.
    logic SCL_sync, SCL_d;
    logic scl_posedge;
    logic scl_negedge;

    assign scl_posedge = (SCL_sync == 1'b1) && (SCL_d == 1'b0);
    assign scl_negedge = (SCL_sync == 1'b0) && (SCL_d == 1'b1);

    //bidirectional tristate SDA
    logic scl_en, scl_reg;
    logic sda_oe, sda_out;
    assign SDA = (sda_oe) ? sda_out : 1'bz;

    //bidirectional tristate SCL
    assign SCL = (scl_reg == 0) ? 1'b0 : 1'bz;

    //even after synchronising SCL, I observed Master FSM was running one clk_400 edge faster. So, Added extra state
    typedef enum logic [3:0] {
        IDLE,
        START,
        SEND_ADDR,
        WAIT_ACK_ADDR,
        SEND_DATA,
        WAIT_ACK_DATA,
        PRE_RECEIVE,
        RECEIVE_DATA,
        MASTER_ACK,
        DATA_VALID,
        PULSE_READY,
        STOP
    } state_t;

    state_t state, next_state;
    assign state_out = state[3:0];

    //SCL generation
    always_ff @(posedge clk_400, negedge rst_n)
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

    //FSM
    always_ff @(posedge clk_400, negedge rst_n)
    begin
        if (!rst_n) begin
            state <= IDLE;
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
            last_addr_bit <= 0;
            last_data_bit <= 0;
            SCL_sync <= 1;
            SCL_d <= 1;
        end

        else
        begin
            state <= next_state;
            data_ready <= 0; //Default to 0, only pulse for one cycle

            //two stage synchronizers for SCL
            SCL_sync <= SCL;
            SCL_d <= SCL_sync;

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
                    addr_reg <= {sub_addr, rw};
                end

                SEND_ADDR: begin
                    sda_oe  <= 1;

                    if (SCL == 0)
                    begin
                        sda_out <= addr_reg[7];
                        if (addr_bit != 0)
                        begin
                            addr_reg <= addr_reg << 1;
                            addr_bit <= addr_bit - 1;
                        end

                        else
                        begin
                            last_addr_bit <= 1;
                            sda_oe <= 0;
                        end
                    end
                end

                WAIT_ACK_ADDR: begin
                   if (rw == 0)
                        data_reg <= data_in;

                    last_addr_bit <= 0;
                    if (SCL == 1)
                    begin
                        if (SDA == 1)
                        begin
                            ack_error <= 1;
                        end
                    end
                end

                SEND_DATA: begin
                    sda_oe <= 1;

                    if (SCL == 0)
                    begin
                        sda_out <= data_reg[7];

                        if (data_bit != 0)
                        begin
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

                PRE_RECEIVE: begin
                    //deliberate extra state for properly synchronizing subordinate and Master FSMs
                    sda_oe <= 0;
                end

                RECEIVE_DATA:
                begin
                    sda_oe <= 0;

                    if (scl_posedge)
                    begin
                        data_reg <= {data_reg[6:0], SDA};
                        if (data_bit == 0)
                        begin
                            last_data_bit <= 1;
                        end

                        else
                        begin
                            data_bit <= data_bit - 1;
                        end
                    end
                end

                WAIT_ACK_DATA: begin
                    last_data_bit <= 0;

                    if (SCL == 1)
                    begin
                        if (SDA == 1)
                        begin
                            ack_error <= 1;
                        end
                    end
                end

                MASTER_ACK: begin
                    last_data_bit <= 0;

                    sda_oe <= 1;
                    sda_out <= 1; //NACK: Since we are only sending 1 byte.
                end

                DATA_VALID: begin
                    //another extra state so valid data is loaded into data_out
                    data_out <= data_reg;
                end

                PULSE_READY: begin
                //another state which is meant to pulse data ready one edge after so data_out is ready
                    data_ready <= 1'b1;
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

                default: begin
                    scl_en <= 0;
                end
            endcase
        end
    end

    //Next state transitions
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
                if (last_addr_bit)
                    next_state = WAIT_ACK_ADDR;
            end

            WAIT_ACK_ADDR: begin
                if (scl_negedge)
                begin
                    if (ack_error)
                        next_state = STOP;

                    else
                    begin
                        if (rw == 0) //Master Writes to subordinate
                            next_state = SEND_DATA;

                        else //Master reads from subordinate for rw = 1
                            next_state = PRE_RECEIVE;
                    end
                end
            end

            PRE_RECEIVE: begin
                next_state = RECEIVE_DATA;
            end

            SEND_DATA: begin
                if (last_data_bit)
                    next_state = WAIT_ACK_DATA;
            end

            RECEIVE_DATA: begin
                if (last_data_bit)
                    next_state = MASTER_ACK;
            end

            WAIT_ACK_DATA: begin
                if (scl_negedge) begin
                    next_state = STOP;
                end
            end

            MASTER_ACK: begin
                if (scl_negedge)
                begin
                    next_state = DATA_VALID;
                end
            end

            DATA_VALID: begin
                next_state = PULSE_READY;
            end

            PULSE_READY: begin
                next_state = STOP;
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
