`default_nettype none

module accelbrot_com_mult_unx1 #(
    parameter int NWORDS = 8 , // 1ブロック内のワード数
    parameter int WWIDTH = 34  // 1ワードの幅
) (
    input   wire                clk     ,
    input   wire                rstn    ,
    input   wire[WWIDTH-1:0]    a       ,
    input   wire[WWIDTH/2-1:0]  b       ,
    input   wire                ab_start,
    input   wire                ab_valid,
    output  wire[WWIDTH-1:0]    q       ,
    output  wire                q_start ,
    output  wire                q_valid
);

localparam int HWIDTH = WWIDTH / 2;
localparam int CNTR_WIDTH = $clog2(NWORDS * 2);

// 部分乗算
logic[HWIDTH-1:0] r_s1_a0;
logic[HWIDTH-1:0] r_s1_a1;
logic[HWIDTH-1:0] r_s1_b0;
logic[HWIDTH-1:0] r_s1_b1;
logic[WWIDTH-1:0] r_s2_ab0;
logic[WWIDTH-1:0] r_s2_ab1;
logic r_s1_start, r_s2_start;
logic r_s1_valid, r_s2_valid;
always_ff @(posedge clk) begin
    r_s1_a0 <= a[HWIDTH-1:0];
    r_s1_a1 <= a[WWIDTH-1:HWIDTH];
    if (ab_start) begin
        r_s1_b0 <= b;
        r_s1_b1 <= b;
    end
    r_s1_start <= ab_valid & ab_start;
    r_s1_valid <= ab_valid;
    
    r_s2_ab0 <= r_s1_a0 * r_s1_b0;
    r_s2_ab1 <= r_s1_a1 * r_s1_b1;
    r_s2_start <= r_s1_start;
    r_s2_valid <= r_s1_valid;
end

// 足し込み
logic[HWIDTH-1:0] r_s3_carry;
logic[WWIDTH-1:0] r_s3_q;
logic r_s3_start;
logic r_s3_valid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s3_carry <= '0;
        r_s3_q <= '0;
        r_s3_start <= '0;
        r_s3_valid <= '0;
    end else begin
        reg[HWIDTH-1:0] carry;
        reg[WWIDTH+HWIDTH-1:0] tmp;
        if (r_s2_start) begin
            carry = '0;
        end else begin
            carry = r_s3_carry;
        end
        tmp = r_s2_ab0 + {r_s2_ab1, {HWIDTH{1'b0}}} + carry;
        r_s3_carry <= tmp[WWIDTH+HWIDTH-1:WWIDTH];
        r_s3_q <= tmp[WWIDTH-1:0];
        r_s3_start <= r_s2_start;
        r_s3_valid <= r_s2_valid;
    end
end

assign q = r_s3_q;
assign q_start = r_s3_start;
assign q_valid = r_s3_valid;

endmodule

`default_nettype wire
