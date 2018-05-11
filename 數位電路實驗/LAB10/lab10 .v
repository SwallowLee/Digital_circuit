`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:26:49 12/02/2015 
// Design Name: 
// Module Name:    lab10
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module lab10(
    input  clk,
    input  reset,
    input  [1:0] button,

    // VGA specific I/O ports
    output HSYNC,
    output VSYNC,
    output VGA_RED,
    output VGA_GREEN,
    output VGA_BLUE,

    // SD card specific I/O ports
    output cs,
    output sclk,
    output mosi,
    input  miso,
	 output [7:0] led
    );

// general VGA control signals
wire video_on;      // when video_on is 0, the VGA controller is sending
                    // synchronization signals to the display device.

wire pixel_tick;    // when pixel tick is 1, we must update the RGB value
                    // based for the new coordinate (pixel_x, pixel_y)

wire [9:0] pixel_x; // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y; // y coordinate of the next pixel (between 0 ~ 479)

reg [2:0] rgb_reg;  // RGB value for the current pixel
reg [2:0] rgb_next; // RGB value for the next pixel
reg [2:0] RGB;
reg [2:0] RGB_counter;
// Application-specific VGA signals
wire [2:0] current_rgb; // RGB values for the frame display application.
                        // In this demo, the value is generated by
                        // a video pattern generator:
                        //      video_pattern(id, x, y, current_rgb),
                        // where the input is the current scan coordinate (x, y),
                        // and the output is the RGB value of the video pattern
                        // 'id' at pixel (x, y).
reg  [2:0] pattern_id;

// Declare a SRAM memory block as video frame buffer:
// Each video line has 320 pixels x 3-bit = 960 bits = 120 bytes.
// Each video frame has 240 video lines = 120*240 bytes = 28.125 KB.
wire        vbuf_en;
wire        vbuf_we;
reg  [2:0]  vbuf[320*240-1:0];
reg  [2:0]  vbuf_dout;
reg  [2:0]  vbuf_din;
reg [16:0]  vbuf_addr;

reg flag ;

// Declare SD card interface signals
wire        clk_sel;
wire        clk_500k;
reg         rd_req;
reg  [31:0] rd_addr;
wire        init_finish;
wire [7:0]  sd_dout;
wire        out_valid;

// Declare a SRAM memory block as SD card buffer
wire        sdbuf_we, sdbuf_en;
reg  [7:0]  sdbuf[511:0];
reg  [7:0]  sdbuf_dout;
wire [7:0]  sdbuf_din;
wire [9:0]  sdbuf_addr;

// Declare system variables
wire [1:0]  btn_level, btn_pressed;
reg  [1:0]  prev_btn_level;
reg  [9:0]  sd_counter;
wire [7:0] header[0:14] ;

assign header[0]  = 8'h50 ; 
assign header[1]  = 8'h36 ; 
assign header[2]  = 8'h0A ; 
assign header[3]  = 8'h33 ; 
assign header[4]  = 8'h32 ; 
assign header[5]  = 8'h30 ; 
assign header[6]  = 8'h20 ; 
assign header[7]  = 8'h32 ; 
assign header[8]  = 8'h34 ; 
assign header[9]  = 8'h30 ; 
assign header[10] = 8'h0A ; 
assign header[11] = 8'h32 ; 
assign header[12] = 8'h35 ; 
assign header[13] = 8'h35 ; 
assign header[14] = 8'h0A ; 

// clock input selection for SD card controller
assign clk_sel = (init_finish)? clk : clk_500k;

debounce btn_db0(
  .clk(clk),
  .btn_input(button[0]),
  .btn_output(btn_level[0])
  );

debounce btn_db1(
  .clk(clk),
  .btn_input(button[1]),
  .btn_output(btn_level[1])
  );

// instiantiate a VGA sync signal generator
vga_sync vs0(
  .clk(clk), .reset(reset), .oHS(HSYNC), .oVS(VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
  );

// instiantiate a video test pattern generator
/*video_pattern vp0(
  .id(pattern_id),
  .x(pixel_x),
  .y(pixel_y),
  .rgb(current_rgb)
  );
*/
sd_card sd_card0(
		.cs(cs),
		.sclk(sclk),
		.mosi(mosi),
		.miso(miso),
		.clk(clk_sel),
		.rst(reset),

		.rd_req(rd_req),
		.block_address(rd_addr),
		.init_finish(init_finish),
		.dout(sd_dout),
		.out_valid(out_valid)
	);

clk_divider#(100) clk_divider0(
    .clk(clk),
    .reset(reset),
    .clk_out(clk_500k)
  );

// Button click controller
always @(posedge clk) begin
  if (reset)
    prev_btn_level <= 2'b11;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);


// Select the video test pattern by pressing the WEST and EAST buttons.
// Note that the code for 'reset' is used to make sure 'vbuf_dout' and
// 'sdbuf_out' connects to something such that the SRAM blocks will not
// be removed by the EDA tool! You can replace the code by "pattern_id <= 3'b000;"
// after you add in your code for video frame buffer accesses.
always @(posedge clk) begin
  if (reset)
    //pattern_id <= {1'b0, &vbuf_dout, &sdbuf_dout };
	pattern_id <= 3'b000;
  else if (btn_pressed[0])
    pattern_id <= pattern_id - 1;
  else if (btn_pressed[1])
    pattern_id <= pattern_id + 1;
end

// ------------------------------------------------------------------------
// The following circuit writes some meaningless data to the video buffer.
// This is a dummy circuit designed to avoid the EDA tool from removing the
// video buffer due to no connection to a "real" circuit components.
// For this lab, you should replace the code with your design.
//
localparam [3:0] S_SD_INIT = 4'b0000, S_SD_IDLE = 4'b0001, S_SD_WAIT = 4'b0010, S_SD_READ = 4'b0011, S_SD_BYTE0 = 4'b0100,S_SD_FIND = 4'b0101, S_SD_DONE = 4'b0110;
localparam [3:0] S_VBUF_IDLE = 4'b0111, S_VBUF_WAIT =4'b1000, S_VBUF_WRITE = 4'b1001, S_VBUF_READ = 4'b1010;
reg [3:0] P, P_next;
//reg [3:0] Q, Q_next;
reg [31:0] location [8:0];
reg [3:0] size;
assign led = {P[3],P[2],P[1],P[0],size[3],size[2],size[1],size[0]};
//assign led = pattern_id;
// FSM of the video buffer controller
always @(posedge clk) begin
  if (reset) P <= S_SD_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_SD_INIT: // wait for SD card initialization
      if (init_finish == 1) P_next = S_SD_IDLE;
      else P_next = S_SD_INIT;
    S_SD_IDLE: // wait for button click
      P_next = S_SD_WAIT;
    S_SD_WAIT: // issue a rd_req to the SD controller until it's ready
      //if (out_valid) P_next = S_SD_WAIT;
	  //else P_next = S_SD_READ;
	  P_next = S_SD_READ;
    S_SD_READ: // wait for the input data to enter the SRAM buffer
	  if(size==8)
		P_next = S_SD_BYTE0;
	  else begin
		  if (sd_counter == 512) P_next = S_SD_BYTE0;
		  else P_next = S_SD_READ;
	  end
    S_SD_BYTE0: // read byte 0 of the superblock from sram[]
	  if (flag == 1) P_next = S_SD_FIND;
	  else P_next = S_SD_WAIT;
	S_SD_FIND:
	   if (size<8) P_next = S_SD_WAIT;
	   else P_next = S_SD_DONE;
	S_SD_DONE:
	  P_next = S_VBUF_WAIT;
	 S_VBUF_WAIT:
		P_next = S_VBUF_IDLE;
    S_VBUF_IDLE: // wait for button click
		if (sd_counter == 512) P_next = S_VBUF_WRITE;
		else P_next = S_VBUF_IDLE;
    S_VBUF_WRITE: // write 16 cells (16 x 3-bit) of data to the video buffer
      if (vbuf_addr >= 320*240-1) P_next = S_VBUF_READ;
      else P_next = S_VBUF_WAIT;
    S_VBUF_READ: // read 16 cells of data from the video buffer
      if (|btn_pressed) P_next = S_SD_DONE;
      else P_next = S_VBUF_READ;
    default:
      P_next = S_SD_IDLE;
  endcase
end

always @(posedge clk) begin
  if (reset || P == S_SD_BYTE0 || P == S_VBUF_WRITE)
    sd_counter <= 0;
  else if (P == S_SD_READ && out_valid ||P == S_VBUF_IDLE&&out_valid)
	 sd_counter <= sd_counter + 1;
  else
	 sd_counter <= sd_counter;
end

always @(posedge clk)begin
	if(reset||P == S_SD_IDLE)
		size<=0;
	else if(P == S_SD_FIND)begin
		if(size<8) begin
			location[size] <= rd_addr;
			size<=size+1;
		end
	end
end

always @(posedge clk) begin
	if (P == S_SD_IDLE) begin
		rd_req <= 0;
		rd_addr <= 0;
	end
	else if (P == S_SD_WAIT || P == S_VBUF_WAIT) begin
		rd_req <= 1;
		rd_addr <= rd_addr + 1;
	end
	else if (P == S_SD_DONE) begin
		rd_req <= 0;
		rd_addr <= location[pattern_id]-1;
	end
	else
		rd_req <= 0;
end

always @(posedge clk) begin
  if(reset || P == S_SD_WAIT) flag <= 1 ; 
  else if(P == S_SD_READ  && out_valid && sd_counter < 15)begin 
    if (sd_dout == header[sd_counter[3:0]]) flag <= flag ;
    else flag <= 0 ; 
  end   
end

// ------------------------------------------------------------------------
// The following code shows synchronous read/write behavior of
// the SD card buffer.
//
assign sdbuf_we = out_valid;     // Write data into SRAM when out_valid is high.
assign sdbuf_en = 1;             // Always enable the SRAM block.
assign sdbuf_din = sd_dout;      // Input data always comes from the SD controller.

// Set the master FSM that controls the SRAM addresses, the master
// is the SD_FSM when the VPW_FSM is in the idle state.
assign sdbuf_addr = sd_counter;

always @(posedge clk) begin      // Write data into the SRAM block
  if (sdbuf_en && sdbuf_we) begin
    sdbuf[sdbuf_addr] <= sdbuf_din;
  end
end
	
always @(posedge clk) begin      // The read data port of the SRAM is always active
  if (sdbuf_en && sdbuf_we)      // If data is being written into SRAM, also
    sdbuf_dout <= sdbuf_din;     // forward the data to the read port
  else
    sdbuf_dout <= sdbuf[sdbuf_addr];  // Send current data to the read port
end

// VGA color pixel generator
assign {VGA_RED, VGA_BLUE, VGA_GREEN} = rgb_reg;

always @(posedge clk) begin
  if (pixel_tick)
    rgb_reg <= rgb_next;
  else
    rgb_reg <= rgb_reg;
end

always @(*) begin
  if (~video_on)
    rgb_next = 3'b000; // synchronization period, no need to set RGB values
  else
    rgb_next = vbuf_dout; // RGB value at (pixel_x, pixel_y)
end

always @(posedge clk) begin // a dummy address generator
  if (reset) begin
	RGB_counter<=0;
	vbuf_addr <= 0;
  end
  else if(P == S_VBUF_READ&&|btn_pressed)
	vbuf_addr <= 0;
  else if (P == S_VBUF_IDLE&&out_valid) begin
	//if (sd_counter>14) begin
	vbuf_din[RGB_counter] <= (sdbuf_dout > 128) ? 1 : 0 ;
		/*if (RGB_counter==0) begin
			RGB[0] <= (sdbuf_dout > 128) ? 1 : 0 ;
			RGB_counter<=RGB_counter+1;
		end
		else if (RGB_counter==1) begin
			RGB[1] <= (sdbuf_dout > 128) ? 1 : 0 ;
			RGB_counter<=RGB_counter+1;
		end
		else*/ if (RGB_counter==2) begin
			//RGB[2] <= (sdbuf_dout > 128) ? 1 : 0 ;
			//vbuf_din<={RGB[0],RGB[1],RGB[2]};
			RGB_counter<=0;
			vbuf_addr <= vbuf_addr + 1;
		end else RGB_counter<=RGB_counter+1;
	//end
  end
  else if(P == S_VBUF_READ) begin
		vbuf_addr <= pixel_x[9:1] + pixel_y[9:1] * 320 +180;
  end
end
// End of dummy video frame buffer read/write controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The following code shows synchronous read/write behavior of
// the video frame buffer.
//
assign vbuf_en = 1;//(P == S_VBUF_READ || P == S_VBUF_IDLE);
assign vbuf_we = (P == S_VBUF_IDLE||P==S_VBUF_WRITE);

always @(posedge clk) begin   // Write data into the video frame buffer
  if (vbuf_en && vbuf_we) begin
    vbuf[vbuf_addr] <= vbuf_din;
  end
end

always @(posedge clk) begin    // The read data port of the SRAM is always active
  if (vbuf_en && vbuf_we)      // If data is being written into SRAM, also
    vbuf_dout <= vbuf_din;     // forward the data to the read port
  else
    vbuf_dout <= vbuf[vbuf_addr];  // Send current data to the read port
end
// End of the video frame buffer.
// ------------------------------------------------------------------------
endmodule
