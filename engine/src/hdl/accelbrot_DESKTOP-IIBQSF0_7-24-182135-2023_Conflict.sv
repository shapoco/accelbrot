`default_nettype none

module accelbrot #(
    parameter int NCORES = 3,
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int IWIDTH = 6,
    parameter int CWIDTH = 20,
    parameter int PWIDTH = 12,
    parameter int QDEPTH = 16 * 1024,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 128,
    parameter int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8,
    parameter int BWIDTH = NWORDS * WWIDTH,
    parameter int TWIDTH = PWIDTH * 2
) (
    input   wire                    clk                 ,
    input   wire                    rstn                ,
    input   wire[15:0]              reg_address         ,
    input   wire                    reg_write           ,
    input   wire[31:0]              reg_writedata       ,
    input   wire                    reg_read            ,
    output  wire[31:0]              reg_readdata        ,
    output  wire                    reg_readdatavalid   ,
    output  wire[AXI_ADDR_WIDTH-1:0]wram_araddr         ,
    output  wire[7:0]               wram_arlen          ,
    output  wire[2:0]               wram_arsize         ,
    output  wire[1:0]               wram_arburst        ,
    output  wire                    wram_arvalid        ,
    input   wire                    wram_arready        ,
    input   wire[AXI_DATA_WIDTH-1:0]wram_rdata          ,
    input   wire                    wram_rlast          ,
    input   wire[1:0]               wram_rresp          ,
    input   wire                    wram_rvalid         ,
    output  wire                    wram_rready         ,
    output  wire[AXI_ADDR_WIDTH-1:0]wram_awaddr         ,
    output  wire[7:0]               wram_awlen          ,
    output  wire[2:0]               wram_awsize         ,
    output  wire[1:0]               wram_awburst        ,
    output  wire                    wram_awvalid        ,
    input   wire                    wram_awready        ,
    output  wire[AXI_DATA_WIDTH-1:0]wram_wdata          ,
    output  wire[AXI_STRB_WIDTH-1:0]wram_wstrb          ,
    output  wire                    wram_wlast          ,
    output  wire                    wram_wvalid         ,
    input   wire                    wram_wready         ,
    input   wire[1:0]               wram_bresp          ,
    input   wire                    wram_bvalid         ,
    output  wire                    wram_bready
);

localparam int RST_WIDTH = 10;

localparam int BYTES_PER_PIXEL = 4;

localparam[7:0] CMD_EDGE_SCAN = 8'h01;
localparam[7:0] CMD_RECT_SCAN = 8'h02;

localparam int SCAN_FLAG_WRITE = 0;
localparam int SCAN_FLAG_PUSH_TASK  = 1;

localparam int PIX_FLAG_HANDLED     = 31;
localparam int PIX_FLAG_FINISHED    = 30;

localparam int BUFF_ADDR_WIDTH = 14;

typedef enum {
    RESET, IDLE, 
    EDGE_INIT, EDGE_WAIT_CENTER, 
    EDGE_ADDR0, EDGE_ADDR1, EDGE_ADDR2,
    EDGE_READ_REQ, EDGE_READ_WAIT,
    EDGE_DETECT, EDGE_TRIG, EDGE_WRITE,
    RECT_INIT, RECT_ACCESS, RECT_READ_WAIT
} state_t;

localparam[2:0] NEIGHBOR_UL = 'd0;
localparam[2:0] NEIGHBOR_UC = 'd1;
localparam[2:0] NEIGHBOR_UR = 'd2;
localparam[2:0] NEIGHBOR_ML = 'd3;
localparam[2:0] NEIGHBOR_MR = 'd4;
localparam[2:0] NEIGHBOR_DL = 'd5;
localparam[2:0] NEIGHBOR_DC = 'd6;
localparam[2:0] NEIGHBOR_DR = 'd7;

logic                       w_sts_busy      ;
wire[7:0]                   w_sts_fsm_state ;
wire[31:0]                  w_sts_axi_state ;
wire[31:0]                  w_sts_num_active;
wire[31:0]                  w_sts_num_queued;
wire[31:0]                  w_sts_num_entered;
wire[31:0]                  w_sts_num_running;
wire[31:0]                  w_sts_num_exited ;
wire[CWIDTH-1:0]            w_sts_max_iter  ;
wire[CWIDTH+PWIDTH*2-1:0]   w_sts_total_iter;

wire                        w_ctl_soft_reset;
wire[7:0]                   w_ctl_command   ;
wire[BWIDTH-1:0]            w_ctl_a_coeff   ;
wire[BWIDTH-1:0]            w_ctl_a_offset  ;
wire[BWIDTH-1:0]            w_ctl_b_coeff   ;
wire[BWIDTH-1:0]            w_ctl_b_offset  ;
wire[CWIDTH-1:0]            w_ctl_max_iter  ;
wire[AXI_ADDR_WIDTH-1:0]    w_ctl_img_addr  ;
wire[PWIDTH-1:0]            w_ctl_img_width ;
wire[PWIDTH-1:0]            w_ctl_img_height;
wire[15:0]                  w_ctl_img_stride;
wire[PWIDTH-1:0]            w_ctl_rect_x    ;
wire[PWIDTH-1:0]            w_ctl_rect_y    ;
wire[PWIDTH-1:0]            w_ctl_rect_width;
wire[PWIDTH-1:0]            w_ctl_rect_height;
wire[31:0]                  w_ctl_rect_value;
wire[31:0]                  w_ctl_cmd_flags ;
wire[BUFF_ADDR_WIDTH-1:0]   w_buff_addr     ;
wire                        w_buff_rd_en    ;
wire[31:0]                  w_buff_rd_data  ;
wire                        w_buff_rd_ack   ;

accelbrot_reg #(
    .NCORES         (NCORES         ),
    .NWORDS         (NWORDS         ),
    .WWIDTH         (WWIDTH         ),
    .IWIDTH         (IWIDTH         ),
    .CWIDTH         (CWIDTH         ),
    .PWIDTH         (PWIDTH         ),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH ),
    .BUFF_ADDR_WIDTH(BUFF_ADDR_WIDTH)
) u_reg (
    .clk            (clk                ), // input
    .rstn           (rstn               ), // input
    .reg_addr       (reg_addr           ), // input [15:0]
    .reg_wr_en      (reg_wr_en          ), // input
    .reg_wr_data    (reg_wr_data        ), // input [31:0]
    .reg_rd_en      (reg_rd_en          ), // input
    .reg_rd_data    (reg_rd_data        ), // output[31:0]
    .reg_rd_ack     (reg_rd_ack         ), // output
    .sts_busy       (w_sts_busy         ), // input
    .sts_fsm_state  (w_sts_fsm_state    ), // input [7:0]
    .sts_axi_state  (w_sts_axi_state    ), // input [31:0]
    .sts_num_active (w_sts_num_active   ), // input [31:0]
    .sts_num_queued (w_sts_num_queued   ), // input [31:0]
    .sts_num_entered(w_sts_num_entered  ), // input [31:0]
    .sts_num_running(w_sts_num_running  ), // input [31:0]
    .sts_num_exited (w_sts_num_exited   ), // input [31:0]
    .sts_max_iter   (w_sts_max_iter     ), // input [CWIDTH-1:0]
    .sts_total_iter (w_sts_total_iter   ), // input [CWIDTH+PWIDTH*2-1:0]
    .ctl_soft_reset (w_ctl_soft_reset   ), // output
    .ctl_command    (w_ctl_command      ), // output[7:0]
    .ctl_img_addr   (w_ctl_img_addr     ), // output[AXI_ADDR_WIDTH-1:0]
    .ctl_img_width  (w_ctl_img_width    ), // output[PWIDTH-1:0]
    .ctl_img_height (w_ctl_img_height   ), // output[PWIDTH-1:0]
    .ctl_img_stride (w_ctl_img_stride   ), // output[15:0]
    .ctl_a_coeff    (w_ctl_a_coeff      ), // output[BWIDTH-1:0]
    .ctl_a_offset   (w_ctl_a_offset     ), // output[BWIDTH-1:0]
    .ctl_b_coeff    (w_ctl_b_coeff      ), // output[BWIDTH-1:0]
    .ctl_b_offset   (w_ctl_b_offset     ), // output[BWIDTH-1:0]
    .ctl_max_iter   (w_ctl_max_iter     ), // output[CWIDTH-1:0]
    .ctl_rect_x     (w_ctl_rect_x       ), // output  wire[PWIDTH-1:0]
    .ctl_rect_y     (w_ctl_rect_y       ), // output  wire[PWIDTH-1:0]
    .ctl_rect_width (w_ctl_rect_width   ), // output  wire[PWIDTH-1:0]
    .ctl_rect_height(w_ctl_rect_height  ), // output  wire[PWIDTH-1:0]
    .ctl_rect_value (w_ctl_rect_value   ), // output  wire[PWIDTH-1:0]
    .ctl_cmd_flags  (w_ctl_cmd_flags    ), // output  wire[PWIDTH-1:0]
    .buff_addr      (w_buff_addr        ), // output[BUFF_ADDR_WIDTH-1:0]
    .buff_rd_en     (w_buff_rd_en       ), // output
    .buff_rd_data   (w_buff_rd_data     ), // input [31:0]
    .buff_rd_ack    (w_buff_rd_ack      )  // input
);

logic[RST_WIDTH-1:0] r_rstn_sreg;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_rstn_sreg <= '0;
    end else if (w_ctl_soft_reset) begin
        r_rstn_sreg <= '0;
    end else begin
        r_rstn_sreg <= {r_rstn_sreg[RST_WIDTH-2:0], 1'b1};
    end
end
wire w_rstn = r_rstn_sreg[RST_WIDTH-1];

wire[TWIDTH-1:0]w_exit_tag  ;
wire[CWIDTH-1:0]w_exit_count;
wire            w_exit_valid;
wire            w_exit_ready;

wire[PWIDTH-1:0]w_push_x    ;
wire[PWIDTH-1:0]w_push_y    ;
wire            w_push_valid;
wire            w_push_ready;

accelbrot_fsm #(
    .NCORES         (NCORES         ),
    .NWORDS         (NWORDS         ),
    .WWIDTH         (WWIDTH         ),
    .IWIDTH         (IWIDTH         ),
    .CWIDTH         (CWIDTH         ),
    .PWIDTH         (PWIDTH         ),
    .QDEPTH         (QDEPTH         ),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH ),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH ),
    .BUFF_ADDR_WIDTH(BUFF_ADDR_WIDTH)
) u_fsm (
    .clk            (clk                ), // input
    .rstn           (w_rstn             ), // input
    .sts_busy       (w_sts_busy         ), // output
    .sts_fsm_state  (w_sts_fsm_state    ), // output[7:0]
    .sts_axi_state  (w_sts_axi_state    ), // output[31:0]
    .sts_num_active (w_sts_num_active   ), // output[31:0]
    .sts_max_iter   (w_sts_max_iter     ), // output[CWIDTH-1:0]
    .sts_total_iter (w_sts_total_iter   ), // output[CWIDTH+PWIDTH*2-1:0]
    .ctl_command    (w_ctl_command      ), // input [7:0]
    .ctl_img_addr   (w_ctl_img_addr     ), // input [AXI_ADDR_WIDTH-1:0]
    .ctl_img_width  (w_ctl_img_width    ), // input [PWIDTH-1:0]
    .ctl_img_height (w_ctl_img_height   ), // input [PWIDTH-1:0]
    .ctl_img_stride (w_ctl_img_stride   ), // input [15:0]
    .ctl_rect_x     (w_ctl_rect_x       ), // input [PWIDTH-1:0]
    .ctl_rect_y     (w_ctl_rect_y       ), // input [PWIDTH-1:0]
    .ctl_rect_width (w_ctl_rect_width   ), // input [PWIDTH-1:0]
    .ctl_rect_height(w_ctl_rect_height  ), // input [PWIDTH-1:0]
    .ctl_rect_value (w_ctl_rect_value   ), // input [31:0]
    .ctl_cmd_flags  (w_ctl_cmd_flags    ), // input [31:0]
    .buff_addr      (w_buff_addr        ), // input [BUFF_ADDR_WIDTH-1:0]
    .buff_rd_en     (w_buff_rd_en       ), // input
    .buff_rd_data   (w_buff_rd_data     ), // input [31:0]
    .buff_rd_ack    (w_buff_rd_ack      ), // input
    .push_x         (w_push_x           ), // output[PWIDTH-1:0]
    .push_y         (w_push_y           ), // output[PWIDTH-1:0]
    .push_valid     (w_push_valid       ), // output
    .push_ready     (w_push_ready       ), // input
    .exit_tag       (w_exit_tag         ), // output[TWIDTH-1:0]
    .exit_count     (w_exit_count       ), // output[CWIDTH-1:0]
    .exit_valid     (w_exit_valid       ), // output
    .exit_ready     (w_exit_ready       ), // input
    .wram_araddr    (wram_araddr        ), // output[AXI_ADDR_WIDTH-1:0]
    .wram_arlen     (wram_arlen         ), // output[7:0]
    .wram_arsize    (wram_arsize        ), // output[2:0]
    .wram_arburst   (wram_arburst       ), // output[1:0]
    .wram_arvalid   (wram_arvalid       ), // output
    .wram_arready   (wram_arready       ), // input
    .wram_rdata     (wram_rdata         ), // input [AXI_DATA_WIDTH-1:0]
    .wram_rlast     (wram_rlast         ), // input
    .wram_rresp     (wram_rresp         ), // input [1:0]
    .wram_rvalid    (wram_rvalid        ), // input
    .wram_rready    (wram_rready        ), // output
    .wram_awaddr    (wram_awaddr        ), // output[AXI_ADDR_WIDTH-1:0]
    .wram_awlen     (wram_awlen         ), // output[7:0]
    .wram_awsize    (wram_awsize        ), // output[2:0]
    .wram_awburst   (wram_awburst       ), // output[1:0]
    .wram_awvalid   (wram_awvalid       ), // output
    .wram_awready   (wram_awready       ), // input
    .wram_wdata     (wram_wdata         ), // output[AXI_DATA_WIDTH-1:0]
    .wram_wstrb     (wram_wstrb         ), // output[AXI_STRB_WIDTH-1:0]
    .wram_wlast     (wram_wlast         ), // output
    .wram_wvalid    (wram_wvalid        ), // output
    .wram_wready    (wram_wready        ), // input
    .wram_bresp     (wram_bresp         ), // input [1:0]
    .wram_bvalid    (wram_bvalid        ), // input
    .wram_bready    (wram_bready        )  // output
);

wire[WWIDTH-1:0]w_enter_a       ;
wire[WWIDTH-1:0]w_enter_b       ;
wire[TWIDTH-1:0]w_enter_tag     ;
wire            w_enter_start   ;
wire            w_enter_valid   ;
wire            w_enter_bp      ;

accelbrot_queue #(
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .PWIDTH(PWIDTH),
    .QDEPTH(QDEPTH)
) u_queue (
    .clk            (clk                ), // input
    .rstn           (w_rstn             ), // input
    .sts_num_queued (w_sts_num_queued   ), // output[31:0]
    .ctl_a_coeff    (w_ctl_a_coeff      ), // input [BWIDTH-1:0]
    .ctl_a_offset   (w_ctl_a_offset     ), // input [BWIDTH-1:0]
    .ctl_b_coeff    (w_ctl_b_coeff      ), // input [BWIDTH-1:0]
    .ctl_b_offset   (w_ctl_b_offset     ), // input [BWIDTH-1:0]
    .push_x         (w_push_x           ), // input [PWIDTH-1:0]
    .push_y         (w_push_y           ), // input [PWIDTH-1:0]
    .push_valid     (w_push_valid       ), // input
    .push_ready     (w_push_ready       ), // output
    .enter_a        (w_enter_a          ), // output[WWIDTH-1:0]
    .enter_b        (w_enter_b          ), // output[WWIDTH-1:0]
    .enter_tag      (w_enter_tag        ), // output[TWIDTH-1:0]
    .enter_start    (w_enter_start      ), // output
    .enter_valid    (w_enter_valid      ), // output
    .enter_bp       (w_enter_bp         )  // input
);

accelbrot_loop #(
    .NCORES(NCORES),
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .IWIDTH(IWIDTH),
    .CWIDTH(CWIDTH),
    .TWIDTH(TWIDTH)
) u_loop (
    .clk            (clk                ), // input
    .rstn           (w_rstn             ), // input
    .sts_num_entered(w_sts_num_entered  ), // output[31:0]
    .sts_num_running(w_sts_num_running  ), // output[31:0]
    .sts_num_exited (w_sts_num_exited   ), // output[31:0]
    .ctl_max_iter   (w_ctl_max_iter     ), // input [CWIDTH-1:0]
    .enter_a        (w_enter_a          ), // input [WWIDTH-1:0]
    .enter_b        (w_enter_b          ), // input [WWIDTH-1:0]
    .enter_tag      (w_enter_tag        ), // input [TWIDTH-1:0]
    .enter_start    (w_enter_start      ), // input
    .enter_valid    (w_enter_valid      ), // input
    .enter_bp       (w_enter_bp         ), // output
    .exit_tag       (w_exit_tag         ), // output[TWIDTH-1:0]
    .exit_count     (w_exit_count       ), // output[CWIDTH-1:0]
    .exit_valid     (w_exit_valid       ), // output
    .exit_ready     (w_exit_ready       )  // input
);

endmodule

`default_nettype wire
