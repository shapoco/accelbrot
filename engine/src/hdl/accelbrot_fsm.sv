`default_nettype none

module accelbrot_fsm #(
    parameter int NCORES = 3,
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34,
    parameter int IWIDTH = 6,
    parameter int CWIDTH = 20,
    parameter int PWIDTH = 12,
    parameter int QDEPTH = 16 * 1024,
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 128,
    parameter int BUFF_ADDR_WIDTH = 15,
    parameter int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8,
    parameter int BWIDTH = NWORDS * WWIDTH,
    parameter int TWIDTH = PWIDTH * 2
) (
    input   wire                        clk             ,
    input   wire                        rstn            ,
    output  wire                        sts_busy        ,
    output  wire[7:0]                   sts_fsm_state   ,
    output  wire[31:0]                  sts_axi_state   ,
    output  wire[31:0]                  sts_num_active  ,
    output  wire[31:0]                  sts_total_queued,
    output  wire[31:0]                  sts_total_exited,
    output  wire[CWIDTH-1:0]            sts_max_iter    ,
    output  wire[CWIDTH+PWIDTH*2-1:0]   sts_total_iter  ,
    output  wire[7:0]                   sts_wram_wrbytes,
    output  wire[7:0]                   sts_wram_rdbytes,
    input   wire[7:0]                   ctl_command     ,
    input   wire[AXI_ADDR_WIDTH-1:0]    ctl_img_addr    ,
    input   wire[PWIDTH-1:0]            ctl_img_width   ,
    input   wire[PWIDTH-1:0]            ctl_img_height  ,
    input   wire[15:0]                  ctl_img_stride  ,
    input   wire[PWIDTH-1:0]            ctl_rect_x      ,
    input   wire[PWIDTH-1:0]            ctl_rect_y      ,
    input   wire[PWIDTH-1:0]            ctl_rect_width  ,
    input   wire[PWIDTH-1:0]            ctl_rect_height ,
    input   wire[31:0]                  ctl_rect_value  ,
    input   wire[31:0]                  ctl_cmd_flags   ,
    output  wire[BUFF_ADDR_WIDTH-1:0]   ctl_rdque_wrptr ,
    input   wire[BUFF_ADDR_WIDTH-1:0]   ctl_rdque_rdptr ,
    input   wire[BUFF_ADDR_WIDTH-1:0]   buff_addr       ,
    input   wire                        buff_rd_en      ,
    output  wire[31:0]                  buff_rd_data    ,
    output  wire                        buff_rd_ack     ,
    output  wire[PWIDTH-1:0]            push_x          ,
    output  wire[PWIDTH-1:0]            push_y          ,
    output  wire                        push_valid      ,
    input   wire                        push_ready      ,
    input   wire[TWIDTH-1:0]            exit_tag        ,
    input   wire[CWIDTH-1:0]            exit_count      ,
    input   wire                        exit_valid      ,
    output  wire                        exit_ready      ,
    output  wire[AXI_ADDR_WIDTH-1:0]    wram_araddr     ,
    output  wire[7:0]                   wram_arlen      ,
    output  wire[2:0]                   wram_arsize     ,
    output  wire[1:0]                   wram_arburst    ,
    output  wire                        wram_arvalid    ,
    input   wire                        wram_arready    ,
    input   wire[AXI_DATA_WIDTH-1:0]    wram_rdata      ,
    input   wire                        wram_rlast      ,
    input   wire[1:0]                   wram_rresp      ,
    input   wire                        wram_rvalid     ,
    output  wire                        wram_rready     ,
    output  wire[AXI_ADDR_WIDTH-1:0]    wram_awaddr     ,
    output  wire[7:0]                   wram_awlen      ,
    output  wire[2:0]                   wram_awsize     ,
    output  wire[1:0]                   wram_awburst    ,
    output  wire                        wram_awvalid    ,
    input   wire                        wram_awready    ,
    output  wire[AXI_DATA_WIDTH-1:0]    wram_wdata      ,
    output  wire[AXI_STRB_WIDTH-1:0]    wram_wstrb      ,
    output  wire                        wram_wlast      ,
    output  wire                        wram_wvalid     ,
    input   wire                        wram_wready     ,
    input   wire[1:0]                   wram_bresp      ,
    input   wire                        wram_bvalid     ,
    output  wire                        wram_bready     ,
    output  wire                        mon_rdque_full
);

localparam int BYTES_PER_PIXEL = 4;
localparam int PIX_PER_WORD = AXI_DATA_WIDTH / 32;
localparam int ALIGN_WIDTH = $clog2(PIX_PER_WORD);

localparam[7:0] CMD_EDGE_SCAN   = 8'h01;
localparam[7:0] CMD_RECT_SCAN   = 8'h02;
localparam[7:0] CMD_RESET_CNTR  = 8'h03;
localparam[7:0] CMD_ABORT       = 8'h04;

localparam int CMD_FLAG_WRITE       = 0;
localparam int CMD_FLAG_PUSH_TASK   = 1;
localparam int CMD_FLAG_RDQUE_ENA   = 2;

localparam int PIX_FLAG_HANDLED     = 31;
localparam int PIX_FLAG_FINISHED    = 30;

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

function[31:0] f_make_word_data(logic handled, logic finished, logic[CWIDTH-1:0] count);
    logic[31:0] v_ret;
    v_ret = '0;
    v_ret[PIX_FLAG_HANDLED] = handled;
    v_ret[PIX_FLAG_FINISHED] = finished;
    v_ret[CWIDTH-1:0] = count;
    return v_ret;
endfunction

logic       r_sts_busy      ;
logic       r_cmd_abort     ;
logic[31:0] r_sts_num_active;
logic[31:0] r_sts_total_queued;
logic[31:0] r_sts_total_exited;
logic[7:0]  r_sts_wram_wrbytes;
logic[7:0]  r_sts_wram_rdbytes;
assign sts_busy = r_sts_busy;
assign sts_num_active = r_sts_num_active;
assign sts_total_queued = r_sts_total_queued;
assign sts_total_exited = r_sts_total_exited;
assign sts_wram_wrbytes = r_sts_wram_wrbytes;
assign sts_wram_rdbytes = r_sts_wram_rdbytes;

wire[31:0] w_wram_rdata;

wire w_cmd_reset_cntr = (ctl_command == CMD_RESET_CNTR) ? '1 : '0;

wire w_cmd_flags_write     = ctl_cmd_flags[CMD_FLAG_WRITE];
wire w_cmd_flags_push_task = ctl_cmd_flags[CMD_FLAG_PUSH_TASK];
wire w_cmd_flags_rdque_ena = ctl_cmd_flags[CMD_FLAG_RDQUE_ENA];

wire w_exit_ready;
wire w_exit_valid;
wire w_exit_acpt;

wire w_edge_raddr_clken;
wire w_edge_reading;
wire w_edge_wr_clken;
wire w_edge_wr_acpt;
wire w_rect_acs_clken;

logic r_edge_raddr_last;
logic[7:0] r_edge_trig;

logic r_rect_s0_x_last;
logic r_rect_s0_y_last;

logic r_read_busy;

logic r_rdque_afull;

state_t r_state;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_state <= RESET;
        r_sts_busy <= '1;
    end else begin
        case (r_state)
        RESET:
            r_state <= IDLE;
            
        IDLE:
            if (ctl_command == CMD_EDGE_SCAN) begin
                r_state <= EDGE_INIT;
            end else if (ctl_command == CMD_RECT_SCAN) begin
                r_state <= RECT_INIT;
            end
        
        EDGE_INIT:
            r_state <= EDGE_WAIT_CENTER;
        
        EDGE_WAIT_CENTER:
            if (r_cmd_abort) begin
                r_state <= IDLE;
            end else if (w_exit_valid) begin
                r_state <= EDGE_ADDR0;
            end else if (r_sts_num_active == '0) begin
                r_state <= IDLE;
            end
        
        EDGE_ADDR0:
            r_state <= EDGE_ADDR1;
        
        EDGE_ADDR1:
            r_state <= EDGE_ADDR2;
        
        EDGE_ADDR2:
            r_state <= EDGE_READ_REQ;
        
        EDGE_READ_REQ:
            if (w_edge_raddr_clken && r_edge_raddr_last) begin
                r_state <= EDGE_READ_WAIT;
            end
        
        EDGE_READ_WAIT:
            if (!w_edge_reading) begin
                r_state <= EDGE_DETECT;
            end
        
        EDGE_DETECT:
            r_state <= EDGE_TRIG;
        
        EDGE_TRIG:
            r_state <= EDGE_WRITE;
        
        EDGE_WRITE:
            if (r_edge_trig == '0 && w_edge_wr_clken) begin
                r_state <= EDGE_WAIT_CENTER;
            end
            
        RECT_INIT:
            r_state <= RECT_ACCESS;
        
        RECT_ACCESS:
            if (r_cmd_abort) begin
                r_state <= IDLE;
            end else if (w_rect_acs_clken && r_rect_s0_y_last && r_rect_s0_x_last) begin
                if (w_cmd_flags_write) begin
                    r_state <= IDLE;
                end else begin
                    r_state <= RECT_READ_WAIT;
                end
            end
        
        RECT_READ_WAIT:
            if (!r_read_busy || r_cmd_abort) begin
                r_state <= IDLE;
            end
        
        default:
            r_state <= RESET;
        endcase
        r_sts_busy <= (r_state != IDLE);
    end
end


always_ff @(posedge clk) begin
    if (!rstn) begin
        r_cmd_abort <= '0;
    end else if (r_state == IDLE) begin
        r_cmd_abort <= '0;
    end else if (ctl_command == CMD_ABORT) begin
        r_cmd_abort <= '1;
    end
end

logic[7:0] r_sts_fsm_state;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_sts_fsm_state <= RESET;
    end else begin
        r_sts_fsm_state <= r_state;
    end
end
assign sts_fsm_state = r_sts_fsm_state;

// exit queue arbitration
assign w_exit_ready = (r_state == EDGE_WAIT_CENTER) && !r_rdque_afull;
assign w_exit_valid = exit_valid & ~r_rdque_afull;
assign w_exit_acpt = w_exit_valid & w_exit_ready;
assign exit_ready = w_exit_ready;

// coordinate latch
logic[PWIDTH-1:0] r_edge_x;
logic[PWIDTH-1:0] r_edge_y;
logic[CWIDTH-1:0] r_count;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_edge_x <= '0;
        r_edge_y <= '0;
        r_count <= '0;
    end else if (w_exit_acpt) begin
        r_edge_x <= exit_tag[PWIDTH-1:0];
        r_edge_y <= exit_tag[PWIDTH*2-1:PWIDTH];
        r_count <= exit_count;
    end
end

// address multiplication
logic[15:0] r_edge_mult_a;
logic[15:0] r_edge_mult_b;
logic[31:0] r_edge_mult_q;
always_ff @(posedge clk) begin
    if (w_exit_acpt) begin
        r_edge_mult_a <= exit_tag[PWIDTH*2-1:PWIDTH];
    end
    r_edge_mult_b <= ctl_img_stride;
    r_edge_mult_q <= r_edge_mult_a * r_edge_mult_b;
end

// dest address
logic[15:0] r_rect_mult_a;
logic[15:0] r_rect_mult_b;
logic[31:0] r_rect_mult_q;
logic[AXI_ADDR_WIDTH-1:0] r_rect_addr;
always_ff @(posedge clk) begin
    r_rect_mult_a <= ctl_rect_y;
    r_rect_mult_b <= ctl_img_stride;
    r_rect_mult_q <= r_rect_mult_a * r_rect_mult_b;
    r_rect_addr <= ctl_img_addr + r_rect_mult_q + ctl_rect_x * BYTES_PER_PIXEL;
end

// AXI read request
logic[2:0] r_edge_raddr_idx;
logic[2:0] r_edge_raddr_idx_d;
logic[AXI_ADDR_WIDTH-1:0] r_edge_pov_addr;
logic[AXI_ADDR_WIDTH-1:0] r_edge_araddr;
logic r_edge_arvalid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_edge_raddr_idx <= '0;
        r_edge_raddr_idx_d <= '0;
        r_edge_raddr_last <= '0;
        r_edge_pov_addr <= '0;
        r_edge_araddr <= '0;
        r_edge_arvalid <= '0;
    end else if (r_state == EDGE_ADDR0) begin
        r_edge_raddr_idx <= '0;
        r_edge_raddr_idx_d <= '0;
        r_edge_raddr_last <= '0;
        r_edge_pov_addr <= '0;
        r_edge_arvalid <= '0;
    end else if (r_state == EDGE_ADDR1) begin
        r_edge_pov_addr <= ctl_img_addr + r_edge_mult_q + r_edge_x * BYTES_PER_PIXEL;
        r_edge_arvalid <= '0;
    end else if (r_state == EDGE_READ_REQ) begin
        if (w_edge_raddr_clken) begin
            r_edge_raddr_idx <= r_edge_raddr_idx + 'd1;
            r_edge_raddr_idx_d <= r_edge_raddr_idx;
            r_edge_raddr_last <= (r_edge_raddr_idx >= 'd6);

            case(r_edge_raddr_idx)
            NEIGHBOR_UL: r_edge_araddr <= r_edge_pov_addr - ctl_img_stride - BYTES_PER_PIXEL;
            NEIGHBOR_UC: r_edge_araddr <= r_edge_pov_addr - ctl_img_stride;
            NEIGHBOR_UR: r_edge_araddr <= r_edge_pov_addr - ctl_img_stride + BYTES_PER_PIXEL;
            NEIGHBOR_ML: r_edge_araddr <= r_edge_pov_addr - BYTES_PER_PIXEL;
            NEIGHBOR_MR: r_edge_araddr <= r_edge_pov_addr + BYTES_PER_PIXEL;
            NEIGHBOR_DL: r_edge_araddr <= r_edge_pov_addr + ctl_img_stride - BYTES_PER_PIXEL;
            NEIGHBOR_DC: r_edge_araddr <= r_edge_pov_addr + ctl_img_stride;
            NEIGHBOR_DR: r_edge_araddr <= r_edge_pov_addr + ctl_img_stride + BYTES_PER_PIXEL;
            endcase
            
            case(r_edge_raddr_idx)
            NEIGHBOR_UL: r_edge_arvalid <= (r_edge_y > '0) && (r_edge_x > '0);
            NEIGHBOR_UC: r_edge_arvalid <= (r_edge_y > '0);
            NEIGHBOR_UR: r_edge_arvalid <= (r_edge_y > '0) && (r_edge_x < ctl_img_width - 'd1);
            NEIGHBOR_ML: r_edge_arvalid <= (r_edge_x > '0);
            NEIGHBOR_MR: r_edge_arvalid <= (r_edge_x < ctl_img_width - 'd1);
            NEIGHBOR_DL: r_edge_arvalid <= (r_edge_y < ctl_img_height - 'd1) && (r_edge_x > '0);
            NEIGHBOR_DC: r_edge_arvalid <= (r_edge_y < ctl_img_height - 'd1);
            NEIGHBOR_DR: r_edge_arvalid <= (r_edge_y < ctl_img_height - 'd1) && (r_edge_x < ctl_img_width - 'd1);
            default: r_edge_arvalid <= '0;
            endcase
        end
    end else begin
        r_edge_arvalid <= '0;
    end
end

wire[2:0] w_edge_rdata_idx;
accelbrot_com_reg_fifo #(
  .DATA_WIDTH   (3),
  .DEPTH        (8)
) u_fifo_edge (
  .clk      (clk        ),
  .rstn     (rstn       ),
  .stored   (/* open */ ),
  .afull    (/* open */ ),
  .aempty   (/* open */ ),
  .wr_ready (/* open */ ),
  .wr_valid (w_edge_raddr_clken & r_edge_arvalid),
  .wr_data  (r_edge_raddr_idx_d),
  .rd_ready (wram_rvalid),
  .rd_valid (w_edge_reading),
  .rd_data  (w_edge_rdata_idx)
);

// edge detection
logic[31:0] r_edge_nei[0:7];
logic r_edge_det_u;
logic r_edge_det_l;
logic r_edge_det_r;
logic r_edge_det_d;
always_ff @(posedge clk) begin
    if (!rstn) begin
        for (int i = 0; i < 8; i++) begin
            r_edge_nei[i] <= '0;
        end
        r_edge_det_u <= '0;
        r_edge_det_l <= '0;
        r_edge_det_r <= '0;
        r_edge_det_d <= '0;
    end else if (r_state == EDGE_ADDR0) begin
        for (int i = 0; i < 8; i++) begin
            r_edge_nei[i] <= (32'd1 << PIX_FLAG_HANDLED);
        end
        r_edge_det_u <= '0;
        r_edge_det_l <= '0;
        r_edge_det_r <= '0;
        r_edge_det_d <= '0;
    end else if (wram_rvalid) begin
        r_edge_nei[w_edge_rdata_idx] <= w_wram_rdata;
    end else if (r_state == EDGE_DETECT) begin
        r_edge_det_u <= r_edge_nei[NEIGHBOR_UC][PIX_FLAG_FINISHED] && r_edge_nei[NEIGHBOR_UC][CWIDTH-1:0] != r_count;
        r_edge_det_d <= r_edge_nei[NEIGHBOR_DC][PIX_FLAG_FINISHED] && r_edge_nei[NEIGHBOR_DC][CWIDTH-1:0] != r_count;
        r_edge_det_l <= r_edge_nei[NEIGHBOR_ML][PIX_FLAG_FINISHED] && r_edge_nei[NEIGHBOR_ML][CWIDTH-1:0] != r_count;
        r_edge_det_r <= r_edge_nei[NEIGHBOR_MR][PIX_FLAG_FINISHED] && r_edge_nei[NEIGHBOR_MR][CWIDTH-1:0] != r_count;
    end
end

logic[AXI_ADDR_WIDTH-1:0] r_edge_awaddr;
logic[31:0] r_edge_wdata;
logic r_edge_wlast;
logic r_edge_wvalid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_edge_trig <= '0;
        r_edge_awaddr <= '0;
        r_edge_wdata <= '0;
        r_edge_wlast <= '0;
        r_edge_wvalid <= '0;
    end else if (r_state == EDGE_ADDR0) begin
        r_edge_trig <= '0;
        r_edge_wlast <= '0;
        r_edge_wvalid <= '0;
    end else if (r_state == EDGE_TRIG) begin
        if (r_edge_det_u) begin
            if (!r_edge_nei[NEIGHBOR_UL][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_UL] = '1;
            if (!r_edge_nei[NEIGHBOR_ML][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_ML] = '1;
            if (!r_edge_nei[NEIGHBOR_UR][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_UR] = '1;
            if (!r_edge_nei[NEIGHBOR_MR][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_MR] = '1;
        end
        if (r_edge_det_d) begin
            if (!r_edge_nei[NEIGHBOR_ML][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_ML] = '1;
            if (!r_edge_nei[NEIGHBOR_DL][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_DL] = '1;
            if (!r_edge_nei[NEIGHBOR_MR][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_MR] = '1;
            if (!r_edge_nei[NEIGHBOR_DR][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_DR] = '1;
        end
        if (r_edge_det_l) begin
            if (!r_edge_nei[NEIGHBOR_UL][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_UL] = '1;
            if (!r_edge_nei[NEIGHBOR_UC][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_UC] = '1;
            if (!r_edge_nei[NEIGHBOR_DL][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_DL] = '1;
            if (!r_edge_nei[NEIGHBOR_DC][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_DC] = '1;
        end
        if (r_edge_det_r) begin
            if (!r_edge_nei[NEIGHBOR_UC][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_UC] = '1;
            if (!r_edge_nei[NEIGHBOR_UR][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_UR] = '1;
            if (!r_edge_nei[NEIGHBOR_DC][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_DC] = '1;
            if (!r_edge_nei[NEIGHBOR_DR][PIX_FLAG_HANDLED]) r_edge_trig[NEIGHBOR_DR] = '1;
        end
        r_edge_wlast <= '0;
        r_edge_wvalid <= '0;
    end else if (r_state == EDGE_WRITE) begin
        if (w_edge_wr_clken) begin
            casex(r_edge_trig)
            8'bxxxxxxx1: r_edge_trig[0] <= '0;
            8'bxxxxxx10: r_edge_trig[1] <= '0;
            8'bxxxxx100: r_edge_trig[2] <= '0;
            8'bxxxx1000: r_edge_trig[3] <= '0;
            8'bxxx10000: r_edge_trig[4] <= '0;
            8'bxx100000: r_edge_trig[5] <= '0;
            8'bx1000000: r_edge_trig[6] <= '0;
            8'b10000000: r_edge_trig[7] <= '0;
            endcase
            
            casex(r_edge_trig)
            8'bxxxxxxx1: r_edge_awaddr <= r_edge_pov_addr - ctl_img_stride - BYTES_PER_PIXEL;
            8'bxxxxxx10: r_edge_awaddr <= r_edge_pov_addr - ctl_img_stride;
            8'bxxxxx100: r_edge_awaddr <= r_edge_pov_addr - ctl_img_stride + BYTES_PER_PIXEL;
            8'bxxxx1000: r_edge_awaddr <= r_edge_pov_addr - BYTES_PER_PIXEL;
            8'bxxx10000: r_edge_awaddr <= r_edge_pov_addr + BYTES_PER_PIXEL;
            8'bxx100000: r_edge_awaddr <= r_edge_pov_addr + ctl_img_stride - BYTES_PER_PIXEL;
            8'bx1000000: r_edge_awaddr <= r_edge_pov_addr + ctl_img_stride;
            8'b10000000: r_edge_awaddr <= r_edge_pov_addr + ctl_img_stride + BYTES_PER_PIXEL;
            default    : r_edge_awaddr <= r_edge_pov_addr;
            endcase
            
            if (r_edge_trig != '0) begin
                r_edge_wdata <= f_make_word_data('1, '0, '0);
                r_edge_wlast <= '0;
            end else begin
                r_edge_wdata <= f_make_word_data('1, '1, r_count);
                r_edge_wlast <= '1;
            end
            
            r_edge_wvalid <= '1;
        end
    end else begin
        r_edge_wlast <= '0;
        r_edge_wvalid <= '0;
    end
end

logic[PWIDTH-1:0] w_edge_write_x;
logic[PWIDTH-1:0] w_edge_write_y;
always_comb begin
    casex(r_edge_trig)
    8'bxxxxxxx1: begin w_edge_write_y = r_edge_y - 'd1; w_edge_write_x = r_edge_x - 'd1; end
    8'bxxxxxx10: begin w_edge_write_y = r_edge_y - 'd1; w_edge_write_x = r_edge_x      ; end
    8'bxxxxx100: begin w_edge_write_y = r_edge_y - 'd1; w_edge_write_x = r_edge_x + 'd1; end
    8'bxxxx1000: begin w_edge_write_y = r_edge_y      ; w_edge_write_x = r_edge_x - 'd1; end
    8'bxxx10000: begin w_edge_write_y = r_edge_y      ; w_edge_write_x = r_edge_x + 'd1; end
    8'bxx100000: begin w_edge_write_y = r_edge_y + 'd1; w_edge_write_x = r_edge_x - 'd1; end
    8'bx1000000: begin w_edge_write_y = r_edge_y + 'd1; w_edge_write_x = r_edge_x      ; end
    8'b10000000: begin w_edge_write_y = r_edge_y + 'd1; w_edge_write_x = r_edge_x + 'd1; end
    default:     begin w_edge_write_y = r_edge_y      ; w_edge_write_x = r_edge_x      ; end
    endcase
end

// coordinate latch
logic r_rect_s0_valid;
logic[PWIDTH-1:0] r_rect_s0_x;
logic[PWIDTH-1:0] r_rect_s0_y;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_rect_s0_valid <= '0;
        r_rect_s0_x <= '0;
        r_rect_s0_y <= '0;
        r_rect_s0_x_last <= '0;
        r_rect_s0_y_last <= '0;
    end else if (r_state == RECT_INIT) begin
        r_rect_s0_valid <= '1;
        r_rect_s0_x <= '0;
        r_rect_s0_y <= '0;
        r_rect_s0_x_last <= (ctl_rect_width == 'd1);
        r_rect_s0_y_last <= (ctl_rect_height == 'd1);
    end else if (r_state == RECT_ACCESS && w_rect_acs_clken) begin
        if (r_rect_s0_x_last && r_rect_s0_y_last) begin
            r_rect_s0_valid <= '0;
        end
        if (r_rect_s0_x_last) begin
            r_rect_s0_x <= '0;
            r_rect_s0_y <= r_rect_s0_y + 'd1;
            r_rect_s0_x_last <= (ctl_rect_width == 'd1);
            r_rect_s0_y_last <= (r_rect_s0_y + 'd2 >= ctl_rect_height);
        end else begin
            r_rect_s0_x <= r_rect_s0_x + 'd1;
            r_rect_s0_x_last <= (r_rect_s0_x + 'd2 >= ctl_rect_width);
        end
    end
end

logic[AXI_ADDR_WIDTH-1:0] r_rect_s1_next_line_addr;
logic[AXI_ADDR_WIDTH-1:0] r_rect_s1_axaddr;
logic[31:0] r_rect_s1_wdata;
logic r_rect_s1_arvalid;
logic r_rect_s1_wvalid;
logic r_rect_s1_x_last;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_rect_s1_next_line_addr <= '0;
        r_rect_s1_axaddr <= '0;
        r_rect_s1_wdata <= '0;
        r_rect_s1_arvalid <= '0;
        r_rect_s1_wvalid <= '0;
        r_rect_s1_x_last <= '0;
    end else if (r_state == RECT_INIT) begin
        r_rect_s1_next_line_addr <= r_rect_addr + ctl_img_stride;
        r_rect_s1_axaddr <= r_rect_addr;
        r_rect_s1_x_last <= '0;
    end else if (w_rect_acs_clken) begin
        if (r_rect_s1_arvalid || r_rect_s1_wvalid) begin
            if (r_rect_s1_x_last) begin
                r_rect_s1_next_line_addr <= r_rect_s1_next_line_addr + ctl_img_stride;
                r_rect_s1_axaddr <= r_rect_s1_next_line_addr;
            end else begin
                r_rect_s1_axaddr <= r_rect_s1_axaddr + BYTES_PER_PIXEL;
            end
        end
        r_rect_s1_wdata <= ctl_rect_value;
        r_rect_s1_arvalid <= r_rect_s0_valid & ~w_cmd_flags_write;
        r_rect_s1_wvalid <= r_rect_s0_valid & w_cmd_flags_write;
        r_rect_s1_x_last <= r_rect_s0_x_last;
    end
end

wire[AXI_ADDR_WIDTH-1:0] w_araddr;
wire w_arvalid;
wire w_arready;
wire w_rready = '1;
wire[AXI_ADDR_WIDTH-1:0] w_awaddr;
wire w_awvalid;
wire w_awready;

wire[31:0] w_wdata;
wire[AXI_STRB_WIDTH-1:0] w_wstrb;
wire w_wvalid;
wire w_wready;

assign w_arvalid = r_edge_arvalid | r_rect_s1_arvalid;
assign w_araddr = r_edge_arvalid ? r_edge_araddr : r_rect_s1_axaddr;
accelbrot_com_axi_slice #(
    .DATA_WIDTH(AXI_ADDR_WIDTH)
) u_slice_ar (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .in_data    (w_araddr       ), // input [DATA_WIDTH-1:0]
    .in_valid   (w_arvalid      ), // input
    .in_ready   (w_arready      ), // output
    .out_data   (wram_araddr    ), // output[DATA_WIDTH-1:0]
    .out_valid  (wram_arvalid   ), // output
    .out_ready  (wram_arready   )  // input
);
assign wram_arlen = 8'd0; // Single Access
assign wram_arsize = 3'b010; // 4 Byte
assign wram_arburst = 2'b01; // INCR

assign wram_rready = w_rready;

assign w_awaddr = r_edge_wvalid ? r_edge_awaddr : r_rect_s1_axaddr;
assign w_awvalid = (r_edge_wvalid | r_rect_s1_wvalid) & w_wready;
accelbrot_com_axi_slice #(
    .DATA_WIDTH(AXI_ADDR_WIDTH)
) u_slice_aw (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .in_data    (w_awaddr       ), // input [DATA_WIDTH-1:0]
    .in_valid   (w_awvalid      ), // input
    .in_ready   (w_awready      ), // output
    .out_data   (wram_awaddr    ), // output[DATA_WIDTH-1:0]
    .out_valid  (wram_awvalid   ), // output
    .out_ready  (wram_awready   )  // input
);
assign wram_awlen = 8'd0; // Single Access
assign wram_awsize = 3'b010; // 4 Byte
assign wram_awburst = 2'b01; // INCR

assign w_wdata = r_edge_wvalid ? r_edge_wdata : r_rect_s1_wdata;
wire[AXI_STRB_WIDTH-1:0] w_strb_lsb = 'h000f;
assign w_wstrb = w_strb_lsb << (w_awaddr % AXI_STRB_WIDTH);
assign w_wvalid = (r_edge_wvalid | r_rect_s1_wvalid) & w_awready;
wire[AXI_STRB_WIDTH-1:0] w_wram_wstrb;
wire[31:0] w_wram_wdata;
wire w_wram_wvalid;
accelbrot_com_axi_slice #(
    .DATA_WIDTH(32+AXI_STRB_WIDTH)
) u_slice_w (
    .clk        (clk            ), // input
    .rstn       (rstn           ), // input
    .in_data    ({w_wstrb, w_wdata}), // input [DATA_WIDTH-1:0]
    .in_valid   (w_wvalid       ), // input
    .in_ready   (w_wready       ), // output
    .out_data   ({w_wram_wstrb, w_wram_wdata}), // output[DATA_WIDTH-1:0]
    .out_valid  (w_wram_wvalid  ), // output
    .out_ready  (wram_wready    )  // input
);
assign wram_wvalid = w_wram_wvalid;
assign wram_wstrb = w_wram_wstrb;
assign wram_wdata = {PIX_PER_WORD{w_wram_wdata}};
assign wram_wlast = '1;

assign w_edge_raddr_clken = w_arready | ~r_edge_arvalid;

assign w_edge_wr_clken = (w_awready & w_wready) | ~r_edge_wvalid;
assign w_edge_wr_acpt = (w_awready & w_wready) & r_edge_wvalid;
assign w_rect_acs_clken = 
    w_cmd_flags_write ?
    ((w_awready & w_wready) | ~r_rect_s1_wvalid) :
    (w_arready | ~r_rect_s1_arvalid);

assign wram_bready = '1;

wire w_aracpt = w_arvalid & w_arready;
wire w_racpt = wram_rvalid & w_rready;

wire[ALIGN_WIDTH-1:0] w_aralign = (w_araddr >> 2) % PIX_PER_WORD;
wire[ALIGN_WIDTH-1:0] w_ralign;
accelbrot_com_reg_fifo #(
    .DATA_WIDTH (ALIGN_WIDTH),
    .DEPTH      (64         )
) u_fifo_ralign (
    .rstn       (rstn       ), // input
    .clk        (clk        ), // input
    .stored     (/* open */ ), // output[SIZE_WIDTH-1:0]
    .afull      (/* open */ ), // output
    .aempty     (/* open */ ), // output
    .wr_data    (w_aralign  ), // input [DATA_WIDTH-1:0]
    .wr_valid   (w_aracpt   ), // input
    .wr_ready   (/* open */ ), // output
    .rd_data    (w_ralign   ), // output[DATA_WIDTH-1:0]
    .rd_valid   (/* open */ ), // output
    .rd_ready   (w_racpt    )  // input
);
assign w_wram_rdata = wram_rdata >> (w_ralign * 32);

logic[15:0] r_read_outstanding;
logic[BUFF_ADDR_WIDTH-1:0] r_read_index;
always @(posedge clk) begin
    if (!rstn) begin
        r_read_outstanding <= '0;
        r_read_busy <= '0;
        r_read_index <= '0;
    end else if (r_state == IDLE) begin
        r_read_outstanding <= '0;
        r_read_busy <= '0;
        r_read_index <= '0;
    end else begin
        if (w_aracpt && !w_racpt) begin
            r_read_outstanding <= r_read_outstanding + 'd1;
            r_read_busy <= '1;
        end else if (!w_aracpt && w_racpt) begin
            r_read_outstanding <= r_read_outstanding - 'd1;
            r_read_busy <= (r_read_outstanding > 'd1);
        end
        if (w_racpt) begin
            r_read_index <= r_read_index + 'd1;
        end
    end
end

wire w_rdque_wr_en = w_cmd_flags_rdque_ena & w_edge_wr_acpt;

logic[BUFF_ADDR_WIDTH-1:0] r_rdque_wrptr;
always @(posedge clk) begin
    if (!rstn) begin
        r_rdque_wrptr <= '0;
        r_rdque_afull <= '0;
    end else if (r_state == EDGE_INIT) begin
        r_rdque_wrptr <= ctl_rdque_rdptr;
        r_rdque_afull <= '0;
    end else begin
        reg[BUFF_ADDR_WIDTH-1:0] v_free;
        reg v_afull;
        v_free = ctl_rdque_rdptr - r_rdque_wrptr - 'd1;
        v_afull = (v_free < 16) ? '1 : '0;
        if (w_rdque_wr_en) begin
`ifdef ACCELBROT_SIM
            if (v_free == 2) $display("*WARNING: Queue Full");
            if (v_free < 2) $display("*FATAL: Queue Overflow");
