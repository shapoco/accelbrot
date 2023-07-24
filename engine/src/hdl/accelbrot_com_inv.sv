`default_nettype none

module accelbrot_com_inv #(
    parameter int WWIDTH = 34
) (
    input   wire            clk         ,
    input   wire            rstn        ,
    input   wire[WWIDTH-1:0]in          ,
    input   wire            in_sign     ,
    input   wire            in_start    ,
    input   wire            in_valid    ,
    output  wire[WWIDTH-1:0]out         ,
    output  wire            out_start   ,
    output  wire            out_valid
);

wire[WWIDTH-1:0] w_s1_neg;
accelbrot_com_sub #(
    .WWIDTH(WWIDTH)
) u_sub (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .a          ('0         ), // input [WWIDTH-1:0]
    .b          (in         ), // input [WWIDTH-1:0]
    .ab_start   (in_start   ), // input
    .ab_valid   (in_valid   ), // input
    .q          (w_s1_neg   ), // output[WWIDTH-1:0]
    .q_start    (out_start  ), // output
    .q_valid    (out_valid  )  // output
);

logic r_s1_sign;
logic[WWIDTH-1:0] r_s1_raw;
always @(posedge clk) begin
    if (!rstn) begin
        r_s1_raw <= '0;
        r_s1_sign <= '0;
    end else begin
        r_s1_raw <= in;
        if (in_start) begin
            r_s1_sign <= in_sign;
        end
    end
end

assign out = r_s1_sign ? w_s1_neg : r_s1_raw;

endmodule

`default_nettype wire
