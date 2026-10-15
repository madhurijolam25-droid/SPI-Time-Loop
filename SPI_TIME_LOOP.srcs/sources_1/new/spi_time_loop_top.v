`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 17:03:54
// Design Name: 
// Module Name: spi_time_loop_top
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




module spi_time_loop_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,
    input  wire       cfg_cpol,
    input  wire       cfg_cpha,

    output wire       sclk,
    output wire       mosi,
    output wire [2:0] slave_cs_n,
    output wire [1:0] slave_sel,
    output wire       busy,
    output wire       done,
    output wire [7:0] rx_data,
    output wire       scheduler_done
);

    wire phy_start;
    wire phy_busy;
    wire phy_done;
    wire phy_miso;
    wire [2:0] dbg_state;
    wire cfg_clamped;

    wire miso0, miso1, miso2;

    // Scheduler: sequentially selects three slaves.
    spi_scheduler scheduler (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .phy_busy(phy_busy),
        .phy_done(phy_done),
        .phy_start(phy_start),
        .slave_sel(slave_sel),
        .scheduler_done(scheduler_done),
        .scheduler_busy(busy)
    );

    // One shared SPI master PHY.
    spi_phy_m2 #(
        .FRAME_BITS(8),
        .BIT_CNT_W(7)
    ) master (
        .clk(clk),
        .rst_n(rst_n),
        .start(phy_start),
        .tx_data(8'hA5),
        .cfg_cpol(cfg_cpol),
        .cfg_cpha(cfg_cpha),
        .cfg_half_div(16'd2),
        .cfg_cs_setup(8'd2),
        .cfg_cs_hold(8'd2),
        .cfg_cs_gap(8'd2),
        .sclk(sclk),
        .mosi(mosi),
       .cs_n(master_cs_n),
        .miso(phy_miso),
        .busy(phy_busy),
        .done(phy_done),
        .rx_data(rx_data),
        .cfg_clamped(cfg_clamped),
        .dbg_state(dbg_state)
    );
 wire master_cs_n;
    // Decode the selected slave into active-low chip selects.
    assign slave_cs_n[0] = master_cs_n | (slave_sel != 2'd0);
    assign slave_cs_n[1] = master_cs_n | (slave_sel != 2'd1);
    assign slave_cs_n[2] = master_cs_n | (slave_sel != 2'd2);

   

    // Connect the PHY's internal chip-select to the routing logic.
    // The PHY drives this signal directly.
    // See the connection note below before compiling.

    // Simulated slave 0.
    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(8'h3C)
    ) slave0 (
        .sclk(sclk),
        .cs_n(slave_cs_n[0]),
        .cpol(cfg_cpol),
        .cpha(cfg_cpha),
        .mosi(mosi),
        .miso(miso0)
    );

    // Simulated slave 1.
    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(8'hA6)
    ) slave1 (
        .sclk(sclk),
        .cs_n(slave_cs_n[1]),
        .cpol(cfg_cpol),
        .cpha(cfg_cpha),
        .mosi(mosi),
        .miso(miso1)
    );

    // Simulated slave 2.
    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(8'h5A)
    ) slave2 (
        .sclk(sclk),
        .cs_n(slave_cs_n[2]),
        .cpol(cfg_cpol),
        .cpha(cfg_cpha),
        .mosi(mosi),
        .miso(miso2)
    );

    // Route MISO only from the selected slave.
    assign phy_miso =
        (slave_sel == 2'd0) ? miso0 :
        (slave_sel == 2'd1) ? miso1 :
        (slave_sel == 2'd2) ? miso2 : 1'b0;

    assign done = scheduler_done;

endmodule
