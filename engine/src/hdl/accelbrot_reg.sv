`default_nettype none

module accelbrot_reg #(
    parameter int NCORES = 3,
    parameter int NWORDS = 8,
    parameter int IWIDTH = 6,
    parameter int WWIDTH = 34,
    parameter int CWIDTH = 20,
    parameter int PWIDTH = 12,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int BUFF_ADDR_WIDTH = 14,
    parameter int BWIDTH = NWORDS * WWIDTH
) (
    input   wire                        clk                 ,
    input   wire                        rstn                ,
    input   wire[15:0]                  reg_address         ,
    input   wire                        reg_write           ,
    input   wire[31:0]                  reg_writedata       ,
    input   wire                        reg_read            ,
    output  wire[31:0]                  reg_readdata        ,
    output  wire                        reg_readdatavalid   ,
    input   wire                        sts_busy            ,
    input   wire[7:0]                   sts_fsm_state       ,
    input   wire[31:0]                  sts_axi_state       ,
    input   wire[31:0]                  sts_num_active      ,
    input   wire[31:0]                  sts_num_queued      ,
    input   wire[31:0]                  sts_num_entered     ,
    input   wire[31:0]                  sts_num_running     ,
    input   wire[31:0]                  sts_num_exited      ,
    input   wire[CWIDTH-1:0]            sts_max_iter        ,
    input   wire[CWIDTH+PWIDTH*2-1:0]   sts_total_iter      ,
    output  wire[7:0]                   ctl_command         ,
    output  wire                        ctl_soft_reset      ,
    output  wire[AXI_ADDR_WIDTH-1:0]    ctl_img_addr        ,
    output  wire[PWIDTH-1:0]            ctl_img_width       ,
    output  wire[PWIDTH-1:0]            ctl_img_height      ,
    output  wire[15:0]                  ctl_img_stride      ,
    output  wire[BWIDTH-1:0]            ctl_a_offset        ,
    output  wire[BWIDTH-1:0]            ctl_b_offset        ,
    output  wire[BWIDTH-1:0]            ctl_a_step_x        ,
    output  wire[BWIDTH-1:0]            ctl_b_step_y        ,
    output  wire[CWIDTH-1:0]            ctl_max_iter        ,
    output  wire[PWIDTH-1:0]            ctl_rect_x          ,
    output  wire[PWIDTH-1:0]            ctl_rect_y          ,
    output  wire[PWIDTH-1:0]            ctl_rect_width      ,
    output  wire[PWIDTH-1:0]            ctl_rect_height     ,
    output  wire[31:0]                  ctl_rect_value      ,
    output  wire[31:0]                  ctl_cmd_flags       ,
    output  wire[BUFF_ADDR_WIDTH-1:0]   buff_addr           ,
    output  wire                        buff_rd_en          ,
    input   wire[31:0]                  buff_rd_data        ,
    input   wire                        buff_rd_ack
);

localparam int ABWIDTH = ((BWIDTH + 31) / 32) * 32;

localparam[31:0] VERSION = 32'h23072300;
localparam[31:0] PRSEED = 32'h00000006;

localparam[15:0] PRM_VERSION        = 16'h0000;
localparam[15:0] PRM_PRSEED         = 16'h000C;
localparam[15:0] PRM_NCORES         = 16'h0010;
localparam[15:0] PRM_NWORDS         = 16'h0014;
localparam[15:0] PRM_WWIDTH         = 16'h0018;
localparam[15:0] PRM_IWIDTH         = 16'h001C;
localparam[15:0] PRM_CWIDTH         = 16'h0020;
localparam[15:0] STS_BUSY           = 16'h0100;
localparam[15:0] STS_LATCH          = 16'h0110;
localparam[15:0] STS_FSM_STATE      = 16'h0120;
localparam[15:0] STS_AXI_STATE      = 16'h0128;
localparam[15:0] STS_NUM_ACTIVE     = 16'h0130;
localparam[15:0] STS_NUM_QUEUED     = 16'h0134;
localparam[15:0] STS_NUM_ENTERED    = 16'h0138;
localparam[15:0] STS_NUM_RUNNING    = 16'h0140;
localparam[15:0] STS_NUM_EXITED     = 16'h0144;
localparam[15:0] STS_MAX_ITER       = 16'h0160;
localparam[15:0] STS_TOTAL_ITER_L   = 16'h0168;
localparam[15:0] STS_TOTAL_ITER_H   = 16'h016C;
localparam[15:0] CTL_SOFT_RESET     = 16'h0400;
localparam[15:0] CTL_COMMAND        = 16'h0410;
localparam[15:0] CTL_IMG_ADDR_L     = 16'h0420;
localparam[15:0] CTL_IMG_ADDR_H     = 16'h0424;
localparam[15:0] CTL_IMG_WIDTH      = 16'h0430;
localparam[15:0] CTL_IMG_HEIGHT     = 16'h0434;
localparam[15:0] CTL_IMG_STRIDE     = 16'h0438;
localparam[15:0] CTL_A_OFFSET       = 16'h0500;
localparam[15:0] CTL_B_OFFSET       = 16'h0504;
localparam[15:0] CTL_A_STEP_X       = 16'h0510;
localparam[15:0] CTL_A_STEP_Y       = 16'h0514; // resereved
localparam[15:0] CTL_B_STEP_X       = 16'h0518; // resereved
localparam[15:0] CTL_B_STEP_Y       = 16'h051C;
localparam[15:0] CTL_MAX_ITER       = 16'h0540;
localparam[15:0] CTL_RECT_X         = 16'h0600;
localparam[15:0] CTL_RECT_Y         = 16'h0604;
localparam[15:0] CTL_RECT_WIDTH     = 16'h0608;
localparam[15:0] CTL_RECT_HEIGHT    = 16'h060c;
localparam[15:0] CTL_RECT_VALUE     = 16'h0610;
localparam[15:0] CTL_CMD_FLAGS      = 16'h0614;
localparam[15:0] BUFF_BASE          = 16'h4000;

logic[7:0]                  r_sts_fsm_state     ;
logic[31:0]                 r_sts_axi_state     ;
logic[31:0]                 r_sts_num_active    ;
logic[31:0]                 r_sts_num_queued    ;
logic[31:0]                 r_sts_num_entered   ;
logic[31:0]                 r_sts_num_running   ;
logic[31:0]                 r_sts_num_exited    ;
logic[CWIDTH-1:0]           r_sts_max_iter      ;
logic[CWIDTH+PWIDTH*2-1:0]  r_sts_total_iter    ;

logic               r_ctl_soft_reset    ;
logic[7:0]          r_ctl_command       ;
logic[63:0]         r_ctl_img_addr      ;
logic[PWIDTH-1:0]   r_ctl_img_width     ;
logic[PWIDTH-1:0]   r_ctl_img_height    ;
logic[15:0]         r_ctl_img_stride    ;
logic[ABWIDTH-1:0]  r_ctl_a_offset      ;
logic[ABWIDTH-1:0]  r_ctl_b_offset      ;
logic[ABWIDTH-1:0]  r_ctl_a_step_x      ;
logic[ABWIDTH-1:0]  r_ctl_b_step_y      ;
logic[CWIDTH-1:0]   r_ctl_max_iter      ;
logic[PWIDTH-1:0]   r_ctl_rect_x        ;
logic[PWIDTH-1:0]   r_ctl_rect_y        ;
logic[PWIDTH-1:0]   r_ctl_rect_width    ;
logic[PWIDTH-1:0]   r_ctl_rect_height   ;
logic[31:0]         r_ctl_rect_value    ;
logic[31:0]         r_ctl_cmd_flags     ;

assign ctl_soft_reset   = r_ctl_soft_reset  ;
assign ctl_command      = r_ctl_command     ;
assign ctl_img_addr     = r_ctl_img_addr    ;
assign ctl_img_width    = r_ctl_img_width   ;
assign ctl_img_height   = r_ctl_img_height  ;
assign ctl_img_stride   = r_ctl_img_stride  ;
assign ctl_a_offset     = r_ctl_a_offset    ;
assign ctl_b_offset     = r_ctl_b_offset    ;
assign ctl_a_step_x     = r_ctl_a_step_x    ;
assign ctl_b_step_y     = r_ctl_b_step_y    ;
assign ctl_max_iter     = r_ctl_max_iter    ;
assign ctl_rect_x       = r_ctl_rect_x      ;
assign ctl_rect_y       = r_ctl_rect_y      ;
assign ctl_rect_width   = r_ctl_rect_width  ;
assign ctl_rect_height  = r_ctl_rect_height ;
assign ctl_rect_value   = r_ctl_rect_value  ;
assign ctl_cmd_flags    = r_ctl_cmd_flags   ;

logic[15:0] r_addr;
logic       r_reg_wr_en;
logic[31:0] r_wr_data;
logic       r_reg_rd_en;
logic       r_buff_rd_en;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_addr <= '0;
        r_reg_wr_en <= '0;
        r_wr_data <= '0;
        r_reg_rd_en <= '0;
        r_buff_rd_en <= '0;
    end else begin
        r_addr <= reg_address;
        r_reg_wr_en <= (reg_address < BUFF_BASE) && reg_write;
        r_wr_data <= reg_writedata;
        r_reg_rd_en <= (reg_address < BUFF_BASE) && reg_read;
        r_buff_rd_en <= (reg_address >= BUFF_BASE) && reg_read;
    end
end
assign buff_addr = (r_addr - BUFF_BASE) >> 2;
assign buff_rd_en = r_buff_rd_en;

// write only registers
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_ctl_soft_reset <= '0;
        r_ctl_command <= '0;
        r_sts_fsm_state     <= '0;
        r_sts_axi_state     <= '0;
        r_sts_num_active    <= '0;
        r_sts_num_queued    <= '0;
        r_sts_num_entered   <= '0;
        r_sts_num_running   <= '0;
        r_sts_num_exited    <= '0;
        r_sts_max_iter      <= '0;
        r_sts_total_iter    <= '0;

    end else begin
        r_ctl_soft_reset <= (r_reg_wr_en && r_addr == CTL_SOFT_RESET) ? r_wr_data[0] : '0;
        r_ctl_command <= (r_reg_wr_en && r_addr == CTL_COMMAND) ? r_wr_data[7:0] : '0;
        if (r_reg_wr_en && r_addr == STS_LATCH && r_wr_data[0]) begin
            r_sts_fsm_state     <= sts_fsm_state    ;
            r_sts_axi_state     <= sts_axi_state    ;
            r_sts_num_active    <= sts_num_active   ;
            r_sts_num_queued    <= sts_num_queued   ;
            r_sts_num_entered   <= sts_num_entered  ;
            r_sts_num_running   <= sts_num_running  ;
            r_sts_num_exited    <= sts_num_exited   ;
            r_sts_max_iter      <= sts_max_iter     ;
            r_sts_total_iter    <= sts_total_iter   ;
        end
    end
end

// read/write registers
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_ctl_img_addr <= '0;
        r_ctl_img_width     <= '0;
        r_ctl_img_height    <= '0;
        r_ctl_img_stride    <= '0;
        r_ctl_a_offset      <= '0;
        r_ctl_b_offset      <= '0;
        r_ctl_a_step_x      <= '0;
        r_ctl_b_step_y      <= '0;
        r_ctl_max_iter      <= '0;
        r_ctl_rect_x        <= '0;
        r_ctl_rect_y        <= '0;
        r_ctl_rect_width    <= '0;
        r_ctl_rect_height   <= '0;
        r_ctl_rect_value    <= '0;
        r_ctl_cmd_flags     <= '0;
    end else if (r_reg_wr_en) begin
        if (r_addr < BUFF_BASE) begin
            case (r_addr)
            CTL_IMG_ADDR_L  : r_ctl_img_addr[31:0] <= r_wr_data;
            CTL_IMG_ADDR_H  : r_ctl_img_addr[63:32]<= r_wr_data;
            CTL_IMG_WIDTH   : r_ctl_img_width   <= r_wr_data;
            CTL_IMG_HEIGHT  : r_ctl_img_height  <= r_wr_data;
            CTL_IMG_STRIDE  : r_ctl_img_stride  <= r_wr_data;
            CTL_A_OFFSET    : r_ctl_a_offset    <= {r_wr_data, r_ctl_a_offset[ABWIDTH-1:32]};
            CTL_B_OFFSET    : r_ctl_b_offset    <= {r_wr_data, r_ctl_b_offset[ABWIDTH-1:32]};
            CTL_A_STEP_X    : r_ctl_a_step_x    <= {r_wr_data, r_ctl_a_step_x[ABWIDTH-1:32]};
            CTL_B_STEP_Y    : r_ctl_b_step_y    <= {r_wr_data, r_ctl_b_step_y[ABWIDTH-1:32]};
            CTL_MAX_ITER    : r_ctl_max_iter    <= r_wr_data;
            CTL_RECT_X      : r_ctl_rect_x      <= r_wr_data;
            CTL_RECT_Y      : r_ctl_rect_y      <= r_wr_data;
            CTL_RECT_WIDTH  : r_ctl_rect_width  <= r_wr_data;
            CTL_RECT_HEIGHT : r_ctl_rect_height <= r_wr_data;
            CTL_RECT_VALUE  : r_ctl_rect_value  <= r_wr_data;
            CTL_CMD_FLAGS   : r_ctl_cmd_flags   <= r_wr_data;
            endcase
        end
    end
end

// register read
logic[31:0] r_rd_data;
logic r_rd_ack;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_rd_data <= '0;
        r_rd_ack <= '0;
    end else if (r_reg_rd_en) begin
        case (r_addr)
        PRM_VERSION     : r_rd_data <= VERSION;
        PRM_PRSEED      : r_rd_data <= PRSEED;
        PRM_NCORES      : r_rd_data <= NCORES;
        PRM_NWORDS      : r_rd_data <= NWORDS;
        PRM_WWIDTH      : r_rd_data <= WWIDTH;
        PRM_IWIDTH      : r_rd_data <= IWIDTH;
        PRM_CWIDTH      : r_rd_data <= CWIDTH;
        STS_BUSY        : r_rd_data <= sts_busy;
        STS_FSM_STATE   : r_rd_data <= r_sts_fsm_state;
        STS_AXI_STATE   : r_rd_data <= r_sts_axi_state;
        STS_NUM_ACTIVE  : r_rd_data <= r_sts_num_active;
        STS_NUM_QUEUED  : r_rd_data <= r_sts_num_queued;
        STS_NUM_ENTERED : r_rd_data <= r_sts_num_entered;
        STS_NUM_RUNNING : r_rd_data <= r_sts_num_running;
        STS_NUM_EXITED  : r_rd_data <= r_sts_num_exited;
        STS_MAX_ITER    : r_rd_data <= r_sts_max_iter;
        STS_TOTAL_ITER_L: r_rd_data <= r_sts_total_iter[31:0];
        STS_TOTAL_ITER_H: r_rd_data <= r_sts_total_iter[CWIDTH+PWIDTH*2-1:32];
        CTL_IMG_ADDR_L  : r_rd_data <= r_ctl_img_addr[31:0];
        CTL_IMG_ADDR_H  : r_rd_data <= r_ctl_img_addr[63:32];
        CTL_IMG_WIDTH   : r_rd_data <= r_ctl_img_width  ;
        CTL_IMG_HEIGHT  : r_rd_data <= r_ctl_img_height ;
        CTL_IMG_STRIDE  : r_rd_data <= r_ctl_img_stride ;
        CTL_A_OFFSET    : r_rd_data <= r_ctl_a_offset[ABWIDTH-1:ABWIDTH-32];
        CTL_B_OFFSET    : r_rd_data <= r_ctl_b_offset[ABWIDTH-1:ABWIDTH-32];
        CTL_A_STEP_X    : r_rd_data <= r_ctl_a_step_x[ABWIDTH-1:ABWIDTH-32];
        CTL_B_STEP_Y    : r_rd_data <= r_ctl_b_step_y[ABWIDTH-1:ABWIDTH-32];
        CTL_MAX_ITER    : r_rd_data <= r_ctl_max_iter   ;
        CTL_RECT_X      : r_rd_data <= r_ctl_rect_x     ;
        CTL_RECT_Y      : r_rd_data <= r_ctl_rect_y     ;
        CTL_RECT_WIDTH  : r_rd_data <= r_ctl_rect_width ;
        CTL_RECT_HEIGHT : r_rd_data <= r_ctl_rect_height;
        CTL_RECT_VALUE  : r_rd_data <= r_ctl_rect_value ;
        CTL_CMD_FLAGS   : r_rd_data <= r_ctl_cmd_flags  ;
        default         : r_rd_data <= '0;
        endcase
        r_rd_ack <= '1;
    end else if (buff_rd_ack) begin
        r_rd_data <= buff_rd_data;
        r_rd_ack  <= '1;
    end else begin
        r_rd_ack  <= '0;
    end
end
assign reg_readdata = r_rd_data;
assign reg_readdatavalid = r_rd_ack;

endmodule

`default_nettype wire
