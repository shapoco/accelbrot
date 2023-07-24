`default_nettype none

module accelbrot_loop_core #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int IWIDTH = 6,
    parameter int CWIDTH = 20,
    parameter int TWIDTH = 24
) (
    input   wire            clk             ,
    input   wire            rstn            ,
    input   wire[CWIDTH-1:0]ctl_max_iter    ,
    input   wire[WWIDTH-1:0]in_x            ,
    input   wire[WWIDTH-1:0]in_y            ,
    input   wire[WWIDTH-1:0]in_a            ,
    input   wire[WWIDTH-1:0]in_b            ,
    input   wire[TWIDTH-1:0]in_tag          ,
    input   wire[CWIDTH-1:0]in_count        ,
    input   wire            in_finish       ,
    input   wire            in_start        ,
    input   wire            in_valid        ,
    output  wire[WWIDTH-1:0]out_x           ,
    output  wire[WWIDTH-1:0]out_y           ,
    output  wire[WWIDTH-1:0]out_a           ,
    output  wire[WWIDTH-1:0]out_b           ,
    output  wire[TWIDTH-1:0]out_tag         ,
    output  wire[CWIDTH-1:0]out_count       ,
    output  wire            out_finish      ,
    output  wire            out_start       ,
    output  wire            out_valid
);

localparam int BWIDTH = NWORDS * WWIDTH;
localparam int CNTR_WIDTH = $clog2(NWORDS);
localparam int ABS_LATENCY = NWORDS;
localparam int W2B_LATENCY = NWORDS;
localparam int MULT_LATENCY = NWORDS + 5;
localparam int NEG_LATENCY = 1;
localparam int ADD_SUB_LATENCY = 1;

wire w_s2_start;
wire w_s2_valid;

// abs(x)
wire[WWIDTH-1:0] w_s2_x_abs;
wire w_s2_x_sign;
accelbrot_com_abs #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_abs_x (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .in         (in_x       ), // input [NWORDS*WWIDTH-1:0]
    .in_start   (in_start   ), // input
    .in_valid   (in_valid   ), // input
    .out_abs    (w_s2_x_abs ), // output[WWIDTH-1:0]
    .out_sign   (w_s2_x_sign), // output
    .out_start  (w_s2_start ), // output
    .out_valid  (w_s2_valid )  // output
);

wire w_s3_valid;

wire[BWIDTH-1:0] w_s3_x_abs;
accelbrot_com_word2block #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_word2block_x_abs (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .in         (w_s2_x_abs ), // input [WWIDTH-1:0]
    .in_start   (w_s2_start ), // input
    .in_valid   (w_s2_valid ), // input
    .out        (w_s3_x_abs ), // output[NWORDS*WWIDTH-1:0]
    .out_valid  (w_s3_valid )  // output
);

// abs(y)
wire[WWIDTH-1:0] w_s2_y_abs;
wire w_s2_y_sign;
accelbrot_com_abs #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_abs_y (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .in         (in_y       ), // input [NWORDS*WWIDTH-1:0]
    .in_start   (in_start   ), // input
    .in_valid   (in_valid   ), // input
    .out_abs    (w_s2_y_abs ), // output[WWIDTH-1:0]
    .out_sign   (w_s2_y_sign), // output
    .out_start  (/* open */ ), // output
    .out_valid  (/* open */ )  // output
);

wire[BWIDTH-1:0] w_s3_y_abs;
accelbrot_com_word2block #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_word2block_y_abs (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .in         (w_s2_y_abs ), // input [WWIDTH-1:0]
    .in_start   (w_s2_start ), // input
    .in_valid   (w_s2_valid ), // input
    .out        (w_s3_y_abs ), // output[NWORDS*WWIDTH-1:0]
    .out_valid  (/* open */ )  // output
);

wire w_s4_start;
wire w_s4_valid;

// x^2
wire[WWIDTH-1:0] w_s4_xx_abs;
accelbrot_com_mult_unxn #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .IWIDTH(IWIDTH)
) u_mult_xx (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .a          (w_s3_x_abs ), // input [NWORDS*WWIDTH-1:0]
    .b          (w_s3_x_abs ), // input [NWORDS*WWIDTH-1:0]
    .ab_valid   (w_s3_valid ), // input
    .q          (w_s4_xx_abs), // output[WWIDTH-1:0]
    .q_start    (w_s4_start ), // output
    .q_valid    (w_s4_valid )  // output
);

// 2 * abs(x)
wire[BWIDTH-1:0] w_s3_2x_abs = {w_s3_x_abs[BWIDTH-1], w_s3_x_abs[BWIDTH-3:0], 1'b0};

// 2 * abs(x) * abs(y)
wire[WWIDTH-1:0] w_s4_2xy_abs;
accelbrot_com_mult_unxn #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .IWIDTH(IWIDTH)
) u_mult_2xy (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s3_2x_abs    ), // input [NWORDS*WWIDTH-1:0]
    .b          (w_s3_y_abs     ), // input [NWORDS*WWIDTH-1:0]
    .ab_valid   (w_s3_valid     ), // input
    .q          (w_s4_2xy_abs   ), // output[WWIDTH-1:0]
    .q_start    (/* open */     ), // output
    .q_valid    (/* open */     )  // output
);

// y^2
wire[WWIDTH-1:0] w_s4_yy_abs;
accelbrot_com_mult_unxn #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .IWIDTH(IWIDTH)
) u_mult_yy (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .a          (w_s3_y_abs ), // input [NWORDS*WWIDTH-1:0]
    .b          (w_s3_y_abs ), // input [NWORDS*WWIDTH-1:0]
    .ab_valid   (w_s3_valid ), // input
    .q          (w_s4_yy_abs), // output[WWIDTH-1:0]
    .q_start    (/* open */ ), // output
    .q_valid    (/* open */ )  // output
);

wire w_s5_start;
wire w_s5_valid;

// x^2 - y^y
wire[WWIDTH-1:0] w_s5_sub_xx_yy;
accelbrot_com_sub #(
    .WWIDTH(WWIDTH)
) u_sub_xx_yy (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s4_xx_abs    ), // input [WWIDTH-1:0]
    .b          (w_s4_yy_abs    ), // input [WWIDTH-1:0]
    .ab_start   (w_s4_start     ), // input
    .ab_valid   (w_s4_valid     ), // input
    .q          (w_s5_sub_xx_yy ), // output[WWIDTH-1:0]
    .q_start    (w_s5_start     ), // output
    .q_valid    (w_s5_valid     )  // output
);

// x^2 + y^y
wire[WWIDTH-1:0] w_s5_add_xx_yy;
accelbrot_com_add #(
    .WWIDTH(WWIDTH)
) u_add_xx_yy (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s4_xx_abs    ), // input [WWIDTH-1:0]
    .b          (w_s4_yy_abs    ), // input [WWIDTH-1:0]
    .ab_start   (w_s4_start     ), // input
    .ab_valid   (w_s4_valid     ), // input
    .q          (w_s5_add_xx_yy ), // output[WWIDTH-1:0]
    .q_start    (/* open */     ), // output
    .q_valid    (/* open */     )  // output
);

wire[WWIDTH-1:0] w_s5_a;
accelbrot_com_delay #(
    .DEPTH(ABS_LATENCY + MULT_LATENCY + W2B_LATENCY),
    .WIDTH(WWIDTH)
) u_delay_a_0 (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     (in_a   ), // input [WIDTH-1:0]
    .out    (w_s5_a )  // output[WIDTH-1:0]
);

// x^2 - y^y + a
accelbrot_com_add #(
    .WWIDTH(WWIDTH)
) u_add_a (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .a          (w_s5_sub_xx_yy ), // input [WWIDTH-1:0]
    .b          (w_s5_a     ), // input [WWIDTH-1:0]
    .ab_start   (w_s5_start ), // input
    .ab_valid   (w_s5_valid ), // input
    .q          (out_x      ), // output[WWIDTH-1:0]
    .q_start    (out_start  ), // output
    .q_valid    (out_valid  )  // output
);

wire w_s2_xy_sign = w_s2_x_sign ^ w_s2_y_sign;
wire w_s4_xy_sign;
accelbrot_com_delay #(
    .DEPTH(MULT_LATENCY),
    .WIDTH(1)
) u_delay_xy_sign (
    .clk    (clk            ), // input
    .rstn   (rstn           ), // input
    .clken  ('1             ), // input
    .in     (w_s2_xy_sign   ), // input [WIDTH-1:0]
    .out    (w_s4_xy_sign   )  // output[WIDTH-1:0]
);

// 2xy
wire[WWIDTH-1:0] w_s5_2xy;
accelbrot_com_inv #(
    .WWIDTH(WWIDTH)
) u_inv_2xy (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .in         (w_s4_2xy_abs   ), // input [WWIDTH-1:0]
    .in_sign    (w_s4_xy_sign   ), // input
    .in_start   (w_s4_start     ), // input
    .in_valid   (w_s4_valid     ), // input
    .out        (w_s5_2xy       ), // output[WWIDTH-1:0]
    .out_start  (/* open */     ), // output
    .out_valid  (/* open */     )  // output
);

wire[WWIDTH-1:0] w_s5_b;
accelbrot_com_delay #(
    .DEPTH(ABS_LATENCY + MULT_LATENCY + W2B_LATENCY),
    .WIDTH(WWIDTH)
) u_delay_b_0 (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     (in_b   ), // input [WIDTH-1:0]
    .out    (w_s5_b )  // output[WIDTH-1:0]
);

// 2xy + b
accelbrot_com_add #(
    .WWIDTH(WWIDTH)
) u_add_b (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .a          (w_s5_2xy   ), // input [WWIDTH-1:0]
    .b          (w_s5_b     ), // input [WWIDTH-1:0]
    .ab_start   (w_s5_start ), // input
    .ab_valid   (w_s5_valid ), // input
    .q          (out_y      ), // output[WWIDTH-1:0]
    .q_start    (/* open */ ), // output
    .q_valid    (/* open */ )  // output
);

accelbrot_com_delay #(
    .DEPTH(ADD_SUB_LATENCY),
    .WIDTH(WWIDTH)
) u_delay_a_1 (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     (w_s5_a ), // input [WIDTH-1:0]
    .out    (out_a  )  // output[WIDTH-1:0]
);

accelbrot_com_delay #(
    .DEPTH(ADD_SUB_LATENCY),
    .WIDTH(WWIDTH)
) u_delay_b_1 (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     (w_s5_b ), // input [WIDTH-1:0]
    .out    (out_b  )  // output[WIDTH-1:0]
);

accelbrot_com_delay #(
    .DEPTH(ABS_LATENCY + MULT_LATENCY + W2B_LATENCY + ADD_SUB_LATENCY),
    .WIDTH(TWIDTH)
) u_delay_tag (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     (in_tag ), // input [WIDTH-1:0]
    .out    (out_tag)  // output[WIDTH-1:0]
);

wire[CWIDTH-1:0] w_s5_count;
wire w_s5_finish;
accelbrot_com_delay #(
    .DEPTH(ABS_LATENCY + MULT_LATENCY + W2B_LATENCY),
    .WIDTH(CWIDTH + 1)
) u_delay_count (
    .clk    (clk                        ), // input
    .rstn   (rstn                       ), // input
    .clken  ('1                         ), // input
    .in     ({in_finish, in_count}      ), // input [WIDTH-1:0]
    .out    ({w_s5_finish, w_s5_count}  )  // output[WIDTH-1:0]
);

// 終了判定
logic[CNTR_WIDTH-1:0] r_s5_cntr;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s5_cntr <= '0;
    end else if (w_s5_start) begin
        r_s5_cntr <= 'd1;
    end else if ('d0 < r_s5_cntr && r_s5_cntr < NWORDS - 1) begin
        r_s5_cntr <= r_s5_cntr + 'd1;
    end else begin
        r_s5_cntr <= 'd0;
    end
end

// xx+yy の整数部
wire[IWIDTH-1:0] w_s5_mag = w_s5_add_xx_yy[WWIDTH-1:WWIDTH-IWIDTH];

// 終了判定
logic[CWIDTH-1:0] r_s6_count;
logic r_s6_finish;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s6_count <= '0;
        r_s6_finish <= '0;
    end else if (r_s5_cntr == NWORDS - 1) begin
        if (w_s5_finish) begin
            // 既に終了している
            r_s6_count <= w_s5_count;
            r_s6_finish <= '1;
        end else if (w_s5_mag >= 'd4) begin
            // 発散
            r_s6_count <= w_s5_count;
            r_s6_finish <= '1;
        end else if (w_s5_count >= ctl_max_iter) begin
            // 最大反復回数に到達
            r_s6_count <= w_s5_count;
            r_s6_finish <= '1;
        end else begin
            // 継続
            r_s6_count <= w_s5_count + 'd1;
            r_s6_finish <= '0;
        end
    end
end

assign out_count = r_s6_count;
assign out_finish = r_s6_finish;

endmodule

`default_nettype wire
