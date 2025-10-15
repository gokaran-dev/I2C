//I2C Master Module, work in progress.
//0------> ACK
//1------> NACK
//next_byte logic is not implemented yet. Thinking of making this a parameter.

`timescale 1ns/1ps

module I2C_master (
	input  logic clk_400,
	input  logic rst_n,
	input  logic rw,
	input  logic start_txn,
	input  logic next_byte, //currently testing only for 1 byte of data
	input  logic [6:0] sub_addr,
	input  logic [7:0] data_in, //data we are sending to subordinate
	output logic [7:0] data_out, //data we are reading from subordinate
	output logic data_ready,
	output logic busy,
	output logic done,
	output logic ack_error,
	output logic SCL,
	inout  tri   SDA
	);

	logic [7:0] addr_reg, data_reg;
	
	logic scl_en, scl_reg;
	logic sda_oe, sda_out;

	logic [2:0] addr_bit = 7; 
	logic [2:0] data_bit = 7;

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

		
	//generation of SCL using a clk_400 which will be a 400KHz clock
	//derieved using IPs
	
	//SCL generation
	always_ff @(posedge clk_400)
	begin
		if (!rst_n)
		begin
			scl_reg <= 1; //At ideal SCL is pulled HIGH
		end
		
		else if (!scl_en)
		begin
			scl_reg <= 1;
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
			data_bit <= 7;
			scl_en <= 0;
		end

		case (state)  
		    IDLE: begin
		      sda_out <= 1;
		      sda_oe  <= 1;
		      scl_en <= 0;
		      busy <= 0;
		      done <= 0;
		    end 
		    
		    START: begin
		        busy <= 1;
		    	sda_out <= 0;
				sda_oe <= 1; 
				scl_en <= 1;
		      	data_reg <= 0;
		      	addr_bit <= 7;
		      	data_bit <= 7; 
		    end
		    
			SEND_ADDR: begin
				sda_oe  <= 1;

				if (addr_bit == 7)
					addr_reg <= {sub_addr, rw}; 
	
				if (SCL == 0) //SDA is sampled only when SCL is low
				begin
					sda_out <= addr_reg[7];

					if (addr_bit != 0)
					begin
						addr_reg <= addr_reg << 1; //shift address reg left
						addr_bit <= addr_bit - 1;
					end
				end

			end
			
			WAIT_ACK_ADDR: begin
			   sda_oe = 0; //control is given to subordinate
			     
			   if (SCL == 1)
			   begin 
			         if (SDA == 0)
			         begin
			             if (rw == 1)
			                 data_bit <= 7;  
			         end
			         
			         else
			             ack_error <= 1;
			   end
			end

			SEND_DATA: begin
				sda_oe <= 1;

				if (data_bit == 7)
					data_reg <= data_in; 

				if (SCL == 0)
				begin
					sda_out <= data_reg[7];
					
                    if (data_bit != 0)
					begin
						data_reg <= data_reg << 1; //shift data reg left
						data_bit <= data_bit - 1;
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
                        data_ready <= 1;
                    end
                    
					else
					begin
						data_bit <= data_bit - 1;
					    data_ready <= 0;
					end
				end
			end
            
            WAIT_ACK_DATA: begin
                sda_oe <= 0;
            end
            
			MASTER_ACK: begin
				sda_oe <= 1;   //Master takes control of SDA
				sda_out <= 0; //acknowledge receiving of 1 byte.
                
                if (next_byte)
                    data_bit <= 7;
				end
				
			STOP: begin
			    sda_out <= 1;
				sda_oe <= 1;
				done <= 1;
				scl_en <= 0;
			
			end
				
			default: 
			     scl_en <= 0;
		endcase

	end

	//FSM for I2C
	always_comb
	begin
	    next_state = state;
	    
		case (state)
			IDLE: begin
				if (start_txn) 
					next_state = START;
			end

			START: begin
				next_state = SEND_ADDR;
			end
			
			SEND_ADDR: begin
			     if (addr_bit == 0)
					   next_state = WAIT_ACK_ADDR;
			
			end

			WAIT_ACK_ADDR: begin //subordinate acknowledgment
				if (SDA == 0) //acknowledgment received 
				begin
					if (rw == 0) 
						next_state = SEND_DATA;

					else 
					begin
						next_state = RECEIVE_DATA;
					end
				end

				else
				begin
					next_state = STOP;
				end
			end
			
			SEND_DATA: begin			
					if (data_bit == 0)
						next_state = WAIT_ACK_DATA;
			end
			
			RECEIVE_DATA: begin
			     if (data_bit == 0)
						next_state = MASTER_ACK;
			end
			
			WAIT_ACK_DATA: begin
				if (SDA == 0)
					next_state = SEND_DATA; //goes to send next byte if there is any

				else
				begin
					ack_error = 1;
					next_state = STOP;
				end
			end
			
			MASTER_ACK: begin
				if (SCL == 0)
				    begin
					   if (next_byte)
						  next_state = RECEIVE_DATA;
					 end
					 
			    if (!next_byte)
			         next_state = STOP;
			end

			STOP:
				next_state = IDLE;

			default:  
			    next_state = IDLE;
		endcase
	end
endmodule
