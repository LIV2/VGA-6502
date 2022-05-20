module vga6502(
  input clk,
  input reset,
  output [11:0] ma,
  output reg [3:0] ra,
  output reg blank,
  output reg hsync,
  output reg vsync,
  output reg latch,
  input phi2,
  input rw,
  input rs,
  input cs,
  input [7:0] data,
  output reg cursor,
  output reg bank
);

reg clk8;

always @(posedge clk)
begin
  clkdiv <= clkdiv + 1;  
  clk8 <= clkdiv[2];
  if (clkdiv[2:0] == 3'b000)
    latch <= 1'b0;
  else
    latch <= 1'b1;
end

localparam H_TOT = 100; // Horizontal Total size / 8
localparam H_FP = 2;    // Horizontal front porch / 8
localparam H_BP = 6;    // Horizontal back porch / 8
localparam H_SW = 12;   // Horizontal Sync width / 8

// Mode 0 - 640x480
localparam V_TOT1 = 525; // Vertical total lines
localparam V_FP1 = 10;   // Vertical front porch
localparam V_BP1 = 33;   // Vertical back porch
localparam V_SW1 = 2;    // Vertical sync width

// Mode 1 - 640x400
localparam V_TOT2 = 449; // Vertical total lines
localparam V_FP2  = 12;  // Vertical front porch
localparam V_BP2  = 35;  // Vertical back porch
localparam V_SW2  = 2;   // Vertical sync width

reg r_mode;
reg r_bank;

reg [9:0] V_TOT;
reg [3:0] V_FP;
reg [1:0] V_SW;
reg [5:0] V_BP;

always @(*)
begin
  if (!r_mode) begin
    V_TOT   <= V_TOT1;
    V_FP    <= V_FP1;
    V_SW    <= V_SW1;
    V_BP    <= V_BP1;
    bank    <= 0;
    ra[3:0] <= line_count[3:0];
  end else begin
    V_TOT <= V_TOT2;
    V_FP  <= V_FP2;
    V_SW  <= V_SW2;
    V_BP  <= V_BP2;
    bank  <= 1;
    ra[3:0] <= {r_bank, line_count[2:0]};
  end
end
reg h_blank;
reg h_end;
reg h_sync;

reg v_blank;
reg v_sync;

reg [6:0] h_counter;
reg [9:0] v_counter;

reg [2:0] clkdiv;

reg [11:0] char_counter;
reg [11:0] char_counter_last; 
reg [3:0] line_count;

reg r_cursor_en;
reg r_curs_flash_en;

reg [3:0] r_charheight;
reg [2:0] r_reg_ptr;
reg [7:0] r_start_lo;
reg [7:0] r_start_hi;
reg [11:0] r_curs_location;

assign ma[11:0] = char_counter[11:0];

always @(negedge phi2 or negedge reset)
begin
  if (!reset)
  begin
    r_bank          <= 1'b0;
    r_mode          <= 1'b0;
    r_charheight    <= 4'b1111;
    r_cursor_en     <= 1'b1;
    r_curs_flash_en <= 1'b0;
    r_curs_location <= 12'b0;
    r_reg_ptr       <= 3'b0;
  end else begin
    if (!cs && !rw) begin
      if (rs == 0) begin
        r_reg_ptr <= data[2:0];
      end else begin
        case (r_reg_ptr)
          3'h0: r_start_lo <= data;
          3'h1: r_start_hi <= data;
          3'h2: begin
            r_bank            <= data[7];
            r_cursor_en       <= data[6];
            r_curs_flash_en   <= data[5];
            r_mode            <= data[4];
            r_charheight[3:0] <= data[3:0];
          end
          3'h3: r_curs_location[7:0]  <= data[7:0];
          3'h4: r_curs_location[11:8] <= data[3:0];
        endcase
      end
    end
  end
end

reg [5:0] cursor_flash_counter;
wire cursor_location_match = (r_curs_location[11:0] == char_counter[11:0]);
wire cursor_on = (!r_curs_flash_en || cursor_flash_counter[5]) && line_count[3:0] <= 4'd10;

// LATCH //
always @(posedge clk)
begin
  if (latch == 1'b0)
  begin
    cursor <= r_cursor_en && cursor_location_match && cursor_on;
    blank  <= v_blank || h_blank;
    vsync  <= v_sync ^ r_mode; // Invert vsync polarity for 640x400 mode
    hsync  <= h_sync;
  end
end

always @(posedge clk8)
begin
  if (h_counter >= H_TOT-1) begin
    h_counter <= 6'b0;
    h_end <= 1;
  end else begin
    h_counter <= h_counter + 1;
    h_end <= 0;
  end
end

always @(posedge clk8) begin
  if (h_counter >= (H_SW + H_BP) && h_counter < (H_TOT - H_FP))
    h_blank <= 0;
  else
    h_blank <= 1;

  if (h_counter > H_SW)
    h_sync <= 1;
  else
    h_sync <= 0;
end

always @(posedge clk8)
begin
  if (h_end) begin
    if (v_counter >= (V_SW + V_BP) && v_counter < (V_TOT - V_FP))
      v_blank <= 0;
    else
      v_blank <= 1;

    if (v_counter > V_SW)
      v_sync <= 1;
    else
      v_sync <= 0;

    if (v_counter >= (V_TOT -1)) begin
      v_counter <= 0;
      cursor_flash_counter <= cursor_flash_counter + 1;
    end else begin
      v_counter <= v_counter +1;
    end
  end
end

always @(posedge clk8)
begin
  if (h_end) begin
    if (v_blank) begin
      line_count <= 0;
      char_counter[11:0]      <= {r_start_hi[3:0], r_start_lo[7:0]};
      char_counter_last[11:0] <= {r_start_hi[3:0], r_start_lo[7:0]};
    end else if (line_count == r_charheight) begin
      char_counter_last <= char_counter;
      line_count        <= 0;
    end else begin
      char_counter <= char_counter_last;
      line_count   <= line_count + 1;
    end
  end else begin
    if (!h_blank) begin
      char_counter <= char_counter + 1;
    end
  end
end

endmodule
