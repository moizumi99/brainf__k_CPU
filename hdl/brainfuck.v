
module brainfuck
  #( parameter AWIDTH = 12, DWIDTH = 16, PWIDTH = 10)
   // AWIDTH: Data address bits
   // DWIDTH: Data bits
   // PWIDTH: Program counter bits
   ( 
	 input 					 clk, rst, // clk and async reset
	 input 					 s_rst, // clocked reset
	 output [PWIDTH-1:0] 	 pc, 
	 output 				 op_r_req, 
	 input [31:0] 			 op, 
	 input 					 op_den, // ignored for now assuming SRAM
	 output reg [AWIDTH-1:0] dp_adr, 
	 output reg [DWIDTH-1:0] data_out, 
	 output reg 			 data_w_req, 
	 output reg 			 data_w_sel, 
	 input 					 data_w_wait, // ignored for now assuming SRAM
	 input [DWIDTH-1:0] 	 data_in, 
	 output reg 			 data_r_req,
	 output reg 			 data_r_sel, 
	 input 					 data_den // this does not stall operation. if 0, input is invalid
	 );

   // opecode
   // brainfuck operation code
   // 8'h2B: +
   // 8'h2C: ,
   // 8'h2D: -
   // 8'h2E: .
   // 8'h3C: <
   // 8'h3E: >
   // 8'h5B: [
   // 8'h5D: ]
   parameter OP_PLUS = 8'h2B, OP_DIN = 8'h2c, OP_MINUS = 8'h2D, OP_DOUT = 8'h2E;
   parameter OP_LEFT = 8'h3C, OP_RIGHT = 8'h3E, OP_LOOP_ST = 8'h5B, OP_LOOP_END = 8'h5D, OP_HLT = 8'h00;
   parameter CMD_NOP   = 3'b000;
   parameter CMD_PLUS  = 3'b010;
   parameter CMD_RIGHT = 3'b001;
   parameter CMD_DIN   = 3'b011;
   parameter CMD_DOUT  = 3'b100;
   parameter CMD_LST   = 3'b101;
   parameter CMD_LEND  = 3'b110;
   parameter CMD_HLT   = 3'b111;
   
   // Initialization
   localparam MEM_MAX = {AWIDTH{1'b1}};
   localparam INIT_WAIT = 4;
   reg [AWIDTH-1:0]    init_cnt;
   reg [AWIDTH-1:0]    mem_cnt;
   
   // high level state machine
   parameter INIT = 4'b0000, MEMI = 4'b0001, PREFETCH = 4'b0010, OPR = 4'b0100, HLT = 4'b1000;
   reg [4:0] 		   cur_state;
   reg [4:0] 		   nxt_state;
   reg 				   hlt_en;

   // pipeline operation
   wire [2:0] 		   cmd_0st;  // Fetch, address change, get operation (op), change dp_adr, 
   reg [2:0] 		   cmd_1st;  // Execute dp_adr change take effect, , dat change
   reg [2:0] 		   cmd_2nd;  // MEM data memory read/write
   wire [3:0] 		   val_0st;
   reg [3:0] 		   val_1st;
   reg [DWIDTH-1:0]    dat;   // copy of *dp
   wire [DWIDTH-1:0]   dat_new;
   wire [DWIDTH-1:0]   dat_tgt; // target of execution
   reg [PWIDTH+1:0]    pc_reg;
   wire [2:0] 		   pc_inc;
   wire [PWIDTH+1:0]   pc_cur;
   wire [PWIDTH+1:0]   pc_nxt;
   wire [PWIDTH+1:0]   pc_prefetch;
   wire 			   pc_dly;
   reg 				   pc_mov; // move o the next ']'
 			   

   // stack for loop
   localparam SDEPTH = 6;
   reg [PWIDTH+1:0]    stack[(1<<SDEPTH)-1:0];
   reg [SDEPTH-1:0]    sp;
   integer 			   i;
   reg [SDEPTH-1:0]    jmp_cnt; // count the number of [ and ] for forward jump

   // data
   wire [DWIDTH-1:0]   dat_fwd; // data forward from memory read block
   reg 				   data_r_sel_z;  // is the current data from memory (0) or from input (1)?
   
   // fetch and decode
   wire [31:0] 		   op_le; // convert to little endian
   wire 			   op_r_req_cur;
   reg 				   op_r_req_z;
//   reg [PWIDTH+1:0]  pc_z;
   wire [1:0] 		 index;
   wire [63:0] 		 op64; // history of up to 8 commands
   wire [31:0] 		 op32; // current 4 commands
   wire [7:0] 		 ops[3:0]; // current 4 commands in 8 bit form
   wire [5:0] 		 opc[3:0]; // decoded 4 opecodes (2bit val + 3bit cmd)
   wire [2:0] 		 cmd[3:0]; // decoded 4 commands // upper 3 bits of opecode
   wire [2:0] 		 cmd0; // the first meaningful command (skip nop)
   wire [3:0] 		 val0[3:0]; // +1 for + and >, -1 for - and <, 0 for the rest. Bits extended for later calc
   wire [3:0] 		 val[3:0]; // val0 masked by executed command (only +- seriese or <> series are executed at once)
   wire [3:0] 		 vals; // sum of val[]
   reg [31:0] 		 op_z;
   wire 			 val0_plus_en, val1_plus_en, val2_plus_en, val3_plus_en;
   wire 			 val0_right_en, val1_right_en, val2_right_en, val3_right_en;
   wire 			 cmd0_nop, cmd1_nop, cmd2_nop, cmd3_nop;
      
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
   always @(cur_state or s_rst or init_cnt or mem_cnt or pc_dly or cmd0 or dat_new or hlt_en) begin
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
			   nxt_state <= PREFETCH;
			 else
			   nxt_state <= MEMI;
		   PREFETCH:
			 nxt_state <= OPR;
		   OPR:
			 if (pc_dly==0 & cmd0==CMD_LEND & dat_new!=0) // jump
			   nxt_state <= PREFETCH;
			 else if (hlt_en)
			   nxt_state <= HLT;
			 else
			   nxt_state <= OPR;
		   default: nxt_state <= HLT; // HALT
		 endcase // case (cur_state)
	  end // else: !if(s_rst)
   end // always @ (cur_state or s_rst or init_cnt or mem_cnt or hlt_en)

   //
   // pipeline processing
   //


   //
   // Decoder
   //
   
   // PC change
   // pc points to the program counter of the 1st stage of pipeline
   always @(posedge clk or posedge rst) begin
	  if (rst)
		pc_reg <= 0;
	  else if (s_rst)
		pc_reg <= 0;
	  else if (cur_state == OPR)
		pc_reg <= pc_nxt;
	  // in prefetch, pc_reg is not updated
   end // always @ (posedge clk or posedge rst)

   assign pc_cur = pc_reg;
   assign pc_nxt = (cur_state!=OPR) ? pc_reg :
				   (pc_dly) ? pc_reg :
				   (cmd0 == CMD_LEND & dat_new!=0) ? stack[sp-1] : pc_reg + pc_inc;

   assign pc_prefetch = pc_nxt + 12'h4;
   assign pc = (nxt_state==PREFETCH) ? pc_nxt[PWIDTH+1:2] : pc_prefetch[PWIDTH+1:2];

//   assign op_le = {op[7:0], op[15:8], op[23:16], op[31:24]};
   assign op_le = op;
   assign op64 = {op_le, op_z};
   assign op32 = (index==2'b00) ? op64[31: 0] :
				 (index==2'b01) ? op64[39: 8] :
				 (index==2'b10) ? op64[47:16] : op64[55:24];
   
   assign ops[0] = op32[ 7: 0];
   assign ops[1] = op32[15: 8];
   assign ops[2] = op32[23:16];
   assign ops[3] = op32[31:24];   
   
   assign index = pc_cur[1:0]; // sub pointer

   always @(posedge clk or posedge rst) begin
	  if (rst)
		op_z <= {4{8'h20}};
	  else if (s_rst)
		op_z <= {4{8'h20}};
	  else if (op_r_req)
		op_z <= op_le;
   end

   function [4:0] decode;
	  input [7:0] opcode;
	  decode = (opcode == OP_PLUS    ) ? {2'b01, CMD_PLUS} :
			   (opcode == OP_MINUS   ) ? {2'b11, CMD_PLUS} :
			   (opcode == OP_RIGHT   ) ? {2'b01, CMD_RIGHT} :
			   (opcode == OP_LEFT    ) ? {2'b11, CMD_RIGHT} :
			   (opcode == OP_DIN     ) ? {2'b00, CMD_DIN} :
			   (opcode == OP_DOUT    ) ? {2'b00, CMD_DOUT} :
			   (opcode == OP_LOOP_ST ) ? {2'b00, CMD_LST} :
			   (opcode == OP_LOOP_END) ? {2'b00, CMD_LEND} :
			   (opcode == OP_HLT     ) ? {2'b11, CMD_HLT} : {2'b00, CMD_NOP};
   endfunction // decode

   assign opc[0] = decode(ops[0]);
   assign opc[1] = decode(ops[1]);
   assign opc[2] = decode(ops[2]);
   assign opc[3] = decode(ops[3]);
   
   assign cmd[0] = opc[0][2:0];
   assign cmd[1] = opc[1][2:0];
   assign cmd[2] = opc[2][2:0];
   assign cmd[3] = opc[3][2:0];
   
   assign val0[0] = {{2{opc[0][4]}}, opc[0][4:3]}; 
   assign val0[1] = {{2{opc[1][4]}}, opc[1][4:3]};
   assign val0[2] = {{2{opc[2][4]}}, opc[2][4:3]};
   assign val0[3] = {{2{opc[3][4]}}, opc[3][4:3]};

   assign val0_plus_en = (cmd[0]==CMD_PLUS);
   assign val1_plus_en = (cmd[1]==CMD_PLUS) & (val0_plus_en);
   assign val2_plus_en = (cmd[2]==CMD_PLUS) & (val1_plus_en);
   assign val3_plus_en = (cmd[3]==CMD_PLUS) & (val2_plus_en);
   
   assign val0_right_en = (cmd[0]==CMD_RIGHT);
   assign val1_right_en = (cmd[1]==CMD_RIGHT) & (val0_right_en);
   assign val2_right_en = (cmd[2]==CMD_RIGHT) & (val1_right_en);
   assign val3_right_en = (cmd[3]==CMD_RIGHT) & (val2_right_en);
   
   assign val[0] = (val0_plus_en | val0_right_en) ? val0[0] : 4'b0000;
   assign val[1] = (val1_plus_en | val1_right_en) ? val0[1] : 4'b0000;
   assign val[2] = (val2_plus_en | val2_right_en) ? val0[2] : 4'b0000;
   assign val[3] = (val3_plus_en | val3_right_en) ? val0[3] : 4'b0000;

   assign vals = val[0] + val[1] + val[2] + val[3];

   assign cmd0_nop = (cmd[0]==CMD_NOP);
   assign cmd1_nop = (cmd[1]==CMD_NOP) & (cmd0_nop);
   assign cmd2_nop = (cmd[2]==CMD_NOP) & (cmd1_nop);
   assign cmd3_nop = (cmd[3]==CMD_NOP) & (cmd2_nop);
   
   assign pc_inc = (val3_plus_en | val3_right_en | cmd3_nop) ? 4'h4 :
				   (val2_plus_en | val2_right_en | cmd2_nop) ? 4'h3 :
				   (val1_plus_en | val1_right_en | cmd1_nop) ? 4'h2 : 4'h1;
   // find the first command
   assign cmd0  = cmd[0];
   
   assign cmd_0st = (cur_state!=OPR | pc_dly | pc_mov) ? CMD_NOP : cmd0; // insert nop (8'h20) when delaying or moving to next ']'
   assign val_0st = vals;
   
   // delay by one clock if the previous operation is reading from memory
   assign pc_dly = ((cmd0==CMD_LEND | cmd0==CMD_LST) & (cmd_1st==CMD_RIGHT | cmd_1st==CMD_RIGHT | cmd_1st==CMD_DIN));
   assign op_r_req_cur = (nxt_state==PREFETCH) ? 1 :
						 (cur_state==PREFETCH) ? 1 :
						 (cur_state==OPR & pc_reg[PWIDTH+1:2] != pc_nxt[PWIDTH+1:2]) ? 1 : 0;

   assign op_r_req = op_r_req_cur;
   always @(posedge clk or posedge rst) begin
	  if (rst)
		op_r_req_z <= 0;
	  else if (s_rst)
		op_r_req_z <= 0;
	  else
		op_r_req_z <= op_r_req_cur;
   end
   

   always @(posedge clk or posedge rst) begin
	  if (rst)
		hlt_en <= 0;
	  else if (s_rst)
		hlt_en <= 0;
	  else if (cur_state==OPR & op==8'h00) // regard 00 as halt operation
		hlt_en <= 1;
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
	  else begin
		if (cmd_0st==CMD_LST & dat_new!=0) begin
		   stack[sp] <= pc_nxt;
		   sp <= sp + 5'h1;
		end
		else if (cmd_0st==CMD_LEND & dat_new==0) begin
		   sp <= sp - 5'h1;
		end
	  end
   end // always @ (posedge clk or posedge rst)

   // jmp to next [
   always @(posedge clk or posedge rst) begin
	  if (rst)
		pc_mov <= 0;
	  else if (s_rst | cur_state!=OPR)
		pc_mov <= 0;
	  else begin
		 if (cmd_0st==CMD_LST & dat_new==0)
		   pc_mov <= 1;
		 else if (cmd0==CMD_LEND & jmp_cnt==0) // this has to be op
		   pc_mov <= 0;
	  end
   end // always @ (posedge clk or posedge rst)

   // count ther number of [(+1) and ](-1)
   always @(posedge clk or posedge rst) begin
	  if (rst)
		jmp_cnt <= 0;
	  else if (s_rst | cur_state!=OPR)
		jmp_cnt <= 0;
	  else begin
		 if (!pc_mov)
		   jmp_cnt <= 0;
		 else if (cmd0==CMD_LST[2:0])
		   jmp_cnt <= jmp_cnt + 1;
		 else if (cmd0==CMD_LEND[2:0] & jmp_cnt!=0)
		   jmp_cnt <= jmp_cnt - 1;
	  end
   end // always @ (posedge clk or posedge rst)
   
   // opecode
   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 cmd_1st <= 0;
		 val_1st <= 0;
	  end
	  else if (s_rst | cur_state!=OPR) begin
		 cmd_1st <= 0;
		 val_1st <= 0;
	  end
	  else begin
		 cmd_1st <= cmd_0st;
		 val_1st <= val_0st;
	  end
   end // always @ (posedge clk or posedge rst)

   //
   // Exec
   // 
   // dp_adr
   always @(posedge clk or posedge rst) begin
	  if (rst)
		dp_adr <= 0;
	  else if (s_rst)
		dp_adr <= 0;
	  else if (cur_state==MEMI)
		dp_adr <= mem_cnt;
	  else if (cur_state==OPR) begin
		if (cmd_0st==CMD_RIGHT)
		  dp_adr <= dp_adr + {{8{val_0st[3]}}, val_0st[3:0]};
	  end
   end // always @ (posedge clk or posedge rst)

   // generate read/write
   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 data_w_req <= 0;
		 data_w_sel <= 0;
		 data_r_req <= 0;
		 data_r_sel <= 0;
	  end
	  else if (s_rst) begin
		 data_w_req <= 0;
		 data_w_sel <= 0;
		 data_r_req <= 0;
		 data_r_sel <= 0;
	  end
	  else if (cur_state==MEMI) begin
		 data_w_req <= 1;
		 data_w_sel <= 0;
		 data_r_req <= 0;
		 data_r_sel <= 0;
	  end
	  else if (cur_state==OPR) begin
		 case (cmd_0st)
		   CMD_RIGHT: begin
			  data_w_req <= 0;
			  data_w_sel <= 0;
			  data_r_req <= 1;
			  data_r_sel <= 0;
		   end
		   CMD_PLUS: begin
			  data_w_req <= 1;
			  data_w_sel <= 0;
			  data_r_req <= 0;
			  data_r_sel <= 0;
		   end
		   CMD_DIN: begin
			  data_w_req <= 1;
			  data_w_sel <= 0;
			  data_r_req <= 1;
			  data_r_sel <= 1;
		   end
		   CMD_DOUT: begin
			  data_w_req <= 1;
			  data_w_sel <= 1;
			  data_r_req <= 0;
			  data_r_sel <= 0;
		   end
		   default: begin
			  data_w_req <= 0;
			  data_w_sel <= 0;
			  data_r_req <= 0;
			  data_r_sel <= 0;
		   end
		 endcase // case (cmd_0st)
	  end // else: !if(s_rst | cur_state!=OPR)
	  else begin
		 data_w_req <= 0;
		 data_w_sel <= 0;
		 data_r_req <= 0;
		 data_r_sel <= 0;
	  end // else: !if(cur_state==OPR)
   end // always @ (posedge clk or posedge rst)
   
   // dat (internal data cache) update
   always @(posedge clk or posedge rst) begin
	  if (rst)
		dat <= 0;
	  else if (s_rst)
		dat <= 0;
	  else
		dat <= dat_new;
   end

   assign dat_tgt = (cmd_2nd==CMD_RIGHT | cmd_2nd==CMD_RIGHT | cmd_2nd==CMD_DIN) ? dat_fwd : dat;
   assign dat_new = (cmd_1st==CMD_PLUS) ? dat_tgt+{{12{val_1st[3]}}, val_1st[3:0]} : dat_tgt;
   // output   
   always @(dat_new) begin
	 data_out <= dat_new;
   end
   
   //
   // MEM Block
   //
   // memory read and write take effect
   // read data is forwarded to dat_tgt

   // opecode
   always @(posedge clk or posedge rst) begin
	  if (rst)
		 cmd_2nd <= 0;
	  else if (s_rst | cur_state!=OPR)
		 cmd_2nd <= 0;
	  else
		 cmd_2nd <= cmd_1st;
   end // always @ (posedge clk or posedge rst)
   
   // if the previous operation is <, >, or , use the input as the target of operation
   assign dat_fwd = (!data_r_sel_z & !data_den) ? 0 : data_in; // if data_den==0 and data is from outside (not memory), replace it with zero
   
   always @(posedge clk or posedge rst) begin
	  if (rst)
		data_r_sel_z <= 0;
	  else if (s_rst)
		data_r_sel_z <= 0;
	  else
		data_r_sel_z <= data_r_sel;
   end

   
endmodule

