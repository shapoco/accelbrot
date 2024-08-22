`default_nettype none

module act_led(
    input   wire    clk         ,
    input   wire    rstn        ,
    input   wire    pulse_1ms   ,
    input   wire    act_in      ,
    output  wire    led_out
);

localparam int BLINK_INTERVAL_HALF_MS = 50;

logic[7:0] r_timer;
logic[1:0] r_blink;

always @(posedge clk) begin
    if (!rstn) begin
        r_timer <= '0;
        r_blink <= '0;
    end else begin
        reg[7:0] v_timer;
        reg[1:0] v_blink;
        v_timer = r_timer;
        v_blink = r_blink;
        if (act_in) begin
            if (v_blink == 'd0) begin
                v_blink = 'd1;
                v_timer = BLINK_INTERVAL_HALF_MS - 'd1;
            end else if (v_blink == 'd1) begin
                v_blink = 'd3;
            end
        end
        if (pulse_1ms) begin
            if (v_timer > 'd0) begin
                v_timer--;
            end else if (v_blink > 'd0) begin
                v_timer = BLINK_INTERVAL_HALF_MS - 'd1;
                v_blink--;
            end
        end
        r_timer <= v_timer;
        r_blink <= v_blink;
    end
end

assign led_out = r_blink[0];

endmodule

`default_nettype wire
