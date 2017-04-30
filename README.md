# Brainf__k CPU
## Whats this?
A CPU that executes brainf\*\*k language written in Verilog HDL. The CPU can run on FPGA. The target device is Terasic DE-0 with LCD.

The project has been tested with Quartus 13.1, which is the latest version that supports Cyclon III that is on DE-0.

## Requirements
- DE-0 FPGA Board with LCD soldered
- Quartus 13.1 and PC environment that can program DE-0
- Tested on Ubuntu 16.04

## How to run
1. Write the brainf\*\*k code into ram_data.hex in Intel HEX format. You can use txt2hex.c in tools folder to convert a brainf\*\*k code to HEX format.
2. On Quartus13.1, open project file "bf.qpf"
3. Then, compile, and transfer the SOF file to DE-0
4. Press Button[1] to reset the CPU state.
5. You will see output on the LCD

## Limitations
- Only tested with a few codes
- Input function has never been tested. I will work on this
- Program ROM is 4K byte
- RAM is 4K byte
