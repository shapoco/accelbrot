
`default_nettype none

module accelbrot_com_ram_fifo #(
    parameter int DATA_WIDTH= 32        ,
    parameter int DEPTH     = 16        ,
    parameter int AFULL_TH  = DEPTH - 4 ,
    parameter int AEMPTY_TH = 4         ,
    parameter int SIZE_WIDTH= $clog2(DEPTH+1)
) (
    input   wire                rstn    ,
    input   wire                clk     ,
    output  wire                afull   ,
    output  wire                aempty  ,
    output  wire[SIZE_WIDTH-1:0]written ,
    output  wire[SIZE_WIDTH-1:0]readable,
    output  wire                wr_ready,
    input   wire                wr_valid,
    input   wire[DATA_WIDTH-1:0]wr_data ,
    input   wire                rd_ready,
    output  wire                rd_valid,
    output  wire[DATA_WIDTH-1:0]rd_data
);
    localparam int ADDR_WIDTH = $clog2(DEPTH);
    localparam int ACPT_LATENCY = 4;
    localparam int RAM_RD_LATENCY = 2;
    
    logic r_wr_ready;
    
    wire w_wr_acpt, w_wr_acpt_d;
    wire w_rd_acpt, w_rd_acpt_d;
    wire w_rd_cken;
    
    assign w_wr_acpt = r_wr_ready & wr_valid;
    
    logic[ADDR_WIDTH-1:0] r_wr_ptr;
    logic[SIZE_WIDTH-1:0] r_written;
    logic[ACPT_LATENCY-1:0] r_wr_acpt_d;
    logic r_afull;
    always_ff @(posedge clk) begin
        if (!rstn) begin
            r_wr_ptr <= '0;
            r_wr_acpt_d <= '0;
            r_written <= '0;
            r_wr_ready <= '0;
            r_afull <= '0;
        end else begin
            // write pointer
            if (w_wr_acpt) begin
                if (r_wr_ptr < DEPTH - 1) begin
                    r_wr_ptr <= r_wr_ptr + 'd1;
                end else begin
                    r_wr_ptr <= '0;
                end
            end
            
            // written count
            if (w_wr_acpt && !w_rd_acpt_d) begin
                r_written <= r_written + 'd1;
                r_wr_ready <= r_written < DEPTH - 1;
            end else if (!w_wr_acpt && w_rd_acpt_d) begin
                r_written <= r_written - 'd1;
                r_wr_ready <= '1;
            end else begin
                r_wr_ready <= r_written < DEPTH;
            end
            
            // almost full
            r_afull <= r_written > AFULL_TH;
            
            // write accept delay
            r_wr_acpt_d <= {r_wr_acpt_d[ACPT_LATENCY-2:0], w_wr_acpt};
        end
    end
    assign wr_ready = r_wr_ready;
    assign written = r_written;
    assign afull = r_afull;
    assign w_wr_acpt_d = r_wr_acpt_d[ACPT_LATENCY-1];
    
    wire[DATA_WIDTH-1:0] w_rd_data;
    accelbrot_com_ram_sdp #(
        .DATA_WIDTH (DATA_WIDTH ),
        .ADDR_WIDTH (ADDR_WIDTH ),
        .DEPTH      (DEPTH      )
    ) ram_i (
        .wr_clk (clk        ), // input
        .wr_en  (w_wr_acpt  ), // input
        .wr_addr(r_wr_ptr   ), // input [ADDR_WIDTH-1:0]
        .wr_data(wr_data    ), // input [DATA_WIDTH-1:0]
        .rd_clk (clk        ), // input
        .rd_en  (w_rd_cken  ), // input
        .rd_addr(r_rd_ptr   ), // input [ADDR_WIDTH-1:0]
        .rd_data(rd_data    )  // output[DATA_WIDTH-1:0]
    );
    
    logic[SIZE_WIDTH-1:0] r_fetchable;
    logic r_fetch_en;
    
    // 読み出し accept は読み出し値がラッチされたときにアサートする
    assign w_rd_acpt = w_rd_cken & r_fetch_en_d[RAM_RD_LATENCY-1];
    
    logic[ADDR_WIDTH-1:0] r_rd_ptr;
    logic[RAM_RD_LATENCY-1:0] r_fetch_en_d;
    logic[ACPT_LATENCY-1:0] r_rd_acpt_d;
    logic[RAM_RD_LATENCY-1:0][SIZE_WIDTH-1:0] r_fetchable_d;
    logic[DATA_WIDTH-1:0] r_rd_data;
    logic r_aempty;
    always_ff @(posedge clk) begin
        if (!rstn) begin
            r_rd_ptr <= '0;
            r_fetchable <= '0;
            r_fetchable_d <= '0;
            r_fetch_en <= '0;
            r_fetch_en_d <= '0;
            r_rd_acpt_d <= '0;
            r_aempty <= '0;
        end else begin
            if (w_rd_cken) begin
                // read pointer
                if (r_fetch_en) begin
                    if (r_rd_ptr < DEPTH - 1) begin
                        r_rd_ptr <= r_rd_ptr + 'd1;
                    end else begin
                        r_rd_ptr <= '0;
                    end
                end
                
                // fetch enable delay
                r_fetch_en_d <= {r_fetch_en_d[RAM_RD_LATENCY-2:0], r_fetch_en};
            end
            
            // fetchable count
            if (w_rd_cken && r_fetch_en && !w_wr_acpt_d) begin
                r_fetchable <= r_fetchable - 'd1;
                r_fetch_en <= r_fetchable > 'd1;
            end else if (!(w_rd_cken && r_fetch_en) && w_wr_acpt_d) begin
                r_fetchable <= r_fetchable + 'd1;
                r_fetch_en <= '1;
            end else begin
                r_fetch_en <= r_fetchable > '0;
            end
            
            // read accept delay
            r_rd_acpt_d <= {r_rd_acpt_d[ACPT_LATENCY-2:0], w_rd_acpt};
            
            // readable count
            r_fetchable_d <= {r_fetchable_d[RAM_RD_LATENCY-2:0], r_fetchable};
            
            // almost empty
            r_aempty <= r_fetchable_d[RAM_RD_LATENCY-1] < AEMPTY_TH;
        end
    end
    assign w_rd_acpt_d = r_rd_acpt_d[ACPT_LATENCY-1];
    wire w_rd_valid = r_fetch_en_d[RAM_RD_LATENCY-1];
    assign rd_valid = w_rd_valid;
    assign readable = r_fetchable_d[RAM_RD_LATENCY-1];
    assign aempty = r_aempty;
    
    assign w_rd_cken = rd_ready || !w_rd_valid;
endmodule

`default_nettype wire
