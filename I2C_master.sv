//I2C Master Module, work in progress

module I2C_master (
	input  logic clk,
	input  logic rst_n,
	input  logic rw,
	input  logic start_txn,
	input  logic [6:0] sub_addr,
	input  logic [7:0] data_in,
	input  logic data_valid,
	output logic [7:0] data_out,
	output logic data_ready,
	output logic busy,
	output logic done,
	output logic ack_error,
	output logic SCL,
	inout  logic SDA
	);


	typedef enum logic [3:0] {
		IDLE,
		START,
		SEND_ADDR,
		WAIT_ACK_ADD,
		SEND_DATA,
		WAIT_ACK_DATA,
		RECEIVE_DATA,
		MASTER_ACK,
		STOP
		} state_t;

	state_t state, next_state;

	always_ff @(posedge clk)
	begin
		if (!rst_n)
			begin
				state <= IDLE;
				data_out <= '0;
				data_ready <= 0;
				busy <= 0;
				done <= 0;
				ack_error <= 0;
				SCL <= 1;
				sda_out <= 1;
				sda_oe <= 0;
			end
		else
			state <= next_state;
	end

	

	always_combo 
	begin
		next_state = state;
		sda_out = 1;
		sda_oe = 0;
		budy = 0;
		done = 0;

		case (state)
			IDLE: begin
				if (start_txn) 
				begin
					next_state = START;
					busy = 1;
				end
			end

			START: begin
				sda_out = 0;
				sda_oe = 1;
				shift_reg = {sub_addr, rw};
				next_state = SEND_ADDR;
			end

			SEND_ADDR: begin
				sda_out = shift_reg[7]; //7 bit address
				sda_oe = 1;

				if (addr_bit == 0)
				begin
					next_state = WAIT_ACK_ADDR;
				end	
			end

			WAIT_ACK_ADDR: begin
				sda_oe = 0;

				if (SDA == 0) //acknowledgment received 
				begin
					if (rw == 0) 
						next_state = SEND_DATA;

					else 
					begin
						data_bits = 7;
						next_state = RECEIVE_DATA;
					end
				end

				else
				begin
					ack_error = 1;
					next_state = STOP;
				end
			end

			SEND_DATA: begin
				sda_out = shift_reg [7];
				sda_oe = 1;

				if (data_bits == 0 && scl_falling)
				begin
					next_state = WAIT_ACK_DATA;
				end
			end
			
			WAIT_ACK_DATA: begin
				sda_oe = 0;

				if (SDA == 0)
				begin
					if (data_valid) 
					begin
						next_state = SEND_DATA;
					end

					else
						next_state = STOP;
				end

				else
					next_state = STOP;
			end

			RECEIVE_DATA: begin
				sda_oe = 0;

				if (data_bits == 
					0)
					next_state = MASTER_ACK;
			end

			MASTER_ACK: begin
				sda_out = next_byte ? 0 : 1;
				sda_oe = 1;
				
				//when and how do we go to stop?
				next_state = STOP;
			end

			STOP: begin
				sda_out = 1;
				sda_oe = 1;
				done = 1;
				
				next_state = IDLE;
			end

			default: next_state = IDLE;
		endcase
	end
endmodule
