`default_nettype none

module accelbrot_com_word2block #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34
) (
    input   wire                    clk         ,
    input   wire                    rstn        ,
    input   wire[WWIDTH-1:0]        in          ,
    input   wire                    in_start    ,
    input   wire                    in_valid    ,
    output  wire[NWORDS*WWIDTH-1:0] out         ,
    output  wire                    out_valid
);

localparam int DWIDTH = NWORDS * WWIDTH;

logic[DWIDTH-WWIDTH-1:0] r_sreg;
logic[NWORDS-2:0] r_start_delay;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_sreg <= '0;
        r_start_delay <= '0;
    end else begin
        r_sreg <= {in, r_sreg[DWIDTH-WWIDTH-1:WWIDTH]};
        if (in_start) begin
            r_start_delay <= 'd1;
        end else begin
            r_start_delay <= {r_start_delay[NWORDS-3:0], 1'b0};
        end
    end
end

assign out = {in, r_sreg};
assign out_valid = r_start_delay[NWORDS-2];

endmodule

`default_nettype wire
