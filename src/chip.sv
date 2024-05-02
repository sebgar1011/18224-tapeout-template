`default_nettype none


module my_chip(
    input logic [11:0] io_in, // Inputs to your chip
    output logic [11:0] io_out, // Outputs from your chip
    input logic clock,
    input logic reset // Important: Reset is ACTIVE-HIGH
);
    logic [6:0] btn;
    
    logic gn14, gn15, gn16, gn17;
    logic gp16, gp17;
    logic gn21, gn22, gn23, gn24;
    logic gp21, gp22, gp23, gp24;

    // Only buttons 3, 4, 5, 6 used
    always_comb begin
        btn[3] = io_in[0];
        btn[4] = io_in[1];
        btn[5] = io_in[2];
        btn[6] = io_in[3];
    end

    // 8 io_in left but we don't care about them

    // Now mapping io_out to VGA output
    always_comb begin
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

    logic [2:0] red, green, blue;
    logic hsync, vsync;
    logic valid;
    logic refresh;
    logic state;

    // Pinout of the VGA PMOD
    // We check 'valid' here to avoid outputting outside of the 640x480 pixel area
    // IMPORTANT: Make sure to do this on your own chip as well, otherwise some
    // VGA monitors will not accept the signal
    assign {gn21, gn22, gn23, gn24} = valid ? {red[2:0], 1'b0} : '0;
    assign {gp21, gp22, gp23, gp24} = valid ? {blue[2:0], 1'b0} : '0;
    assign {gn14, gn15, gn16, gn17} = valid ? {green[2:0], 1'b0} : '0;
    assign gp16 = vsync;
    assign gp17 = hsync;

    // h_idx = column, v_idx = row
    logic [9:0] v_idx, h_idx;
    logic frame_end;

    vga vga (
        .v_idx, .h_idx, .valid,
        .vsync, .hsync,
        .rst(reset), .clk(clock), .refresh, .frame_end
    );

    logic fsm_state;
    logic [2:0] focus_row, focus_col;
    logic btn3_tmp, btn3_sync, btn4_tmp, btn4_sync;
    logic lock_state;

    always_ff @(posedge clock) begin
        btn3_tmp <= btn[3];
        btn3_sync <= btn3_tmp;
        btn4_tmp <= btn[4];
        btn4_sync <= btn4_tmp;
    end


    // State machine to set inputs
    always_ff @(posedge clock) begin
        if (reset) begin
            focus_row <= 0;
            focus_col <= 0;
            fsm_state <= 0;
            lock_state <= 0;
        end

        else if (btn3_sync && frame_end) begin // Move to new tile (UP)
            
            if (focus_row == 7 && focus_col == 7) begin
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

        else if (btn4_sync && frame_end) begin // Move to new tile (UP)
            lock_state <= 1;
        end  

        else if (btn[6]) fsm_state <= 1;   

        else if (btn[5]) fsm_state <= 0;

        else begin
            fsm_state <= fsm_state;
            lock_state <= 0;
        end
    end
    /*
    Inputs to the system will be: screen resolution tile height, tile width, 
                                  num of tile rows/cols
    */
    
    int COLS = 640;
    int ROWS = 480;
    int TILE_HEIGHT = 50;
    int TILE_WIDTH = 50;
    int TILE_COLS = 8;
    int TILE_ROWS = 8;

    // sel_one_hot selects which tile we want to get the state of for given pixel
    logic [7:0][7:0] tile_sel_one_hot;
    logic [7:0][7:0] tile_states;

    logic [7:0][7:0][9:0] left;
    logic [7:0][7:0][9:0] right;
    logic [7:0][7:0][9:0] top;
    logic [7:0][7:0][9:0] bottom;
    
    genvar row_i, col_j;

    // Modules used to determine if pixel is in a certain tile and the state
    // of each tile
    generate
        for (row_i = 0; row_i < 8; row_i++) begin: row_sel
            for (col_j = 0; col_j < 8; col_j++) begin: col_sel
                
                always_comb begin
                    left[row_i][col_j] = col_j * TILE_WIDTH;
                    right[row_i][col_j] = col_j * TILE_WIDTH + TILE_WIDTH - 1; // -1 for 0-based indexing
                    top[row_i][col_j] = row_i * TILE_HEIGHT;
                    bottom[row_i][col_j] = row_i * TILE_HEIGHT + TILE_HEIGHT - 1;
                    //#display(left[row_i][col_j]);
                end

                is_pixel_in_tile tile(.h_idx, .v_idx, .left(left[row_i][col_j]), .right(right[row_i][col_j]), .top(top[row_i][col_j]), .bottom(bottom[row_i][col_j]), 
                                        .is_in_tile(tile_sel_one_hot[row_i][col_j]));

                tile_state_reg #(.tile_row(row_i), .tile_col(col_j)) tile_state(.tile_states, 
                                        .state(tile_states[row_i][col_j]), 
                                        .clk(clock), .rst(reset),
                                        .refresh, .focus_row, .focus_col, .fsm_state, .lock_state);
            end: col_sel
        end: row_sel
    endgenerate

    // Encoder modules used to convert packed array tile_sel into usable
    // row and col indices for the tile state packed array
    
    logic [7:0] row_sel_one_hot;
    logic [7:0] col_sel_one_hot;
    logic [2:0] row_idx;
    logic [2:0] col_idx; // TODO: make dependent

    genvar row_k;
    
    // Determine the row idx by compressing the 2d row/col array to 1d row array
    generate
        for (row_i = 0; row_i < 8; row_i++) begin
            assign row_sel_one_hot[row_i] = ^tile_sel_one_hot[row_i];
        end
    endgenerate

    logic in_arena_row, in_arena_col; // TODO: make clean up to save space
    
    one_hot_to_idx get_row_idx(.one_hot(row_sel_one_hot), .idx(row_idx), 
                                .in_arena(in_arena_row));

    assign col_sel_one_hot = tile_sel_one_hot[row_idx];

    one_hot_to_idx get_col_idx(.one_hot(col_sel_one_hot), .idx(col_idx), 
                                .in_arena(in_arena_col));
    
    // At this point we have the row and col index of the tile of focus
    

    // Pixel coloring
    always_comb begin
        red = 0;
        green = 0;
        blue = 0;
        if (in_arena_col) begin // Then pixel in arena
            state = tile_states[row_idx][col_idx];
            if (state == 1) green = 1;
            else blue = 1;
        end
    end
endmodule


module tile_state_reg #(tile_row, tile_col) ( 
    input logic [7:0][7:0] tile_states, // TODO: fix sizes
    input logic clk, rst,
    input logic refresh,
    input logic fsm_state,
    input logic lock_state,
    input logic [2:0] focus_row, focus_col,
    output logic state); // TODO: change from high/low

    logic [1:0] neighbors_vert; // up to 2
    logic [1:0] neighbors_hori; // up to 2
    logic [1:0] neighbors; // up to 4

    // Count neigbors!
    always_comb begin

        // Then we know there is no top neighbors
        if (tile_row == 0) begin
            // Only check bottom neighbor
            neighbors_vert = tile_states[tile_row+1][tile_col] + 1;
        end
        // Then we know there is no bottom neighbors
        else if (tile_row == 7) begin
            // Only check top neighbor
            neighbors_vert = tile_states[tile_row-1][tile_col] + 1;
        end
        // Check top and bottom
        else begin
            neighbors_vert = tile_states[tile_row-1][tile_col] + tile_states[tile_row+1][tile_col];
        end

        // Checking horizontal neighbors
        // Then we know there is no left neighbors
        if (tile_col == 0) begin
            // Only check right neighbor
            neighbors_hori = tile_states[tile_row][tile_col+1] + 1;
        end
        // Then we know there is no right neighbors
        else if (tile_col == 7) begin
            // Only check left neighbor
            neighbors_hori = tile_states[tile_row][tile_col-1] + 1;
        end
        // Check left and right
        else begin
            neighbors_hori = tile_states[tile_row][tile_col-1] + tile_states[tile_row][tile_col+1];
        end
        neighbors = neighbors_hori + neighbors_vert;
    end

    logic state_locked;
    
    always_ff @(posedge clk) begin
    
        if (rst) begin
            state_locked <= 0;
            state <= 0;
        end

        else if (fsm_state == 0 && state == 1 && lock_state) begin
            state_locked <= 1;
        end

        else if (fsm_state == 0 && !state_locked) begin

            if (tile_row == focus_row && tile_col == focus_col) begin
                //$display("match in tile with row=%d, col=%d", tile_row, tile_col);
                state <= 1;
            end
            else state <= 0;
        end

        else if (fsm_state == 1 && refresh) begin
            // Game of life logic!
            if (neighbors == 4) state <= 0; // Death (overcrowding)!
            else if (neighbors == 0) state <= 0; // Death (loneliness)!
            else if (neighbors == 2) state <= 1; // Birth!
            else state <= 1; // Life!
        end

        else state <= state;
    end

endmodule


module is_pixel_in_tile(
    input logic [9:0] h_idx, v_idx,
    input logic [9:0] left, right, top, bottom,
    output logic is_in_tile);

    assign is_in_tile = h_idx < right && h_idx > left && 
                       v_idx > top && v_idx < bottom;
endmodule


module one_hot_to_idx ( // TODO: fix defaults
    input logic [7:0] one_hot,
    output logic [2:0] idx,
    output logic in_arena
);
    
    always_comb begin

        if (^one_hot) begin // Check if there is a 1 in one-hot encoding
            if (one_hot == 8'b1) idx = 3'd0;
            else if (one_hot == 8'b10) idx = 3'd1;
            else if (one_hot == 8'b100) idx = 3'd2;
            else if (one_hot == 8'b1000) idx = 3'd3;
            else if (one_hot == 8'b1_0000) idx = 3'd4;
            else if (one_hot == 8'b10_0000) idx = 3'd5;
            else if (one_hot == 8'b100_0000) idx = 3'd6;
            else if (one_hot == 8'b1000_0000) idx = 3'd7;
            in_arena = 1'b1;
        end
        else begin
            idx = 3'd0; 
            in_arena = 1'b0;
        end

    end
    
endmodule

module vga (
    output logic [9:0] v_idx,
    output logic [9:0] h_idx,
    output logic valid,
    output logic vsync, hsync,
    output logic refresh,
    output logic frame_end,
    input logic rst,
    input logic clk
);

    assign valid = (v_idx < 480) && (h_idx < 640);

    int frame_count;

    always @(posedge clk) begin
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
            // Horizontal sync region
            if (h_idx >= 656 && h_idx < 752) begin
                hsync <= 1'b0;
            end

            // End of row
            if (h_idx >= 800) begin
                h_idx <= 0;
                v_idx <= v_idx + 1;

                // Vertical sync region
                if (v_idx >= 490 && v_idx < 492) begin
                    vsync <= 0;
                end
                else begin
                    vsync <= 1;
                end

                // End of frame
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
				else if (frame_count % 32 == 0) frame_end <= 1;

			end
        end
    end

endmodule
