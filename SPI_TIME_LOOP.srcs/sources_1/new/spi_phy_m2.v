`timescale 1ns/1ps

module spi_phy_m2 #(
    parameter FRAME_BITS = 8,
    parameter BIT_CNT_W  = 7
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [FRAME_BITS-1:0] tx_data,

    input wire cfg_cpol,
    input wire cfg_cpha,
    input wire [15:0] cfg_half_div,
    input wire [7:0] cfg_cs_setup,
    input wire [7:0] cfg_cs_hold,
    input wire [7:0] cfg_cs_gap,

    output reg sclk,
    output reg mosi,
    output reg cs_n,
    input wire miso,

    output wire busy,
    output reg done,
    output reg [FRAME_BITS-1:0] rx_data,
    output reg cfg_clamped,
    output wire [2:0] dbg_state
);

    localparam [2:0]
        IDLE     = 3'd0,
        SETUP    = 3'd1,
        TRANSFER = 3'd2,
        HOLD     = 3'd3,
        GAP      = 3'd4;

    reg [2:0] state;

    reg [FRAME_BITS-1:0] tx_shift, rx_shift;
    reg [BIT_CNT_W-1:0] bit_index;

    reg [15:0] half_count, div_r;
    reg [7:0] phase_count, setup_r, hold_r, gap_r;

    reg cpol_r, cpha_r;
    reg trailing_pending;
    reg last_sampled;

    wire [15:0] div_eff =
        (cfg_half_div == 0) ? 16'd1 : cfg_half_div;

    wire [7:0] setup_eff =
        (cfg_cs_setup == 0) ? 8'd1 : cfg_cs_setup;

    wire [7:0] hold_eff =
        (cfg_cs_hold == 0) ? 8'd1 : cfg_cs_hold;

    wire [7:0] gap_eff =
        (cfg_cs_gap == 0) ? 8'd1 : cfg_cs_gap;

    assign busy = (state != IDLE);
    assign dbg_state = state;

    always @(posedge clk) begin
        if (!rst_n) begin
            state            <= IDLE;
            sclk             <= 1'b0;
            mosi             <= 1'b0;
            cs_n             <= 1'b1;
            done             <= 1'b0;
            rx_data          <= {FRAME_BITS{1'b0}};
            cfg_clamped      <= 1'b0;

            tx_shift         <= {FRAME_BITS{1'b0}};
            rx_shift         <= {FRAME_BITS{1'b0}};
            bit_index        <= 0;

            half_count       <= 0;
            phase_count      <= 0;
            div_r            <= 1;
            setup_r          <= 1;
            hold_r           <= 1;
            gap_r            <= 1;

            cpol_r           <= 0;
            cpha_r           <= 0;
            trailing_pending <= 0;
            last_sampled     <= 0;
        end else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    cs_n <= 1'b1;
                    sclk <= cfg_cpol;
                    mosi <= 1'b0;

                    if (start) begin
                        cpol_r <= cfg_cpol;
                        cpha_r <= cfg_cpha;

                        div_r   <= div_eff;
                        setup_r <= setup_eff;
                        hold_r  <= hold_eff;
                        gap_r   <= gap_eff;

                        cfg_clamped <=
                            (cfg_half_div == 0) ||
                            (cfg_cs_setup == 0) ||
                            (cfg_cs_hold == 0) ||
                            (cfg_cs_gap == 0);

                        tx_shift <= tx_data;
                        rx_shift <= {FRAME_BITS{1'b0}};
                        bit_index <= 0;

                        half_count <= 0;
                        phase_count <= 0;
                        trailing_pending <= 0;
                        last_sampled <= 0;

                        cs_n <= 1'b0;
                        sclk <= cfg_cpol;

                        // CPHA=0: first bit must be ready
                        // before the first leading edge.
                        if (!cfg_cpha)
                            mosi <= tx_data[FRAME_BITS-1];
                        else
                            mosi <= 1'b0;

                        state <= SETUP;
                    end
                end

                SETUP: begin
                    if (phase_count >= setup_r - 1'b1) begin
                        phase_count <= 0;
                        half_count <= 0;
                        trailing_pending <= 0;
                        state <= TRANSFER;
                    end else begin
                        phase_count <= phase_count + 1'b1;
                    end
                end

                TRANSFER: begin
                    if (half_count >= div_r - 1'b1) begin
                        half_count <= 0;

                        if (!trailing_pending) begin
                            // LEADING EDGE: move away from CPOL.
                            sclk <= ~cpol_r;

                            if (!cpha_r) begin
                                // Mode phase 0: sample on leading edge.
                                rx_shift <= {
                                    rx_shift[FRAME_BITS-2:0], miso
                                };

                                if (bit_index == FRAME_BITS-1)
                                    last_sampled <= 1'b1;
                            end else begin
                                // Mode phase 1: prepare data on leading edge.
                                mosi <= tx_shift[FRAME_BITS-1];
                            end

                            trailing_pending <= 1'b1;

                        end else begin
                            // TRAILING EDGE: return to CPOL.
                            sclk <= cpol_r;
                            trailing_pending <= 1'b0;

                            if (!cpha_r) begin
                                // CPHA=0: finish only after the final
                                // sample and its trailing edge.
                                if (last_sampled) begin
                                    phase_count <= 0;
                                    state <= HOLD;
                                end else begin
                                    tx_shift <= {
                                        tx_shift[FRAME_BITS-2:0], 1'b0
                                    };
                                    mosi <= tx_shift[FRAME_BITS-2];
                                    bit_index <= bit_index + 1'b1;
                                end

                            end else begin
                                // CPHA=1: sample on trailing edge.
                                rx_shift <= {
                                    rx_shift[FRAME_BITS-2:0], miso
                                };

                                if (bit_index == FRAME_BITS-1) begin
                                    phase_count <= 0;
                                    state <= HOLD;
                                end else begin
                                    tx_shift <= {
                                        tx_shift[FRAME_BITS-2:0], 1'b0
                                    };
                                    bit_index <= bit_index + 1'b1;
                                end
                            end
                        end

                    end else begin
                        half_count <= half_count + 1'b1;
                    end
                end

                HOLD: begin
                    sclk <= cpol_r;

                    if (phase_count >= hold_r - 1'b1) begin
                        cs_n <= 1'b1;
                        mosi <= 1'b0;
                        rx_data <= rx_shift;
                        done <= 1'b1;
                        phase_count <= 0;
                        state <= GAP;
                    end else begin
                        phase_count <= phase_count + 1'b1;
                    end
                end

                GAP: begin
                    if (phase_count >= gap_r - 1'b1) begin
                        phase_count <= 0;
                        state <= IDLE;
                    end else begin
                        phase_count <= phase_count + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                    sclk <= cpol_r;
                    mosi <= 1'b0;
                    cs_n <= 1'b1;
                    phase_count <= 0;
                    half_count <= 0;
                    trailing_pending <= 0;
                    last_sampled <= 0;
                end

            endcase
        end
    end

endmodule