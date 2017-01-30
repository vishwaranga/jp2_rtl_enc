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
// FILE         : bit_assembler 
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
//  25/01/2017  sajith          bit assembler
//
// ********************************************************************************************************************

`timescale 1ns / 1ps

module bit_assembler
#(
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter               DATA_W          =   128,
    parameter               KEEP_W          =   DATA_W/8,

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

    input                                       valid_o,
    input                                       hdr_last_o,
    input                                       insert_zero_o,
    input                                       insert_ones_o,
    input                   [BIT_CNT_W-1:0]     bit_cnt_o,
    input                   [HDR_DATA_W-1:0]    hdr_data_o,
    output reg                                  hdr_ready_i
);

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam              NO_OF_STATES        = 10;   
    localparam              TMP_W               = 8;
    localparam              REM_CNT_W           = BIT_CNT_W;    
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
    reg                 [NO_OF_STATES-1:0]      state;
    reg                 [TMP_W-1:0]             tmp_b; 
    reg                 [REM_CNT_W-1:0]         remain_bits;
    reg                 [TMP_W-1:0]             data_o, data_tmp;
    reg                 [BIT_CNT_W-1:0]         bit_cnt_tmp;                    
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
         <= 0;
    end 
    else begin
        case (state) begin
            STATE_INIT : begin
                if(valid_o) begin
                    state                       <= STATE_BIT_FILL;

                    tmp_b                       <= TMP_W{1'b0};
                    remain_bits                 <= 6'd8;  
                end
            end
            STATE_BIT_FILL : begin
                if(valid_o) begin
                    if(insert_zero_o && !insert_ones_o) begin
                        if(bit_cnt_o < (remain_bits-1'b1)) begin
                            tmp_b               <= tmp_b + (1'b1 << bit_cnt_o);
                            remain_bits         <= remain_bits;
                            hdr_ready_i         <= 1'b1; 
                        end
                        else if(bit_cnt_o == (remain_bits-1'b1)) begin
                            data_o              <= tmp_b + (1'b1 << bit_cnt_o);

                            tmp_b               <= TMP_W{1'b0};
                            hdr_ready_i         <= 1'b1;
                            if(data_o == 8'hff) begin
                                remain_bits     <= 6'd7; 
                            end
                            else begin
                                remain_bits     <= 6'd8;
                            end    
                        end
                        else if((bit_cnt_o - remain_bits) < 6'd7) begin
                            data_o              <= tmp_b;

                            tmp_b               <= 1'b1 << (bit_cnt_o - remain_bits);
                            remain_bits         <= bit_cnt_o - remain_bits -1'b1;
                            hdr_ready_i         <= 1'b1;
                        end
                        else begin
                            state               <= STATE_TMP_ZERO_FILL;

                            data_o              <= tmp_b;
                            tmp_b               <= TMP_W{1'b0};
                            bit_cnt_tmp         <= bit_cnt_o - remain_bits;
                            hdr_ready_i         <= 1'b0;
                        end
                    end
                    else if(!insert_zero_o && insert_ones_o) begin
                        if(bit_cnt_tmp < (remain_bits-1'b1)) begin
                            
                        end                
                    end
                    else begin
                        if(bit_cnt_o < remain_bits) begin
                            tmp_b               <= tmp_b + (hdr_data_o << remain_bits);
                            remain_bits         <= remain_bits - bit_cnt_o;
                        end
                        else if(bit_cnt_o == remain_bits) begin
                            data_o              <= tmp_b + (hdr_data_o << remain_bits);

                            tmp_b               <= TMP_W{1'b0};
                            remain_bits         <= 6'd8;
                        end
                        else if(bit_cnt_o < (remain_bits + 6'd8)) begin
                            data_o              <= tmp_b + (hdr_data_o << remain_bits);

                            tmp_b               <= hdr_data_o >> (6'd8 - remain_bits);
                        end
                    end    
                end
            end
            STATE_TMP_ZERO_FILL : begin
                if(bit_cnt_tmp < 6'd7) begin
                    state                       <= STATE_BIT_FILL;

                    tmp_b                       <= 1'b1 << bit_cnt_tmp;
                    remain_bits                 <= bit_cnt_tmp -1'b1;
                    hdr_ready_i                 <= 1'b1;
                end
                else if(bit_cnt_tmp == 6'd7) begin
                    state                       <= STATE_BIT_FILL;

                    data_o                      <= 8'b10000000;
                    tmp_b                       <= TMP_W{1'b0};
                    remain_bits                 <= 6'd8;
                    hdr_ready_i                 <= 1'b1;
                end
                else begin
                    data_o                      <= 8'd0;
                    bit_cnt_tmp                 <= bit_cnt_tmp - 6'd8;
                end
            end
            default begin 
            end
        endcase  
    end
end
endmodule