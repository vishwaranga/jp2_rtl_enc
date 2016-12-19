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
// FILE         : bit_ssembler.v  
// AUTHOR       : sajith vishwaranga  
// DESCRIPTION  : assemble compressed data and make the the out put image  
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

module bit_assembler
#(
//---------------------------------------------------------------------------------------------------------------------
// parameter definitions
//---------------------------------------------------------------------------------------------------------------------
    parameter               DATA_W      =   32,
    parameter               KEEP_W      =   DATA_W/8,    

)
(
//---------------------------------------------------------------------------------------------------------------------
// I/O signals
//---------------------------------------------------------------------------------------------------------------------
    input                                   clk,
    input                                   rst_n,

    input                                   s_axis_rx_valid_i,
    input                                   s_axis_rx_last_i,
    input                   [DATA_W-1:0]    s_axis_rx_data_i,
    input                   [KEEP_W-1:0]    s_axis_rx_keep_i,
    input reg                               s_axis_rx_ready_o,

    output reg                              m_axis_tx_valid_o,
    output reg                              m_axis_tx_last_o,
    output reg              [DATA_W-1:0]    m_axis_tx_data_o,
    output reg              [KEEP_W-1:0]    m_axis_tx_keep_o,
    input                                   m_axis_tx_ready_i
);

//---------------------------------------------------------------------------------------------------------------------
// Global constant headers
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// localparam definitions
//---------------------------------------------------------------------------------------------------------------------
    localparam          NO_OF_BOX_STATES        = 7;

    localparam          JP2_SIGNATURE_L_BOX     = 32'h0000000C;
    localparam          JP2_SIGNATURE_T_BOX     = 32'h6A502020;
    localparam          JP2_SIGNATURE_D_BOX     = 32'h0D0A870A;

    localparam          PROFILE_L_BOX           = 32'h00000014;
    localparam          PROFILE_T_BOX           = 32'h66747970;
    localparam          PROFILE_D_BOX_BR        = 32'h6A703220;
    localparam          PROFILE_T_BOX_MV        = 32'h0;
    localparam          PROFILE_T_BOX_CL        = 32'h6A703220;

    localparam          JP2_HEADER_L_BOX        = 32'h0000002d;
    localparam          JP2_HEADER_T_BOX        = 32'h6A703268;

    localparam          IMG_HEADER_L_BOX        = 32'h00000016;
    localparam          IMG_HEADER_T_BOX        = 32'h69686472;
    localparam          IMG_HEADER_D_BOX_WIDTH  = WIDTH;           // 32 bit
    localparam          IMG_HEADER_D_BOX_HEIGHT = HEIGHT;          // 32 bit
    localparam          IMG_HEADER_D_BOX_C      = 2'h03;           // no of components (2 bit)
    localparam          IMG_HEADER_D_BOX_BPC    = 8'h07;           // bcp-1
    localparam          IMG_HEADER_D_BOX_CT     = 8'h07;           //CT
    localparam          IMG_HEADER_D_BOX_UC     = 8'h00;           // UC
    localparam          IMG_HEADER_D_BOX_IPR    = 8'h00;           //IPR

    localparam          CLR_SPEC_L_BOX          = 32'h0000000f;
    localparam          CLR_SPEC_T_BOX          = 32'h636F6C72;
    localparam          CLR_SPEC_D_BOX_METH     = 8'h01;
    localparam          CLR_SPEC_T_BOX_PREC     = 8'h00;
    localparam          CLR_SPEC_T_BOX_APROX    = 8'h00;
    localparam          CLR_SPEC_D_BOX_ENUM     = 32'h00000010;     //RGB (0x10) // mono (0x11)

    localparam          CODE_STREAM_L_BOX       = 32'h00000000;
    localparam          CODE_STREAM_T_BOX       = 32'h6A703263;

    localparam          SOC                     = 16'hff4f;

    localparam          SIZ                     = 16'hff51;
    localparam          SIZ_L                   = 16'h002f;      // no_of_cmp = 3 (L_size = 0x2f) //  no_of_cmp = 1 (L_size = 0x29)      
    localparam          SIZ_CA                  = 16'h0000;
    localparam          SIZ_F2                  = WIDTH;         // 32 bit
    localparam          SIZ_F1                  = HEIGHT;        // 32 bit
    localparam          SIZ_E2                  = 16'h0000;
    localparam          SIZ_E1                  = 16'h0000;            
    localparam          SIZ_T2                  = WIDTH;         // 32 bit
    localparam          SIZ_T1                  = HEIGHT;        // 32 bit
    localparam          SIZ_OMG2                = 32'h00000000;
    localparam          SIZ_OMG1                = 32'h00000000;
    localparam          SIZ_C                   = 16'h0003;      // no of cmps
    localparam          SIZ_B                   = 16'h0007;      // bcp-1              // 3 time for cmp =3
    localparam          SIZ_S2                  = 16'h0001;                            //
    localparam          SIZ_S1                  = 16'h0001;                            //

    localparam          SOT                     = 16'hFF90;
    localparam          SOT_L                   = 16'h000A;
    localparam          SOT_I_T                 = 16'h0000;
    localparam          SOT_L_TP                = 32'h00000000;      // for last tile = 0
    localparam          SOT_I_TP                = 8'h00;
    localparam          SOT_N_TP                = 8'h01;

    localparam          SOD                     = 16'hff93;
    localparam          EOC                     = 16'hffd9;


//---------------------------------------------------------------------------------------------------------------------
// Internal wires and registers
//---------------------------------------------------------------------------------------------------------------------

//---------------------------------------------------------------------------------------------------------------------
// Implementation
//---------------------------------------------------------------------------------------------------------------------
    reg             [NO_OF_BOX_STATES-1:0]      state_box;
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        state_box                                   <= STATE_BOX_INIT;

        s_axis_rx_ready_o                           <= 1'b0;

        m_axis_tx_valid_o                           <= 1'b0;
        m_axis_tx_last_o                            <= 1'b0;
        m_axis_tx_data_o                            <= {DATA_W{1'b0}};
        m_axis_tx_keep_o                            <= {KEEP_W{1'b0}};
    end 
    else begin
        case (state_box)    : begin
            STATE_BOX_1 :   begin
            end
            STATE_BOX_2 :   begin
            end
            STATE_BOX_3 :   begin
            end
            STATE_BOX_4 :   begin
            end
            STATE_BOX_4 :   begin
            end
            STATE_BOX_5 :   begin
            end
            STATE_BOX_6 :   begin
            end
        
            default :   begin
            end
        endcase
    end
end
endmodule
