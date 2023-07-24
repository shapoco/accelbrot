`default_nettype none

module accelbrot_com_delay #(
    parameter int       DEPTH   = 1,
    parameter int       WIDTH   = 1,
    parameter[WIDTH-1:0]INIT    = 0
) (
    input   wire            clk     ,
    input   wire            rstn    ,
    input   wire            clken   ,
    input   wire[WIDTH-1:0] in      ,
    output  wire[WIDTH-1:0] out
);

logic[DEPTH-1:0][WIDTH-1:0] sreg;
always_ff @(posedge clk) begin
    if (!rstn) begin
        for(int i = 0; i < DEPTH; i++) begin
            sreg[i] <= INIT;
        end
    end else if (clken) begin
        sreg[0] <= in;
        for(int i = 1; i < DEPTH; i++) begin
            sreg[i] <= sreg[i-1];
        end
    end
end
assign out = sreg[DEPTH-1];

endmodule

`default_nettype wire
