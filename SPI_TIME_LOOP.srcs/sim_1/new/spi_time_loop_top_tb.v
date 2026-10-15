`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 17:10:31
// Design Name: 
// Module Name: spi_time_loop_top_tb
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



module spi_time_loop_top_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg enable = 0;
    reg cpol = 0;
    reg cpha = 0;

    wire sclk, mosi;
    wire [2:0] slave_cs_n;
    wire [1:0] slave_sel;
    wire busy, done, scheduler_done;
    wire [7:0] rx_data;

    integer errors = 0;
    integer timeout_count;

    spi_time_loop_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .cfg_cpol(cpol),
        .cfg_cpha(cpha),
        .sclk(sclk),
        .mosi(mosi),
        .slave_cs_n(slave_cs_n),
        .slave_sel(slave_sel),
        .busy(busy),
        .done(done),
        .rx_data(rx_data),
        .scheduler_done(scheduler_done)
    );

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        enable = 1;

        @(negedge clk);
        enable = 0;

        timeout_count = 0;
        while ((scheduler_done !== 1'b1) &&
               (timeout_count < 1000)) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        if (scheduler_done !== 1'b1) begin
            $display("FAIL: integration timeout");
            errors = errors + 1;
        end else begin
            $display("Scheduler completed all three slave selections.");
            $display("Last received byte: %02h", rx_data);
        end

        if (errors == 0)
            $display("INTEGRATION TEST: PASS");
        else
            $display("INTEGRATION TEST: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #50000;
        $display("GLOBAL TIMEOUT");
        $finish;
    end

endmodule
