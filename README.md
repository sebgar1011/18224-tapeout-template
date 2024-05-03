# Tiny Game of Life!

Sebastian Garcia
18-224 Spring 2024 Final Tapeout Project

## Overview

My chip implements Conway's Game of Life on an 8 by 8 grid with two tile colors,
green and blue. The neighbors of each tile are the 4 adjacent tiles (not the
diagonally adjacent ones). The user can choose an arbitrary start state and then
watch the Game play out.

## How it Works

The core of Game of Life is the state registers which store the color of each tile
in the grid. These tiles are generated using generate statements so by changing
the high level parameters (number of rows/cols and tile width/height) you can 
easily change the dimensions of the Game. Additionally, each state register knows
where it is in the grid so to determine what its next state should be, it simply
counts the numbers of neighbors surrounding it and uses that number to choose the
next state. 

To actually render the game, each tile also has a corresponding, combination 
is_pixel_in_tile module that outputs True if the current pixel being selected by
the VGA driver is in that tile. Then that signal is used to index into a specific
state register to determine the color of the pixel. This is done using 2D unpacked
arrays.

Lastly, to add some complexity to the Game, on startup that user can set an 
arbitrary start state with some buttons. One button is used to shift through
all the tiles and another button is used to color the selected tile. These buttons
should be active-high and must be held down for about 1 second to be registered
if the clock is running at 25 MHz. Once the user is done setting the start state.
she/he can press another button to begin running the simulation and relishing 
in its endless complexity. To reset back to the start state, the user must simply
press the reset button.

## Inputs/Outputs

The buttons should be mapped to io_in inputs according to these assignments:

// Only buttons 3, 4, 5, 6 used
    always_comb begin
        btn[3] = io_in[0];
        btn[4] = io_in[1];
        btn[5] = io_in[2];
        btn[6] = io_in[3];
    end

btn[3] is used to change the position of the selected tile when the system is in
setup mode (the first stage in the video demo). btn[4] is used to save the state
of the selected tile in setup mode. And btn[6] is used to go to the simulation
state where the Game of Life will play out.

Similarly, the VGA outputs (if using a PMOD VGA connector like the one from
Digilent) should be the following:

// Now mapping io_out to VGA output
    always_comb begin
        io_out[0] = gp16;
        io_out[1] = gp17;
        io_out[2] = gn23;
        io_out[3] = gp22;
        io_out[4] = gn21;
        io_out[5] = gp23;
        io_out[6] = gp22;
        io_out[7] = gp21;
        io_out[8] = gn16;
        io_out[9] = gn15;
        io_out[10] = gn14;
    end

Only 11 of the 12 outputs are used. Each output is used for the VGA display. The
pin names correspond to the pins shown in the diagram below for the PMOD VGA
connector.

![](vga.png)

## Hardware Peripherals

4 buttons should be used with this system. 3 for setting up the initial state
of the Game of Life and one for reset. A VGA monitor, cable, and connector
should also be used.

## Design Testing / Bringup

To test the design, simply hook up buttons and a VGA monitor to the chip (using
a custom PCB). Then, press the buttons specified above to set the initial state 
of the Game, press the start button to set the game in motion, and watch as 
the cellular automata plays out.    

There is also a testbench.py CocoTB test function in the src folder which 
runs through pixel values and checks what the state of each should be.

## Media

![](Demo_Video.mov)

