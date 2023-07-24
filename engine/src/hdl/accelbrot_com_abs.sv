`default_nettype none

module accelbrot_com_abs #(
    parameter int NWORDS = 8,
    parameter int WWIDTH = 34
) (
    input   wire                clk         ,
    input   wire                rstn        ,
    input   wire[WWIDTH-1:0]    in          ,
    input   wire                in_start    ,
    input   wire                in_valid    ,
    output  wire[WWIDTH-1:0]    out_abs     ,
    output  wire                out_sign    ,
    output  wire                out_start   ,
    output  wire                out_valid
);

wire[WWIDTH-1:0] w_s1_raw;
wire w_s1_start;
wire w_s1_valid;
accelbrot_com_delay #(
    .DEPTH(NWORDS - 1),
    .WIDTH(WWIDTH + 2)
) u_delay_a_0 (
    .clk    (clk    ), // input
    .rstn   (rstn   ), // input
    .clken  ('1     ), // input
    .in     ({in_valid, in_start, in}), // input [WIDTH-1:0]
    .out    ({w_s1_valid, w_s1_start, w_s1_raw})  // output[WIDTH-1:0]
);

logic r_s1_sign_hold;
always @(posedge clk) begin
    if (!rstn) begin
        r_s1_sign_hold <= '0;
    end else if (w_s1_start) begin
        r_s1_sign_hold <= in[WWIDTH-1];
    end
end
wire w_s1_sign = w_s1_start ? in[WWIDTH-1] : r_s1_sign_hold;

wire[WWIDTH-1:0] w_s2_inv;
wire w_s2_start;
wire w_s2_valid;
accelbrot_com_inv #(
    .WWIDTH(WWIDTH)
) u_inv (
    .clk        (clk        ), // input
    .rstn       (rstn       ), // input
    .in         (w_s1_raw   ), // input [WWIDTH-1:0]
    .in_sign    (w_s1_sign  ), // input
    .in_start   (w_s1_start ), // input
    .in_valid   (w_s1_valid ), // input
    .out        (out_abs    ), // output[WWIDTH-1:0]
    .out_start  (out_start  ), // output
    .out_valid  (out_valid  )  // output
);

logic r_s2_sign;
always @(posedge clk) begin
    if (!rstn) begin
        r_s2_sign <= '0;
    end else begin
        r_s2_sign <= w_s1_sign;
    end
end
assign out_sign = r_s2_sign;

endmodule

`default_nettype wire
