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

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;

        run_mode(0,0);
        run_mode(0,1);
        run_mode(1,0);
        run_mode(1,1);

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