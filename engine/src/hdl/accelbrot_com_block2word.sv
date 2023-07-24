`default_nettype none

module accelbrot_com_block2word #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34
) (
    input   wire                    clk         ,
    input   wire                    rstn        ,
    input   wire[NWORDS*WWIDTH-1:0] in          ,
    input   wire                    in_valid    ,
    output  wire[WWIDTH-1:0]        out         ,
    output  wire                    out_start   ,
    output  wire                    out_valid
);

localparam int BWIDTH = NWORDS * WWIDTH;
localparam int CNTR_WIDTH = $clog2(NWORDS);

logic[CNTR_WIDTH-1:0] r_cntr;
logic[BWIDTH-1:0] r_sreg;
logic r_start;
logic r_valid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_cntr <= '0;
        r_sreg <= '0;
        r_start <= '0;
        r_valid <= '0;
    end else if (in_valid) begin
        r_cntr <= NWORDS - 1;
        r_sreg <= in;
        r_start <= '1;
        r_valid <= '1;
    end else begin
        if (r_cntr > '0) begin
            r_cntr <= r_cntr - 'd1;
        end else begin
            r_valid <= '0;
        end
        r_start <= '0;
        r_sreg <= {{WWIDTH-1{1'b0}}, r_sreg[BWIDTH-1:WWIDTH]};
    end
end

assign out = r_sreg[WWIDTH-1:0];
assign out_start = r_start;
assign out_valid = r_valid;

endmodule

`default_nettype wire
