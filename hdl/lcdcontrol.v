module LCDCONTROL (
				   input 	   CLK, RST,
				   input 	   WRITE,
				   input [8:0] WRDATA,
				   output reg  STATUS,
				   output 	   LCD_BLON, //	LCD Back Light ON/OFF
				   output 	   LCD_RW, //	LCD Read/Write Select, 0 = Write, 1 = Read
				   output 	   LCD_EN, //	LCD Enable
				   output 	   LCD_RS, //	LCD Command/Data Select, 0 = Command, 1 = Data
				   inout [7:0] LCD_DATA							//	LCD Data bus 8 bits
				   );

   reg [8:0] 					 cmd;
   reg [4:0] 					 en_cnt;
   reg [17:0] 					 wait_cnt;
   wire 						 st;
   wire 						 busy;
   reg 							 rst_dly;
   reg [19:0] 					 dly_cnt;

   assign LCD_RW = 1'b0; // always write
   assign LCD_BLON = 1'b1; // Backlight on
   assign LCD_RS = cmd[8];
   assign LCD_DATA = cmd[7:0];
   assign LCD_EN = (en_cnt!=0) ? 1'b1 : 1'b0;

   assign st = (WRITE==1 && busy==0) ? 1'b1 : 1'b0;

   always @(posedge CLK or posedge RST)
	 begin
		if (RST) begin
		  dly_cnt <= 20'h0;
		   rst_dly <= 1'b1;
		end 
		else if (dly_cnt!=20'hFFFFF)
		  begin
			 dly_cnt <= dly_cnt + 20'h1;
			 rst_dly <= 1'b1;
		  end
		else
		  begin
			 rst_dly <= 1'b0;
		  end
	 end

   always @(posedge CLK or posedge RST)
	 begin
		if (RST)
		  cmd <= 9'h0;
		else if (rst_dly)
		  cmd <= 9'h0;
		else if (st)
		  cmd <= WRDATA[8:0];
	 end

   always @(posedge CLK or posedge RST)
	 begin
		if (RST)
		  en_cnt <= 5'h0;
		else if (rst_dly)
		  en_cnt <= 5'h0;
		else if (st)
		  en_cnt <= 5'h10;
		else if (en_cnt!=5'h0)
		  en_cnt <= en_cnt - 5'h1;
	 end

   always @(posedge CLK or posedge RST)
	 begin
		if (RST)
		  wait_cnt <= 18'h00000;
		else if (rst_dly)
		  wait_cnt <= 18'h00000;
		else if (en_cnt == 5'h1)
		  wait_cnt <= 18'h3FFFF; // this should be changed depending on the command
		else if (wait_cnt!=18'h0)
		  wait_cnt <= wait_cnt - 18'h1;
	 end

   assign busy = (en_cnt==5'h0 && wait_cnt==18'h0) ? 1'b0 : 1'b1;

   always @(posedge CLK or posedge RST)
	 begin
		if (RST)
		  STATUS <= 1'b1;
		else if (rst_dly)
		  STATUS <= 1'b1;
		else
		  STATUS <= st | busy;
	 end

endmodule


