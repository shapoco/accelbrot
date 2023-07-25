`default_nettype none

module reset_sync #(
    parameter bit IN_POLARITY  = 1, // 0: active-high, 1: active-low
    parameter bit OUT_POLARITY = 1  // 0: active-high, 1: active-low
) (
    input   wire    clk     ,
    input   wire    in_rst  ,
    output  wire    out_rst
);

logic r_rst_async;
logic r_rst_sync;

generate
    if (IN_POLARITY == 0) begin

        always_ff @(posedge clk or posedge in_rst) begin
            if (in_rst) begin
                r_rst_async  <= OUT_POLARITY;
                r_rst_sync   <= OUT_POLARITY;
            end else begin
                r_rst_async  <= ~OUT_POLARITY;
                r_rst_sync   <= r_rst_async;
            end
        end

    end else begin

        always_ff @(posedge clk or negedge in_rst) begin
            if (!in_rst) begin
                r_rst_async  <= ~OUT_POLARITY;
                r_rst_sync   <= ~OUT_POLARITY;
            end else begin
                r_rst_async  <= OUT_POLARITY;
                r_rst_sync   <= r_rst_async;
            end
        end

    end
endgenerate

assign out_rst = r_rst_sync;

endmodule

`default_nettype wire
