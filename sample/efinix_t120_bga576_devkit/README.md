# Accelbrot for Efinix T120

## Block Diagram

![](img/block_diagram.png)

## FT232H Pin Assign

|J14 Pin Number|FT232HL Pin Name|FPGA Pin Name|HDL Port Name|
|:--:|:--:|:--:|:--:|
|1|ADBUS3|GPIOB_RXN26|spi_cs_n|
|2|ADBUS0|GPIOB_RXP27|spi_sck|
|3|ADBUS1|GPIOB_RXN27|spi_mosi|
|4|ADBUS2|GPIOB_RXP28|spi_miso|
|5 / 11|GND|GND|-|

----