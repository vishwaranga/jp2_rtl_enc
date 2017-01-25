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
    parameter               PASS_DATA_W     =   9,
    parameter               LENGTH_DATA_W   =   32,
    parameter               BIT_CNT_W       =   6,
    parameter               HDR_DATA_W      =   32                  
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
    output reg                                  s_axis_zero_rx_reday_o,

    output reg                                  valid_o,
    output reg                                  hdr_last_o,
    output reg                                  insert_zero_o,
    output reg                                  insert_ones_o,
    output reg              [BIT_CNT_W-1:0]     bit_cnt_o,
    output reg              [HDR_DATA_W-1:0]    hdr_data_o,
);  input                                       hdr_ready_i,

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------
    `include "functions_inc.v"
//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam          NO_OF_FILL_STATES       = 4;
    localparam          NO_OF_HDR_STATES        = 4;

    localparam          Y_W                     = 4;
    localparam          X_W                     = 4;
    localparam          TMP_W                   = 4;
    localparam          BITS_W                  = 6;
    localparam          PKT_INDEX_W             = 2;
    localparam          SB_CNT_W                = 2;
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg                 [NO_OF_FILL_STATES-1:0]     state_fill;
    reg                 [NO_OF_HDR_STATES-1:0]      state_hdr;

    reg                                             zero_reg_1;
    reg                 [ZERO_DATA_W-1:0]           zero_reg_2;            [1:0][1:0];
    reg                 [ZERO_DATA_W-1:0]           zero_reg_3;            [3:0][3:0];
    reg                 [ZERO_DATA_W-1:0]           zero_reg_4;            [7:0][70];

    reg                 [Y_W-1:0]                   cb_y,y;
    reg                 [X_W-1:0]                   cb_x,x;

    wire                [Y_W-1:0]                   y_limit;
    wire                [Y_W-1:0]                   x_limit;

    reg                 [BITS_W-1:0]                lblock;
    reg                 [BITS_W-1:0]                bits;
    reg                 [BITS_W-1:0]                bits_pass;
    reg                 [PKT_INDEX_W-1:0]           pkt_index;
    reg                 [SB_CNT_W-1:0]              sb_cnt;

    reg                                             hdr_maker_busy;
                                              
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
assign y_limit      = 7;
assign x_limit      = 7;

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        state_fill                              <= STATE_FILL_INIT;
    end else begin
        case(state_fill)  : begin
            STATE_FILL_INIT  :   begin
                if(s_axis_zero_rx_valid_i && (!hdr_maker_busy)) begin
                    state_fill                  <= STATE_FILL_ROW; 
                end

                filed_flag                      <= 1'b0;
            end
            STATE_FILL_ROW  :   begin
                if(!s_axis_zero_rx_valid_i) begin
                    state_fill                  <= STATE_FILL_IDLE;

                    s_axis_zero_rx_reday_o      <= 1'b0;       
                end
                else 
                    if((y == y_limit) &&  (x == x_limit)) begin
                        state_fill              <= STATE_FILL_END;

                        y                       <= {Y_W}1'b0;
                        x                       <= {X_W}1'b0;
                    end
                    else if(x == x_limit) begin
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
                    if(filed_flag_3) begin
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
                    if(filed_flag_2) begin
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
        if(filed_flag_1) begin
            zero_reg_1  <= c;   
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        filed_flag_0                            <= 1'b0;
        filed_flag_1                            <= 1'b0;
        filed_flag_2                            <= 1'b0;
        filed_flag_3                            <= 1'b0;
    end 
    else begin
        if(filed_flag) begin
            filed_flag_3                        <= 1'b1;
        end
        else if(filed_flag_3) begin
            filed_flag_2                        <= 1'b1;
            filed_flag_3                        <= 1'b0;
        end
        else if(filed_flag_2) begin
            filed_flag_1                        <= 1'b1;
            filed_flag_2                        <= 1'b0;
        end
        else if(filed_flag_1 && (!hdr_maker_busy)) begin
            filed_flag_0                        <= 1'b1;
            filed_flag_1                        <= 1'b0;
        end
        else if(filed_flag_0 && hdr_maker_busy) begin
            filed_flag_0                        <= 1'b0;
        end
    end
end
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
         <= 0;
    end
    else begin
        case (state_hdr) begin
            STATE_HDR_INIT_TILE : begin
                state_hdr                       <= STATE_HDR_INIT_PKT;

                pkt_index                       <= PKT_INDEX_W{1'b0};

                valid_o                         <= 1'b0;
                insert_zero_o                   <= 1'b0;
                insert_ones_o                   <= 1'b0;
                hdr_maker_busy                  <= 1'b0;
            end
            STATE_HDR_INIT_PKT :    begin
                if(filed_flag_0) begin
                    state_hdr                   <= STATE_HDR_PKT_INDEX;

                    hdr_data_o                  <= 32'hff910004;
                    valid_o                     <= 1'b1;
                    bit_cnt_o                   <= 6'd32;

                    hdr_maker_busy              <= 1'b1;

                    sb_cnt                      <= SB_CNT_W{1'b0};
                    cb_y                        <= Y_W{1'b0};
                    cb_x                        <= X_W{1'b0};     
                end
                else begin
                    hdr_maker_busy              <= 1'b0;
                end
            end
            STATE_HDR_PKT_INDEX : begin
                if(hdr_ready_i) begin
                    state_hdr                   <= STATE_HDR_CHECK_ZERO;

                    hdr_data_o                  <= pkt_index;
                    valid_o                     <= 1'b1;
                    bit_cnt_o                   <= 6'd16; 
                end
            end
            STATE_HDR_CHECK_ZERO : begin
                if(s_axis_pass_rx_valid_i && (hdr_ready_i || !valid_o)) begin
                    if(s_axis_pass_rx_data_i == 0) begin
                        state_hdr               <= STATE_HDR_LAST;

                        hdr_data_o              <= HDR_DATA_W{1'b0};
                        valid_o                 <= 1'b1;
                        bit_cnt_o               <= 6'd16;
                        hdr_last_o              <= 1'b1;
                    end
                    else begin
                        state_hdr               <= STATE_HDR_CODE_BLOCK;

                        hdr_data_o              <= {8'h00,1'b1,15'd0,16'hff92};
                        valid_o                 <= 1'b1;
                        bit_cnt_o               <= 6'd32;
                    end
                end
                else if(!s_axis_pass_rx_valid_i)begin
                    valid_o                     <= 1'b0;
                end
            end
            STATE_HDR_CODE_BLOCK : begin
                if(hdr_ready_i || (!valid_o)) begin
                    if((cb_y == 0 )&& (cb_x == 0)) begin
                        state_hdr               <= STATE_HDR_ZERO_1;

                        hdr_data_o              <= {28'd0,4'b1111};
                        valid_o                 <= 1'b1;
                        bit_cnt_o               <= 6'd4;
                    end
                    else begin
                        if((cb_y>>2)==0 && (cb_x>>2) == 0) begin
                            state_hdr           <= STATE_HDR_ZERO_2;

                            hdr_data_o          <= {29'd0,3'b111};
                            valid_o             <= 1'b1;
                            bit_cnt_o           <= 6'd3;
                        end
                        else if((cb_y>>1) == 0 && (cb_x>>1) == 0) begin
                            state_hdr           <= STATE_HDR_ZERO_3;

                            hdr_data_o          <= {30'd0,2'b11};
                            valid_o             <= 1'b1;
                            bit_cnt_o           <= 6'd2;
                        end
                        else begin
                            state_hdr           <= STATE_HDR_ZERO_4;

                            hdr_data_o          <= {31'd0,1'b1};
                            valid_o             <= 1'b1;
                            bit_cnt_o           <= 6'd1;
                        end
                    end
                end
            end
            STATE_HDR_ZERO_1 : begin
                if(hdr_ready_i) begin
                    state_hdr                   <= STATE_HDR_ZERO_2;

                    hdr_data_o                  <= {(32-ZERO_DATA_W){1'b0},zero_reg_1};
                    valid_o                     <= 1'b1;
                    insert_zero_o               <= 1'b1;
                end
            end
            STATE_HDR_ZERO_2 : begin
                if(hdr_ready_i) begin
                    state_hdr                   <= STATE_HDR_ZERO_3;

                    hdr_data_o                  <= {(32-ZERO_DATA_W){1'b0},zero_reg_2[y>>2][x>>2]};
                    valid_o                     <= 1'b1;
                    insert_zero_o               <= 1'b1;
                end
            end
            STATE_HDR_ZERO_3 : begin
                if(hdr_ready_i) begin
                    state_hdr                   <= STATE_HDR_ZERO_4;

                    hdr_data_o                  <= {(32-ZERO_DATA_W){1'b0},zero_reg_3[y>>1][x>>1]};
                    valid_o                     <= 1'b1;
                    insert_zero_o               <= 1'b1;
                end
            end
            STATE_HDR_ZERO_4 : begin
                if(hdr_ready_i) begin
                    state_hdr                   <= STATE_HDR_PASS;

                    hdr_data_o                  <= {(32-ZERO_DATA_W){1'b0},zero_reg_4[y][x]};
                    valid_o                     <= 1'b1;
                    insert_zero_o               <= 1'b1;
                end
            end
            STATE_HDR_PASS : begin
                if(s_axis_pass_rx_valid_i && (hdr_ready_i || (!valid_o))) begin
                    
                    state_hdr                   <= STATE_HDR_LBLOCK;
                    valid_o                     <= 1'b1;
                    insert_zero_o               <= 1'b0;
                    bits_pass                   <= bits_of(23{1'b0},(s_axis_pass_rx_data_i-1'b1));

                    if(s_axis_pass_rx_data_i == 1) begin
                        hdr_data_o              <= {32'd0};
                        bit_cnt_o               <= 6'd1;
                    end
                    else if(s_axis_pass_rx_data_i == 2) begin
                        hdr_data_o              <= {30'd0,2'b10;
                        bit_cnt_o               <= 6'd2;
                    end
                    else if(s_axis_pass_rx_data_i == 3) begin
                        hdr_data_o              <= {28'd0,4'b1100};
                        bit_cnt_o               <= 6'd4;
                    end
                    else if(s_axis_pass_rx_data_i == 4) begin
                        hdr_data_o              <= {28'd0,4'b1101};
                        bit_cnt_o               <= 6'd4;
                    end
                    else if(s_axis_pass_rx_data_i == 5) begin
                        hdr_data_o              <= {28'd0,4'b1110};
                        bit_cnt_o               <= 6'd4;
                    end
                    else if(s_axis_pass_rx_data_i < 37) begin
                        hdr_data_o              <= {(s_axis_pass_rx_data_i-9'd6),4'b1111};
                        bit_cnt_o               <= 6'd9; 
                    end
                    else begin
                        hdr_data_o              <= {(s_axis_pass_rx_data_i-9'd37),b'9111111111};
                        bit_cnt_o               <= 6'd16;
                    end    
                end
                else if(!s_axis_pass_rx_valid_i) begin
                    valid_o                     <= 1'b0;
                end
            end
            STATE_HDR_LBLOCK_1 : begin
                if(s_axis_lenght_rx_valid_i) begin
                    state_hdr                   <= STATE_HDR_LBLOCK_2;

                    bits                        <= bits_of(s_axis_lenght_rx_data_i-1'b1) + 1'b1;
                end
                if(hdr_ready_i && valid_o) begin
                    valid_o                     <= 1'b0;        
                end    
            end
            STATE_HDR_LBLOCK_2 : begin
                if(!valid_o || (valid_o && hdr_ready_i)) begin

                    state_hdr                   <= STATE_HDR_LENGTH;
                    if((bits - bits_pass < 4)) begin

                        hdr_data_o              <= HDR_DATA_W{1'b0};
                        valid_o                 <= 1'b1;
                        bit_cnt_o               <= 6'd1;

                        lblock                  <= 6'd3;      
                    end
                    else begin
                        hdr_data_o              <= {(HDR_DATA_W- BITS_W){1'b0},(bits - bits_pass)};
                        valid_o                 <= 1'b1;
                        bit_cnt_o               <= 6'd1;
                        insert_ones_o           <= 1'b1;

                        lblock                  <= bits - bits_pass;
                    end    
                end    
            end
            STATE_HDR_LENGTH : begin
                if(hdr_ready_i) begin
                    if((cb_y == y_limit) && (cb_x == x_limit)) begin
                        if((pkt_index == 0) || (sb_cnt == 2)) begin
                            state_hdr           <= STATE_HDR_LAST;
                            hdr_last_o          <= 1'b1;
                        end
                        else begin
                            state_hdr           <= STATE_HDR_SB_WAIT;
                            sb_cnt              <= sb_cnt + 1'b1;
                        end
                        cb_x                    <= X_W{1'b0};
                        cb_y                    <= Y_W{1'b0}; 
                        hdr_maker_busy          <= 1'b0;
                    end
                    else begin
                        state_hdr               <= STATE_HDR_CODE_BLOCK;
                        if(cb_x == x_limit) begin
                            cb_y                <= cb_y + 1'b1;
                            cb_x                <= X_W{1'b0};    
                        end
                        else begin
                            cb_x                <= cb_x + 1'b1;
                        end
                    end
                    hdr_data_o                  <= s_axis_lenght_rx_data_i;
                    valid_o                     <= 1'b1;
                    bit_cnt_o                   <= {26{1'b0},(lblock + bits)};
                    insert_ones_o               <= 1'b0;
                end
            end
            STATE_HDR_LAST : begin
                if(hdr_ready_i) begin
                    if(sb_cnt == 2) begin
                        state_hdr               <= STATE_HDR_INIT_TILE;

                        pkt_index               <= PKT_INDEX_W{1'b0};    
                    end
                    else begin
                        state_hdr               <= STATE_HDR_INIT_PKT;

                        pkt_index               <= pkt_index +1'b1;
                    end
                    sb_cnt                      <= SB_CNT_W{1'b0};
                    valid_o                     <= 1'b0;
                    hdr_last_o                  <= 1'b0;
                end
            end
            STATE_HDR_SB_WAIT : begin
                if(filed_flag_0 && (!valid_o)) begin
                    state_hdr                   <= STATE_HDR_CODE_BLOCK;
                    hdr_maker_busy              <= 1'b1;    
                end
                else if(hdr_ready_i && valid_o) begin
                    valid_o                     <= 1'b0;
                end
            end
            default begin
                state_hdr                       <= STATE_HDR_INIT_TILE;

                lblock                          <= 0;
                bits                            <= 0;
                bits_pass                       <= 0;
                pkt_index                       <= 0;
                sb_cnt                          <= 0;
                cb_x                            <= 0;
                cb_y                            <= 0;

                valid_o                         <= 0;
                hdr_last_o                      <= 0;
                insert_ones_o                   <= 0;
                insert_zero_o                   <= 0;
                hdr_maker_busy                  <= 0;

                s_axis_zero_rx_reday_o          <= 0;
                s_axis_lenght_rx_reday_o        <= 0;
                s_axis_pass_rx_reday_o          <= 0;
            end
        endcase   
    end
end
endmodule
