`default_nettype none

module accelbrot_com_axi_slice #(
    parameter int DATA_WIDTH = 32
) (
    input   wire                clk         ,
    input   wire                rstn        ,
    input   wire[DATA_WIDTH-1:0]in_data     ,
    input   wire                in_valid    ,
    output  wire                in_ready    ,
    output  wire[DATA_WIDTH-1:0]out_data    ,
    output  wire                out_valid   ,
    input   wire                out_ready
);

logic r_in_ready;
logic r_in_valid;
logic r_out_valid;
logic[DATA_WIDTH-1:0] r_in_data;
logic[DATA_WIDTH-1:0] r_out_data;

wire w_shift_en = out_ready | ~r_out_valid;

always_ff @(posedge clk) begin
    if (!rstn) begin
        r_in_ready  <= 0;
        r_in_valid  <= 0;
        r_in_data   <= 0;
        r_out_valid <= 0;
        r_out_data  <= 0;
    end else if (w_shift_en) begin
        r_in_ready  <= 1;
        r_in_valid  <= 0;
        if (r_in_ready) begin
            r_out_valid <= in_valid;
            r_out_data  <= in_data;
        end else begin
            r_out_valid <= r_in_valid;
            r_out_data  <= r_in_data;
        end
    end else begin
        if (!r_out_valid) begin
            r_in_ready  <= 1;
            r_in_valid  <= 0;
            r_out_valid <= in_valid;
            r_out_data  <= in_data;
        end else if (!r_in_valid) begin
            r_in_ready  <= ~ in_valid;
            r_in_valid  <= in_valid;
            r_in_data   <= in_data;
        end
    end
end
assign in_ready  = r_in_ready;
assign out_valid = r_out_valid;
assign out_data  = r_out_data;

endmodule

`default_nettype wire
