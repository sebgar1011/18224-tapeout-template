import os
import logging
import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import *


@cocotb.test()
async def basic_test(dut):
    print("============== STARTING TEST ==============")

    # Run the clock
    cocotb.start_soon(Clock(dut.clock, 10, units="ns").start())

    # Since our circuit is on the rising edge,
    # we can feed inputs on the falling edge
    # This makes things easier to read and visualize
    await FallingEdge(dut.clock)

    # Reset the DUT
    dut.reset.value = True
    await FallingEdge(dut.clock)
    await FallingEdge(dut.clock)
    dut.reset.value = False

    # Check pixel in top left tile
    dut.h_idx.value = 10
    dut.v_idx.value = 10
    await FallingEdge(dut.clock)
    print(f"DUT STATE: {dut.state}")
    assert dut.state == 0

    # Check pixel to the right of top left tile
    dut.h_idx.value = 10 + 50
    dut.v_idx.value = 10 + 50
    await FallingEdge(dut.clock)
    print(f"DUT STATE: {dut.state}")
    assert dut.state == 1

    dut.h_idx.value = 10 + 50 + 50
    dut.v_idx.value = 10 + 50 + 50
    await FallingEdge(dut.clock)
    print(f"DUT STATE: {dut.state}")
    assert dut.state == 0

    dut.h_idx.value = 10 + 50 + 50 + 50 + 50
    dut.v_idx.value = 10 + 50 + 50 + 50 + 50
    await FallingEdge(dut.clock)
    print(f"DUT STATE: {dut.state}")
    assert dut.state == 0