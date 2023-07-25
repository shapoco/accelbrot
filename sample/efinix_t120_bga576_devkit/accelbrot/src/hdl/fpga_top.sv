`default_nettype none

module fpga_top (
    input   wire        axi_clk         ,
    input   wire        arstn           ,
    input   wire        ddr_clk_locked  ,
    
    input   wire        spi_cs_n        ,
    input   wire        spi_sck         ,
    input   wire        spi_mosi        ,
    output  wire        spi_miso        ,

    output  wire        ddr0_rstn       ,
    output  wire        ddr0_seq_rst    ,
    output  wire        ddr0_seq_start  ,

    output  wire[7:0]   ddr0_axi0_aid   ,
    output  wire[31:0]  ddr0_axi0_aaddr ,
    output  wire[7:0]   ddr0_axi0_alen  ,
    output  wire[2:0]   ddr0_axi0_asize ,
    output  wire[1:0]   ddr0_axi0_aburst,
    output  wire[1:0]   ddr0_axi0_alock ,
    output  wire        ddr0_axi0_atype ,
    output  wire        ddr0_axi0_avalid,
    input   wire        ddr0_axi0_aready,

    output  wire[7:0]   ddr0_axi0_wid   ,
    output  wire[255:0] ddr0_axi0_wdata ,
    output  wire[31:0]  ddr0_axi0_wstrb ,
    output  wire        ddr0_axi0_wlast ,
    output  wire        ddr0_axi0_wvalid,
    input   wire        ddr0_axi0_wready,

    input   wire[7:0]   ddr0_axi0_rid   ,
    input   wire[255:0] ddr0_axi0_rdata ,
    input   wire        ddr0_axi0_rlast ,
    input   wire        ddr0_axi0_rvalid,
    output  wire        ddr0_axi0_rready,
    input   wire[1:0]   ddr0_axi0_rresp ,

    input   wire[7:0]   ddr0_axi0_bid   ,
    input   wire        ddr0_axi0_bvalid,
    output  wire        ddr0_axi0_bready,
    
    output  wire[7:0]   ddr0_axi1_aid   ,
    output  wire[31:0]  ddr0_axi1_aaddr ,
    output  wire[7:0]   ddr0_axi1_alen  ,
    output  wire[2:0]   ddr0_axi1_asize ,
    output  wire[1:0]   ddr0_axi1_aburst,
    output  wire[1:0]   ddr0_axi1_alock ,
    output  wire        ddr0_axi1_atype ,
    output  wire        ddr0_axi1_avalid,
    input   wire        ddr0_axi1_aready,

    output  wire[7:0]   ddr0_axi1_wid   ,
    output  wire[127:0] ddr0_axi1_wdata ,
    output  wire[15:0]  ddr0_axi1_wstrb ,
    output  wire        ddr0_axi1_wlast ,
    output  wire        ddr0_axi1_wvalid,
    input   wire        ddr0_axi1_wready,

    input   wire[7:0]   ddr0_axi1_rid   ,
    input   wire[127:0] ddr0_axi1_rdata ,
    input   wire        ddr0_axi1_rlast ,
    input   wire        ddr0_axi1_rvalid,
    output  wire        ddr0_axi1_rready,
    input   wire[1:0]   ddr0_axi1_rresp ,

    input   wire[7:0]   ddr0_axi1_bid   ,
    input   wire        ddr0_axi1_bvalid,
    output  wire        ddr0_axi1_bready,
    
    output  wire[7:0]   led
);

localparam int NCORES = 3;
localparam int NWORDS = 8;
localparam int WWIDTH = 34;
localparam int BWIDTH = NWORDS * WWIDTH;
localparam int CWIDTH = 20;
localparam int IWIDTH = 6;
localparam int PWIDTH = 12;
localparam int QDEPTH = 16 * 1024;

// Reset sync for AXI clock
wire axi_rstn;
reset_sync #(
    .IN_POLARITY (1), // 0: active-high, 1: low-active
    .OUT_POLARITY(1)  // 0: active-high, 1: low-active
) u_reset_axi (
    .clk    (axi_clk    ), // input
    .in_rst (arstn      ), // input
    .out_rst(axi_rstn   )  // output
);

// DDR reset
ddr_reset_sequencer inst_ddr_reset (
    .ddr_rstn_i         (ddr_clk_locked ),
    .clk                (axi_clk        ),
    .ddr_rstn           (ddr0_rstn      ),
    .ddr_cfg_seq_rst    (ddr0_seq_rst   ),
    .ddr_cfg_seq_start  (ddr0_seq_start )
);


wire[15:0]  w_reg_address       ;
wire        w_reg_read          ;
wire        w_reg_write         ;
wire[31:0]  w_reg_writedata     ;
wire[31:0]  w_reg_readdata      ;
wire        w_reg_readdatavalid ;

avmm_as_spisram #(
    .SPI_ADDR_BYTES(2),
    .SPI_DATA_BYTES(4)
) (
    .spi_cs_n           (spi_cs_n           ), // input
    .spi_sck            (spi_sck            ), // input
    .spi_mosi           (spi_mosi           ), // input
    .spi_miso           (spi_miso           ), // output
    .sys_clk            (axi_clk            ), // input
    .sys_rstn           (axi_rstn           ), // input
    .mem_address        (w_reg_address      ), // output[MEM_ADDR_WIDTH-1:0]
    .mem_read           (w_reg_read         ), // output
    .mem_write          (w_reg_write        ), // output
    .mem_writedata      (w_reg_writedata    ), // output[MEM_DATA_WIDTH-1:0]
    .mem_readdata       (w_reg_readdata     ), // input [MEM_DATA_WIDTH-1:0]
    .mem_readdatavalid  (w_reg_readdatavalid), // input
    .mem_waitrequest    ('0                 )  // input
);

assign ddr0_axi0_aid    = '0;
assign ddr0_axi0_aaddr  = '0;
assign ddr0_axi0_alen   = '0;
assign ddr0_axi0_asize  = '0;
assign ddr0_axi0_aburst = 2'b01;
assign ddr0_axi0_alock  = '0;
assign ddr0_axi0_atype  = '0;
assign ddr0_axi0_avalid = '0;
assign ddr0_axi0_wid    = '0;
assign ddr0_axi0_wdata  = '0;
assign ddr0_axi0_wstrb  = '0;
assign ddr0_axi0_wlast  = '0;
assign ddr0_axi0_wvalid = '0;
assign ddr0_axi0_rready = '1;
assign ddr0_axi0_bready = '1;

wire[31:0]w_axi1_awaddr ;
wire[7:0] w_axi1_awlen  ;
wire[2:0] w_axi1_awsize ;
wire[1:0] w_axi1_awburst;
wire      w_axi1_awvalid;
wire      w_axi1_awready;
wire[31:0]w_axi1_araddr ;
wire[7:0] w_axi1_arlen  ;
wire[2:0] w_axi1_arsize ;
wire[1:0] w_axi1_arburst;
wire      w_axi1_arvalid;
wire      w_axi1_arready;

accelbrot #(
    .NCORES         (NCORES ),
    .NWORDS         (NWORDS ),
    .WWIDTH         (WWIDTH ),
    .IWIDTH         (IWIDTH ),
    .CWIDTH         (CWIDTH ),
    .PWIDTH         (PWIDTH ),
    .QDEPTH         (QDEPTH ),
    .AXI_ADDR_WIDTH (32     ),
    .AXI_DATA_WIDTH (128    )
) u_accelbrot (
    .clk                (axi_clk            ), // input
    .rstn               (axi_rstn           ), // input
    .reg_address        (w_reg_address      ), // input [15:0]
    .reg_write          (w_reg_write        ), // input
    .reg_writedata      (w_reg_writedata    ), // input [31:0]
    .reg_read           (w_reg_read         ), // input
    .reg_readdata       (w_reg_readdata     ), // output[31:0]
    .reg_readdatavalid  (w_reg_readdatavalid), // output
    .wram_araddr        (w_axi1_araddr      ), // output[AXI_ADDR_WIDTH-1:0]
    .wram_arlen         (w_axi1_arlen       ), // output[7:0]
    .wram_arsize        (w_axi1_arsize      ), // output[2:0]
    .wram_arburst       (w_axi1_arburst     ), // output[1:0]
    .wram_arvalid       (w_axi1_arvalid     ), // output
    .wram_arready       (w_axi1_arready     ), // input
    .wram_rdata         (ddr0_axi1_rdata    ), // input [AXI_DATA_WIDTH-1:0]
    .wram_rlast         (ddr0_axi1_rlast    ), // input
    .wram_rvalid        (ddr0_axi1_rvalid   ), // input
    .wram_rresp         (ddr0_axi1_rresp    ), // input [1:0]
    .wram_rready        (ddr0_axi1_rready   ), // output
    .wram_awaddr        (w_axi1_awaddr      ), // output[AXI_ADDR_WIDTH-1:0]
    .wram_awlen         (w_axi1_awlen       ), // output[7:0]
    .wram_awsize        (w_axi1_awsize      ), // output[2:0]
    .wram_awburst       (w_axi1_awburst     ), // output[1:0]
    .wram_awvalid       (w_axi1_awvalid     ), // output
    .wram_awready       (w_axi1_awready     ), // input
    .wram_wdata         (ddr0_axi1_wdata    ), // output[AXI_DATA_WIDTH-1:0]
    .wram_wstrb         (ddr0_axi1_wstrb    ), // output[AXI_STRB_WIDTH-1:0]
    .wram_wlast         (ddr0_axi1_wlast    ), // output
    .wram_wvalid        (ddr0_axi1_wvalid   ), // output
    .wram_wready        (ddr0_axi1_wready   ), // input
    .wram_bresp         ('0                 ), // input [1:0]
    .wram_bvalid        (ddr0_axi1_bvalid   ), // input
    .wram_bready        (ddr0_axi1_bready   )  // output
);

assign ddr0_axi1_wid = '0;

axi2paxi #(
    .ADDR_WIDTH(32)
) u_axi2paxi1 (
    .clk        (axi_clk            ), // input
    .rstn       (axi_rstn           ), // input
    .axi_awaddr (w_axi1_awaddr      ), // input [ADDR_WIDTH-1:0]
    .axi_awlen  (w_axi1_awlen       ), // input [7:0]
    .axi_awsize (w_axi1_awsize      ), // input [2:0]
    .axi_awburst(w_axi1_awburst     ), // input [1:0]
    .axi_awvalid(w_axi1_awvalid     ), // input
    .axi_awready(w_axi1_awready     ), // output
    .axi_araddr (w_axi1_araddr      ), // input [ADDR_WIDTH-1:0]
    .axi_arlen  (w_axi1_arlen       ), // input [7:0]
    .axi_arsize (w_axi1_arsize      ), // input [2:0]
    .axi_arburst(w_axi1_arburst     ), // input [1:0]
    .axi_arvalid(w_axi1_arvalid     ), // input
    .axi_arready(w_axi1_arready     ), // output
    .paxi_aaddr (ddr0_axi1_aaddr    ), // output[ADDR_WIDTH-1:0]
    .paxi_alen  (ddr0_axi1_alen     ), // output[7:0]
    .paxi_asize (ddr0_axi1_asize    ), // output[2:0]
    .paxi_aburst(ddr0_axi1_aburst   ), // output[1:0]
    .paxi_atype (ddr0_axi1_atype    ), // output
    .paxi_avalid(ddr0_axi1_avalid   ), // output
    .paxi_aready(ddr0_axi1_aready   )  // input
);
assign ddr0_axi1_aid = '0;
assign ddr0_axi1_alock = '0;

endmodule

`default_nettype wire
