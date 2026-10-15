`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 16:46:29
// Design Name: 
// Module Name: spi_scheduler_tb
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

module spi_scheduler_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg enable = 0;
    reg phy_busy = 0;
    reg phy_done = 0;

    wire phy_start;
    wire [1:0] slave_sel;
    wire scheduler_done;
    wire scheduler_busy;

    integer errors = 0;
    integer completed = 0;
    integer timeout_count;

    spi_scheduler dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .phy_busy(phy_busy),
        .phy_done(phy_done),
        .phy_start(phy_start),
        .slave_sel(slave_sel),
        .scheduler_done(scheduler_done),
        .scheduler_busy(scheduler_busy)
    );

    // Simulate the PHY completing each requested transaction.
    always @(posedge clk) begin
        if (!rst_n) begin
            phy_busy <= 0;
            phy_done <= 0;
        end else begin
            phy_done <= 0;

            if (phy_start && !phy_busy) begin
                phy_busy <= 1;
            end else if (phy_busy) begin
                phy_busy <= 0;
                phy_done <= 1;
                completed <= completed + 1;
                $display("PHY transaction completed for slave %0d",
                         slave_sel);
            end
        end
    end

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;

        @(negedge clk);
        enable = 1;

        @(negedge clk);
        enable = 0;

        timeout_count = 0;
        while ((scheduler_done !== 1'b1) &&
               (timeout_count < 100)) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        if (scheduler_done !== 1'b1) begin
            $display("FAIL: scheduler timeout");
            errors = errors + 1;
        end

        if (completed != 3) begin
            $display("FAIL: expected 3 transactions, got %0d",
                     completed);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("SCHEDULER TEST: PASS");
        else
            $display("SCHEDULER TEST: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #5000;
        $display("GLOBAL TIMEOUT");
        $finish;
    end

endmodule
