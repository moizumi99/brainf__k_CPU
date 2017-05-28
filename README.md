# Brainf__k CPU
## Updates 
5/27/2017
Support 16KB program
Support TXD output through GPIO (Connext your RXD to GPIO01_D5, GND to GPIO1 GND)
Mandelbrot.b can run now. Enjoy
https://youtu.be/7C1cCE1fIII

5/20/2017
Now, the loop command "]" uses stack to find the return address instead of searching for a corresponding "["
PIPELINE processing is implemented
Can execute up to 4 consecutive commands of "+-" or "<>"
Now it is 6 times faster than the first version.

## Whats this?
A CPU that executes brainf\*\*k language written in Verilog HDL. The CPU can run on FPGA. The target device is Terasic DE0 with LCD.

The project file has been tested with Quartus 13.1, which is the latest version that supports Cyclon III that is on DE0.

## What is Brainf\*\*k?
It's a very simple programming language made of only 8 commands +-<>.,[]
https://esolangs.org/wiki/Brainfuck

## Requirements
- DE0 FPGA Board with LCD soldered
- Quartus 13.1 and PC environment that can program DE0

## How to run
1. Write the brainf\*\*k code into rom_data.hex in MIF format. You can use txt2mif.c in tools folder to convert a brainf\*\*k code to MIF format.
2. On Quartus13.1, open project file "bf.qpf"
3. Then, compile, and transfer the SOF file to DE-0
4. Press Button[1] to reset the CPU state.
5. You will see output on the LCD

## Limitations
- Only tested with a few codes
- Tested only on Ubuntu 16.04
- Input function has never been tested. I will work on this
- Program ROM is 4K byte
- RAM is 4K byte
