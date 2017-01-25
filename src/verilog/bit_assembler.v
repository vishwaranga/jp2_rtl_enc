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
//  25/01/2017  sajith 			bit assembler
//
// ********************************************************************************************************************

`timescale 1ns / 1ps

module _
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

    input 	                                    valid_o,
    input 	                                    hdr_last_o,
    input 	                                    insert_zero_o,
    input 	                                    insert_ones_o,
    input 	                [BIT_CNT_W-1:0]     bit_cnt_o,
    input 	                [HDR_DATA_W-1:0]    hdr_data_o,
    output reg                                  hdr_ready_i
);

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
	localparam 				NO_OF_STATES		= 10;	
	localparam 				TMP_W 				= 8;
	localparam 				REM_CNT_W 			= BIT_CNT_W;	
//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------
	reg 				[NO_OF_STATES-1:0] 		state;
	reg 				[TMP_W-1:0] 			tmp_b; 
	reg 				[REM_CNT_W-1:0]			remain_bits;					
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
					
				end
			end
			default : /* default */;
		endcase	 
	end
end
endmodule