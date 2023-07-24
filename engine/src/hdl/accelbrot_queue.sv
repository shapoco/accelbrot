`default_nettype none

module accelbrot_queue #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int PWIDTH = 12,
    parameter int QDEPTH = 16 * 1024,
    parameter int BWIDTH = NWORDS * WWIDTH,
    parameter int TWIDTH = PWIDTH * 2
) (
    input   wire            clk             ,
    input   wire            rstn            ,
    output  wire[31:0]      sts_num_queued  ,
    input   wire[BWIDTH-1:0]ctl_a_offset    ,
    input   wire[BWIDTH-1:0]ctl_b_offset    ,
    input   wire[BWIDTH-1:0]ctl_a_step_x    ,
    input   wire[BWIDTH-1:0]ctl_b_step_y    ,
    input   wire[PWIDTH-1:0]push_x          ,
    input   wire[PWIDTH-1:0]push_y          ,
    input   wire            push_valid      ,
    output  wire            push_ready      ,
    output  wire[WWIDTH-1:0]enter_a         ,
    output  wire[WWIDTH-1:0]enter_b         ,
    output  wire[TWIDTH-1:0]enter_tag       ,
    output  wire            enter_start     ,
    output  wire            enter_valid     ,
    input   wire            enter_bp
);

localparam int CNTR_WIDTH = $clog2(NWORDS * 2);

localparam int B2W_LATENCY = 1;
localparam int MULT_LATENCY = 3;
localparam int ADD_SUB_LATENCY = 1;

wire[PWIDTH-1:0] w_push_x;
wire[PWIDTH-1:0] w_push_y;
wire w_push_valid;
wire w_push_ready;
wire[$clog2(QDEPTH+1)-1:0] w_written;
accelbrot_com_ram_fifo #(
    .DATA_WIDTH (TWIDTH ),
    .DEPTH      (QDEPTH )
) u_queue (
    .rstn       (rstn               ), // input
    .clk        (clk                ), // input
    .afull      (/* open */         ), // output
    .aempty     (/* open */         ), // output
    .written    (w_written          ), // output[SIZE_WIDTH-1:0]
    .readable   (/* open */         ), // output[SIZE_WIDTH-1:0]
    .wr_data    ({push_y, push_x}   ), // input [DATA_WIDTH-1:0]
    .wr_valid   (push_valid         ), // input
    .wr_ready   (push_ready         ), // output
    .rd_data    ({w_push_y, w_push_x}), // output[DATA_WIDTH-1:0]
    .rd_valid   (w_push_valid       ), // output
    .rd_ready   (w_push_ready       )  // input
);

logic[31:0] r_queued;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_queued <= '0;
    end else begin
        r_queued <= w_written;
    end
end
assign sts_num_queued = r_queued;

logic[CNTR_WIDTH-1:0] r_s0_cntr;
wire w_s0_start = (r_s0_cntr == '0) && w_push_valid && !enter_bp;
wire w_s0_last = (r_s0_cntr == NWORDS - 1);

assign w_push_ready = w_s0_start;

always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s0_cntr <= '0;
    end else if (w_s0_start) begin
        r_s0_cntr <= 'd1;
    end else if ('0 < r_s0_cntr && r_s0_cntr < NWORDS - 1) begin
        r_s0_cntr <= r_s0_cntr + 'd1;
    end else begin
        r_s0_cntr <= '0;
    end
end

logic[PWIDTH-1:0] r_s1_x;
logic[PWIDTH-1:0] r_s1_y;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s1_x <= '0;
        r_s1_y <= '0;
    end else if (w_s0_start) begin
        r_s1_x <= w_push_x;
        r_s1_y <= w_push_y;
    end
end
wire[WWIDTH/2-1:0] w_s1_x = r_s1_x;
wire[WWIDTH/2-1:0] w_s1_y = r_s1_y;

wire w_s1_start;
wire w_s1_valid;

wire[WWIDTH-1:0] w_s1_a_step_x;
accelbrot_com_block2word #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_b2w_a (
    .clk        (clk            ), // input   wire
    .rstn       (rstn           ), // input   wire
    .in         (ctl_a_step_x   ), // input   wire[NWORDS*WWIDTH-1:0]
    .in_valid   (w_s0_start     ), // input   wire
    .out        (w_s1_a_step_x  ), // output  wire[WWIDTH-1:0]
    .out_start  (w_s1_start     ), // output  wire
    .out_valid  (w_s1_valid     )  // output  wire
);

wire w_s3_start;
wire w_s3_valid;

// a_step_x * x
wire[WWIDTH-1:0] w_s3_ax;
accelbrot_com_mult_unx1 #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_mult_ax (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s1_a_step_x  ), // input [WWIDTH-1:0]
    .b          (w_s1_x         ), // input [WWIDTH/2-1:0]
    .ab_start   (w_s1_start     ), // input
    .ab_valid   (w_s1_valid     ), // input
    .q          (w_s3_ax        ), // output[WWIDTH-1:0]
    .q_start    (w_s3_start     ), // output
    .q_valid    (w_s3_valid     )  // output
);

wire[WWIDTH-1:0] w_s1_b_step_y;
accelbrot_com_block2word #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_b2w_b (
    .clk        (clk            ), // input   wire
    .rstn       (rstn           ), // input   wire
    .in         (ctl_b_step_y   ), // input   wire[NWORDS*WWIDTH-1:0]
    .in_valid   (w_s0_start     ), // input   wire
    .out        (w_s1_b_step_y  ), // output  wire[WWIDTH-1:0]
    .out_start  (/* open */     ), // output  wire
    .out_valid  (/* open */     )  // output  wire
);

// b_step_y* y
wire[WWIDTH-1:0] w_s3_by;
accelbrot_com_mult_unx1 #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_mult_by (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s1_b_step_y  ), // input [WWIDTH-1:0]
    .b          (w_s1_y         ), // input [WWIDTH/2-1:0]
    .ab_start   (w_s1_start     ), // input
    .ab_valid   (w_s1_valid     ), // input
    .q          (w_s3_by        ), // output[WWIDTH-1:0]
    .q_start    (/* open */     ), // output
    .q_valid    (/* open */     )  // output
);

wire w_s2_valid;
accelbrot_com_delay #(
    .DEPTH(MULT_LATENCY),
    .WIDTH(1)
) u_delay_a_0 (
    .clk    (clk        ), // input
    .rstn   (rstn       ), // input
    .clken  ('1         ), // input
    .in     (w_s0_start ), // input [WIDTH-1:0]
    .out    (w_s2_valid )  // output[WIDTH-1:0]
);

wire[WWIDTH-1:0] w_s3_a_offset;
accelbrot_com_block2word #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_b2w_a_offset (
    .clk        (clk            ), // input   wire
    .rstn       (rstn           ), // input   wire
    .in         (ctl_a_offset   ), // input   wire[NWORDS*WWIDTH-1:0]
    .in_valid   (w_s2_valid     ), // input   wire
    .out        (w_s3_a_offset  ), // output  wire[WWIDTH-1:0]
    .out_start  (/* open */     ), // output  wire
    .out_valid  (/* open */     )  // output  wire
);

// a_step_x * x + a_offset
accelbrot_com_add #(
    .WWIDTH(WWIDTH)
) u_add_ax_offset (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s3_ax        ), // input [WWIDTH-1:0]
    .b          (w_s3_a_offset  ), // input [WWIDTH-1:0]
    .ab_start   (w_s3_start     ), // input
    .ab_valid   (w_s3_valid     ), // input
    .q          (enter_a        ), // output[WWIDTH-1:0]
    .q_start    (enter_start    ), // output
    .q_valid    (enter_valid    )  // output
);

wire[WWIDTH-1:0] w_s3_b_offset;
accelbrot_com_block2word #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH)
) u_b2w_b_offset (
    .clk        (clk            ), // input   wire
    .rstn       (rstn           ), // input   wire
    .in         (ctl_b_offset   ), // input   wire[NWORDS*WWIDTH-1:0]
    .in_valid   (w_s2_valid     ), // input   wire
    .out        (w_s3_b_offset  ), // output  wire[WWIDTH-1:0]
    .out_start  (/* open */     ), // output  wire
    .out_valid  (/* open */     )  // output  wire
);

// b_step_y* y + b_offset
accelbrot_com_add #(
    .WWIDTH(WWIDTH)
) u_add_by_offset (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .a          (w_s3_by        ), // input [WWIDTH-1:0]
    .b          (w_s3_b_offset  ), // input [WWIDTH-1:0]
    .ab_start   (w_s3_start     ), // input
    .ab_valid   (w_s3_valid     ), // input
    .q          (enter_b        ), // output[WWIDTH-1:0]
    .q_start    (/* open */     ), // output
    .q_valid    (/* open */     )  // output
);

wire[TWIDTH-1:0] w_s1_tag = {r_s1_y, r_s1_x};
accelbrot_com_delay #(
    .DEPTH(MULT_LATENCY + ADD_SUB_LATENCY),
    .WIDTH(TWIDTH)
) u_delay_tag (
    .clk    (clk        ), // input
    .rstn   (rstn       ), // input
    .clken  ('1         ), // input
    .in     (w_s1_tag   ), // input [WIDTH-1:0]
    .out    (enter_tag  )  // output[WIDTH-1:0]
);

endmodule

`default_nettype wire
