
module vfd(
	input clk,
	output reg [18:0] vfd_addr,
	output reg [7:0] vfd_dout,
	output reg vfd_vram_we,

	output reg [24:0] sdram_addr,
	input [7:0] sdram_data,
	output reg sdram_rd,

	input [3:0] C,
	input [3:0] D,
	input [3:0] E,
	input [3:0] F,
	input [3:0] G,
	input [3:0] H,
	input [2:0] I,

	input rdy
);

reg [24:0] old_sdram_addr;

reg [3:0] grid; // col
always @*
	case ({ I[1:0], D, C })
		10'b0000000001: grid = 4'd0;
		10'b0000000010: grid = 4'd1;
		10'b0000000100: grid = 4'd2;
		10'b0000001000: grid = 4'd3;
		10'b0000010000: grid = 4'd4;
		10'b0000100000: grid = 4'd5;
		10'b0001000000: grid = 4'd6;
		10'b0010000000: grid = 4'd7;
		10'b0100000000: grid = 4'd8;
		10'b1000000000: grid = 4'd9;
	endcase

reg [16:0] cache[8:0];
always @(posedge clk) begin
	cache[grid] <= { F[3], G[3], F[2], G[2], F[1], G[1], F[0], G[0], H[0], E[0], 1'b1, H[1], E[1], H[2], E[2], H[3], E[3] };
end

// BG pxl to col/row decoder
wire [3:0] col = sdram_data[7:4] <= 4'd9 ? sdram_data[7:4] : sdram_data[3:0];
wire [4:0] row = sdram_data[7:4] == 10 ? 5'd16 : { 1'd0, sdram_data[3:0] };

reg [2:0] state;
wire seg_en = cache[col][row];


always @(posedge clk)
	if (rdy)
		case (state)

			3'b000: begin // init
				vfd_addr <= 0;
				state <= 3'b001;
				sdram_addr <= 640*480;
			end

			3'b001: begin // prepare sdram read mask pxl
				sdram_rd <= 1'b1;
				sdram_addr <= sdram_addr + 25'd1;
				state <= 3'b010;
			end

			3'b010: begin
				sdram_rd <= 1'b0;
				old_sdram_addr <= sdram_addr;

				// if it's a segment pixel and status is on
				// write 0 to vram
				if (seg_en) begin
					vfd_vram_we <= 1'b1;
					vfd_addr <= sdram_addr - 640*480;
					vfd_dout <= 8'd0;
					state <= 3'b001; // then read next mask pxl
				end
				else begin
					state <= 3'b011; // if bg or segment is off read bg color
				end

				if (sdram_addr >= 2*640*480) begin // end? go back to init
					state <= 3'b000;
				end

			end

			3'b011: begin // setup bg read
				sdram_rd <= 1'b1;
				sdram_addr <= old_sdram_addr - 640*480; // point to bg
				state <= 3'b100;
			end

			3'b100: begin // read bg color
				vfd_vram_we <= 1'b1;
				vfd_addr <= sdram_addr;
				vfd_dout <= sdram_data;
				sdram_rd <= 1'b0;
				sdram_addr <= sdram_addr + 640*480; // fix addr
				if (sdram_addr >= 640*480) begin // end, go back to init
					state <= 3'b000;
				end
				else begin // continue reading mask
					state <= 3'b001;
				end
			end

		endcase



endmodule