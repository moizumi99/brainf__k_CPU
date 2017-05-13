module brainfuck( 
				  // input 			clk, rst, s_rst,
				  input 			clk, rst, // clk and async signals
				  input 			s_rst,
				  output reg [11:0] pc, 
				  output reg 		op_r_req, 
				  input [7:0] 		op, 
				  input 			op_den, 
				  output reg [11:0] dp_adr, 
				  output reg [15:0] data_out, 
				  output reg 		data_w_req, 
				  output reg 		data_w_sel, 
				  input 			data_w_wait, 
				  input [15:0] 		data_in, 
				  output 			data_r_req,
				  output reg 		data_r_sel, 
				  input 			data_den
				  );
   reg [11:0] 	 pc_reg, pc_nxt;
   reg 			 data_r_req_reg;
   reg 			 mov; // mov: 0, regular operation, 1: [ or ]
   reg 			 loop; // go back to [ from ]
   reg [11:0] 	 p_cnt; //  number of parenthesis skipped
   
   reg [5:0] 	 cur_state, nxt_state; // state machine
   reg [7:0] 	 cur_op;
   parameter INIT = 6'b00000, MEMI = 6'b000001, IDLE = 6'b000010, FETCH = 6'b000100, MEMR = 6'b001000, MEMW = 6'b010000, HLT = 6'b100000;
   
   
   reg 			 pc_inc, pc_dec;
   wire 		 mread, mwrite;
   reg [11:0] 	 mem_cnt;
   reg [11:0] 	 init_cnt;
   localparam MEM_MAX = 12'hfff;
   localparam INIT_WAIT = 12'd4;

   reg [11:0] 	 stack[63:0];
   reg [5:0] 	 sp;

   integer 		 i;
   
   
   // init_cnt
   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 init_cnt <= 0;
	  end
	  else if (s_rst) begin
		 init_cnt <= 0;
	  end
	  else if (init_cnt<INIT_WAIT) begin
		 init_cnt <= init_cnt + 12'b1;
	  end
   end
   
   // memory clear
   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 mem_cnt <= 0;
	  end
	  else if (s_rst) begin
		 mem_cnt <= 0;
	  end
	  else if (cur_state==MEMI) begin
		 mem_cnt <= mem_cnt + 12'b1;
	  end
   end // always @ (posedge clk or posedge rst)
      
   // state machine 
   always @(posedge clk or posedge rst) begin
      if (rst)
		cur_state <= INIT;
      else if (s_rst)
		cur_state <= INIT;
	  else
		cur_state <= nxt_state;
   end
   
   // state machine next state
   always @(cur_state or op_den or mread or data_den or s_rst or init_cnt or mem_cnt or data_w_wait or cur_op) begin
	  if (s_rst)
		nxt_state <= INIT;
	  else begin
		 case (cur_state)
		   INIT:
			 if (init_cnt == INIT_WAIT)
			   nxt_state <= MEMI;
			 else
			   nxt_state <= INIT;
		   MEMI:
			 if (mem_cnt == MEM_MAX)
			   nxt_state <= IDLE;
			 else
			   nxt_state <= MEMI;
		   IDLE:
			 nxt_state <= FETCH;
		   FETCH:        
			 if (op_den == 1) // Next ope code came in
			   nxt_state <= MEMR;
			 else
			   nxt_state <= FETCH;
		   MEMR:
			 if (mread==0 | data_den == 1'b1)
			   nxt_state <= MEMW;
			 else
			   nxt_state <= MEMR;
		   MEMW:
			 if (cur_op == 0)
			   nxt_state <= HLT;
			 else if (data_w_wait==0)
			   nxt_state <= FETCH;
			 else
			   nxt_state <= MEMW;
		   default: nxt_state <= HLT; // HALT
		 endcase // case (cur_state)
	  end // else: !if(s_rst)
   end
   
   // pc change
   always @(posedge clk or posedge rst) begin
	  if (rst)
		pc_reg <= 0;
	  else if (s_rst)
		pc_reg <= 0;
	  else
		pc_reg <= pc_nxt;
   end
   
   always @(pc_inc or pc_dec or pc_reg or sp) begin
      if (pc_inc==0 & pc_dec==1)
		pc_nxt <= stack[sp];
      else if (pc_inc==1 & pc_dec==0)
		pc_nxt <= pc_reg + 12'b1;
      else
		pc_nxt <= pc_reg;
   end
   
   // pc_read
   always @(pc_inc or pc_dec or pc_nxt or pc_reg) begin
      op_r_req <= pc_inc | pc_dec;
      if (pc_inc | pc_dec)
		pc <= pc_nxt;
      else
		pc <= pc_reg;
   end
   
   // Decoder for [ & ]
   always @(posedge clk or posedge rst) begin
      if (rst)
		begin
           mov <= 0;
           p_cnt <= 0;
		end
	  else if (s_rst)
		begin
           mov <= 0;
           p_cnt <= 0;
		end
      else if (cur_state==MEMR)
		begin
		   if (mov == 1)
			 begin
				if       (cur_op==8'h5B)
				  p_cnt <= p_cnt+12'b1;
				else if (cur_op==8'h5D & p_cnt==0)
        		  mov <= 0;
				else if (cur_op==8'h5D)
				  p_cnt = p_cnt-12'b1; 
			 end
		   else if (data_den == 1'b1 & cur_op==8'h5B & data_in==0)
			 begin
				mov <= 1;
				p_cnt <= 0;
			 end
		   else if (data_den == 1'b1 & cur_op==8'h5D & data_in!=0)
			 mov <= 0;
		end // if (cur_state==MEMR)
   end // always @ (posedge clk or posedge rst)

   always @(posedge clk or posedge rst) begin
      if (rst)
		begin
		   loop <= 0;
		end
	  else if (s_rst)
		begin
		   loop <= 0;
		end
      else if (cur_state==MEMR)
		if (mov==0 & data_den == 1'b1 & cur_op==8'h5D & data_in!=0)
		  loop <= 1;
		else
		  loop <= 0;
	  else if (cur_state==FETCH)
		loop <= 0;
   end // always @ (posedge clk or posedge rst)
   
   // decoder for PC change  
   always @(cur_state or mov or loop) begin
      case (cur_state)
		IDLE:
          begin
			 pc_inc <= 1;
			 pc_dec <= 1;
          end
		MEMW:
          begin
			 pc_inc <= (loop) ? 1'b0 : 1'b1;
			 pc_dec <= (loop) ? 1'b1 : 1'b0;
          end
		default:
          begin
			 pc_inc <= 0;
			 pc_dec <= 0;
          end
      endcase
   end  
   
   always @(posedge clk or posedge rst) begin
      if (rst)
		cur_op <= 8'd0;
	  else if (s_rst)
		cur_op <= 8'd0;
      else if (cur_state==FETCH & op_den==1)
		cur_op <= op;
   end
   
   // dp_adr
   always @(posedge clk or posedge rst) begin
      if (rst)
		dp_adr <= 0;
	  else if (s_rst)
		dp_adr <= 0;
	  else if (cur_state==MEMI)
		dp_adr <= mem_cnt;
	  else if (cur_state==IDLE)
		dp_adr <= 0;
      else if (cur_state==MEMR & mov==0 & cur_op==8'h3C)
		dp_adr <= dp_adr - 12'h1;
      else if (cur_state==MEMR & mov==0 & cur_op==8'h3E)
		dp_adr <= dp_adr + 12'h1;
   end
   
   // data_r_req
   always @(posedge clk or posedge rst) begin
      if (rst)
		data_r_req_reg <= 0;
	  else if (s_rst)
		data_r_req_reg <= 0;
      else if (cur_state==FETCH & nxt_state==MEMR & mread)
		data_r_req_reg <= 1;
      else if (cur_state==MEMR & nxt_state==MEMR)
		data_r_req_reg <= 1;
      else
		data_r_req_reg <= 0;
   end
   assign data_r_req = (cur_state==FETCH & nxt_state==MEMR & mread) | data_r_req_reg;
   
   assign mread = (mov==0 & (op==8'h2B | op==8'h2C | op==8'h2D | op==8'h2E | op==8'h5B | op==8'h5D)) ? 1'b1 : 1'b0;
//   assign mread = (mov==0 & op!=8'h2C) ? 1'b1 : 1'b0;
   
   // data read
   always @(posedge clk or posedge rst) begin
      if (rst)
		data_out <= 0;
	  else if (s_rst)
		data_out <= 0;
      else
		if (nxt_state==MEMI)
		  data_out <= 0;
		else if (mov==1)
          data_out <= data_out; // no operation. Just for readability
		else if (cur_state==MEMR & data_den==1 & cur_op==8'h2B) // +
          data_out <= data_in + 16'b1;
		else if (cur_state==MEMR & data_den==1 & cur_op==8'h2D)  // -
          data_out <= data_in - 16'b1;
		else if (cur_state==MEMR & data_den==1)
          data_out <= data_in;
   end
   
   // data_r_sel
   always @(posedge clk or posedge rst) begin
      if (rst)
		data_r_sel <= 0;
	  else if (s_rst)
		data_r_sel <= 0;
      else if (cur_state==FETCH & op_den==1 & op==8'h2C)
		data_r_sel <= 1;
      else if (cur_state==FETCH & op_den==1)
		data_r_sel <= 0;
   end
   
   // write the data
   always @(posedge clk or posedge rst) begin
      if (rst)
		data_w_req<=0;
	  else if (cur_state==MEMI)
		data_w_req<=1;
      else if (nxt_state == MEMW)
        data_w_req <= mwrite;
	  else 
        data_w_req <= 0;
   end
   
   assign mwrite = (mov==0 & (cur_op==8'h2B | cur_op==8'h2D | cur_op==8'h2E)) ? 1'b1 : 1'b0;
   
   // data_w_sel
   always @(posedge clk or posedge rst) begin
      if (rst)
		data_w_sel <= 0;
	  else if (s_rst)
		data_w_sel <= 0;
	  else if (cur_state==MEMI)
		data_w_sel <= 0;
      else if (cur_state==FETCH & op_den==1 & op==8'h2E)
		data_w_sel <= 1;
      else if (cur_state==FETCH & op_den==1)
		data_w_sel <= 0;
   end

   // Stack for loop
   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 sp <= 12'h0;
		 for(i=0; i<64; i=i+1) begin
			stack[i] <= 12'h0;
		 end
	  end
	  else if (s_rst)
		sp <= 12'h0;
	  else if (cur_state==MEMR) begin
		if (op==8'h5B) begin
		   stack[sp] <= pc_reg;
		   sp <= sp + 5'h1;
		end
		else if (op==7'h5D ) begin
		   sp <= sp - 5'h1;
		end
	  end
   end // always @ (posedge clk or posedge rst)
   
endmodule

