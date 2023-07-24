
`default_nettype none

module accelbrot_com_reg_fifo #(
    parameter int DATA_WIDTH    = 32        ,
    parameter int DEPTH         = 16        ,
    parameter int AFULL_TH      = DEPTH - 1 ,
    parameter int AEMPTY_TH     = 1
) (
    input   wire                        clk     ,
    input   wire                        rstn    ,
    output  wire[$clog2(DEPTH+1)-1:0]   stored  ,
    output  wire                        afull   ,
    output  wire                        aempty  ,
    output  wire                        wr_ready,
    input   wire                        wr_valid,
    input   wire[DATA_WIDTH-1:0]        wr_data ,
    input   wire                        rd_ready,
    output  wire                        rd_valid,
    output  wire[DATA_WIDTH-1:0]        rd_data
);

    genvar i;

    logic[DEPTH-1:0][DATA_WIDTH-1:0]  r_mem;
    logic[DEPTH-1:0]                  r_word_en;
    logic                             r_not_full;

    wire            w_load_en_root  = wr_valid & r_not_full;
    wire            w_shift_en      = rd_ready & r_word_en[0];
    wire[DEPTH-1:0] w_load_point    = { (~r_word_en[DEPTH-1:1] & r_word_en[DEPTH-2:0]), ~r_word_en[0] };

    logic[DEPTH-1:0] w_load_en_array;
    always @(*) begin
        w_load_en_array = '0;
        if (w_load_en_root) begin
            if (w_shift_en) begin
                w_load_en_array = { 1'b0, w_load_point[DEPTH-1:1] };
            end else begin
                w_load_en_array = w_load_point;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            r_not_full <= '0;
        end else if (w_load_en_array[DEPTH-1]) begin
            r_not_full <= '0;
        end else if (w_shift_en) begin
            r_not_full <= '1;
        end else if ( ! r_word_en[DEPTH-2]) begin
            r_not_full <= '1;
        end
    end
    assign wr_ready = r_not_full;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            r_mem     [DEPTH-1] <= '0;
            r_word_en [DEPTH-1] <= '0;
        end else if (w_load_en_array[DEPTH-1]) begin
            r_mem     [DEPTH-1] <= wr_data;
            r_word_en [DEPTH-1] <= '1;
        end else if (w_shift_en) begin
            r_mem     [DEPTH-1] <= '0;
            r_word_en [DEPTH-1] <= '0;
        end
    end

    generate
        for (i = 0; i < DEPTH - 1; i = i + 1) begin : stage
            always_ff @(posedge clk) begin
                if (!rstn) begin
                    r_mem     [i] <= '0;
                    r_word_en [i] <= '0;
                end else if (w_load_en_array[i]) begin
                    r_mem     [i] <= wr_data;
                    r_word_en [i] <= '1;
                end else if (w_shift_en) begin
                    r_mem     [i] <= r_mem    [i+1];
                    r_word_en [i] <= r_word_en[i+1];
                end
            end
        end
    endgenerate

    assign rd_data  = r_mem[0];
    assign rd_valid = r_word_en[0];

    logic[$clog2(DEPTH+1)-1:0] w_stored_next;
    logic[$clog2(DEPTH+1)-1:0] r_stored;
    always @(*) begin
        w_stored_next = r_stored;
        if (rstn) begin
            w_stored_next = '0;
        end else if (   w_load_en_root && ! w_shift_en) begin
            w_stored_next = r_stored + 1;
        end else if ( ! w_load_en_root &&   w_shift_en) begin
            w_stored_next = r_stored - 1;
        end
    end

    logic r_afull;
    logic r_aempty;
    always_ff @(posedge clk) begin
        if (!rstn) begin
            r_stored  <= '0;
            r_afull   <= '0;
            r_aempty  <= '0;
        end else begin
            r_stored  <= w_stored_next;
            r_afull   <= (w_stored_next >= AFULL_TH) ? '1 : '0;
            r_aempty  <= (w_stored_next < AEMPTY_TH) ? '1 : '0;
        end
    end
    assign stored = r_stored;
    assign afull  = r_afull;
    assign aempty = r_aempty;

endmodule

`default_nettype wire
