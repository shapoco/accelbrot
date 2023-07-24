`timescale 1ns / 1ps
`default_nettype none

module tb_top;

localparam int NCORES = 3;
localparam int NWORDS = 8;
localparam int WWIDTH = 34;
localparam int BWIDTH = NWORDS * WWIDTH;
localparam int IWIDTH = 6;
localparam int PWIDTH = 12;
localparam int TWIDTH = PWIDTH * 2;
localparam int CWIDTH = 20;
localparam int QDEPTH = 16 * 1024;
localparam int CNTR_WIDTH = $clog2(NWORDS);

localparam int AXI_ADDR_WIDTH = 32;
localparam int AXI_DATA_WIDTH = 128;
localparam int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

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
localparam[15:0] CTL_RECT_HEIGHT    = 16'h060C;
localparam[15:0] CTL_RECT_VALUE     = 16'h0610;
localparam[15:0] CTL_CMD_FLAGS      = 16'h0614;
localparam[15:0] BUFF_BASE          = 16'h4000;

localparam[7:0] CMD_EDGE_SCAN = 8'h01;
localparam[7:0] CMD_RECT_SCAN = 8'h02;

localparam int CMD_FLAG_WRITE       = 0;
localparam int CMD_FLAG_PUSH_TASK   = 1;

localparam int PIX_FLAG_HANDLED     = 31;
localparam int PIX_FLAG_FINISHED    = 30;
localparam int PIX_FLAG_WALL        = 29;

localparam time DLY = 1ns;

logic clk;
logic rstn;

logic[15:0]             reg_address    ; // input
logic                   reg_write   ; // input
logic[31:0]             reg_writedata ; // input
logic                   reg_read   ; // input
wire[31:0]              reg_readdata ; // output
wire                    reg_readdatavalid  ; // output
wire[AXI_ADDR_WIDTH-1:0]wram_araddr ; // input
wire[7:0]               wram_arlen  ; // input
wire[2:0]               wram_arsize ; // input
wire[1:0]               wram_arburst; // input
wire                    wram_arvalid; // input
wire                    wram_arready; // output
wire[AXI_DATA_WIDTH-1:0]wram_rdata  ; // output
wire                    wram_rlast  ; // output
wire                    wram_rvalid ; // output
wire                    wram_rready ; // input
wire[1:0]               wram_rresp  ; // output
wire[AXI_ADDR_WIDTH-1:0]wram_awaddr ; // input
wire[7:0]               wram_awlen  ; // input
wire[2:0]               wram_awsize ; // input
wire[1:0]               wram_awburst; // input
wire                    wram_awvalid; // input
wire                    wram_awready; // output
wire[AXI_DATA_WIDTH-1:0]wram_wdata  ; // input
wire[AXI_STRB_WIDTH-1:0]wram_wstrb  ; // input
wire                    wram_wlast  ; // input
wire                    wram_wvalid ; // input
wire                    wram_wready ; // output
wire                    wram_bvalid ; // output
wire                    wram_bready ; // input
wire[1:0]               wram_bresp  ; // output

axi_ram #(
    .ADDR_WIDTH(AXI_ADDR_WIDTH),
    .DATA_WIDTH(AXI_DATA_WIDTH)
) dram (
    .clk        (clk            ), // input
    .axi_araddr (wram_araddr    ), // input [ADDR_WIDTH-1:0]
    .axi_arlen  (wram_arlen     ), // input [7:0]
    .axi_arsize (wram_arsize    ), // input [2:0]
    .axi_arburst(wram_arburst   ), // input [1:0]
    .axi_arvalid(wram_arvalid   ), // input
    .axi_arready(wram_arready   ), // output
    .axi_rdata  (wram_rdata     ), // output[DATA_WIDTH-1:0]
    .axi_rlast  (wram_rlast     ), // output
    .axi_rvalid (wram_rvalid    ), // output
    .axi_rready (wram_rready    ), // input
    .axi_rresp  (wram_rresp     ), // output[1:0]
    .axi_awaddr (wram_awaddr    ), // input [ADDR_WIDTH-1:0]
    .axi_awlen  (wram_awlen     ), // input [7:0]
    .axi_awsize (wram_awsize    ), // input [2:0]
    .axi_awburst(wram_awburst   ), // input [1:0]
    .axi_awvalid(wram_awvalid   ), // input
    .axi_awready(wram_awready   ), // output
    .axi_wdata  (wram_wdata     ), // input [DATA_WIDTH-1:0]
    .axi_wstrb  (wram_wstrb     ), // input [STRB_WIDTH-1:0]
    .axi_wlast  (wram_wlast     ), // input
    .axi_wvalid (wram_wvalid    ), // input
    .axi_wready (wram_wready    ), // output
    .axi_bvalid (wram_bvalid    ), // output
    .axi_bready (wram_bready    ), // input
    .axi_bresp  (wram_bresp     )  // output[1:0]
);

