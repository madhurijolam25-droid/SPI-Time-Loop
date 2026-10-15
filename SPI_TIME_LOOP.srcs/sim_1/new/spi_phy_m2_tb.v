`timescale 1ns/1ps

module spi_phy_m2_tb;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;
    reg start = 0;
    reg [7:0] tx_data = 8'hA5;
    reg cpol = 0;
    reg cpha = 0;

    reg [15:0] half_div = 2;
    reg [7:0] cs_setup = 2;
    reg [7:0] cs_hold = 2;
    reg [7:0] cs_gap = 2;

    wire sclk, mosi, cs_n, busy, done, cfg_clamped;
    wire [7:0] rx_data;
    wire [2:0] dbg_state;
    wire miso;

    integer errors = 0;
    integer timeout_count = 0;
    integer mosi_bits = 0;

    reg [7:0] mosi_received = 0;
    reg prev_sclk = 0;

    spi_phy_m2 #(
        .FRAME_BITS(8),
        .BIT_CNT_W(7)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .cfg_cpol(cpol),
        .cfg_cpha(cpha),
        .cfg_half_div(half_div),
        .cfg_cs_setup(cs_setup),
        .cfg_cs_hold(cs_hold),
        .cfg_cs_gap(cs_gap),
        .sclk(sclk),
        .mosi(mosi),
        .cs_n(cs_n),
        .miso(miso),
        .busy(busy),
        .done(done),
        .rx_data(rx_data),
        .cfg_clamped(cfg_clamped),
        .dbg_state(dbg_state)
    );

    spi_slave_mode_model #(
        .FRAME_BITS(8),
        .RESPONSE(8'h3C)
    ) slave (
        .sclk(sclk),
        .cs_n(cs_n),
        .cpol(cpol),
        .cpha(cpha),
        .mosi(mosi),
        .miso(miso)
    );

    // Sample after SCLK has settled, away from the DUT's
    // posedge-clock nonblocking assignments.
    always @(negedge clk) begin
        if (!rst_n) begin
            prev_sclk = sclk;
        end else begin
            if (!cs_n && (sclk != prev_sclk)) begin
                if ((!cpha && (sclk != cpol)) ||
                    ( cpha && (sclk == cpol))) begin
                    mosi_received =
                        {mosi_received[6:0], mosi};
                    mosi_bits = mosi_bits + 1;
                end
            end

            prev_sclk = sclk;
        end
    end

    task run_mode;
        input cp;
        input ch;
        begin
            @(negedge clk);
            cpol = cp;
            cpha = ch;
            tx_data = 8'hA5;
            mosi_received = 0;
            mosi_bits = 0;
            prev_sclk = sclk;

            repeat (3) @(negedge clk);

            start = 1;
            @(negedge clk);
            start = 0;

            timeout_count = 0;
            while ((done !== 1'b1) &&
                   (timeout_count < 500)) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (done !== 1'b1) begin
                $display(
                    "FAIL CPOL=%0d CPHA=%0d TIMEOUT",
                    cp, ch
                );
                errors = errors + 1;
            end else begin
                if (rx_data !== 8'h3C) begin
                    $display(
                        "FAIL RX CPOL=%0d CPHA=%0d RX=%02h EXPECTED=3C",
                        cp, ch, rx_data
                    );
                    errors = errors + 1;
                end else begin
                    $display(
                        "PASS RX CPOL=%0d CPHA=%0d RX=%02h",
                        cp, ch, rx_data
                    );
                end

                if ((mosi_bits != 8) ||
                    (mosi_received !== 8'hA5)) begin
                    $display(
                        "FAIL MOSI CPOL=%0d CPHA=%0d TX=%02h BITS=%0d EXPECTED=A5",
                        cp, ch, mosi_received, mosi_bits
                    );
                    errors = errors + 1;
                end else begin
                    $display(
                        "PASS MOSI CPOL=%0d CPHA=%0d TX=%02h",
                        cp, ch, mosi_received
                    );
                end
            end

            while (busy) @(negedge clk);
            repeat (3) @(negedge clk);
        end
    endtask

    task test_zero_timing_config;
        begin
            @(negedge clk);
            cpol = 0;
            cpha = 0;
            half_div = 0;
            cs_setup = 0;
            cs_hold = 0;
            cs_gap = 0;
            tx_data = 8'hA5;

            repeat (3) @(negedge clk);

            start = 1;
            @(negedge clk);
            start = 0;

            if (cfg_clamped !== 1'b1) begin
                $display("FAIL: zero timing configuration was not flagged");
                errors = errors + 1;
            end

            timeout_count = 0;
            while ((done !== 1'b1) && (timeout_count < 500)) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: zero timing configuration timed out");
                errors = errors + 1;
            end else if (rx_data !== 8'h3C) begin
                $display("FAIL: zero timing configuration RX=%02h, expected 3C",
                         rx_data);
                errors = errors + 1;
            end else begin
                $display("PASS: zero timing configuration clamped; RX=3C");
            end

            while (busy) @(negedge clk);
            repeat (3) @(negedge clk);
        end
    endtask

    task test_nonzero_timing_config;
        time cs_assert_time;
        time first_edge_time;
        time previous_edge_time;
        time current_edge_time;
        time last_edge_time;
        time cs_deassert_time;
        time next_cs_assert_time;
        integer edge_index;
        begin
            @(negedge clk);
            cpol = 0;
            cpha = 0;
            half_div = 3;
            cs_setup = 4;
            cs_hold = 3;
            cs_gap = 5;
            tx_data = 8'hA5;

            repeat (3) @(negedge clk);

            start = 1;
            @(negedge clk);
            start = 0;

            @(negedge cs_n);
            cs_assert_time = $time;
            @(sclk);
            first_edge_time = $time;

            if ((first_edge_time - cs_assert_time) < (cs_setup * 10)) begin
                $display("FAIL: CS setup interval was shorter than configured");
                errors = errors + 1;
            end
            if (cfg_clamped !== 1'b0) begin
                $display("FAIL: nonzero timing configuration reported clamped");
                errors = errors + 1;
            end

            previous_edge_time = first_edge_time;
            last_edge_time = first_edge_time;
            for (edge_index = 1; edge_index < 16;
                 edge_index = edge_index + 1) begin
                @(sclk);
                current_edge_time = $time;
                if ((current_edge_time - previous_edge_time) !=
                    (half_div * 10)) begin
                    $display("FAIL: SCLK half-period=%0t ns, expected %0t ns",
                             current_edge_time - previous_edge_time,
                             half_div * 10);
                    errors = errors + 1;
                end
                previous_edge_time = current_edge_time;
                last_edge_time = current_edge_time;
            end

            @(posedge cs_n);
            cs_deassert_time = $time;
            if ((cs_deassert_time - last_edge_time) < (cs_hold * 10)) begin
                $display("FAIL: CS hold interval was shorter than configured");
                errors = errors + 1;
            end
            if (rx_data !== 8'h3C) begin
                $display("FAIL: timed transfer RX=%02h, expected 3C", rx_data);
                errors = errors + 1;
            end

            start = 1;
            @(negedge cs_n);
            next_cs_assert_time = $time;
            start = 0;

            if ((next_cs_assert_time - cs_deassert_time) < (cs_gap * 10)) begin
                $display("FAIL: CS gap interval was shorter than configured");
                errors = errors + 1;
            end

            timeout_count = 0;
            while ((done !== 1'b1) && (timeout_count < 500)) begin
                @(negedge clk);
                timeout_count = timeout_count + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: second timed transfer timed out");
                errors = errors + 1;
            end else if (rx_data !== 8'h3C) begin
                $display("FAIL: second timed transfer RX=%02h, expected 3C",
                         rx_data);
                errors = errors + 1;
            end

            while (busy) @(negedge clk);
            repeat (3) @(negedge clk);
            half_div = 2;
            cs_setup = 2;
            cs_hold = 2;
            cs_gap = 2;
            $display("Completed nonzero divider and CS timing checks");
        end
    endtask

    task test_reset_during_transfer;
        begin
            @(negedge clk);
            cpol = 0;
            cpha = 0;
            half_div = 2;
            cs_setup = 2;
            cs_hold = 2;
            cs_gap = 2;

            repeat (3) @(negedge clk);

            start = 1;
            @(negedge clk);
            start = 0;

            while (cs_n !== 1'b0) @(negedge clk);
            repeat (3) @(negedge clk);
            rst_n = 0;
            @(negedge clk);

            if ((busy !== 1'b0) || (cs_n !== 1'b1) ||
                (done !== 1'b0) || (rx_data !== 8'h00)) begin
                $display("FAIL: reset did not abort and clear the PHY transaction");
                errors = errors + 1;
            end else begin
                $display("PASS: reset aborted the active PHY transaction");
            end

            rst_n = 1;
            repeat (3) @(negedge clk);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;

        run_mode(0,0);
        run_mode(0,1);
        run_mode(1,0);
        run_mode(1,1);
        test_zero_timing_config();
        test_nonzero_timing_config();
        test_reset_during_transfer();

        if (errors == 0)
            $display("OVERALL: PASS");
        else
            $display("OVERALL: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #100000;
        $display("GLOBAL TIMEOUT");
        $finish;
    end

endmodule