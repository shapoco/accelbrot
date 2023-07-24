#!/bin/bash

set -eux

iverilog -s tb_top \
  -g2012 \
  ../../src/hdl/accelbrot.sv \
  ../../src/hdl/accelbrot_com_abs.sv \
  ../../src/hdl/accelbrot_com_add.sv \
  ../../src/hdl/accelbrot_com_axi_slice.sv \
  ../../src/hdl/accelbrot_com_block2word.sv \
  ../../src/hdl/accelbrot_com_delay.sv \
  ../../src/hdl/accelbrot_com_inv.sv \
  ../../src/hdl/accelbrot_com_mult_u2x2.sv \
  ../../src/hdl/accelbrot_com_mult_unx1.sv \
  ../../src/hdl/accelbrot_com_mult_unxn.sv \
  ../../src/hdl/accelbrot_com_ram_fifo.sv \
  ../../src/hdl/accelbrot_com_ram_sdp.sv \
  ../../src/hdl/accelbrot_com_reg_fifo.sv \
  ../../src/hdl/accelbrot_com_sub.sv \
  ../../src/hdl/accelbrot_com_word2block.sv \
  ../../src/hdl/accelbrot_fsm.sv \
  ../../src/hdl/accelbrot_loop.sv \
  ../../src/hdl/accelbrot_loop_core.sv \
  ../../src/hdl/accelbrot_loop_enter.sv \
  ../../src/hdl/accelbrot_loop_exit.sv \
  ../../src/hdl/accelbrot_queue.sv \
  ../../src/hdl/accelbrot_reg.sv \
  ../common/axi_ram.sv \
  ./tb_top.sv


./a.out
