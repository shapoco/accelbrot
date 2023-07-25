`default_nettype none

module avmm_as_spisram #(
  parameter int ANTI_CHATTER_CYCLES = 3,
  parameter int SPI_ADDR_BYTES      = 2,
  parameter int SPI_DATA_BYTES      = 4,
  parameter int MEM_ADDR_WIDTH      = 8 * SPI_ADDR_BYTES,
  parameter int MEM_DATA_WIDTH      = 8 * SPI_DATA_BYTES
) (
  input   wire                      spi_cs_n          ,
  input   wire                      spi_sck           ,
  input   wire                      spi_mosi          ,
  output  wire                      spi_miso          ,
  
  input   wire                      sys_clk           ,
  input   wire                      sys_rstn          ,
  
  output  wire[MEM_ADDR_WIDTH-1:0]  mem_address       ,
  output  wire                      mem_read          ,
  output  wire                      mem_write         ,
  output  wire[MEM_DATA_WIDTH-1:0]  mem_writedata     ,
  input   wire[MEM_DATA_WIDTH-1:0]  mem_readdata      ,
  input   wire                      mem_readdatavalid ,
  input   wire                      mem_waitrequest
);

  wire w_cs_n, w_sck, w_mosi;
  
  avmm_as_mcspisram_input_sync #(
    .WIDTH              (3                  ), // int
    .ANTI_CHATTER_CYCLES(ANTI_CHATTER_CYCLES)  // int
  ) sync (
    .sys_clk    (sys_clk                        ), // input
    .sys_rstn   (sys_rstn                       ), // input
    .signal_in  ({spi_cs_n, spi_sck , spi_mosi} ), // input [WIDTH-1:0]
    .signal_out ({w_cs_n  , w_sck   , w_mosi  } )  // output[WIDTH-1:0]
  );
  
  logic r_sck_dly;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_sck_dly <= 0;
    end else begin
      r_sck_dly <= w_sck;
    end
  end
  wire w_sck_rising = w_sck & ~ r_sck_dly;
  
  logic[2:0] r_bit_cntr;
  wire w_end_of_byte = w_sck_rising & (r_bit_cntr == 7);
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_bit_cntr <= 0;
    end else if (w_cs_n) begin
      r_bit_cntr <= 0;
    end else if (w_sck_rising) begin
      if (w_end_of_byte) begin
        r_bit_cntr <= 0;
      end else begin
        r_bit_cntr <= r_bit_cntr + 1;
      end
    end
  end
  
  typedef enum {
    ST_CMD,
    ST_ADDR,
    ST_DATA
  } spi_state_t;
  
  spi_state_t r_state;
  logic[2:0] r_byte_cntr;
  
  wire w_end_of_addr =
      w_end_of_byte &
      (r_state == ST_ADDR) &
      (r_byte_cntr == SPI_ADDR_BYTES - 1);
      
  wire w_end_of_data =
      w_end_of_byte &
      (r_state == ST_DATA) &
      (r_byte_cntr == SPI_DATA_BYTES - 1);
  
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_state <= ST_CMD;
      r_byte_cntr <= 0;
    end else if (w_cs_n) begin
      r_state <= ST_CMD;
      r_byte_cntr <= 0;
    end else if (w_end_of_byte) begin
      case (r_state)
      ST_CMD:
        begin
          r_state <= ST_ADDR;
          r_byte_cntr <= 0;
        end
      ST_ADDR:
        if (w_end_of_addr) begin
          r_state <= ST_DATA;
          r_byte_cntr <= 0;
        end else begin
          r_byte_cntr <= r_byte_cntr + 1;
        end
      ST_DATA:
        if (w_end_of_data) begin
          r_byte_cntr <= 0;
        end else begin
          r_byte_cntr <= r_byte_cntr + 1;
        end
      endcase
    end
  end
  
  logic[7:0] r_cmd;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_cmd <= 0;
    end else if (w_cs_n) begin
      r_cmd <= 0;
    end else if (r_state == ST_CMD && w_sck_rising) begin
      r_cmd <= { r_cmd[6:0], w_mosi };
    end
  end
  wire w_cmd_is_write = r_cmd == 8'h02;
  wire w_cmd_is_read  = r_cmd == 8'h03;
  
  wire w_mem_cmd_acpt;
  wire w_read_acpt;
  
  logic[MEM_ADDR_WIDTH-1:0] r_mem_addr;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_mem_addr <= 0;
    end else if (r_state == ST_ADDR && w_sck_rising) begin
      r_mem_addr <= { r_mem_addr[MEM_ADDR_WIDTH-2:0], w_mosi };
    end else if (w_mem_cmd_acpt) begin
      r_mem_addr <= r_mem_addr + SPI_DATA_BYTES;
    end
  end
  assign mem_address = r_mem_addr;
  
  logic r_read_trig;
  logic r_write_trig;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_read_trig   <= 0;
      r_write_trig  <= 0;
    end else if (w_cs_n) begin
      r_read_trig   <= 0;
      r_write_trig  <= 0;
    end else begin
      r_read_trig   <= w_cmd_is_read  & (w_end_of_addr | w_end_of_data);
      r_write_trig  <= w_cmd_is_write & w_end_of_data;
    end
  end
  
  logic r_mem_read;
  logic r_mem_write;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_mem_read  <= 0;
      r_mem_write <= 0;
    end else begin
      r_mem_read  <= (r_mem_read  & mem_waitrequest) | r_read_trig;
      r_mem_write <= (r_mem_write & mem_waitrequest) | r_write_trig;
    end
  end
  assign mem_read   = r_mem_read;
  assign mem_write  = r_mem_write;
  assign w_mem_cmd_acpt = (r_mem_read | r_mem_write) & ~ mem_waitrequest;
  
  logic[SPI_DATA_BYTES*8-1:0] r_mem_data;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_mem_data <= 0;
    end else if (w_cs_n) begin
      r_mem_data <= 0;
    end else if (mem_readdatavalid) begin
      r_mem_data <= mem_readdata;
    end else if (r_state == ST_DATA && w_sck_rising) begin
      r_mem_data <= { r_mem_data[SPI_DATA_BYTES*8-2:0], w_mosi };
    end
  end
  assign mem_writedata = r_mem_data[MEM_DATA_WIDTH-1:0];
  
  logic r_miso_ctl;
  logic r_miso_data;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_miso_ctl  <= 0;
      r_miso_data <= 0;
    end else if (w_cs_n) begin
      r_miso_ctl  <= 0;
      r_miso_data <= 0;
    end else if (w_cmd_is_read && r_state == ST_DATA) begin
      r_miso_ctl  <= 1;
      r_miso_data <= r_mem_data[MEM_DATA_WIDTH-1];
    end else begin
      r_miso_ctl  <= 0;
      r_miso_data <= 0;
    end
  end
  //assign spi_miso = r_miso_ctl ? r_miso_data : 1'bz;
  assign spi_miso = r_miso_data;
  
endmodule

module avmm_as_mcspisram_input_sync #(
  parameter integer WIDTH               = 3,
  parameter integer ANTI_CHATTER_CYCLES = 3,
  parameter integer DEFAULT_VALUE       = 0
) (
  input   wire            sys_clk   ,
  input   wire            sys_rstn  ,
  input   wire[WIDTH-1:0] signal_in ,
  output  wire[WIDTH-1:0] signal_out
);
  
  reg[WIDTH-1:0] r_in_sreg_0;
  reg[WIDTH-1:0] r_in_sreg_1;
  reg[WIDTH-1:0] r_in_sreg_2;
  
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_in_sreg_0 <= DEFAULT_VALUE;
      r_in_sreg_1 <= DEFAULT_VALUE;
      r_in_sreg_2 <= DEFAULT_VALUE;
    end else begin
      r_in_sreg_0 <= signal_in;
      r_in_sreg_1 <= r_in_sreg_0;
      r_in_sreg_2 <= r_in_sreg_1;
    end
  end
  
  localparam int CNTR_MAX   = ANTI_CHATTER_CYCLES - 1;
  localparam int CNTR_WIDTH = $clog2(CNTR_MAX + 1);
  reg[CNTR_WIDTH-1:0] r_stable_cntr;
  
  wire w_in_changed = (r_in_sreg_1 != r_in_sreg_2);
  
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_stable_cntr <= 0;
    end else if (w_in_changed) begin
      r_stable_cntr <= 0;
    end else if (r_stable_cntr < CNTR_MAX) begin
      r_stable_cntr <= r_stable_cntr + 1;
    end
  end
  
  wire w_in_stable = ( ! w_in_changed) & (r_stable_cntr == CNTR_MAX);
  
  reg[WIDTH-1:0] r_in_hold;
  always @(posedge sys_clk) begin
    if (!sys_rstn) begin
      r_in_hold <= DEFAULT_VALUE;
    end else if (w_in_stable) begin
      r_in_hold <= r_in_sreg_1;
    end
  end
  
  assign signal_out = w_in_stable ? r_in_sreg_1 : r_in_hold;
  
endmodule

`default_nettype wire
