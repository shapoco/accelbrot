`default_nettype none

module accelbrot_com_add #(
    parameter int WWIDTH = 34
) (
    input   wire            clk     ,
    input   wire            rstn    ,
    input   wire[WWIDTH-1:0]a       ,
    input   wire[WWIDTH-1:0]b       ,
    input   wire            ab_start,
    input   wire            ab_valid,
    output  wire[WWIDTH-1:0]q       ,
    output  wire            q_start ,
    output  wire            q_valid
);

logic[WWIDTH-1:0] r_q;
logic r_carry;
logic r_q_start;
logic r_q_valid;

always_ff @(posedge clk) begin
    if (!rstn) begin
        r_q <= '0;
        r_carry <= '0;
        r_q_start <= '0;
        r_q_valid <= '0;
    end else begin
        reg[WWIDTH:0] tmp;
        tmp = a + b + (ab_start ? 1'b0 : r_carry);
        r_q <= tmp[WWIDTH-1:0];
        r_carry <= tmp[WWIDTH];
        r_q_start <= ab_start;
        r_q_valid <= ab_valid;
    end
end

assign q = r_q;
assign q_start = r_q_start;
assign q_valid = r_q_valid;

endmodule

`default_nettype wire
