`default_nettype none

module accelbrot_loop_enter #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int CWIDTH = 16,
    parameter int TWIDTH = 24
) (
    input   wire            clk             ,
    input   wire            rstn            ,
    output  wire[31:0]      sts_num_entered ,
    input   wire[WWIDTH-1:0]enter_a         ,
    input   wire[WWIDTH-1:0]enter_b         ,
    input   wire[TWIDTH-1:0]enter_tag       ,
    input   wire            enter_start     ,
    input   wire            enter_valid     ,
    output  wire            enter_bp        ,
    output  wire            enter_insert    ,
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

localparam int CNTR_WIDTH = $clog2(NWORDS);
localparam int WFIFO_DEPTH = 256;
localparam int TFIFO_DEPTH = WFIFO_DEPTH / NWORDS;

wire[WWIDTH-1:0]w_enter_a;
wire[WWIDTH-1:0]w_enter_b;
wire[TWIDTH-1:0]w_enter_tag;
wire            w_enter_w_valid;
wire            w_enter_w_ready;
wire            w_enter_t_valid;
wire            w_enter_t_ready;

wire[WWIDTH-1:0]w_in_x;
wire[WWIDTH-1:0]w_in_y;
wire[WWIDTH-1:0]w_in_a;
wire[WWIDTH-1:0]w_in_b;
wire[TWIDTH-1:0]w_in_tag;
wire[CWIDTH-1:0]w_in_count;
wire            w_in_finish;
wire            w_in_w_valid;
wire            w_in_w_ready;
wire            w_in_t_valid;
wire            w_in_t_ready;
wire            w_in_afull;

accelbrot_com_ram_fifo #(
    .DATA_WIDTH (WWIDTH * 2 ),
    .DEPTH      (WFIFO_DEPTH),
    .AFULL_TH   (WFIFO_DEPTH - NWORDS * 4)
) u_enter_wfifo (
    .rstn       (rstn           ), // input
    .clk        (clk            ), // input
    .afull      (/* open */     ), // output
    .aempty     (/* open */     ), // output
    .written    (/* open */     ), // output[SIZE_WIDTH-1:0]
    .readable   (/* open */     ), // output[SIZE_WIDTH-1:0]
    .wr_data    ({enter_b, enter_a}), // input [DATA_WIDTH-1:0]
    .wr_valid   (enter_valid    ), // input
    .wr_ready   (/* open */     ), // output
    .rd_data    ({w_enter_b, w_enter_a}), // output[DATA_WIDTH-1:0]
    .rd_valid   (w_enter_w_valid), // output
    .rd_ready   (w_enter_w_ready)  // input
);

logic[CNTR_WIDTH-1:0] r_enter_cntr;
logic r_enter_last;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_enter_cntr <= '0;
        r_enter_last <= '0;
    end else begin
        if (enter_valid && enter_start) begin
            r_enter_cntr <= 'd1;
        end else if ('0 < r_enter_cntr && r_enter_cntr < NWORDS - 1) begin
            r_enter_cntr <= r_enter_cntr + 'd1;
        end else begin
            r_enter_cntr <= '0;
        end
        r_enter_last <= (r_enter_cntr == NWORDS - 2);
    end
end

wire[$clog2(TFIFO_DEPTH+1)-1:0] w_written;
accelbrot_com_ram_fifo #(
    .DATA_WIDTH (TWIDTH     ),
    .DEPTH      (TFIFO_DEPTH),
    .AFULL_TH   (TFIFO_DEPTH - 4)
) u_enter_tfifo (
    .rstn       (rstn           ), // input
    .clk        (clk            ), // input
    .afull      (enter_bp       ), // output
    .aempty     (/* open */     ), // output
    .written    (w_written      ), // output[SIZE_WIDTH-1:0]
    .readable   (/* open */     ), // output[SIZE_WIDTH-1:0]
    .wr_data    (enter_tag      ), // input [DATA_WIDTH-1:0]
    .wr_valid   (r_enter_last   ), // input
    .wr_ready   (/* open */     ), // output
    .rd_data    (w_enter_tag    ), // output[DATA_WIDTH-1:0]
    .rd_valid   (w_enter_t_valid), // output
    .rd_ready   (w_enter_t_ready)  // input
);

logic[31:0] r_entered;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_entered <= '0;
    end else begin
        r_entered <= w_written;
    end
end
assign sts_num_entered = r_entered;

assign enter_insert = w_enter_t_valid & w_enter_t_ready;

accelbrot_com_ram_fifo #(
    .DATA_WIDTH (WWIDTH * 4 ),
    .DEPTH      (WFIFO_DEPTH),
    .AFULL_TH   (WFIFO_DEPTH - NWORDS * 4)
) u_in_wfifo (
    .rstn       (rstn           ), // input
    .clk        (clk            ), // input
    .afull      (/* open */     ), // output
    .aempty     (/* open */     ), // output
    .written    (/* open */     ), // output[SIZE_WIDTH-1:0]
    .readable   (/* open */     ), // output[SIZE_WIDTH-1:0]
    .wr_data    ({in_b, in_a, in_y, in_x}), // input [DATA_WIDTH-1:0]
    .wr_valid   (in_valid       ), // input
    .wr_ready   (/* open */     ), // output
    .rd_data    ({w_in_b, w_in_a, w_in_y, w_in_x}), // output[DATA_WIDTH-1:0]
    .rd_valid   (w_in_w_valid   ), // output
    .rd_ready   (w_in_w_ready   )  // input
);

logic[CNTR_WIDTH-1:0] r_in_cntr;
logic r_in_last;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_in_cntr <= '0;
        r_in_last <= '0;
    end else begin
        if (in_valid && in_start) begin
            r_in_cntr <= 'd1;
        end else if ('0 < r_in_cntr && r_in_cntr < NWORDS - 1) begin
            r_in_cntr <= r_in_cntr + 'd1;
        end else begin
            r_in_cntr <= '0;
        end
        r_in_last <= (r_in_cntr == NWORDS - 2);
    end
end

accelbrot_com_ram_fifo #(
    .DATA_WIDTH (TWIDTH + CWIDTH + 1),
    .DEPTH      (TFIFO_DEPTH),
    .AFULL_TH   (TFIFO_DEPTH - 4)
) u_in_tfifo (
    .rstn       (rstn           ), // input
    .clk        (clk            ), // input
    .afull      (w_in_afull     ), // output
    .aempty     (/* open */     ), // output
    .written    (/* open */     ), // output[SIZE_WIDTH-1:0]
    .readable   (/* open */     ), // output[SIZE_WIDTH-1:0]
    .wr_data    ({in_finish, in_count, in_tag}), // input [DATA_WIDTH-1:0]
    .wr_valid   (r_in_last      ), // input
    .wr_ready   (/* open */     ), // output
    .rd_data    ({w_in_finish, w_in_count, w_in_tag}), // output[DATA_WIDTH-1:0]
    .rd_valid   (w_in_t_valid   ), // output
    .rd_ready   (w_in_t_ready   )  // input
);

logic[CNTR_WIDTH-1:0] r_out_cntr;
logic r_sel_new;

logic[WWIDTH-1:0]r_out_x;
logic[WWIDTH-1:0]r_out_y;
logic[WWIDTH-1:0]r_out_a;
logic[WWIDTH-1:0]r_out_b;
logic[TWIDTH-1:0]r_out_tag;
logic[TWIDTH-1:0]r_out_count;
logic            r_out_finish;
logic            r_out_start;
logic            r_out_valid;

wire w_enter_start = (r_out_cntr == '0) && !w_in_afull && w_enter_t_valid;
wire w_in_start  = (r_out_cntr == '0) && !w_enter_start && w_in_t_valid;

assign w_enter_t_ready = w_enter_start;
assign w_enter_w_ready = w_enter_start || ((r_out_cntr != 0) && r_sel_new);

assign w_in_t_ready = w_in_start;
assign w_in_w_ready = w_in_start || ((r_out_cntr != 0) && !r_sel_new);

always_ff @(posedge clk) begin
    if (!rstn) begin
        r_out_cntr  <= '0;
        r_sel_new   <= '0;
        r_out_x     <= '0;
        r_out_y     <= '0;
        r_out_a     <= '0;
        r_out_b     <= '0;
        r_out_tag   <= '0;
        r_out_count <= '0;
        r_out_finish<= '0;
        r_out_start <= '0;
        r_out_valid <= '0;
    end else if (r_out_cntr == '0) begin
        if (w_enter_start) begin
            r_out_cntr  <= 'd1;
            r_sel_new   <= '1;
            r_out_x     <= '0;
            r_out_y     <= '0;
            r_out_a     <= w_enter_a;
            r_out_b     <= w_enter_b;
            r_out_tag   <= w_enter_tag;
            r_out_count <= '0;
            r_out_finish<= '0;
            r_out_start <= '1;
            r_out_valid <= '1;
        end else if (w_in_start) begin
            r_out_cntr  <= 'd1;
            r_sel_new   <= '0;
            r_out_x     <= w_in_x;
            r_out_y     <= w_in_y;
            r_out_a     <= w_in_a;
            r_out_b     <= w_in_b;
            r_out_tag   <= w_in_tag;
            r_out_count <= w_in_count;
            r_out_finish<= w_in_finish;
            r_out_start <= '1;
            r_out_valid <= '1;
        end else begin
            r_out_start <= '0;
            r_out_valid <= '0;
        end
    end else begin
        if (r_out_cntr < NWORDS - 1) begin
            r_out_cntr <= r_out_cntr + 'd1;
        end else begin
            r_out_cntr <= '0;
        end
        r_out_x     <= r_sel_new ? {WWIDTH{1'b0}} : w_in_x;
        r_out_y     <= r_sel_new ? {WWIDTH{1'b0}} : w_in_y;
        r_out_a     <= r_sel_new ? w_enter_a      : w_in_a;
        r_out_b     <= r_sel_new ? w_enter_b      : w_in_b;
        r_out_start <= '0;
        r_out_valid <= '1;
    end
end

assign out_x        = r_out_x       ;
assign out_y        = r_out_y       ;
assign out_a        = r_out_a       ;
assign out_b        = r_out_b       ;
assign out_tag      = r_out_tag     ;
assign out_count    = r_out_count   ;
assign out_finish   = r_out_finish  ;
assign out_start    = r_out_start   ;
assign out_valid    = r_out_valid   ;
    
endmodule

`default_nettype wire
