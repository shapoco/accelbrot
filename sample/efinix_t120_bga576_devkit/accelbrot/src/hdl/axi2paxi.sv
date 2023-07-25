`default_nettype none

module axi2paxi #(
    parameter int ADDR_WIDTH = 32
) (
    input   wire                clk         ,
    input   wire                rstn        ,
    input   wire[ADDR_WIDTH-1:0]axi_awaddr  ,
    input   wire[7:0]           axi_awlen   ,
    input   wire[2:0]           axi_awsize  ,
    input   wire[1:0]           axi_awburst ,
    input   wire                axi_awvalid ,
    output  wire                axi_awready ,
    input   wire[ADDR_WIDTH-1:0]axi_araddr  ,
    input   wire[7:0]           axi_arlen   ,
    input   wire[2:0]           axi_arsize  ,
    input   wire[1:0]           axi_arburst ,
    input   wire                axi_arvalid ,
    output  wire                axi_arready ,
    output  wire[ADDR_WIDTH-1:0]paxi_aaddr  ,
    output  wire[7:0]           paxi_alen   ,
    output  wire[2:0]           paxi_asize  ,
    output  wire[1:0]           paxi_aburst ,
    output  wire                paxi_atype  ,
    output  wire                paxi_avalid ,
    input   wire                paxi_aready
);

wire w_clken;

logic[ADDR_WIDTH-1:0]   r_aaddr ;
logic[7:0]              r_alen  ;
logic[2:0]              r_asize ;
logic[1:0]              r_aburst;
logic                   r_avalid;
logic                   r_atype ;

always @(posedge clk) begin
    if (!rstn) begin
        r_aaddr  <= '0;
        r_alen   <= '0;
        r_asize  <= '0;
        r_aburst <= '0;
        r_atype  <= '0;
        r_avalid <= '0;
    end else if (w_clken) begin
        if (axi_awvalid) begin
            r_aaddr  <= axi_awaddr;
            r_alen   <= axi_awlen;
            r_asize  <= axi_awsize;
            r_aburst <= axi_awburst;
            r_atype  <= '1; // 1=write
            r_avalid <= '1;
        end else if (axi_arvalid) begin
            r_aaddr  <= axi_araddr;
            r_alen   <= axi_arlen;
            r_asize  <= axi_arsize;
            r_aburst <= axi_arburst;
            r_atype  <= '0; // 1=read
            r_avalid <= '1;
        end else begin
            r_avalid <= '0;
        end
    end
end
assign paxi_aaddr  = r_aaddr ;
assign paxi_alen   = r_alen  ;
assign paxi_asize  = r_asize ;
assign paxi_aburst = r_aburst;
assign paxi_atype  = r_atype ;
assign paxi_avalid = r_avalid;

assign axi_awready = w_clken;
assign axi_arready = w_clken & ~axi_awvalid;

assign w_clken = paxi_aready | ~r_avalid;

endmodule

`default_nettype wire
