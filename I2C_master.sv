//I2C Master Module, work in progress.
//0------> ACK
//1------> NACK
//next_byte logic is not implemented yet. Thinking of making this a parameter.

module I2C_master (
	input  logic clk,
	input  logic rst_n,
	input  logic rw,
	input  logic start_txn,
	input  logic next_byte, //currently testing only for 1 byte of data
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

	
	logic scl_en, scl_reg;

	logic [2:0] addr_bit = 7; 
	logic [2:0] data_bit = 7;

	assign SDA = (sda_oe) ? sda_out : 1'bz; 
	
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

		
	//generation of SCL using a clk_400 which will be a 400KHz clock
	//derieved using IPs
	
	//SCL generation
	always_ff @(posedge clk)
	begin
		if (!rst_n)
		begin
			scl_reg <= 1; //At ideal SCL is pulled HIGH
		end
		elseif (!scl_en)
		begin
			scl_reg <= 0;
		end
		else
		begin
			scl_reg <= ~scl_reg;
		end
	end

	assign SCL = scl_reg;

	//handling sending/receiving of data and address
	always_ff @(posedge clk_400)
	begin
		if (!rst_n)
			begin
				state <= IDLE;
				data_out <= '0;
				data_ready <= 0;
				busy <= 0;
				done <= 0;
				ack_error <= 0;
				sda_out <= 1;
				sda_oe <= 0;
			end
		else
			state <= next_state;
	end

	//Sending, receiving of data from master. Sending Address from master.
	always_ff @(posedge clk_400)
	begin
		if (!rst_n)
		begin
			addr_bit <= 7;
		end

		case (state)
			SEND_ADDR: begin
				sda_oe  <= 1;

				if (addr_bit == 7)
					addr_reg <= {sub_addr, rw}; 
	
				if (SCL == 0) //SDA is sampled only when SCL is low
				begin
					sda_out <= addr_reg[7];

					if (addr_bit == 0)
						next_state <= WAIT_ACK_ADDR;
					else
					begin
						addr_reg <= addr_reg << 1; //shift address reg left
						addr_bit <= addr_bit - 1;
						next_state <= SEND_ADDR;
					end
				end

			end

			SEND_DATA: begin
				sda_oe <= 1;

				if (data_bit == 7)
					data_reg <= data_in;

				if (SCL == 0)
				begin
					sda_out <= data_reg[7];

					if (data_bit == 0)
						next_state <= WAIT_ACK_DATA;
					else
					begin
						data_reg <= data_reg << 1; //shift data reg left
						data_bit <= data_bit - 1;
						next_state <= SEND_DATA;
					end
				end

			end
			
			RECEIVE_DATA: begin
				sda_oe <= 0;

				if (SCL == 1)
				begin
					data_reg[data_bit] <= SDA;
					
					if (data_bit == 0)
						data_out <= data_reg;
						next_state <= MASTER_ACK;

					else
					begin
						data_bit <= data_bit - 1;
						next_state <= RECEIVE_DATA;
					end
				end
			end

			MASTER_ACK: begin
				sda_oe <= 1;   //Master takes control of SDA
				sda_out <= 0; //acknowledge receiving of 1 byte.

				if (SCL == 0)
				begin
					if (next_byte)
					begin
						data_bit <= 7;
						next_state <= RECEIVE_DATA;
					end

					else
						next_state <= STOP;
				end


			end
		endcase

	end

	

	//FSM for I2C
	always_combo 
	begin
		next_state = state;
		sda_out = 1;
		sda_oe = 0;
		busy = 0;
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
				data_reg = 0; //can have possible timing issues
				next_state = SEND_ADDR;
			end

			WAIT_ACK_ADDR: begin //subordinate acknowledgment
				sda_oe = 0; //control is given to subordinate

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
			
			WAIT_ACK_DATA: begin
				sda_oe = 0;

				if (SDA == 0)
					next_state = SEND_DATA; //goes to send next byte if there is any

				else
				begin
					ack_error = 1;
					next_state = STOP;
				end
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