`endif
            r_rdque_wrptr <= r_rdque_wrptr + 'd2;
        end
        r_rdque_afull <= v_afull;
    end
end
assign ctl_rdque_wrptr = r_rdque_wrptr;

logic r_rbuff_wr_en_l;
logic r_rbuff_wr_en_h;
logic[BUFF_ADDR_WIDTH-2:0] r_rbuff_wr_addr;
logic[31:0] r_rbuff_wr_data_l;
logic[31:0] r_rbuff_wr_data_h;
always @(posedge clk) begin
    if (!rstn) begin
        r_rbuff_wr_en_l     <= '0;
        r_rbuff_wr_en_h     <= '0;
        r_rbuff_wr_addr     <= '0;
        r_rbuff_wr_data_l   <= '0;
        r_rbuff_wr_data_h   <= '0;
    end else if (w_rdque_wr_en) begin
        r_rbuff_wr_en_l     <= '1;
        r_rbuff_wr_en_h     <= '1;
        r_rbuff_wr_addr     <= r_rdque_wrptr[BUFF_ADDR_WIDTH-1:1];
        r_rbuff_wr_data_l   <= r_edge_wdata;
        r_rbuff_wr_data_h   <= '0;
        r_rbuff_wr_data_h[PWIDTH-1:0]       <= w_edge_write_x;
        r_rbuff_wr_data_h[16+PWIDTH-1:16]   <= w_edge_write_y;
    end else if ((r_state == RECT_ACCESS || r_state == RECT_READ_WAIT) && w_racpt) begin
        r_rbuff_wr_en_l     <= ~r_read_index[0];
        r_rbuff_wr_en_h     <=  r_read_index[0];
        r_rbuff_wr_addr     <= r_read_index[BUFF_ADDR_WIDTH-1:1];
        r_rbuff_wr_data_l   <= w_wram_rdata;
        r_rbuff_wr_data_h   <= w_wram_rdata;
    end else begin
        r_rbuff_wr_en_l <= '0;
        r_rbuff_wr_en_h <= '0;
    end
end

wire[BUFF_ADDR_WIDTH-2:0] w_rbuff_rd_addr = buff_addr[BUFF_ADDR_WIDTH-1:1];
wire[31:0] w_rbuff_rd_data_l;
wire[31:0] w_rbuff_rd_data_h;
accelbrot_com_ram_sdp #(
    .DATA_WIDTH(32                  ),
    .ADDR_WIDTH(BUFF_ADDR_WIDTH-1   )
) u_read_buff_l (
    .wr_clk (clk                ), // input
    .wr_en  (r_rbuff_wr_en_l    ), // input
    .wr_addr(r_rbuff_wr_addr    ), // input [ADDR_WIDTH-1:0]
    .wr_data(r_rbuff_wr_data_l  ), // input [DATA_WIDTH-1:0]
    .rd_clk (clk                ), // input
    .rd_en  ('1                 ), // input
    .rd_addr(w_rbuff_rd_addr    ), // input [ADDR_WIDTH-1:0]
    .rd_data(w_rbuff_rd_data_l  )  // output[DATA_WIDTH-1:0]
);
accelbrot_com_ram_sdp #(
    .DATA_WIDTH(32                  ),
    .ADDR_WIDTH(BUFF_ADDR_WIDTH-1   )
) u_read_buff_h (
    .wr_clk (clk                ), // input
    .wr_en  (r_rbuff_wr_en_h    ), // input
    .wr_addr(r_rbuff_wr_addr    ), // input [ADDR_WIDTH-1:0]
    .wr_data(r_rbuff_wr_data_h  ), // input [DATA_WIDTH-1:0]
    .rd_clk (clk                ), // input
    .rd_en  ('1                 ), // input
    .rd_addr(w_rbuff_rd_addr    ), // input [ADDR_WIDTH-1:0]
    .rd_data(w_rbuff_rd_data_h  )  // output[DATA_WIDTH-1:0]
);
logic r_buff_rd_en;
logic r_buff_rd_ack;
logic r_buff_rd_addr0_d0;
logic r_buff_rd_addr0_d1;
always @(posedge clk) begin
    if (!rstn) begin
        r_buff_rd_en <= '0;
        r_buff_rd_ack <= '0;
        r_buff_rd_addr0_d0 <= '0;
        r_buff_rd_addr0_d1 <= '0;
    end else begin
        r_buff_rd_en <= buff_rd_en;
        r_buff_rd_ack <= r_buff_rd_en;
        r_buff_rd_addr0_d0 <= buff_addr[0];
        r_buff_rd_addr0_d1 <= r_buff_rd_addr0_d0;
    end
end
assign buff_rd_ack = r_buff_rd_ack;
assign buff_rd_data = r_buff_rd_addr0_d1 == 1'b0 ? w_rbuff_rd_data_l : w_rbuff_rd_data_h;

logic[31:0] r_sts_axi_state;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_sts_axi_state <= '0;
    end else begin
        r_sts_axi_state <= '0;
        r_sts_axi_state[31:16] <= r_read_outstanding;
        r_sts_axi_state[ 0] <= r_edge_arvalid;
        r_sts_axi_state[ 1] <= r_rect_s1_arvalid;
        r_sts_axi_state[ 3] <= wram_arready;
        r_sts_axi_state[ 4] <= r_edge_wvalid;
        r_sts_axi_state[ 5] <= r_rect_s1_wvalid;
        r_sts_axi_state[ 7] <= wram_awready;
        r_sts_axi_state[11] <= wram_wready;
    end
end
assign sts_axi_state = r_sts_axi_state;

logic[PWIDTH-1:0] r_push_x;
logic[PWIDTH-1:0] r_push_y;
logic r_push_valid;
always @(posedge clk) begin
    if (!rstn) begin
        r_push_x <= '0;
        r_push_y <= '0;
        r_push_valid <= '0;
    end else if (r_state == EDGE_WRITE && w_edge_wr_clken) begin
        r_push_x <= w_edge_write_x;
        r_push_y <= w_edge_write_y;
        r_push_valid <= (r_edge_trig != '0);
    end else if (r_state == RECT_ACCESS && w_rect_acs_clken) begin
        r_push_x <= ctl_rect_x + r_rect_s0_x;
        r_push_y <= ctl_rect_y + r_rect_s0_y;
        r_push_valid <= ctl_cmd_flags[CMD_FLAG_PUSH_TASK];
    end else begin
        r_push_valid <= '0;
    end
end
assign push_x = r_push_x;
assign push_y = r_push_y;
assign push_valid = r_push_valid;

`ifdef ACCELBROT_SIM
always @(posedge clk) begin
    if (rstn && r_push_valid && (r_push_x >= ctl_img_width || r_push_y >= ctl_img_height)) begin
        $display("*ERROR: Invalid push coord: x=%1d, y=%1d", r_push_x, r_push_y);
    end
