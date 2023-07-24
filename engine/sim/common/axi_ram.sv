`timescale 1ns / 1ps
`default_nettype none

//`define AXI_RAM_USE_HASHMAP

module axi_ram #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 256,
    parameter int STRB_WIDTH = DATA_WIDTH / 8,
    parameter int DEPTH = 1024 * 1024
) (
    input   wire                clk         ,
    input   wire[ADDR_WIDTH-1:0]axi_araddr  ,
    input   wire[7:0]           axi_arlen   ,
    input   wire[2:0]           axi_arsize  ,
    input   wire[1:0]           axi_arburst ,
    input   wire                axi_arvalid ,
    output  wire                axi_arready ,
    output  wire[DATA_WIDTH-1:0]axi_rdata   ,
    output  wire                axi_rlast   ,
    output  wire                axi_rvalid  ,
    input   wire                axi_rready  ,
    output  wire[1:0]           axi_rresp   ,
    input   wire[ADDR_WIDTH-1:0]axi_awaddr  ,
    input   wire[7:0]           axi_awlen   ,
    input   wire[2:0]           axi_awsize  ,
    input   wire[1:0]           axi_awburst ,
    input   wire                axi_awvalid ,
    output  wire                axi_awready ,
    input   wire[DATA_WIDTH-1:0]axi_wdata   ,
    input   wire[STRB_WIDTH-1:0]axi_wstrb   ,
    input   wire                axi_wlast   ,
    input   wire                axi_wvalid  ,
    output  wire                axi_wready  ,
    output  wire                axi_bvalid  ,
    input   wire                axi_bready  ,
    output  wire[1:0]           axi_bresp
);

localparam time DLY = 100ps;

typedef logic[ADDR_WIDTH-1:0] addr_t;
`ifdef AXI_RAM_USE_HASHMAP
byte mem[addr_t];
`else
byte mem[0:DEPTH-1];
`endif

logic[ADDR_WIDTH+8+3+2-1:0] raddr_queue[$];
logic[DATA_WIDTH+2+1-1:0] rresp_queue[$];

logic r_arready;
initial forever begin
    int unsigned ur;
    r_arready <= #DLY '0;
    ur = $random();
    repeat(ur % 4) @(posedge clk);
    r_arready <= #DLY '1;
    ur = $random();
    repeat(ur % 8) @(posedge clk);
end
always @(posedge clk) begin
    //r_arready <= #DLY (raddr_queue.size() < 2);
    if (r_arready && axi_arvalid) begin
        raddr_queue.push_back({axi_arburst, axi_arsize, axi_arlen, axi_araddr});
    end
end
assign axi_arready = r_arready;

initial forever begin
    int unsigned ur;
    logic[ADDR_WIDTH-1:0] addr;
    logic[7:0] len;
    logic[2:0] size;
    logic[1:0] burst;
    logic[STRB_WIDTH-1:0][7:0] data;
    int stride;
    logic last;
    logic[1:0] resp;
    
    ur = $random();
    repeat(ur % 8) @(posedge clk);
    
    while (raddr_queue.size() <= 0) @(posedge clk);
    {burst, size, len, addr} = raddr_queue.pop_front();
    stride = 2 ** size;
    resp = 2'b00;
    for (int i = 0; i <= len; i++) begin
        logic[ADDR_WIDTH-1:0] word_addr;
        word_addr = (addr / STRB_WIDTH) * STRB_WIDTH;
        data = '0;
        for (int b = 0; b < STRB_WIDTH; b++) begin
`ifdef AXI_RAM_USE_HASHMAP
            if (mem.exist(word_addr + b)) begin
                data[b] = mem[word_addr + b];
            end else begin
                data[b] = 'z;
            end
`else
            data[b] = mem[word_addr + b];
`endif
        end
        addr += stride;
        last = (i == len);
        rresp_queue.push_back({last, resp, data});
    end
end

logic[DATA_WIDTH-1:0] r_rdata;
logic r_rlast;
logic[1:0] r_rresp;
logic r_rvalid;
always @(posedge clk) begin
    if (r_rvalid && axi_rready) begin
        void'(rresp_queue.pop_front());
    end
    if (rresp_queue.size() > 0) begin
        { r_rlast, r_rresp, r_rdata } <= #DLY rresp_queue[0];
        r_rvalid <= #DLY '1;
    end else begin
        r_rvalid <= #DLY '0;
    end
end
assign axi_rdata = r_rdata;
assign axi_rresp = r_rresp;
assign axi_rlast = r_rlast;
assign axi_rvalid = r_rvalid;

logic[ADDR_WIDTH+8+3+2-1:0] waddr_queue[$];
logic[DATA_WIDTH+STRB_WIDTH+1-1:0] wdata_queue[$];
logic[1:0] bresp_queue[$];

logic r_awready;
always @(posedge clk) begin
    r_awready <= #DLY (waddr_queue.size() < 16);
    if (r_awready && axi_awvalid) begin
        waddr_queue.push_back({axi_awburst, axi_awsize, axi_awlen, axi_awaddr});
    end
end
assign axi_awready = r_awready;

logic r_wready;
always @(posedge clk) begin
    r_wready <= #DLY (wdata_queue.size() < 16);
    if (r_wready && axi_wvalid) begin
        wdata_queue.push_back({axi_wlast, axi_wstrb, axi_wdata});
    end
end
assign axi_wready = r_wready;

initial forever begin
    logic[ADDR_WIDTH-1:0] addr;
    logic[7:0] len;
    logic[2:0] size;
    logic[1:0] burst;
    logic last;
    logic[STRB_WIDTH-1:0] strb;
    logic[STRB_WIDTH-1:0][7:0] data;
    int stride;
    
    while (waddr_queue.size() <= 0) @(posedge clk);
    {burst, size, len, addr} = waddr_queue.pop_front();
    stride = 2 ** size;
    addr = (addr / STRB_WIDTH) * STRB_WIDTH;
    for (int i = 0; i <= len; i++) begin
        logic[ADDR_WIDTH-1:0] word_addr;
        word_addr = (addr / STRB_WIDTH) * STRB_WIDTH;
        while (wdata_queue.size() <= 0) @(posedge clk);
        {last, strb, data} = wdata_queue.pop_front();
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (strb[b]) begin
                mem[word_addr + b] = data[b];
            end
        end
        addr += stride;
    end
    
    bresp_queue.push_back(2'b00);
end

logic[1:0] r_bresp;
logic r_bvalid;
always @(posedge clk) begin
    if (r_bvalid && axi_bready) begin
        void'(bresp_queue.pop_front());
    end
    if (bresp_queue.size() > 0) begin
        r_bresp <= #DLY bresp_queue[0];
        r_bvalid <= #DLY '1;
    end else begin
        r_bvalid <= #DLY '0;
    end
end
assign axi_bresp = r_bresp;
assign axi_bvalid = r_bvalid;

task read_uint32(
    input bit[ADDR_WIDTH-1:0] addr,
    output bit[31:0] data
);
    data[ 0+:8] = mem[addr+0];
    data[ 8+:8] = mem[addr+1];
    data[16+:8] = mem[addr+2];
    data[24+:8] = mem[addr+3];
endtask

endmodule

`default_nettype wire
