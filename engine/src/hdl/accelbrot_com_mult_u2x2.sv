`default_nettype none

module accelbrot_com_mult_u2x2 #(
    parameter int WWIDTH = 34
) (
    input   wire                clk ,
    input   wire[WWIDTH-1:0]    a   ,
    input   wire[WWIDTH-1:0]    b   ,
    input   wire                cea ,
    input   wire                ceb ,
    output  wire[WWIDTH*2-1:0]  q
);

localparam int HWIDTH = WWIDTH / 2;

logic[1:0][HWIDTH-1:0] r_a;
logic[1:0][HWIDTH-1:0] r_b;
always_ff @(posedge clk) begin
    if (cea) r_a <= a;
    if (ceb) r_b <= b;
end

logic[1:0][HWIDTH-1:0] r_ab00;
logic[1:0][HWIDTH-1:0] r_ab01;
logic[1:0][HWIDTH-1:0] r_ab10;
logic[1:0][HWIDTH-1:0] r_ab11;
always_ff @(posedge clk) begin
    r_ab00 <= r_a[0] * r_b[0];
    r_ab10 <= r_a[1] * r_b[0];
    r_ab01 <= r_a[0] * r_b[1];
    r_ab11 <= r_a[1] * r_b[1];
end

logic[1:0][HWIDTH-1:0] r_ab00_d;
logic[1:0][HWIDTH-1:0] r_ab01_d;
logic[1:0][HWIDTH-1:0] r_ab10_d;
logic[1:0][HWIDTH-1:0] r_ab11_d;
logic[HWIDTH+1:0] r_tmp1;
always_ff @(posedge clk) begin
    r_tmp1 <= r_ab00[1] + r_ab10[0] + r_ab01[0];
    r_ab00_d <= r_ab00;
    r_ab01_d <= r_ab01;
    r_ab10_d <= r_ab10;
    r_ab11_d <= r_ab11;
end

logic[3:0][HWIDTH-1:0] r_q;
always_ff @(posedge clk) begin
    reg[HWIDTH+1:0] tmp2;
    tmp2 = r_ab10_d[1] + r_ab01_d[1] + r_ab11_d[0] + r_tmp1[HWIDTH+1:HWIDTH];
    r_q[0] <= r_ab00_d[0];
    r_q[1] <= r_tmp1[HWIDTH-1:0];
    r_q[2] <= tmp2[HWIDTH-1:0];
    r_q[3] <= r_ab11_d[1] + tmp2[HWIDTH+1:HWIDTH];
end

assign q = r_q;

endmodule

`default_nettype wire
