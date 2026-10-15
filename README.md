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

- **Configurable PHY:** Simulation passed MOSI and MISO checks in all four SPI modes. The PHY received the expected `0x3C` response in each mode and transmitted `0xA5`.
- **Scheduler:** Test passed for sequential selection of three simulated slaves.
- **Top-level integration:** Simulation passed checks for the ordered slave selections and received bytes: slave 0 returned `0x3C`, slave 1 returned `0xA6`, and slave 2 returned `0x5A`.

## Next Steps

- Document additional features as they are implemented and verified.

## License

License not yet specified.
