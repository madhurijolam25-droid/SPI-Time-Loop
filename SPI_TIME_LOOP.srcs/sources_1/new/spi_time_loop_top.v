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




module spi_time_loop_top #(
    parameter [7:0] GAS_RESPONSE = 8'h30,
    parameter [7:0] TEMPERATURE_RESPONSE = 8'h30,
    parameter [7:0] WORKER_STATUS_RESPONSE = 8'h01
) (
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
    output wire       scheduler_done,
    output reg  [7:0] gas_reading,
    output reg  [7:0] temperature_reading,
    output reg  [7:0] worker_status,
    output reg        worker_distress,
    output reg        rescue_alert
);

    wire phy_start;
    wire phy_busy;
    wire phy_done;
    wire phy_miso;
    wire [2:0] dbg_state;
    wire cfg_clamped;

    wire miso0, miso1, miso2;

    localparam [7:0] GAS_WARNING_LEVEL = 8'h40;
    localparam [7:0] TEMPERATURE_WARNING_LEVEL = 8'h40;

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

    // Simulated gas sensor; its 8-bit reading is set by a module parameter.
    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(GAS_RESPONSE)
    ) slave0 (
        .sclk(sclk),
        .cs_n(slave_cs_n[0]),
        .cpol(cfg_cpol),
        .cpha(cfg_cpha),
        .mosi(mosi),
        .miso(miso0)
    );

    // Simulated temperature sensor; its reading is set by a module parameter.
    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(TEMPERATURE_RESPONSE)
    ) slave1 (
        .sclk(sclk),
        .cs_n(slave_cs_n[1]),
        .cpol(cfg_cpol),
        .cpha(cfg_cpha),
        .mosi(mosi),
        .miso(miso1)
    );

    // Simulated worker-status device; 8'h01 means OK in this demo.
    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(WORKER_STATUS_RESPONSE)
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

    always @(posedge clk) begin
        if (!rst_n) begin
            gas_reading <= 8'h00;
            temperature_reading <= 8'h00;
            worker_status <= 8'h01;
            worker_distress <= 1'b0;
            rescue_alert <= 1'b0;
        end else if (phy_done) begin
            case (slave_sel)
                2'd0: begin
                    gas_reading <= rx_data;
                    if (rx_data >= GAS_WARNING_LEVEL)
                        rescue_alert <= 1'b1;
                end
                2'd1: begin
                    temperature_reading <= rx_data;
                    if (rx_data >= TEMPERATURE_WARNING_LEVEL)
                        rescue_alert <= 1'b1;
                end
                2'd2: begin
                    worker_status <= rx_data;
                    worker_distress <= (rx_data != 8'h01);
                    if (rx_data != 8'h01)
                        rescue_alert <= 1'b1;
                end
                default: rescue_alert <= 1'b1;
            endcase
        end
    end

    assign done = scheduler_done;

endmodule
