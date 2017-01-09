//*********************************************************************************************************************
//
//
// This copy of the Source Code is intended for j2k_group's internal use only and is
// intended for view by persons duly authorized by the management of j2k_group. No
// part of this file may be reproduced or distributed in any form or by any
// means without the written approval of the Management of j2k_group.
//

//
// ********************************************************************************************************************
//
// PROJECT      : j2K_encoder  
// PRODUCT      : j2K_encoder  
// FILE         :   
// AUTHOR       : sajith vishwaranga  
// DESCRIPTION  :   
//
//
// ********************************************************************************************************************
//
// REVISIONS:
//
//  Date        Developer       Description
//  ----        ---------       -----------
//  
//
// ********************************************************************************************************************

`timescale 1ns / 1ps

module hdr_make
#(
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter               DATA_W          =   128,
    parameter               KEEP_W          =   DATA_W/8,

    parameter               ZERO_DATA_W     =   5,
    parameter               PASS_DATA_W     =   32,
    parameter               LENGTH_DATA_W   =   32                   
)
(
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                       clk,
    input                                       rst_n,

    output reg                                  m_axis_hdr_tx_valid_o,
    output reg                                  m_axis_hdr_tx_last_o,
    output reg              [DATA_W-1:0]        m_axis_hdr_tx_data_o,
    output reg              [KEEP_W-1:0]        m_axis_hdr_tx_keep_o,
    input                                       m_axis_hdr_tx_ready_i,

    input                                       s_axis_pass_rx_valid_i,
    input                                       s_axis_pass_rx_last_i,
    input                   [PASS_DATA_W-1:0]   s_axis_pass_rx_data_i,
    output reg                                  s_axis_pass_rx_reday_o,

    input                                       s_axis_lenght_rx_valid_i,
    input                                       s_axis_lenght_rx_last_i,
    input                   [LENGTH_DATA_W-1:0] s_axis_lenght_rx_data_i,
    output reg                                  s_axis_lenght_rx_reday_o,

    input                                       s_axis_zero_rx_valid_i,
    input                                       s_axis_zero_rx_last_i,
    input                   [ZERO_DATA_W-1:0]   s_axis_zero_rx_data_i,
    output reg                                  s_axis_zero_rx_reday_o

);

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam          NO_OF_FILL_STATES       = 4;
    localparam          NO_OF_TAG_STATES        = 4;

    localparam          Y_W                     = 4;
    localparam          X_W                     = 4;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg                 [NO_OF_FILL_STATES-1:0]     state_fill;
    reg                 []

    reg                                             zero_reg_1;
    reg                 [ZERO_DATA_W-1:0]           zero_reg_2            [1:0][1:0];
    reg                 [ZERO_DATA_W-1:0]           zero_reg_3            [3:0][3:0];
    reg                 [ZERO_DATA_W-1:0]           zero_reg_4            [7:0][70];

    reg                 [Y_W-1:0]                   y;
    reg                 [X_W-1:0]                   x;

    wire                [Y_W-1:0]                   row_cnt;
    wire                [Y_W-1:0]                   colum_cnt;

    wire                
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
assign row_cnt      = 3;
assign colum_cnt    = 3;

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        state_fill                              <= STATE_FILL_INIT;
    end else begin
        case(state_fill)  : begin
            STATE_FILL_INIT  :   begin
                if(s_axis_zero_rx_valid_i) begin
                    state_fill                  <= STATE_FILL_ROW; 
                end
            end
            STATE_FILL_ROW  :   begin
                if(!s_axis_zero_rx_valid_i) begin
                    state_fill                  <= STATE_FILL_IDLE;

                    s_axis_zero_rx_reday_o      <= 1'b0;       
                end
                else 
                    if((y == row_cnt) &&  (x == colum_cnt)) begin
                        state_fill              <= STATE_FILL_END;

                        y                       <= {Y_W}1'b0;
                        x                       <= {X_W}1'b0;
                    end
                    else if(x == colum_cnt) begin
                        y                       <= y + 1'b1;
                        x                       <= {X_W}1'b0;
                    end
                    else
                        x                       <= x + 1'b1;
                    end
                    zero_reg_4[y][x]            <= s_axis_zero_rx_data_i;

                    s_axis_zero_rx_reday_o      <= 1'b1;
                end
            end
            STATE_FILL_IDLE :   begin
                if(s_axis_zero_rx_valid_i) begin
                    state_fill                  <= STATE_FILL_ROW;
                end
            end
            STATE_FILL_END  :   begin
                if(!hdr_maker_busy) begin
                    state_fill                  <= STATE_FILL_INIT;

                    filed_flag                  <= 1'b1;
                end
                s_axis_zero_rx_reday_o          <= 1'b0;
            end
        endcase    
    end
end

genvar x,y;
generate
    for (y = 0; y < 8; y = y +2) begin
        for (x = 0; x < 8; x = x +2) begin
            wire [ZERO_DATA_W-1:0] a,b,c;

            assign a = (zero_reg_4[y][x] <zero_reg_4[y][x+1]) ? zero_reg_4[y][x+1] : zero_reg_4[y][x]; 
            assign b = (zero_reg_4[y+1][x] <zero_reg_4[y+1][x+1]) ? zero_reg_4[y+1][x+1] : zero_reg_4[y+1][x];
            assign c = (a<b) ? b:a;

            always @(posedge clk or negedge rst_n) begin
                if(~rst_n) begin
                     <= 0;
                end
                else begin
                    if(filed_flag) begin
                        zero_reg_3[y>>1][x<<1]  <= c;   
                    end
                end
            end
        end
    end
endgenerate

genvar x,y;
generate
    for (y = 0; y < 4; y = y +2) begin
        for (x = 0; x < 4; x = x +2) begin
            wire [ZERO_DATA_W-1:0] a,b,c;

            assign a = (zero_reg_3[y][x] <zero_reg_3[y][x+1]) ? zero_reg_3[y][x+1] : zero_reg_3[y][x]; 
            assign b = (zero_reg_3[y+1][x] <zero_reg_3[y+1][x+1]) ? zero_reg_3[y+1][x+1] : zero_reg_3[y+1][x];
            assign c = (a<b) ? b:a;

            always @(posedge clk or negedge rst_n) begin
                if(~rst_n) begin
                     <= 0;
                end
                else begin
                    if(filed_flag) begin
                        zero_reg_2[y>>1][x<<1]  <= c;   
                    end
                end
            end
        end
    end
endgenerate


wire [ZERO_DATA_W-1:0] a,b,c;

assign a = (zero_reg_2[0][0] <zero_reg_2[0][1]) ? zero_reg_2[0][1] : zero_reg_2[0][0]; 
assign b = (zero_reg_2[1][0] <zero_reg_2[1][1]) ? zero_reg_2[1][1] : zero_reg_2[1][0];
assign c = (a<b) ? b:a;

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
         <= 0;
    end
    else begin
        if(filed_flag) begin
            zero_reg_1  <= c;   
        end
    end
end

endmodule
