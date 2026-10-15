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
    integer transaction_count = 0;

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

    always @(posedge clk) begin
        if (rst_n && dut.phy_done) begin
            case (transaction_count)
                0: begin
                    if (slave_sel !== 2'd0) begin
                        $display("FAIL: transaction 0 selected slave %0d, expected 0",
                                 slave_sel);
                        errors = errors + 1;
                    end
                    if (rx_data !== 8'h3C) begin
                        $display("FAIL: slave 0 RX=%02h, expected 3C", rx_data);
                        errors = errors + 1;
                    end
                end

                1: begin
                    if (slave_sel !== 2'd1) begin
                        $display("FAIL: transaction 1 selected slave %0d, expected 1",
                                 slave_sel);
                        errors = errors + 1;
                    end
                    if (rx_data !== 8'hA6) begin
                        $display("FAIL: slave 1 RX=%02h, expected A6", rx_data);
                        errors = errors + 1;
                    end
                end

                2: begin
                    if (slave_sel !== 2'd2) begin
                        $display("FAIL: transaction 2 selected slave %0d, expected 2",
                                 slave_sel);
                        errors = errors + 1;
                    end
                    if (rx_data !== 8'h5A) begin
                        $display("FAIL: slave 2 RX=%02h, expected 5A", rx_data);
                        errors = errors + 1;
                    end
                end

                default: begin
                    $display("FAIL: unexpected extra PHY transaction");
                    errors = errors + 1;
                end
            endcase

            transaction_count = transaction_count + 1;
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
               (timeout_count < 1000)) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        if (scheduler_done !== 1'b1) begin
            $display("FAIL: integration timeout");
            errors = errors + 1;
        end else begin
            if (transaction_count != 3) begin
                $display("FAIL: observed %0d PHY transactions, expected 3",
                         transaction_count);
                errors = errors + 1;
            end

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
