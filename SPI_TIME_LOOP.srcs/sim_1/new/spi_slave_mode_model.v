`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 16:15:06
// Design Name: 
// Module Name: spi_slave_mode_model
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns/1ps

module spi_slave_mode_model #(
    parameter FRAME_BITS = 8,
    parameter [FRAME_BITS-1:0] RESPONSE = 8'h3C
)(
    input wire sclk,
    input wire cs_n,
    input wire cpol,
    input wire cpha,
    input wire mosi,
    output reg miso
);

    reg [FRAME_BITS-1:0] tx_shift;
    reg [FRAME_BITS-1:0] rx_shift;
    integer bit_count;

    initial begin
        miso = 1'b0;
        tx_shift = RESPONSE;
        rx_shift = {FRAME_BITS{1'b0}};
        bit_count = 0;
    end

    // Reset the response at the beginning of each selected frame.
    always @(negedge cs_n) begin
        tx_shift = RESPONSE;
        rx_shift = {FRAME_BITS{1'b0}};
        bit_count = 0;

        // CPHA=0: first response bit is ready before first sample edge.
        if (!cpha)
            miso = RESPONSE[FRAME_BITS-1];
        else
            miso = 1'b0;
    end

    // SPI sampling and shifting edges depend on CPOL and CPHA.
    always @(sclk) begin
        if (!cs_n) begin
            if ((!cpha && (sclk != cpol)) ||
                ( cpha && (sclk == cpol))) begin

                // Sampling edge: collect MOSI.
                rx_shift = {rx_shift[FRAME_BITS-2:0], mosi};
                bit_count = bit_count + 1;

            end else begin

                // Data-changing edge: advance the slave response.
                if (bit_count < FRAME_BITS) begin
                    if (!cpha) begin
                        tx_shift = {
                            tx_shift[FRAME_BITS-2:0], 1'b0
                        };
                        miso = tx_shift[FRAME_BITS-1];
                    end else begin
                        miso = tx_shift[FRAME_BITS-1];
                        tx_shift = {
                            tx_shift[FRAME_BITS-2:0], 1'b0
                        };
                    end
                end
            end
        end
    end

endmodule
