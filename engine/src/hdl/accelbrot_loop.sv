`default_nettype none

module accelbrot_loop #(
    parameter int NCORES = 3,
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int IWIDTH = 6,
    parameter int CWIDTH = 20,
    parameter int TWIDTH = 24
) (
    input   wire            clk             ,
    input   wire            rstn            ,
    output  wire[31:0]      sts_num_entered ,
    output  wire[31:0]      sts_num_running ,
    output  wire[31:0]      sts_num_exited  ,
    input   wire[CWIDTH-1:0]ctl_max_iter    ,
    input   wire[WWIDTH-1:0]enter_a         ,
    input   wire[WWIDTH-1:0]enter_b         ,
    input   wire[TWIDTH-1:0]enter_tag       ,
    input   wire            enter_start     ,
    input   wire            enter_valid     ,
    output  wire            enter_bp        ,
    output  wire[TWIDTH-1:0]exit_tag        ,
    output  wire[CWIDTH-1:0]exit_count      ,
    output  wire            exit_valid      ,
    input   wire            exit_ready
);

localparam int BWIDTH = NWORDS * WWIDTH;
localparam int CNTR_WIDTH = $clog2(NWORDS);

wire w_enter_insert;

wire[WWIDTH-1:0]w_loop_x        ;
wire[WWIDTH-1:0]w_loop_y        ;
wire[WWIDTH-1:0]w_loop_a        ;
wire[WWIDTH-1:0]w_loop_b        ;
wire[TWIDTH-1:0]w_loop_tag      ;
wire[CWIDTH-1:0]w_loop_count    ;
wire            w_loop_finish   ;
wire            w_loop_start    ;
wire            w_loop_valid    ;

wire[WWIDTH-1:0]w_iter_x        [0:NCORES];
wire[WWIDTH-1:0]w_iter_y        [0:NCORES];
wire[WWIDTH-1:0]w_iter_a        [0:NCORES];
wire[WWIDTH-1:0]w_iter_b        [0:NCORES];
wire[TWIDTH-1:0]w_iter_tag      [0:NCORES];
wire[CWIDTH-1:0]w_iter_count    [0:NCORES];
wire            w_iter_finish   [0:NCORES];
wire            w_iter_start    [0:NCORES];
wire            w_iter_valid    [0:NCORES];

accelbrot_loop_enter #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .CWIDTH(CWIDTH),
    .TWIDTH(TWIDTH)
) u_enter (
    .clk            (clk                ), // input
    .rstn           (rstn               ), // input
    .sts_num_entered(sts_num_entered    ), // output[31:0]
    .enter_a        (enter_a            ), // input [WWIDTH-1:0]
    .enter_b        (enter_b            ), // input [WWIDTH-1:0]
    .enter_tag      (enter_tag          ), // input [TWIDTH-1:0]
    .enter_start    (enter_start        ), // input
    .enter_valid    (enter_valid        ), // input
    .enter_bp       (enter_bp           ), // output
    .enter_insert   (w_enter_insert     ), // output
    .in_x           (w_loop_x           ), // input [WWIDTH-1:0]
    .in_y           (w_loop_y           ), // input [WWIDTH-1:0]
    .in_a           (w_loop_a           ), // input [WWIDTH-1:0]
    .in_b           (w_loop_b           ), // input [WWIDTH-1:0]
    .in_tag         (w_loop_tag         ), // input [TWIDTH-1:0]
    .in_count       (w_loop_count       ), // input [CWIDTH-1:0]
    .in_finish      (w_loop_finish      ), // input
    .in_start       (w_loop_start       ), // input
    .in_valid       (w_loop_valid       ), // input
    .out_x          (w_iter_x        [0]), // output[WWIDTH-1:0]
    .out_y          (w_iter_y        [0]), // output[WWIDTH-1:0]
    .out_a          (w_iter_a        [0]), // output[WWIDTH-1:0]
    .out_b          (w_iter_b        [0]), // output[WWIDTH-1:0]
    .out_tag        (w_iter_tag      [0]), // output[TWIDTH-1:0]
    .out_count      (w_iter_count    [0]), // output[CWIDTH-1:0]
    .out_finish     (w_iter_finish   [0]), // output
    .out_start      (w_iter_start    [0]), // output
    .out_valid      (w_iter_valid    [0])  // output
);

generate
    for (genvar i = 0; i < NCORES; i++) begin : cores

        accelbrot_loop_core #(
            .NWORDS(NWORDS),
            .WWIDTH(WWIDTH),
            .IWIDTH(IWIDTH),
            .CWIDTH(CWIDTH),
            .TWIDTH(TWIDTH)
        ) u_core (
            .clk            (clk                ), // input
            .rstn           (rstn               ), // input
            .ctl_max_iter   (ctl_max_iter       ), // input [CWIDTH-1:0]
            .in_x           (w_iter_x      [i]  ), // input [WWIDTH-1:0]
            .in_y           (w_iter_y      [i]  ), // input [WWIDTH-1:0]
            .in_a           (w_iter_a      [i]  ), // input [WWIDTH-1:0]
            .in_b           (w_iter_b      [i]  ), // input [WWIDTH-1:0]
            .in_tag         (w_iter_tag    [i]  ), // input [TWIDTH-1:0]
            .in_count       (w_iter_count  [i]  ), // input [CWIDTH-1:0]
            .in_finish      (w_iter_finish [i]  ), // input
            .in_start       (w_iter_start  [i]  ), // input
            .in_valid       (w_iter_valid  [i]  ), // input
            .out_x          (w_iter_x      [i+1]), // output[WWIDTH-1:0]
            .out_y          (w_iter_y      [i+1]), // output[WWIDTH-1:0]
            .out_a          (w_iter_a      [i+1]), // output[WWIDTH-1:0]
            .out_b          (w_iter_b      [i+1]), // output[WWIDTH-1:0]
            .out_tag        (w_iter_tag    [i+1]), // output[TWIDTH-1:0]
            .out_count      (w_iter_count  [i+1]), // output[CWIDTH-1:0]
            .out_finish     (w_iter_finish [i+1]), // output
            .out_start      (w_iter_start  [i+1]), // output
            .out_valid      (w_iter_valid  [i+1])  // output
        );

    end
endgenerate

accelbrot_loop_exit #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .CWIDTH(CWIDTH),
    .TWIDTH(TWIDTH)
) u_exit (
    .clk            (clk                    ), // input
    .rstn           (rstn                   ), // input
    .sts_num_exited (sts_num_exited         ), // output[31:0]
    .in_x           (w_iter_x       [NCORES]), // input [WWIDTH-1:0]
    .in_y           (w_iter_y       [NCORES]), // input [WWIDTH-1:0]
    .in_a           (w_iter_a       [NCORES]), // input [WWIDTH-1:0]
    .in_b           (w_iter_b       [NCORES]), // input [WWIDTH-1:0]
    .in_tag         (w_iter_tag     [NCORES]), // input [TWIDTH-1:0]
    .in_count       (w_iter_count   [NCORES]), // input [CWIDTH-1:0]
    .in_finish      (w_iter_finish  [NCORES]), // input
    .in_start       (w_iter_start   [NCORES]), // input
    .in_valid       (w_iter_valid   [NCORES]), // input
    .out_x          (w_loop_x               ), // output[WWIDTH-1:0]
    .out_y          (w_loop_y               ), // output[WWIDTH-1:0]
    .out_a          (w_loop_a               ), // output[WWIDTH-1:0]
    .out_b          (w_loop_b               ), // output[WWIDTH-1:0]
    .out_tag        (w_loop_tag             ), // output[TWIDTH-1:0]
    .out_count      (w_loop_count           ), // output[CWIDTH-1:0]
    .out_finish     (w_loop_finish          ), // output
    .out_start      (w_loop_start           ), // output
    .out_valid      (w_loop_valid           ), // output
    .exit_tag       (exit_tag               ), // output[TWIDTH-1:0]
    .exit_count     (exit_count             ), // output[CWIDTH-1:0]
    .exit_valid     (exit_valid             ), // output
    .exit_ready     (exit_ready             )  // input
);

logic[31:0] r_sts_num_running;
logic r_running_incr;
logic r_running_decr;
always @(posedge clk) begin
    if (!rstn) begin
        r_running_incr <= '0;
        r_running_decr <= '0;
        r_sts_num_running <= '0;
    end else begin
        r_running_incr <= w_enter_insert;
        r_running_decr <= exit_valid & exit_ready;
        if (r_running_incr && !r_running_decr) begin
            r_sts_num_running <= r_sts_num_running + 'd1;
        end else if (r_running_decr && !r_running_incr) begin
            r_sts_num_running <= r_sts_num_running - 'd1;
        end
    end
end
assign sts_num_running = r_sts_num_running;

endmodule

`default_nettype wire
