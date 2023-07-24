`default_nettype none

module accelbrot_com_mult_unxn #(
    parameter int NWORDS = 8 , // 1ブロック内のワード数
    parameter int WWIDTH = 34, // 1ワードの幅
    parameter int IWIDTH = 6,  // 整数部の幅
    parameter int BWIDTH = NWORDS * WWIDTH
) (
    input   wire            clk     ,
    input   wire            rstn    ,
    input   wire[BWIDTH-1:0]a       ,
    input   wire[BWIDTH-1:0]b       ,
    input   wire            ab_valid,
    output  wire[WWIDTH-1:0]q       ,
    output  wire            q_start ,
    output  wire            q_valid
);

localparam int CNTR_WIDTH = $clog2(NWORDS * 2);

// シーケンサ
logic[CNTR_WIDTH-1:0] r_s0_cntr;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s0_cntr <= '0;
    end else if (ab_valid) begin
        r_s0_cntr <= 'd1;
    end else if ('d1 <= r_s0_cntr && r_s0_cntr < NWORDS - 1) begin
        r_s0_cntr <= r_s0_cntr + 'd1;
    end else begin
        r_s0_cntr <= '0;
    end
end
wire w_s0_init = (r_s0_cntr == '0);
wire w_s0_last = (r_s0_cntr == NWORDS - 1);

// 入力を分解
wire[NWORDS-1:0][WWIDTH-1:0] w_s0_a_array = a;
wire[NWORDS-1:0][WWIDTH-1:0] w_s0_b_array = b;

// Bのシフト
logic[NWORDS-1:1][WWIDTH-1:0] r_s0_b_sreg;
always_ff @(posedge clk) begin
    if (ab_valid) begin
        for (int i = 1; i < NWORDS; i++) begin
            r_s0_b_sreg[i] <= w_s0_b_array[i];
        end
    end else begin
        for (int i = 1; i < NWORDS-1; i++) begin
            r_s0_b_sreg[i] <= r_s0_b_sreg[i+1];
        end
        r_s0_b_sreg[NWORDS-1] <= '0;
    end
end
wire[WWIDTH-1:0] w_s0_b = ab_valid ? w_s0_b_array[0] : r_s0_b_sreg[1];

// 乗算
wire[NWORDS-1:0][WWIDTH*2-1:0] w_s4_ab;
generate
    for (genvar i = 0; i < NWORDS; i++) begin

        accelbrot_com_mult_u2x2 #(
            .WWIDTH(WWIDTH)
        ) u_mult (
            .clk(clk            ), // input
            .a  (w_s0_a_array[i]), // input [WWIDTH-1:0]
            .b  (w_s0_b         ), // input [WWIDTH-1:0]
            .cea(ab_valid       ), // input
            .ceb('1             ), // input
            .q  (w_s4_ab[i]     )  // output[WWIDTH*2-1:0]
        );

    end
endgenerate

// タイミング信号遅延調整
logic r_s1_init, r_s1_last;
logic r_s2_init, r_s2_last;
logic r_s3_init, r_s3_last;
logic r_s4_init, r_s4_last;
logic r_s5_accum_last;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s1_init <= '0;
        r_s2_init <= '0;
        r_s3_init <= '0;
        r_s4_init <= '0;
        r_s1_last <= '0;
        r_s2_last <= '0;
        r_s3_last <= '0;
        r_s4_last <= '0;
        r_s5_accum_last <= '0;
    end else begin
        r_s1_init <= w_s0_init;
        r_s2_init <= r_s1_init;
        r_s3_init <= r_s2_init;
        r_s4_init <= r_s3_init;
        r_s1_last <= w_s0_last;
        r_s2_last <= r_s1_last;
        r_s3_last <= r_s2_last;
        r_s4_last <= r_s3_last;
        r_s5_accum_last <= r_s4_last;
    end
end

// カウンタ待ち合わせ
logic[CNTR_WIDTH-1:0] r_s5_flush_cntr;
logic r_s5_flush_act;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s5_flush_cntr <= '0;
        r_s5_flush_act <= '0;
    end else begin
        if (r_s5_accum_last) begin
            r_s5_flush_cntr <= NWORDS;
            r_s5_flush_act <= '1;
        end else if (NWORDS <= r_s5_flush_cntr && r_s5_flush_cntr < 2 * NWORDS - 1) begin
            r_s5_flush_cntr <= r_s5_flush_cntr + 'd1;
            r_s5_flush_act <= (r_s5_flush_cntr < 2 * NWORDS - 2);
        end else begin
            r_s5_flush_cntr <= '0;
            r_s5_flush_act <= '0;
        end
    end
end

// 部分乗算結果連結
logic[NWORDS:0][WWIDTH-1:0] w_s4_ab_sum;
logic[NWORDS:0] w_s4_ab_carry;
//always_comb begin
always @* begin
    w_s4_ab_sum[0] = w_s4_ab[0][WWIDTH-1:0];
    w_s4_ab_carry[0] = '0;
    w_s4_ab_carry[1] = '0;
    for (int i = 1; i < NWORDS; i++) begin
        reg[WWIDTH*2-1:0] h, l;
        reg[WWIDTH:0] tmp;
        h = w_s4_ab[i-1];
        l = w_s4_ab[i];
        tmp = h[WWIDTH*2-1:WWIDTH] + l[WWIDTH-1:0];
        w_s4_ab_sum[i] = tmp[WWIDTH-1:0];
        w_s4_ab_carry[i+1] = tmp[WWIDTH];
    end
    w_s4_ab_sum[NWORDS] = w_s4_ab[NWORDS-1][WWIDTH*2-1:WWIDTH];
end

// アキュムレータ
logic[NWORDS:0][WWIDTH-1:0] r_s5_accum_value;
logic[NWORDS:0][1:0] r_s5_accum_carry;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s5_accum_value <= '0;
        r_s5_accum_carry <= '0;
    end else begin
        reg[NWORDS:0][WWIDTH-1:0] accum_shift;
        reg[NWORDS:0][1:0] carry_in;
        if (r_s4_init) begin
            accum_shift = '0;
            carry_in = '0;
        end else begin
            accum_shift[NWORDS] = '0;
            accum_shift[NWORDS-1:0] = r_s5_accum_value[NWORDS:1];
            carry_in = r_s5_accum_carry;
        end
        for(int i = 0; i < NWORDS + 1; i++) begin
            reg[WWIDTH+1:0] tmp;
            tmp = accum_shift[i] + carry_in[i] + w_s4_ab_sum[i] + w_s4_ab_carry[i];
            r_s5_accum_value[i] <= tmp[WWIDTH-1:0];
            r_s5_accum_carry[i] <= tmp[WWIDTH+1:WWIDTH];
        end
    end
end

// キャリーを処理しながら押し出し
logic[NWORDS-1:0][WWIDTH-1:0] r_s5_flush_value;
logic[NWORDS-1:0][1:0] r_s5_flush_carry;
logic r_s5_start;
logic r_s5_valid;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s5_flush_value <= '0;
        r_s5_flush_carry <= '0;
        r_s5_start <= '0;
        r_s5_valid <= '0;
    end else begin
        reg[NWORDS-1:0][WWIDTH-1:0] accum_shift;
        reg[NWORDS-1:0][1:0] carry_in;
        if (r_s5_accum_last) begin
            accum_shift = r_s5_accum_value[NWORDS:1];
            carry_in = r_s5_accum_carry[NWORDS-1:0];
        end else begin
            accum_shift[NWORDS-1] = '0;
            accum_shift[NWORDS-2:0] = r_s5_flush_value[NWORDS-1:1];
            carry_in = r_s5_flush_carry;
        end
        for(int i = 0; i < NWORDS; i++) begin
            reg[WWIDTH+1:0] tmp;
            tmp = accum_shift[i] + carry_in[i];
            r_s5_flush_value[i] <= tmp[WWIDTH-1:0];
            r_s5_flush_carry[i] <= tmp[WWIDTH+1:WWIDTH];
        end
        r_s5_start <= r_s5_accum_last;
        r_s5_valid <= r_s5_accum_last || r_s5_flush_act;
    end
end

// 桁合わせ
logic[WWIDTH-1:0] r_s6_q_shift;
always_ff @(posedge clk) begin
    if (!rstn) begin
        r_s6_q_shift <= '0;
    end else if (r_s5_accum_last) begin
        r_s6_q_shift <= r_s5_accum_value[0];
    end else begin
        r_s6_q_shift <= r_s5_flush_value[0];
    end
end
wire[WWIDTH*2-1:0] w_s5_q_concat = {r_s5_flush_value[0], r_s6_q_shift};

assign q = w_s5_q_concat[WWIDTH*2-IWIDTH-1:WWIDTH-IWIDTH];
assign q_start = r_s5_start;
assign q_valid = r_s5_valid;

endmodule

`default_nettype wire
