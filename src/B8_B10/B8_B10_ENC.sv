/*
The MIT License (MIT)

Copyright (C) 2021 Avinash ("Avi") Singh

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/*
**  B8_B10_ENC.sv:
**
**      An 8b/10b encoder using my own ruleset. The 8b/10b module is made of
**  two separate 5b/6b and 3b/4b encoders. This tries to follow the scheme on
**  wikipedia and the following link without implementing control characters:
**  https://urchin.earth.li/~twic/The_Widmer-Franaszek_8b10b_code.html.
**
**  The ruleset for the individual encoders is as follows. Running disparity
**  (RD) is initially -1:
**
**  (1) If reset (RST) is low at a clock positive edge, the input data is
**      latched.
**
**  (2) For each encoder, the output is looked up from a LUT according to the
**      input.
**
**  (3) If RD is high, one option according to the input is selected. Otherwise
**      another is selected.
**
**  (4) The current disparity (CD) of the output is calculated as ones minus
**      zeroes.
**
**  (5) If the CD is -2 or +2, flip the value of RD on the next clock.
**      Otherwise, continue.
**
**      I have not physically tested this module, but the output yields an
**  18-LUT 10-FF module on synthesis for a Zybo Z7-20. I will most likely not
**  come back to this since I initially started making this thinking I could
**  use it to encode DVI and HDMI signals. (Apparently TMDS is too different
**  for this to be of any use to me.) If anything, I may come back to try and
**  make a decoder just for the hell of it.
**
** Modules:
**      - b8_b10_encoder -- 8b-to-10b encoder made of 5b/6b and 3b/4b modules
**      - b5_b6_encoder
**      - b3_b4_encoder
** 
** Synthesizable module tests:
**      - None
**
** Testbenches:
**      - tb4_b8_encoder
**
*/