accelbrot #(
    .NCORES(NCORES),
    .NWORDS(NWORDS),
    .WWIDTH(WWIDTH),
    .IWIDTH(IWIDTH),
    .CWIDTH(CWIDTH),
    .PWIDTH(PWIDTH),
    .QDEPTH(QDEPTH),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
) dut (
    .*
);

initial forever begin
    clk = 0; #5ns;
    clk = 1; #5ns;
end

task reg_wr(
    input bit[15:0] addr,
    input bit[31:0] data,
    input bit verbose = 1
);
    //@(posedge clk);
    reg_address <= #DLY addr;
    reg_writedata <= #DLY data;
    reg_write <= #DLY '1;
    @(posedge clk);
    reg_write <= #DLY '0;
    if (verbose) $display("reg[0x%x] <--  0x%x", addr, data);
endtask

task reg_rd(
    input bit[15:0] addr,
    output bit[31:0] data,
    input bit verbose = 1
);
    //@(posedge clk);
    reg_address <= #DLY addr;
    reg_read <= #DLY '1;
    @(posedge clk);
    reg_read <= #DLY '0;
    while (!reg_readdatavalid) @(posedge clk);
    data = reg_readdata;
    if (verbose) $display("reg[0x%x]  --> 0x%x", addr, reg_readdata);
endtask

task wait_idle();
    repeat (10) @(posedge clk);
    begin : wait_idle_blk
        for (int i = 0; i < 1000000; i++) begin
            logic[31:0] busy;
            reg_rd(STS_BUSY, busy, 0);
            if (busy == 0) disable wait_idle_blk;
        end
    end
endtask

task show_state();
    int unsigned busy;
    int unsigned fsm_state;
    int unsigned axi_state;
    reg_wr(STS_LATCH, 1, 0);
    reg_rd(STS_BUSY       , busy      , 0);
    reg_rd(STS_FSM_STATE  , fsm_state , 0);
    reg_rd(STS_AXI_STATE  , axi_state , 0);
    $display("busy=%1d, fsm_state=%1d, axi_state=0x%1x", busy, fsm_state, axi_state);
endtask

task scan_rect(
    input int x,
    input int y,
    input int w,
    input int h,
    input int value,
    input int flags,
    input bit verbose = 1
);
    reg_wr(CTL_RECT_X        , x     , verbose);
    reg_wr(CTL_RECT_Y        , y     , verbose);
    reg_wr(CTL_RECT_WIDTH    , w     , verbose);
    reg_wr(CTL_RECT_HEIGHT   , h     , verbose);
    reg_wr(CTL_RECT_VALUE    , value , verbose);
    reg_wr(CTL_CMD_FLAGS     , flags , verbose);
    reg_wr(CTL_COMMAND, CMD_RECT_SCAN, verbose);
    if (verbose) begin
        $display("CMD_RECT_SCAN(%1d, %1d, %1d, %1d, 0x%x, 0x%x)", x, y, w, h, value, flags);
        show_state();
    end
    wait_idle();
endtask

task write_param(
    input bit[15:0] addr,
    input bit[BWIDTH-1:0] value
);
    bit[BWIDTH-1:0] tmp;
    int numWrites;
    tmp = value;
    $display("reg[0x%x] <--  0x%x", addr, value);
    numWrites = (BWIDTH + 31) / 32;
    for (int i = 0; i < numWrites; i++) begin
        reg_wr(addr, tmp[31:0], 0);
        tmp >>= 32;
    end
endtask

task show_stats();
    int unsigned active;
    int unsigned queued;
    int unsigned entered;
    int unsigned running;
    int unsigned exited;
    int unsigned max_iter;
    int unsigned total_iter_l;
    int unsigned total_iter_h;
    reg_wr(STS_LATCH, 1, 0);
    reg_rd(STS_NUM_ACTIVE     , active    , 0);
    reg_rd(STS_NUM_QUEUED     , queued    , 0);
    reg_rd(STS_NUM_ENTERED    , entered   , 0);
    reg_rd(STS_NUM_RUNNING    , running   , 0);
    reg_rd(STS_NUM_EXITED     , exited    , 0);
    reg_rd(STS_MAX_ITER       , max_iter  , 0);
    reg_rd(STS_TOTAL_ITER_L   , total_iter_l, 0);
    reg_rd(STS_TOTAL_ITER_H   , total_iter_h, 0);
    $display("active=%1d, queued=%1d, entered=%1d, running=%1d, exited=%1d, max_iter=%1d, total_iter=%1d",
        active, queued, entered, running, exited, max_iter, {total_iter_h, total_iter_l});
