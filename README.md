# SPI Time Loop

A Verilog-based SPI communication project developed using Xilinx Vivado 2023.2.

## Overview

SPI Time Loop explores communication between one SPI master and three simulated slave devices. It includes an SPI physical interface, a scheduler, simulated slave models, and testbenches.

## Architecture

- **SPI Master/PHY:** Handles SPI clock, chip-select, MOSI, and MISO.
- **SPI Scheduler:** Sequences transactions across three slave selections.
- **Slave Models:** Simulate slave responses.
- **Testbenches:** Verify PHY behavior, scheduler operation, and top-level integration.

## Tools

- Verilog HDL
- Xilinx Vivado 2023.2
- WSL, Git, and GitHub

## Verification Status

- **Configurable PHY:** Receive tests passed for SPI modes 0, 1, 2, and 3 with test byte `0x3C`.
- **Scheduler:** Test passed for sequential selection of three simulated slaves.
- **Top-level integration:** All three slave selections completed, but the received byte was `0x2D`, not one of the expected slave responses. End-to-end data verification is still required.

## Next Steps

- Verify correct transmit and receive behavior in all SPI modes.
- Confirm each slave returns its expected response.
- Expand integration tests to check data correctness.
- Document additional features as they are implemented and verified.

## License

License not yet specified.