end
`endif

// iteration counter
logic[CWIDTH-1:0] r_sts_max_iter;
logic[CWIDTH+PWIDTH*2-1:0] r_sts_total_iter;
always @(posedge clk) begin
    if (!rstn) begin
        r_sts_max_iter <= '0;
        r_sts_total_iter <= '0;
    end else if (w_cmd_reset_cntr) begin
        r_sts_max_iter <= '0;
        r_sts_total_iter <= '0;
    end else begin
        if (w_exit_acpt) begin
            if (r_sts_max_iter < exit_count) begin
                r_sts_max_iter <= exit_count;
            end
            r_sts_total_iter <= r_sts_total_iter + exit_count;
        end
    end
end
assign sts_max_iter = r_sts_max_iter;
assign sts_total_iter = r_sts_total_iter;

// active task counter
logic r_active_incr;
logic r_active_decr;
always @(posedge clk) begin
    if (!rstn) begin
        r_active_incr <= '0;
        r_active_decr <= '0;
        r_sts_total_queued <= '0;
        r_sts_total_exited <= '0;
        r_sts_num_active <= '0;
    end else if (w_cmd_reset_cntr) begin
        r_sts_total_queued <= '0;
        r_sts_total_exited <= '0;
        r_sts_num_active <= '0;
    end else begin
        r_active_incr <= r_push_valid & push_ready;
        r_active_decr <= r_edge_wlast & w_edge_wr_clken;
        if (r_active_incr) begin
            r_sts_total_queued <= r_sts_total_queued + 'd1;
        end
        if (r_active_decr) begin
            r_sts_total_exited <= r_sts_total_exited + 'd1;
        end
        if (r_active_incr && !r_active_decr) begin
            r_sts_num_active <= r_sts_num_active + 'd1;
        end else if (r_active_decr && !r_active_incr) begin
            r_sts_num_active <= r_sts_num_active - 'd1;
        end
    end
end

// wram access bytes
always @(posedge clk) begin
    if (!rstn) begin
        r_sts_wram_wrbytes <= '0;
        r_sts_wram_rdbytes <= '0;
    end else begin
        if (w_wready && w_wvalid) begin
            reg[7:0] v_bytes;
            v_bytes = 0;
            for (int i = 0; i < AXI_STRB_WIDTH; i++) begin
                if (w_wstrb[i]) v_bytes++;
            end
            r_sts_wram_wrbytes <= v_bytes;
        end else begin
            r_sts_wram_wrbytes <= '0;
        end
        if (w_racpt) begin
            r_sts_wram_rdbytes <= 'd4;
        end else begin
            r_sts_wram_rdbytes <= '0;
        end
    end
end

logic r_mon_rdque_full;
always @(posedge clk) begin
    if (!rstn) begin
        r_mon_rdque_full <= '0;
    end else begin
        r_mon_rdque_full <= r_rdque_afull;
    end
end
assign mon_rdque_full = r_mon_rdque_full;

endmodule

`default_nettype wire