endtask

task dump_from_dram();
    for (int y = 0; y < H; y++) begin
        for (int x = 0; x < W; x++) begin
            int unsigned data;
            dram.read_uint32(BASE_ADDR + (y * W + x) * 4, data);
            if (data[PIX_FLAG_FINISHED]) begin
                case(data[CWIDTH-1:0] % 8) 
                4'h0: $write(" ");
                4'h1: $write(".");
                4'h2: $write(";");
                4'h3: $write("/");
                4'h4: $write("l");
                4'h5: $write("S");
                4'h6: $write("H");
                4'h7: $write("$");
                endcase
            end else if (data[PIX_FLAG_HANDLED]) begin
                $write("?");
            end else begin
                $write(" ");
            end
        end
        $display();
    end
endtask

task dump_thru_reg();
    for (int y = 0; y < H; y++) begin
        scan_rect(0, y, W, 1, 0, 0, 0);
        for (int x = 0; x < W; x++) begin
            int unsigned data;
            reg_rd(BUFF_BASE + x * 4, data, 0);
            if (data[PIX_FLAG_FINISHED]) begin
                case(data[CWIDTH-1:0] % 8) 
                4'h0: $write(" ");
                4'h1: $write(".");
                4'h2: $write(";");
                4'h3: $write("/");
                4'h4: $write("l");
                4'h5: $write("S");
                4'h6: $write("H");
                4'h7: $write("$");
                endcase
            end else if (data[PIX_FLAG_HANDLED]) begin
                $write("?");
            end else begin
                $write(" ");
            end
        end
        $display();
    end

endtask

localparam int BASE_ADDR = 'h1000;
localparam int W = 32;
localparam int H = W / 2;

localparam[BWIDTH-1:0] ONE = {32'd1, {(BWIDTH-IWIDTH){1'b0}}};

localparam[BWIDTH-1:0] A = -(ONE / 2);
localparam[BWIDTH-1:0] B = '0;
localparam[BWIDTH-1:0] RANGE = ONE * 2;

initial begin
    int unsigned scan_value;
    int unsigned scan_flags;
    int unsigned busy;
    bit[BWIDTH-1:0] prm;

    $dumpfile("wave.vcd");
    $dumpvars(0, tb_top);

    rstn = '0;
    reg_address     = '0;
    reg_write       = '0;
    reg_writedata   = '0;
    reg_read        = '0;
    repeat (3) @(posedge clk);
    rstn <= #DLY '1;
    repeat (10) @(posedge clk);
    
    reg_wr(CTL_SOFT_RESET, 1);
    
    reg_wr(CTL_IMG_ADDR_L, BASE_ADDR);
    reg_wr(CTL_IMG_ADDR_H, '0);
    reg_wr(CTL_IMG_WIDTH , W);
    reg_wr(CTL_IMG_HEIGHT, H);
    reg_wr(CTL_IMG_STRIDE, W * 4);

    write_param(CTL_A_OFFSET, A - (RANGE / 2));
    write_param(CTL_B_OFFSET, B - (RANGE / 2));
    write_param(CTL_A_STEP_X, RANGE / W);
    write_param(CTL_B_STEP_Y, RANGE / W * 2);

    reg_wr(CTL_MAX_ITER  , 16);
    
    scan_value = 0;
    scan_flags = (32'd1 << CMD_FLAG_WRITE);
    scan_rect(0, 0, W, H, scan_value, scan_flags);
    
    scan_value = 32'd1 << PIX_FLAG_HANDLED;
    scan_flags = (32'd1 << CMD_FLAG_WRITE) | (32'd1 << CMD_FLAG_PUSH_TASK);
    //scan_rect(0, 0, W, H, scan_value, scan_flags);
    scan_rect(0  , H-1, W, 1  , scan_value, scan_flags);
    scan_rect(0  , 0  , W, 1  , scan_value, scan_flags);
    scan_rect(0  , 1  , 1, H-2, scan_value, scan_flags);
    scan_rect(W-1, 1  , 1, H-2, scan_value, scan_flags);
    
    reg_wr(CTL_COMMAND, CMD_EDGE_SCAN);
    show_state();
    
    do begin
        show_stats();
        //dump_from_dram();
        repeat(1000) @(posedge clk);
        //show_state();
        reg_rd(STS_BUSY, busy, 0);
    end while (busy);
    
    //$display("----------------------------------------------------------------");
    //
    //show_stats();
    //dump_from_dram();
    
    $display("----------------------------------------------------------------");
    
    dump_thru_reg();
    
    $finish(0);
end

endmodule

`default_nettype wire
