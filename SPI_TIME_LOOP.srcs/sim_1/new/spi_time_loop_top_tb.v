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
    wire [7:0] gas_reading, temperature_reading, worker_status;
    wire worker_distress, rescue_alert;
    wire gas_hazard_done, temperature_hazard_done, worker_hazard_done;
    wire gas_hazard_alert, temperature_hazard_alert, worker_hazard_alert;
    wire [7:0] gas_hazard_reading, temperature_hazard_reading;
    wire [7:0] worker_hazard_status;
    wire worker_hazard_distress;

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
        .scheduler_done(scheduler_done),
        .gas_reading(gas_reading),
        .temperature_reading(temperature_reading),
        .worker_status(worker_status),
        .worker_distress(worker_distress),
        .rescue_alert(rescue_alert)
    );

    spi_time_loop_top #(
        .GAS_RESPONSE(8'h40),
        .TEMPERATURE_RESPONSE(8'h30),
        .WORKER_STATUS_RESPONSE(8'h01)
    ) gas_hazard_dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .cfg_cpol(cpol), .cfg_cpha(cpha),
        .scheduler_done(gas_hazard_done),
        .gas_reading(gas_hazard_reading),
        .temperature_reading(),
        .worker_distress(),
        .rescue_alert(gas_hazard_alert)
    );

    spi_time_loop_top #(
        .GAS_RESPONSE(8'h30),
        .TEMPERATURE_RESPONSE(8'h40),
        .WORKER_STATUS_RESPONSE(8'h01)
    ) temperature_hazard_dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .cfg_cpol(cpol), .cfg_cpha(cpha),
        .scheduler_done(temperature_hazard_done),
        .gas_reading(),
        .temperature_reading(temperature_hazard_reading),
        .worker_distress(),
        .rescue_alert(temperature_hazard_alert)
    );

    spi_time_loop_top #(
        .GAS_RESPONSE(8'h30),
        .TEMPERATURE_RESPONSE(8'h30),
        .WORKER_STATUS_RESPONSE(8'h00)
    ) worker_hazard_dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .cfg_cpol(cpol), .cfg_cpha(cpha),
        .scheduler_done(worker_hazard_done),
        .gas_reading(),
        .temperature_reading(),
        .worker_status(worker_hazard_status),
        .worker_distress(worker_hazard_distress),
        .rescue_alert(worker_hazard_alert)
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
                    if (rx_data !== 8'h30) begin
                        $display("FAIL: gas sensor RX=%02h, expected 30", rx_data);
                        errors = errors + 1;
                    end
                end

                1: begin
                    if (slave_sel !== 2'd1) begin
                        $display("FAIL: transaction 1 selected slave %0d, expected 1",
                                 slave_sel);
                        errors = errors + 1;
                    end
                    if (rx_data !== 8'h30) begin
                        $display("FAIL: temperature sensor RX=%02h, expected 30",
                                 rx_data);
                        errors = errors + 1;
                    end
                end

                2: begin
                    if (slave_sel !== 2'd2) begin
                        $display("FAIL: transaction 2 selected slave %0d, expected 2",
                                 slave_sel);
                        errors = errors + 1;
                    end
                    if (rx_data !== 8'h01) begin
                        $display("FAIL: worker status RX=%02h, expected 01",
                                 rx_data);
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
        while (((scheduler_done !== 1'b1) ||
                (gas_hazard_done !== 1'b1) ||
                (temperature_hazard_done !== 1'b1) ||
                (worker_hazard_done !== 1'b1)) &&
               (timeout_count < 1000)) begin
            @(negedge clk);
            timeout_count = timeout_count + 1;
        end

        if ((scheduler_done !== 1'b1) ||
            (gas_hazard_done !== 1'b1) ||
            (temperature_hazard_done !== 1'b1) ||
            (worker_hazard_done !== 1'b1)) begin
            $display("FAIL: integration timeout");
            errors = errors + 1;
        end else begin
            if (transaction_count != 3) begin
                $display("FAIL: observed %0d PHY transactions, expected 3",
                         transaction_count);
                errors = errors + 1;
            end

            if ((gas_reading !== 8'h30) ||
                (temperature_reading !== 8'h30) ||
                (worker_status !== 8'h01) ||
                (worker_distress !== 1'b0) ||
                (rescue_alert !== 1'b0)) begin
                $display("FAIL: safe scenario readings or alert state were incorrect");
                errors = errors + 1;
            end

            if ((gas_hazard_alert !== 1'b1) ||
                (gas_hazard_reading !== 8'h40)) begin
                $display("FAIL: gas warning scenario did not raise an alert");
                errors = errors + 1;
            end

            if ((temperature_hazard_alert !== 1'b1) ||
                (temperature_hazard_reading !== 8'h40)) begin
                $display("FAIL: temperature warning scenario did not raise an alert");
                errors = errors + 1;
            end

            if ((worker_hazard_alert !== 1'b1) ||
                (worker_hazard_status !== 8'h00) ||
                (worker_hazard_distress !== 1'b1)) begin
                $display("FAIL: worker distress scenario did not raise an alert");
                errors = errors + 1;
            end

            $display("Mine scenario completed: gas=%02h temperature=%02h worker_distress=%0d alert=%0d",
                     gas_reading, temperature_reading, worker_distress,
                     rescue_alert);
            $display("Gas, temperature, and worker-distress alert scenarios checked.");

            @(negedge clk);
            rst_n = 0;
            @(negedge clk);
            if ((rescue_alert !== 1'b0) ||
                (gas_hazard_alert !== 1'b0) ||
                (temperature_hazard_alert !== 1'b0) ||
                (worker_hazard_alert !== 1'b0)) begin
                $display("FAIL: reset did not clear the rescue alerts");
                errors = errors + 1;
            end else begin
                $display("PASS: reset cleared the rescue alerts");
            end
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
