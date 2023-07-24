`default_nettype none

module accelbrot_loop_exit #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int CWIDTH = 16,
    parameter int TWIDTH = 24
) (
    input   wire            clk             ,
    input   wire            rstn            ,
    output  wire[31:0]      sts_num_exited  ,
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
    output  wire            out_valid       ,
    output  wire[TWIDTH-1:0]exit_tag        ,
    output  wire[CWIDTH-1:0]exit_count      ,
    output  wire            exit_valid      ,
    input   wire            exit_ready
);

localparam int CNTR_WIDTH = $clog2(NWORDS * 2);
localparam int FIFO_DEPTH = 145;

logic[CNTR_WIDTH-1:0] r_in_cntr;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_in_cntr      <= '0;
    end else if (in_valid && in_start) begin
        r_in_cntr <= 'd1;
    end else if ('0 < r_in_cntr && r_in_cntr < NWORDS - 1) begin
        r_in_cntr <= r_in_cntr + 'd1;
    end else begin
        r_in_cntr <= '0;
    end
end

wire w_exit_bp;
wire w_finish_acpt = in_finish && !w_exit_bp;
wire w_out_start  = (r_in_cntr == NWORDS - 1) && !w_finish_acpt;
wire w_exit_valid = (r_in_cntr == NWORDS - 1) && w_finish_acpt;

logic[CNTR_WIDTH-1:0] r_out_cntr;
logic r_out_start;
logic r_out_valid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_out_cntr  <= '0;
        r_out_start <= '0;
        r_out_valid <= '0;
    end else if (w_out_start) begin
        r_out_cntr  <= NWORDS;
        r_out_start <= '1;
        r_out_valid <= '1;
    end else if (NWORDS <= r_out_cntr && r_out_cntr < NWORDS * 2 - 1) begin
        r_out_cntr  <= r_out_cntr + 'd1;
        r_out_start <= '0;
        r_out_valid <= '1;
    end else begin
        r_out_cntr  <= '0;
        r_out_start <= '0;
        r_out_valid <= '0;
    end
end
assign out_start = r_out_start;
assign out_valid = r_out_valid;

logic[TWIDTH-1:0] r_tag;
logic[CWIDTH-1:0] r_count;
logic r_finish;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_tag   <= '0;
        r_count <= '0;
        r_finish<= '0;
    end else if (r_in_cntr == NWORDS - 1) begin
        r_tag    <= in_tag;
        r_count  <= in_count;
        r_finish <= in_finish;
    end
end
assign out_tag = r_tag;
assign out_count = r_count;
assign out_finish = r_finish;

accelbrot_com_delay #(
    .DEPTH(NWORDS),
    .WIDTH(WWIDTH * 4)
) delay_w_i (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     ({in_b, in_a, in_y, in_x}), // input [WIDTH-1:0]
    .out    ({out_b, out_a, out_y, out_x})  // output[WIDTH-1:0]
);

logic r_exit_valid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_exit_valid <= '0;
    end else begin
        r_exit_valid <= w_exit_valid;
    end
end

wire[$clog2(FIFO_DEPTH+1)-1:0] w_written;
accelbrot_com_ram_fifo #(
    .DATA_WIDTH (CWIDTH + TWIDTH),
    .DEPTH      (FIFO_DEPTH     ),
    .AFULL_TH   (FIFO_DEPTH - 8 )
) u_fifo_exit (
    .rstn       (rstn           ), // input
    .clk        (clk            ), // input
    .afull      (w_exit_bp      ), // output
    .aempty     (/* open */     ), // output
    .written    (w_written      ), // output[SIZE_WIDTH-1:0]
    .readable   (/* open */     ), // output[SIZE_WIDTH-1:0]
    .wr_data    ({r_tag, r_count}), // input [DATA_WIDTH-1:0]
    .wr_valid   (r_exit_valid   ), // input
    .wr_ready   (/* open */     ), // output
    .rd_data    ({exit_tag, exit_count}), // output[DATA_WIDTH-1:0]
    .rd_valid   (exit_valid     ), // output
    .rd_ready   (exit_ready     )  // input
);

logic[31:0] r_exited;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_exited <= '0;
    end else begin
        r_exited <= w_written;
    end
end
assign sts_num_exited = r_exited;

endmodule

`default_nettype wire
