`default_nettype none
module my_chip (
	io_in,
	io_out,
	clock,
	reset
);
	input wire [11:0] io_in;
	output reg [11:0] io_out;
	input wire clock;
	input wire reset;
	reg [6:0] btn;
	wire gn14;
	wire gn15;
	wire gn16;
	wire gn17;
	wire gp16;
	wire gp17;
	wire gn21;
	wire gn22;
	wire gn23;
	wire gn24;
	wire gp21;
	wire gp22;
	wire gp23;
	wire gp24;
	always @(*) begin
		btn[3] = io_in[0];
		btn[4] = io_in[1];
		btn[5] = io_in[2];
		btn[6] = io_in[3];
	end
	always @(*) begin
		io_out[0] = gp16;
		io_out[1] = gp17;
		io_out[2] = gn23;
		io_out[3] = gp22;
		io_out[4] = gn21;
		io_out[5] = gp23;
		io_out[6] = gp22;
		io_out[7] = gp21;
		io_out[8] = gn16;
		io_out[9] = gn15;
		io_out[10] = gn14;
	end
	reg [2:0] red;
	reg [2:0] green;
	reg [2:0] blue;
	wire hsync;
	wire vsync;
	wire valid;
	wire refresh;
	reg state;
	assign {gn21, gn22, gn23, gn24} = (valid ? {red[2:0], 1'b0} : {4 {1'sb0}});
	assign {gp21, gp22, gp23, gp24} = (valid ? {blue[2:0], 1'b0} : {4 {1'sb0}});
	assign {gn14, gn15, gn16, gn17} = (valid ? {green[2:0], 1'b0} : {4 {1'sb0}});
	assign gp16 = vsync;
	assign gp17 = hsync;
	wire [9:0] v_idx;
	wire [9:0] h_idx;
	wire frame_end;
	vga vga(
		.v_idx(v_idx),
		.h_idx(h_idx),
		.valid(valid),
		.vsync(vsync),
		.hsync(hsync),
		.rst(reset),
		.clk(clock),
		.refresh(refresh),
		.frame_end(frame_end)
	);
	reg fsm_state;
	reg [2:0] focus_row;
	reg [2:0] focus_col;
	reg btn3_tmp;
	reg btn3_sync;
	reg btn4_tmp;
	reg btn4_sync;
	reg lock_state;
	always @(posedge clock) begin
		btn3_tmp <= btn[3];
		btn3_sync <= btn3_tmp;
		btn4_tmp <= btn[4];
		btn4_sync <= btn4_tmp;
	end
	always @(posedge clock)
		if (reset) begin
			focus_row <= 0;
			focus_col <= 0;
			fsm_state <= 0;
			lock_state <= 0;
		end
		else if (btn3_sync && frame_end) begin
			if ((focus_row == 7) && (focus_col == 7)) begin
				focus_row <= 0;
				focus_col <= 0;
			end
			else if (focus_col == 7) begin
				focus_row <= focus_row + 1;
				focus_col <= 0;
			end
			else begin
				focus_col <= focus_col + 1;
				focus_row <= focus_row;
			end
		end
		else if (btn4_sync && frame_end)
			lock_state <= 1;
		else if (btn[6])
			fsm_state <= 1;
		else if (btn[5])
			fsm_state <= 0;
		else begin
			fsm_state <= fsm_state;
			lock_state <= 0;
		end
	reg signed [31:0] COLS = 640;
	reg signed [31:0] ROWS = 480;
	reg signed [31:0] TILE_HEIGHT = 50;
	reg signed [31:0] TILE_WIDTH = 50;
	reg signed [31:0] TILE_COLS = 8;
	reg signed [31:0] TILE_ROWS = 8;
	wire [63:0] tile_sel_one_hot;
	wire [63:0] tile_states;
	reg [639:0] left;
	reg [639:0] right;
	reg [639:0] top;
	reg [639:0] bottom;
	genvar row_i;
	genvar col_j;
	generate
		for (row_i = 0; row_i < 8; row_i = row_i + 1) begin : row_sel
			for (col_j = 0; col_j < 8; col_j = col_j + 1) begin : col_sel
				always @(*) begin
					left[((row_i * 8) + col_j) * 10+:10] = col_j * TILE_WIDTH;
					right[((row_i * 8) + col_j) * 10+:10] = ((col_j * TILE_WIDTH) + TILE_WIDTH) - 1;
					top[((row_i * 8) + col_j) * 10+:10] = row_i * TILE_HEIGHT;
					bottom[((row_i * 8) + col_j) * 10+:10] = ((row_i * TILE_HEIGHT) + TILE_HEIGHT) - 1;
				end
				is_pixel_in_tile tile(
					.h_idx(h_idx),
					.v_idx(v_idx),
					.left(left[((row_i * 8) + col_j) * 10+:10]),
					.right(right[((row_i * 8) + col_j) * 10+:10]),
					.top(top[((row_i * 8) + col_j) * 10+:10]),
					.bottom(bottom[((row_i * 8) + col_j) * 10+:10]),
					.is_in_tile(tile_sel_one_hot[(row_i * 8) + col_j])
				);
				tile_state_reg #(
					.tile_row(row_i),
					.tile_col(col_j)
				) tile_state(
					.tile_states(tile_states),
					.state(tile_states[(row_i * 8) + col_j]),
					.clk(clock),
					.rst(reset),
					.refresh(refresh),
					.focus_row(focus_row),
					.focus_col(focus_col),
					.fsm_state(fsm_state),
					.lock_state(lock_state)
				);
			end
		end
	endgenerate
	wire [7:0] row_sel_one_hot;
	wire [7:0] col_sel_one_hot;
	wire [2:0] row_idx;
	wire [2:0] col_idx;
	genvar row_k;
	generate
		for (row_i = 0; row_i < 8; row_i = row_i + 1) begin : genblk2
			assign row_sel_one_hot[row_i] = ^tile_sel_one_hot[row_i * 8+:8];
		end
	endgenerate
	wire in_arena_row;
	wire in_arena_col;
	one_hot_to_idx get_row_idx(
		.one_hot(row_sel_one_hot),
		.idx(row_idx),
		.in_arena(in_arena_row)
	);
	assign col_sel_one_hot = tile_sel_one_hot[row_idx * 8+:8];
	one_hot_to_idx get_col_idx(
		.one_hot(col_sel_one_hot),
		.idx(col_idx),
		.in_arena(in_arena_col)
	);
	always @(*) begin
		red = 0;
		green = 0;
		blue = 0;
		if (in_arena_col) begin
			state = tile_states[(row_idx * 8) + col_idx];
			if (state == 1)
				green = 1;
			else
				blue = 1;
		end
	end
endmodule
module tile_state_reg (
	tile_states,
	clk,
	rst,
	refresh,
	fsm_state,
	lock_state,
	focus_row,
	focus_col,
	state
);
	parameter tile_row = 0;
	parameter tile_col = 0;
	input wire [63:0] tile_states;
	input wire clk;
	input wire rst;
	input wire refresh;
	input wire fsm_state;
	input wire lock_state;
	input wire [2:0] focus_row;
	input wire [2:0] focus_col;
	output reg state;
	reg [1:0] neighbors_vert;
	reg [1:0] neighbors_hori;
	reg [1:0] neighbors;
	always @(*) begin
		if (tile_row == 0)
			neighbors_vert = tile_states[((tile_row + 1) * 8) + tile_col] + 1;
		else if (tile_row == 7)
			neighbors_vert = tile_states[((tile_row - 1) * 8) + tile_col] + 1;
		else
			neighbors_vert = tile_states[((tile_row - 1) * 8) + tile_col] + tile_states[((tile_row + 1) * 8) + tile_col];
		if (tile_col == 0)
			neighbors_hori = tile_states[(tile_row * 8) + (tile_col + 1)] + 1;
		else if (tile_col == 7)
			neighbors_hori = tile_states[(tile_row * 8) + (tile_col - 1)] + 1;
		else
			neighbors_hori = tile_states[(tile_row * 8) + (tile_col - 1)] + tile_states[(tile_row * 8) + (tile_col + 1)];
		neighbors = neighbors_hori + neighbors_vert;
	end
	reg state_locked;
	always @(posedge clk)
		if (rst) begin
			state_locked <= 0;
			state <= 0;
		end
		else if (((fsm_state == 0) && (state == 1)) && lock_state)
			state_locked <= 1;
		else if ((fsm_state == 0) && !state_locked) begin
			if ((tile_row == focus_row) && (tile_col == focus_col))
				state <= 1;
			else
				state <= 0;
		end
		else if ((fsm_state == 1) && refresh) begin
			if (neighbors == 4)
				state <= 0;
			else if (neighbors == 0)
				state <= 0;
			else if (neighbors == 2)
				state <= 1;
			else
				state <= 1;
		end
		else
			state <= state;
endmodule
module is_pixel_in_tile (
	h_idx,
	v_idx,
	left,
	right,
	top,
	bottom,
	is_in_tile
);
	input wire [9:0] h_idx;
	input wire [9:0] v_idx;
	input wire [9:0] left;
	input wire [9:0] right;
	input wire [9:0] top;
	input wire [9:0] bottom;
	output wire is_in_tile;
	assign is_in_tile = (((h_idx < right) && (h_idx > left)) && (v_idx > top)) && (v_idx < bottom);
endmodule
module one_hot_to_idx (
	one_hot,
	idx,
	in_arena
);
	input wire [7:0] one_hot;
	output reg [2:0] idx;
	output reg in_arena;
	always @(*)
		if (^one_hot) begin
			if (one_hot == 8'b00000001)
				idx = 3'd0;
			else if (one_hot == 8'b00000010)
				idx = 3'd1;
			else if (one_hot == 8'b00000100)
				idx = 3'd2;
			else if (one_hot == 8'b00001000)
				idx = 3'd3;
			else if (one_hot == 8'b00010000)
				idx = 3'd4;
			else if (one_hot == 8'b00100000)
				idx = 3'd5;
			else if (one_hot == 8'b01000000)
				idx = 3'd6;
			else if (one_hot == 8'b10000000)
				idx = 3'd7;
			in_arena = 1'b1;
		end
		else begin
			idx = 3'd0;
			in_arena = 1'b0;
		end
endmodule
module vga (
	v_idx,
	h_idx,
	valid,
	vsync,
	hsync,
	refresh,
	frame_end,
	rst,
	clk
);
	output reg [9:0] v_idx;
	output reg [9:0] h_idx;
	output wire valid;
	output reg vsync;
	output reg hsync;
	output reg refresh;
	output reg frame_end;
	input wire rst;
	input wire clk;
	assign valid = (v_idx < 480) && (h_idx < 640);
	reg signed [31:0] frame_count;
	always @(posedge clk)
		if (rst) begin
			v_idx <= 0;
			h_idx <= 0;
			vsync <= 1;
			hsync <= 1;
			frame_count <= 0;
			refresh <= 0;
			frame_end <= 0;
		end
		else begin
			refresh <= 0;
			hsync <= 1;
			h_idx <= h_idx + 1;
			frame_end <= 0;
			if ((h_idx >= 656) && (h_idx < 752))
				hsync <= 1'b0;
			if (h_idx >= 800) begin
				h_idx <= 0;
				v_idx <= v_idx + 1;
				if ((v_idx >= 490) && (v_idx < 492))
					vsync <= 0;
				else
					vsync <= 1;
				if (v_idx >= 525) begin
					v_idx <= 0;
					frame_count <= frame_count + 1;
				end
			end
			if ((v_idx == 490) && (h_idx == 656)) begin
				if (frame_count == 100) begin
					refresh <= 1;
					frame_count <= 0;
				end
				else if ((frame_count % 32) == 0)
					frame_end <= 1;
			end
		end
endmodule
