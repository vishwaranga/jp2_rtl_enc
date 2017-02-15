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

    input                                       valid_i,
    input                                       hdr_last_i,
    input                                       insert_zero_i,
    input                                       insert_ones_i,
    input                   [BIT_CNT_W-1:0]     bit_cnt_i,
    input                   [HDR_DATA_W-1:0]    hdr_data_i,
    output reg                                  hdr_ready_o
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
    reg                 [TMP_W-1:0]             data_o;
    reg                 [HDR_DATA_W-1:0]        data_tmp;
    reg                 [BIT_CNT_W-1:0]         bit_cnt_tmp;                    
//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        state                                   <= STATE_INIT;
        tmp_b                                   <= TMP_W{1'b0};
        hdr_ready_o                             <= 1'b0;
    end 
    else begin
        case (state) begin
            STATE_INIT : begin
                if(valid_i) begin
                    state                       <= STATE_BIT_FILL;

                    tmp_b                       <= TMP_W{1'b0};
                    remain_bits                 <= 6'd8;
                    hdr_ready_o                 <= 1'b1;  
                end
                else begin
                    hdr_ready_o                 <= 1'b0;
                end
            end
            STATE_BIT_FILL : begin
                if(valid_i && hdr_ready_o) begin
                    if(insert_zero_i && !insert_ones_i) begin
                        if(bit_cnt_i < remain_bits) begin
                            tmp_b               <= tmp_b + (1'b1 << (remain_bits - bit_cnt_i));
                            remain_bits         <= remain_bits - bit_cnt_i;
                            hdr_ready_o         <= 1'b1; 
                        end
                        else if(bit_cnt_i == remain_bits) begin
                            data_o              <= tmp_b + 1'b1;

                            tmp_b               <= TMP_W{1'b0};
                            hdr_ready_o         <= 1'b1;
                            if((tmp_b + 1'b1) == 8'hff) begin
                                remain_bits     <= 6'd7; 
                            end
                            else begin
                                remain_bits     <= 6'd8;
                            end    
                        end
                        else if((bit_cnt_i - remain_bits) < 6'd7) begin
                            data_o              <= tmp_b;

                            tmp_b               <= TMP_W{1'b0} + 1'b1 << ( 6'd8 + remain_bits - bit_cnt_i);
                            remain_bits         <= 6'd8 + remain_bits - bit_cnt_i;
                            hdr_ready_o         <= 1'b1;
                        end
                        else begin
                            state               <= STATE_TMP_ZERO_FILL;

                            data_o              <= tmp_b;
                            tmp_b               <= TMP_W{1'b0};
                            bit_cnt_tmp         <= bit_cnt_i - remain_bits;
                            hdr_ready_o         <= 1'b0;
                        end
                    end
                    else if(!insert_zero_i && insert_ones_i) begin
                        if(bit_cnt_i < remain_bits) begin

                            if(bit_cnt_i == 1) begin
                                remain_bits     <= remain_bits - 1'b1;
                            end
                            else if(bit_cnt_i == 2) begin
                                tmp_b           <= tmp_b + ((2'b10) << (remain_bits - 2));
                                remain_bits     <= remain_bits - 2;
                            end
                            else if(bit_cnt_i == 3) begin
                                tmp_b           <= tmp_b + ((3'b110) << (remain_bits - 3));
                                remain_bits     <= remain_bits - 3;
                            end
                            else if(bit_cnt_i == 4) begin
                                tmp_b           <= tmp_b + ((4'b1110) << (remain_bits - 4));
                                remain_bits     <= remain_bits - 4;
                            end
                            else if(bit_cnt_i == 5) begin
                                tmp_b           <= tmp_b + ((5'b11110) << (remain_bits - 5));
                                remain_bits     <= remain_bits - 5;
                            end
                            else if(bit_cnt_i == 6) begin
                                tmp_b           <= tmp_b + ((6'b111110) << (remain_bits - 6));
                                remain_bits     <= remain_bits - 6;
                            end
                            else begin
                                tmp_b           <= tmp_b + ((7'b1111110) << (remain_bits - 7));
                                remain_bits     <= remain_bits - 7;
                            end
                        end
                        else if(bit_cnt_i == remain_bits) begin
                            if(bit_cnt_i == 1) begin
                                data_o          <= tmp_b;
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                            else if(bit_cnt_i == 2) begin
                                data_o          <= tmp_b + 2'b10
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                            else if(bit_cnt_i == 3) begin
                                data_o          <= tmp_b + ((3'b110) << (remain_bits - 3));
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                            else if(bit_cnt_i == 4) begin
                                data_o          <= tmp_b + ((4'b1110) << (remain_bits - 4));
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                            else if(bit_cnt_i == 5) begin
                                data_o          <= tmp_b + ((5'b11110) << (remain_bits - 5));
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                            else if(bit_cnt_i == 6) begin
                                data_o          <= tmp_b + ((6'b111110) << (remain_bits - 6));
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                            else begin
                                data_o          <= tmp_b + ((7'b1111110) << (remain_bits - 7));
                                remain_bits     <= 6'd8;
                                tmp_b           <= TMP_W{1'b0};
                            end
                        end
                        else begin
                            state               <= STATE_TMP_ONE_FILL;
                            hdr_ready_o         <= 1'b0;
                            if(remain_bits == 1) begin
                                data_o          <= tmp_b + 1'b1;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits; 
                            end
                            else if(remain_bits == 2) begin
                                data_o          <= tmp_b + 2'b11;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                            else if(remain_bits == 3) begin
                                data_o          <= tmp_b + 3'b111;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                            else if(remain_bits == 4) begin
                                data_o          <= tmp_b + 4'b1111;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                            else if(remain_bits == 5) begin
                                data_o          <= tmp_b + 5'b11111;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                            else if(remain_bits == 6) begin
                                data_o          <= tmp_b + 6'b111111;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                            else if(remain_bits == 7) begin
                                data_o          <= tmp_b + 7'b1111111;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                            else if(remain_bits == 8) begin
                                data_o          <= tmp_b + 8'hff;
                                bit_cnt_tmp     <= bit_cnt_i - remain_bits;
                            end
                        end                
                    end
                    else begin
                        if(bit_cnt_i < remain_bits) begin
                            tmp_b               <= tmp_b + (hdr_data_i << (remain_bits - bit_cnt_i));
                            remain_bits         <= remain_bits - bit_cnt_i;
                        end
                        else if(bit_cnt_i == remain_bits) begin
                            data_o              <= tmp_b + hdr_data_i ;

                            tmp_b               <= TMP_W{1'b0};
                            if((tmp_b + hdr_data_i) == 8'hff ) begin
                                remain_bits     <= 6'd7;
                            end
                            else begin
                                remain_bits     <= 6'd8;
                            end
                        end
                        else begin
                            state               <= STATE_TMP_DATA_FILL;

                            data_o              <= tmp_b + (hdr_data_i >> (bit_cnt_i - remain_bits));
                            data_tmp            <= hdr_data_i;
                            tmp_b               <= TMP_W{1'b0};
                            bit_cnt_tmp         <= bit_cnt_i - remain_bits;
                            hdr_ready_o         <= 1'b0;
                        end
                    end    
                end
            end
            STATE_TMP_ONE_FILL : begin
                if(bit_cnt_tmp < 6'd8) begin
                    state                       <= STATE_BIT_FILL;
                    hdr_ready_o                 <= 1'b1;

                    if(data_o == 8'hff) begin
                        if(bit_cnt_tmp == 1) begin
                            tmp_b               <= TMP_W{1'b0};
                            remain_bits         <= 6'd6;
                        end
                        else if(bit_cnt_tmp == 2) begin
                            tmp_b               <= {1'b0,7'h40};
                            remain_bits         <= 6'd5;
                        end
                        else if(bit_cnt_tmp == 3) begin
                            tmp_b               <= {1'b0,7'h60};
                            remain_bits         <= 6'd4;
                        end 
                        else if(bit_cnt_tmp == 4) begin
                            tmp_b               <= {1'b0,7'h70};
                            remain_bits         <= 6'd3;
                        end 
                        else if(bit_cnt_tmp == 5) begin
                            tmp_b               <= {1'b0,7'h78};
                            remain_bits         <= 6'd2;
                        end 
                        else if(bit_cnt_tmp == 6) begin
                            tmp_b               <= {1'b0,7'h7c};
                            remain_bits         <= 6'd1;
                        end 
                        else if(bit_cnt_tmp == 7) begin
                            data_o              <= {1'b0,7'h7e};
                            tmp_b               <= TMP_W{1'b0};
                            remain_bits         <= 6'd8;
                        end     
                    end
                    else begin
                        if(bit_cnt_tmp == 1) begin
                            tmp_b               <= TMP_W{1'b0};
                            remain_bits         <= 6'd7;
                        end
                        else if(bit_cnt_tmp == 2) begin
                            tmp_b               <= 8'h80;
                            remain_bits         <= 6'd6;
                        end
                        else if(bit_cnt_tmp == 3) begin
                            tmp_b               <= 8'hc0;
                            remain_bits         <= 6'd5;
                        end
                        else if(bit_cnt_tmp == 4) begin
                            tmp_b               <= 8'he0;
                            remain_bits         <= 6'd4;
                        end
                        else if(bit_cnt_tmp == 5) begin
                            tmp_b               <= 8'hf0;
                            remain_bits         <= 6'd3;
                        end
                        else if(bit_cnt_tmp == 6) begin
                            tmp_b               <= 8'hf8;
                            remain_bits         <= 6'd2;
                        end
                        else if(bit_cnt_tmp == 7) begin
                            tmp_b               <= 8'hfc;
                            remain_bits         <= 6'd1;
                        end
                    end   
                end
                else if(bit_cnt_tmp == 6'd8) begin
                    state                       <= STATE_BIT_FILL;
                    hdr_ready_o                 <= 1'b1;

                    data_o                      <= 8'hfe;
                    tmp_b                       <= TMP_W{1'b0};
                    remain_bits                 <= 6'd8;
                end
                else begin
                    data_o                      <= 8'hff;
                    bit_cnt_tmp                 <= bit_cnt_tmp - 6'd8;
                end
            end
            STATE_TMP_ZERO_FILL : begin
                if(bit_cnt_tmp < 6'd8) begin
                    state                       <= STATE_BIT_FILL;

                    tmp_b                       <= 1'b1 << (6'd8 - bit_cnt_tmp);
                    remain_bits                 <= 6'd8 - bit_cnt_tmp;
                    hdr_ready_o                 <= 1'b1;
                end
                else if(bit_cnt_tmp == 6'd8) begin
                    state                       <= STATE_BIT_FILL;

                    data_o                      <= 8'b00000001;
                    tmp_b                       <= TMP_W{1'b0};
                    remain_bits                 <= 6'd8;
                    hdr_ready_o                 <= 1'b1;
                end
                else begin
                    data_o                      <= 8'd0;
                    bit_cnt_tmp                 <= bit_cnt_tmp - 6'd8;
                end
            end
            STATE_TMP_DATA_FILL : begin
                if(bit_cnt_tmp < 6'd8) begin
                    state                       <= STATE_BIT_FILL;
                    if(data_o == 8'hff) begin
                        if(bit_cnt_tmp == 6'd7) begin
                            data_o[7]           <= 1'b0;
                            data_o[6:0]         <= (TMP_W-1){1'b0} + data_tmp << (6'd7 - bit_cnt_tmp);
                            tmp_b               <= TMP_W{1'b0};
                            remain_bits         <= 6'd8;
                        end
                        else begin
                            tmp_b[7]            <= 1'b0;
                            tmp_b[6:0]          <= (TMP_W-1){1'b0} + data_tmp << (6'd7 - bit_cnt_tmp);
                            remain_bits         <= 6'd7 - bit_cnt_tmp;
                        end
                    end
                    else begin
                        tmp_b                   <= TMP_W{1'b0} + data_tmp << (6'd8 - bit_cnt_tmp);
                        remain_bits             <= 6'd8 - bit_cnt_tmp;
                    end
                    hdr_ready_o                 <= 1'b1; 
                end
                else if( bit_cnt_tmp == 6'd8) begin
                    state                       <= STATE_BIT_FILL;
                    if(data_o == 8'hff) begin
                        data_o[7]               <= 1'b0;
                        data_o[6:0]             <= data_tmp >> 1;
                        tmp_b                   <= {data_tmp[0],6'd0};
                        remain_bits             <= 6'd7;
                    end
                    else begin
                        data_o                  <= data_tmp;
                        tmp_b                   <= TMP_W{1'b0};
                        if(data_tmp == 8'hff) begin
                            remain_bits         <= 6'd7;
                        end
                        else begin
                            remain_bits         <= 6'd8;
                        end
                    end
                    hdr_ready_o                 <= 1'b1;
                end
                else begin
                    if(data_o == 8'hff) begin
                        data_o[7]               <= 1'b0;
                        data_o[6:0]             <= (TMP_W-1){1'b0} + data_tmp >> (bit_cnt_tmp - 6d7);
                        bit_cnt_tmp             <= bit_cnt_tmp - 6'd7;
                    end
                    else begin
                        data_o                  <= TMP{1'b0} + data_tmp >> (bit_cnt_tmp - 6d8);
                        bit_cnt_tmp             <= bit_cnt_tmp - 6'd8;
                    end
                end
            end
            default begin 
                state                           <= STATE_INIT;
                tmp_b                           <= TMP_W{1'b0};
                hdr_ready_o                     <= 1'b0;
            end
        endcase  
    end
end
endmodule