`timescale 1ns / 1ps

/******************************************************************************
**
** Name:   b8_b10_encoder
**
** Desc.:  Concatenated module of 3b/4b and 5b/6b encoders.
**
** Author: Avinash Singh
**
******************************************************************************/

module b8_b10_encoder
(
    input clk,  // clock
    input ce,   // HIGH = reset, LOW = active
    input logic [8:1] in_b8_d,    // byte input
    
    output logic [10:1] out_b10_q // 10-bit output
);

    logic [5:1] major_symbol;
    assign major_symbol = in_b8_d[5:1];

    logic [3:1] minor_symbol;
    assign minor_symbol = in_b8_d[8:6];

    logic [6:1] major_out;
    logic [4:1] minor_out;
    assign out_b10_q = { major_out, minor_out };

    b3_b4_encoder min_encoder
    (
        .clk(clk),  // clock
        .rst(ce),  // reset
        .in_b3_d(minor_symbol),  // 3-bit input
        
        .out_b4_q(minor_out) // 4-bit output
    );
    
    b5_b6_encoder maj_encoder
    (
        .clk(clk),  // clock
        .rst(ce),  // reset
        .in_b5_d(major_symbol),  // 3-bit input
        
        .out_b6_q(major_out) // 4-bit output
    );

endmodule


/******************************************************************************
**
** Name:   b5_b6_encoder
**
** Desc.:  A 5b/6b encoder abiding by the ruleset at the top of this file.
**
** Author: Avinash Singh
**
******************************************************************************/

module b5_b6_encoder
(
    input clk,  // clock
    input rst,  // reset
    input logic [5:1] in_b5_d,  // 5-bit input
    
    output logic [6:1] out_b6_q // 6-bit output
);

    // LUT for encoding
    logic [12:1] maj_enc [31:0];
    /*                           rd=0 | rd=1   */
    assign maj_enc[5'd0]  = 12'b100111_011000; // D.00
    assign maj_enc[5'd1]  = 12'b011101_100010; // D.01
    assign maj_enc[5'd2]  = 12'b101101_010010; // D.02
    assign maj_enc[5'd3]  = 12'b110001_110001; // D.03
    assign maj_enc[5'd4]  = 12'b110101_001010; // D.04
    assign maj_enc[5'd5]  = 12'b101001_101001; // D.05
    assign maj_enc[5'd6]  = 12'b101001_101001; // D.06
    assign maj_enc[5'd7]  = 12'b111000_000111; // D.07
    assign maj_enc[5'd8]  = 12'b111001_000110; // D.08
    assign maj_enc[5'd9]  = 12'b100101_100101; // D.09
    assign maj_enc[5'd10] = 12'b010101_010101; // D.10
    assign maj_enc[5'd11] = 12'b110100_110100; // D.11
    assign maj_enc[5'd12] = 12'b001101_001101; // D.12
    assign maj_enc[5'd13] = 12'b101100_101100; // D.13
    assign maj_enc[5'd14] = 12'b011100_011100; // D.14
    assign maj_enc[5'd15] = 12'b010111_101000; // D.15
    assign maj_enc[5'd16] = 12'b011011_100100; // D.16
    assign maj_enc[5'd17] = 12'b100011_100011; // D.17
    assign maj_enc[5'd18] = 12'b010011_010011; // D.18
    assign maj_enc[5'd19] = 12'b110010_110010; // D.19
    assign maj_enc[5'd20] = 12'b001011_001011; // D.20
    assign maj_enc[5'd21] = 12'b101010_101010; // D.21
    assign maj_enc[5'd22] = 12'b011010_011010; // D.22
    assign maj_enc[5'd23] = 12'b111010_000101; // D.23
    assign maj_enc[5'd24] = 12'b110011_001100; // D.24
    assign maj_enc[5'd25] = 12'b100110_100110; // D.25
    assign maj_enc[5'd26] = 12'b010110_010110; // D.26
    assign maj_enc[5'd27] = 12'b110110_001001; // D.27
    assign maj_enc[5'd28] = 12'b001110_001110; // D.28
    assign maj_enc[5'd29] = 12'b101110_010001; // D.29
    assign maj_enc[5'd30] = 12'b011110_100001; // D.30
    assign maj_enc[5'd31] = 12'b101011_010100; // D.31
    
    logic [6:1] out_b6; // unbuffered combinational output
    assign out_b6_q = out_b6;

    logic [5:1] in_b5;  // latched input

    // determine the number of ones and zeros in the output
    logic [3:1] q_out_ones;
    logic [3:1] q_out_zeros;
    assign q_out_ones  =  out_b6_q[1] +  out_b6_q[2] +  out_b6_q[3] +  out_b6_q[4] +  out_b6_q[5] +  out_b6_q[6];
    assign q_out_zeros = 3'd6 - q_out_ones;
    
    logic signed [3:1] cd;                  // current disparity of buffered output (ones minus zeros);
    assign cd = q_out_ones - q_out_zeros;   // this is only 0 or +/-2 for any given input
    
    logic rd_q; // running disparity; HIGH = +1, LOW = -1
    
    // clock-triggered register for input
    always_ff @(posedge clk or posedge rst) begin
    
        if(rst) begin
            in_b5 <= 5'd10; // results in a balanced input
            rd_q <= 1'b0; // start with running disparity of -1
        end else begin

            in_b5 <= in_b5_d; // latch input @ every enabled clock cycle

            // update the running disparity at every clock cycle
            case(|cd)
                1'b1: rd_q <= ~rd_q; // disparity present -- flip running disparity value
                1'b0: begin end      // no disparity -- do nothing
            endcase
            
        end
        
    end

    // Major encoding
    always_comb begin
    
        if(rst) begin
            out_b6 = maj_enc[5'd10] [12:7]; // push out a balanced value to set the current combinational disparity to 0    
        end else begin
            // use 5-bit input as an address to the LUT
            out_b6 = rd_q ? maj_enc[in_b5]  [6:1] :
                            maj_enc[in_b5] [12:7] ;
        end

    end

endmodule


/******************************************************************************
**
** Name:   b3_b4_encoder
**
** Desc.:  A 3b/4b encoder abiding by the ruleset at the top of this file.
**
** Author: Avinash Singh
**
******************************************************************************/

module b3_b4_encoder
(
    input clk,  // clock
    input rst,  // reset
    input logic [3:1] in_b3_d,  // 3-bit input
    
    output logic [4:1] out_b4_q // 4-bit output
);

    // LUT for encoding
    logic [8:1] min_enc [7:0];
    /*                       rd=0 | rd=1 */
    assign min_enc[3'd0] = 8'b1011_0100; // D.x.0
    assign min_enc[3'd1] = 8'b1001_1001; // D.x.1
    assign min_enc[3'd2] = 8'b0101_0101; // D.x.2
    assign min_enc[3'd3] = 8'b1100_0011; // D.x.3
    assign min_enc[3'd4] = 8'b1101_0010; // D.x.4
    assign min_enc[3'd5] = 8'b1010_1010; // D.x.5
    assign min_enc[3'd6] = 8'b0110_0110; // D.x.6
    assign min_enc[3'd7] = 8'b1110_0001; // D.x.(P)7
    
    // D.x.7 is a little special since it has an alternate case
    logic [8:1] dxa7 = 8'b0111_1000; // D.x.A7

    
    logic [4:1] out_b4; // unbuffered combinational output
    assign out_b4_q = out_b4;
    logic [3:1] in_b3;  // latched input

    // determine the number of ones and zeros in the output
    logic [3:1] q_out_ones;
    logic [3:1] q_out_zeros;
    assign q_out_ones  =  out_b4_q[1] +  out_b4_q[2] +  out_b4_q[3] +  out_b4_q[4];
    assign q_out_zeros = 3'd4 - q_out_ones;
    
    logic signed [3:1] cd;                  // current disparity of buffered output (ones minus zeros);
    assign cd = q_out_ones - q_out_zeros;   // this is only 0 or +/-2 for any given input

    logic rd_q; // running disparity; HIGH = +1, LOW = -1

    // clock-triggered register for input
    always_ff @(posedge clk or posedge rst) begin
    
        if(rst) begin
            in_b3 <= 3'd2; // results in a balanced input
            rd_q <= 1'b0; // start with running disparity of -1
        end else begin
            
            in_b3 <= in_b3_d; // latch input @ every enabled clock cycle

            // update the running disparity at every clock cycle
            case(|cd)
                1'b1: rd_q <= ~rd_q; // disparity present -- flip running disparity value
                1'b0: begin end      // no disparity -- do nothing
            endcase
            
        end
        
    end

    // Minor encoding
    always_comb begin

        if(rst) begin
            out_b4 = min_enc[3'd2] [8:5]; // push out a balanced value to set the current combinational disparity to 0        
        end else begin
            // use 3-bit input as an address to the LUT
            out_b4 = rd_q ? min_enc[in_b3] [4:1] :
                            min_enc[in_b3] [8:5] ;
        end
        
    end

endmodule


/******************************************************************************
**
** Name:   tb4_b8_b10_encoder
**
** Desc.:  Testbench for b8_b10_encoder. Pushes out an encoded ASCII string
**         "Hello, World!".
**
** Author: Avinash Singh
**
******************************************************************************/

// synthesis off
module tb4_b8_b10_encoder();

    logic clk;
    logic ce;
    string msg = "Hello, World!";
    byte in_b8;
    logic [10:1] out_b10;
    
    b8_b10_encoder b8b10enc4tb
    (
        .clk(clk),  // clock
        .ce(ce),   // HIGH = reset, LOW = active
        .in_b8_d(in_b8),    // byte input
        
        .out_b10_q(out_b10) // 10-bit output
    );
    
    initial begin
        clk <= 1'b1;
        ce  <= 1'b1;
        forever #0.5 clk <= ~clk;
    end
    
    initial begin

        #9.999 ce <= 1'b0;
        
        for(int i = 0; i < 13; i++) begin
            in_b8 = msg[i];
            #1;
        end
        $finish;
    end
   
endmodule
// synthesis on