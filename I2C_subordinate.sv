//I2C subordinate module. Work in progress.

`timescale 1ns/1ps

module I2C_subordinate (
		input logic clk,
		input logic rst_n,
		input logic SCL,
		inout tri   SDA,
		
		input  logic [7:0] addr, //address for the subordinate.
		input  logic [7:0] data_in, //data we want to send
		output logic [7:0] data_out, //data we want to receive 
		output logic data_ready,
		output logic ack_error
	);

	typedef enum logic [2:0] {
			IDLE,
			START,
			ADDR_RX,
			ADDR_ACK,
			RECEIVE_DATA,
			SEND_DATA,
			DATA_ACK,
			STOP
		} state_t;
	
	state_t state, next_state;

	logic sda_out;
	logic sda_oe;
	logic [2:0] data_bit, addr_bit;
	logic [7:0] addr_reg, data_reg;
	logic [6:0] my_addr = 7'b0000001;
	logic rw; //whether to read or write coming from master
	
	
	assign SDA = sda_oe ? sda_out : 1'bz;

	always_ff @(posedge SCL)
	begin
		if (!rst_n)
		begin
			state <= IDLE;
			data_bit <= 0;
			addr_bit <= 0;
			data_out <= 0;
			sda_oe <= 0;
			sda_out <= 1;
		end

		else
			state <= next_state;
	end
	
	always_ff @(posedge SCL)
	begin
		case (state)
			ADDR_RX: begin
				addr_reg[addr_bit] <= SDA;

				if (addr_bit == 0)
					state <= ADDR_ACK;
				else 
				begin
					addr_bit = addr_bit - 1;
					state <= ADDR_RX;
				end
			end

			SEND_DATA: begin
				sda_oe <= 1;
				sda_out <= data_in[7];

				if (data_bit == 7)
					data_reg == data_in;

				if (SCL == 0)
				begin
					data_reg = data_reg << 1;
					if (data_bit == 0)
						state <= DATA_ACK;

					else
					begin
						data_bit = data_bit - 1;
						state = SEND_DATA;
					end
						
				end
			end

			RECEIVE_DATA: begin
				sda_oe <= 0;
				
				if (SCL == 1)
				begin
					data_reg[data_bit] <= SDA;

					if (data_bit == 0)
					begin
						data_out <= data_reg;
						next_state <= DATA_ACK;
					end

					else
					begin
						data_bit <= data_bit - 1;
						next_state <= RECEIVE_DATA;
					end
				end
			end

			DATA_ACK: begin
				sda_oe <= 1;
				sda_out <= 0;
			end
		endcase
	end

	always_combo
	begin
		sda_out = 1;
		sda_oe = 0;
		busy = 0;
		next_state = state;

		case(state)
			IDLE: begin
				if (SDA == 0 && SCL == 1)
					state = START;
			end

			START: begin
				data_bit = 7;
				addr_bit = 7;
				busy = 1;
				next_state = ADDR_RX;
			end

			ADDR_ACK: begin
				if (addr == my_addr)
				begin
					sda_oe = 1;
					sda_out = 0; //acknowledge

					if (addr[0] == 0) //master writing to subordinate
						state = RECEIVE_DATA;
					
					elseif (addr[0] == 1) //master reading from subordinate
						state = SEND_DATA;
				end
			end
		endcase
	end

endmodule
