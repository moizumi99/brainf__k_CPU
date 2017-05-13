`timescale 1ps/1ps

module brainfuck_tb;
   wire [7:0] LCD_DATA;
   reg 		  clk, rst;
   wire 	  rst_n;
   wire 	  LCD_BLON, LCD_RW, LCD_EN, LCD_RS;
   reg 		  key_d_en;
   reg [7:0]  key_in;
   integer 	  key_latency, j;
   
   brainfuck_top bft(
					 .clk(clk), 
					 .rst_n(rst_n),
					 .LCD_BLON(LCD_BLON),
					 .LCD_RW(LCD_RW),
					 .LCD_EN(LCD_EN),
					 .LCD_RS(LCD_RS),
					 .LCD_DATA(LCD_DATA),
					 .key_in(key_in),
					 .key_d_en(key_d_en)
					 );
   
   parameter STEP = 20000; // 20 ns = 50 MHz
   
   reg 		  lcd_en_z;
   
   // Reset
   initial
     begin
		rst = 1;
		#50
		  rst = 1;
		#STEP
		  rst = 0;
     end
   
   assign rst_n = !rst;
   
   // clock
   always begin
      clk = 0;
      #(STEP/2);
      clk = 1;
      #(STEP/2);
   end
   
   always @(posedge clk) begin
	  if (LCD_EN==1 & lcd_en_z==0)
		begin
           $display($stime, ", %h %c", {LCD_RS, LCD_DATA}, LCD_DATA);
		end
   end

   always @(posedge clk or rst) begin
	  if (rst)
		lcd_en_z <= 0;
	  else
		lcd_en_z <= LCD_EN;
   end
   
   initial begin
      key_d_en <= 0;
      key_in <= 255;
	  key_latency <= 7;
	  j = 0;
      while(1) begin
		 @(posedge clk);
		 key_latency = ($random & 5'h1f)+1;
		 for(j=0; j<key_latency; j = j+1)
		   @(posedge clk);
		 key_d_en <= 1;
		 key_in <= $random % 8'hff;
		 @(posedge clk);
		 key_d_en <= 0;
      end
   end
   
endmodule
