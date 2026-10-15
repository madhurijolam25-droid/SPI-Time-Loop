`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.10.2026 16:44:25
// Design Name: 
// Module Name: spi_scheduler
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

module spi_scheduler (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,

    input  wire       phy_busy,
    input  wire       phy_done,

    output reg        phy_start,
    output reg [1:0]  slave_sel,
    output reg        scheduler_done,
    output wire       scheduler_busy
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam WAIT  = 2'd2;
    localparam DONE  = 2'd3;

    reg [1:0] state;

    assign scheduler_busy = (state != IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= IDLE;
            phy_start     <= 1'b0;
            slave_sel     <= 2'd0;
            scheduler_done <= 1'b0;
        end else begin
            phy_start      <= 1'b0;
            scheduler_done <= 1'b0;

            case (state)
                IDLE: begin
                    if (enable) begin
                        slave_sel <= 2'd0;
                        state <= START;
                    end
                end

                START: begin
                    if (!phy_busy) begin
                        phy_start <= 1'b1;
                        state <= WAIT;
                    end
                end

                WAIT: begin
                    if (phy_done) begin
                        if (slave_sel < 2'd2) begin
                            slave_sel <= slave_sel + 1'b1;
                            state <= START;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    scheduler_done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
