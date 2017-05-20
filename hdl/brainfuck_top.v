module brainfuck_top(
					 input 		 clk, rst_n,
					 output 	 LCD_BLON, //	LCD Back Light ON/OFF
					 output 	 LCD_RW, //	LCD Read/Write Select, 0 = Write, 1 = Read
					 output 	 LCD_EN, //	LCD Enable
					 output 	 LCD_RS, //	LCD Command/Data Select, 0 = Command, 1 = Data
					 inout [7:0] LCD_DATA, //	LCD Data bus 8 bits
					 input [7:0] key_in,
					 input 		 key_d_en 		 
					 );

   wire [31:0] 					 op;
   reg 							 op_en;
   wire [11:0] 					 dp;
   wire [15:0] 					 d_o;
   wire 						 w_en, w_sel, w_wait;
   wire [15:0] 					 d_i;
   wire 						 r_en, d_en, r_sel;
   wire 						 ram_w_en, ram_r_en;
   reg 							 ram_d_en;
   wire [15:0] 					 ram_d_i;
   wire 						 s_rst;
   
   
   wire 						 rst;
   reg 							 lcd_wen;
   reg [8:0] 					 lcd_wdt;
   wire 						 lcd_status;
   wire [9:0] 					 pc;
   wire 						 pc_r;

   assign rst = !rst_n;
   
   brainfuck bf( .clk(clk), .rst(rst), .s_rst(s_rst),
                 .pc(pc), .op_r_req(pc_r), .op(op),  .op_den(op_en), 
                 .dp_adr(dp), .data_out(d_o), .data_w_req(w_en), .data_w_sel(w_sel), .data_w_wait(w_wait),
                 .data_in(d_i), .data_r_req(r_en), .data_r_sel(r_sel), .data_den(d_en)
                 );

   
   
   LCDCONTROL lcd(.CLK(clk), .RST(rst), .WRITE(lcd_wen), .WRDATA(lcd_wdt), .STATUS(lcd_status),
				  .LCD_BLON(LCD_BLON), .LCD_RW(LCD_RW), .LCD_EN(LCD_EN), .LCD_RS(LCD_RS), .LCD_DATA(LCD_DATA)
				  );

   wire [8:0] 					 cmd_in;
   reg [8:0] 					 cmd [31:0];
   reg [5:0] 					 cmd_len;
   wire 						 cmd_st, cmd_busy, cmd_en;
   integer 						 ci;
						 
   
   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 cmd[0] <= 9'h38;
		 cmd[1] <= 9'h0c;
		 cmd[2] <= 9'h01;
		 cmd[3] <= 9'h06;
		 cmd[4] <= 9'h80;
		 for(ci=5; ci<32; ci=ci+1) begin
			cmd[ci] <= 0;
		 end
		 cmd_len <= 6'd5;
	  end // if (rst)
	  else begin
		 if (cmd_st) begin
			for(ci=0; ci<31; ci=ci+1) begin
			   cmd[ci] <= cmd[ci+1];
			end
			if (cmd_en) begin
			   cmd[cmd_len-6'h1] <= cmd_in;
			end
			else begin
			   cmd_len <= cmd_len - 6'h1;
			end
		 end
		 else if (cmd_len < 6'd32 & cmd_en==1) begin
			cmd[cmd_len] <= cmd_in;
			cmd_len <= cmd_len + 6'h1;
		 end
	  end // else: !if(rst)
   end // always @ (posedge clk or posedge rst)
      
   assign cmd_st = (cmd_len>0 & cmd_busy==0);
   assign cmd_busy = lcd_status | lcd_wen;
   assign cmd_in = {1'b1, d_o[7:0]};
   assign cmd_en = (w_en & w_sel) ? 1'b1 : 1'b0;
   assign w_wait = (w_sel & cmd_len >= 6'h32) ? 1'b1 : 1'b0;

   always @(posedge clk or posedge rst) begin
	  if (rst) begin
		 lcd_wen <= 0;
		 lcd_wdt <= 0;
	  end
	  else begin
		 if (cmd_st) begin
			lcd_wen <= 1;
			lcd_wdt <= cmd[0];
		 end
		 else begin
			lcd_wen <= 0;
		 end
	  end // else: !if(rst)
   end // always @ (posedge clk or rst)
   
   
   // program memory
   drom32	drom_inst ( .address ( pc ), .clock ( clk ), .q ( op ) );   
   
   // data memory
   dmem16 dmem_inst (.address ( dp ),	.clock ( clk ), .data ( d_o ), .wren ( ram_w_en ), .q ( ram_d_i ));

   assign ram_w_en = (w_sel==0) ? w_en : 1'b0;
   assign ram_r_en = (r_sel==0) ? r_en : 1'b0;
   assign d_en = (r_sel==0) ? ram_d_en : key_d_en;
   assign d_i  = (r_sel==0) ? ram_d_i : {8'h0, key_in};
   assign s_rst = 0;

   always @(posedge clk or posedge rst) begin
	  if (rst)
		op_en  <= 0;
	  else
		op_en  <= pc_r;
   end
   
   always @(posedge clk or posedge rst) begin
      if (rst)
		ram_d_en <= 0;
      else
		ram_d_en <= ram_r_en;
   end

endmodule // brainfuck_top

