/*
The MIT License (MIT)

Copyright (C) 2021 Avinash ("Avi") Singh

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

`timescale 1ns / 1ps

/*
** XIYO.sv: A collection of "X-in-Y-out" modules.
**
** Modules:
**      - u_SIPO   -- wrapper for the current approved SIPO module
**      - u_PISO   -- wrapper for the current approved PISO module
**      - SIPO     -- Serial-in-Parallel-out module
**      - PISO_mux -- Revised Parallel-in-Serial-out module taking advantage
**                    of multiplexing the input
**      - PISO_old -- Outdated PISO model no longer recommended for use
** 
** Synthesizable module tests:
**      - SIPO_synth_test -- ZYBO Z7-20 target
**      - PISO_synth_test -- ZYBO Z7-20 target
**
** Testbenches:
**      - tb4XIYO -- testbench for all modules currently used in design
**      - tb4SIPO -- test on u_PISO; wcfg file is tb4_XIYO.wcfg
**      - tb4PISO -- test on u_SIPO; wcfg file is tb4_XIYO.wcfg
**
*/


/******************************************************************************
**
** Name:   u_SIPO
**
** Desc.:  A wrapper for the current approved SIPO module (SIPO).
**
** Author: Avinash Singh
**
******************************************************************************/

module u_SIPO #(parameter BITS = 16) (
    input logic Clock,
    input logic Reset,
    input logic SDataI,
    input logic Enable,
    
    output logic Busy,
    output logic [BITS:1] PDataO
);

    SIPO #(.BITS(BITS)) unit_SIPO(
        .Clock(Clock),
        .Reset(Reset),
        .SDataI(SDataI),
        .Enable(Enable),
        
        .Busy(Busy),
        .PDataO(PDataO)
    );

endmodule


/******************************************************************************
**
** Name:   u_PISO
**
** Desc.:  A wrapper for the current approved PISO module (PISO_mux).
**
** Author: Avinash Singh
**
******************************************************************************/

module u_PISO #(parameter BITS = 16) (
    input logic Clock,
    input logic Reset,
    input logic Enable,
    input logic [BITS:1] PDataIn,
    
    output logic Busy,
    output logic SDataOut
);

    PISO_mux #(.BITS(BITS)) unit_PISO(
        .Clock(Clock),
        .Reset(Reset),
        .Enable(Enable),
        .PDataIn(PDataIn),
        
        .Busy(Busy),
        .SDataOut(SDataOut)
    );

endmodule


/******************************************************************************
**
** Name:   SIPO -- Serial In Parallel Out
**
** Desc.:  Block runs until internal counter hits specified value. Output is
**         latched afterwards. This SIPO unit is a "one-shot" device and will 
**         only collect data for the counter interval, ignoring any Enable
**         changes during this time. Outputs a busy signal when deserializing
**         input.
**
** Author: Avinash Singh, Jericho Tabacolde
**
******************************************************************************/

module SIPO #(parameter BITS = 16) (
    input logic Clock,
    input logic Reset,
    input logic SDataI,
    input logic Enable,
    
    output logic Busy, // signals when SIPO is in operation
    output logic [BITS:1] PDataO
);

    // counter for SIPO cycles -- can be optimized by using an efficient amount
    // of counter bits
    logic [BITS:1] ctr;
    logic [BITS:1] internal;
    
    // SIPO operation
    always @(posedge Clock or posedge Reset) begin
    
        if (Reset) begin
            Busy   <= 1'b0;
            internal <= 'b0;
            PDataO <=  'b0;
        end else begin
        
            // reset counter and activate operation;
            // if triggered during operation (Busy), ignore Enable
            if (Enable & ~Busy) begin
                ctr <= 1'b0;
                Busy <= 1'b1;
                // shift first serial value in
                internal <= (internal << 1) + SDataI;
            end
    
            // SIPO logic
            if (Busy) begin
    
                // shift if the counter hasn't reached max value
                if (ctr < BITS - 2) begin
                    ctr <= ctr + 1'b1;
                    internal <= (internal << 1) + SDataI;
                    
                // disable operation otherwise
                end else begin
                    PDataO <= (internal << 1) + SDataI;
                    Busy <= 1'b0;
                end
    
            end
            
        end
        
    end
    
endmodule


/******************************************************************************
**
** Name:   PISO_mux
**
** Desc.:  A parallel to serial interface optimized from the older PISO version
**         and using MUXFX primitives. This could be improved further by
**         optimizing the number of select bits for synthesis and piping the
**         parallel input straight to the mux, assuming there is no risk of the
**         input changing mid-operation.
**
** Author: Avinash Singh
**
******************************************************************************/

module PISO_mux #(parameter BITS = 16) // number of bits; default is 16 
(
    input logic Clock,
    input logic Reset,
    input logic [BITS:1] PDataIn,
    input logic Enable,
    
    output logic Busy, // indicates when PISO is in operation -- When high, it
                       // ignores enable
    output logic SDataOut
);

    // mux select is implemented as a counter
    logic [BITS:1] select;
    
    // Internal register used for serializing data.
    // This loads input as soon as a busy signal is triggered
    logic [BITS:1] internal;

    // Shift register operations
    always @(posedge Clock or posedge Reset) begin

        if (Reset) begin
            select   <= 1'b0;
            Busy     <= 1'b0;
            internal <=  'b0;
        end else begin
        
            if (~Busy) begin
                // set busy status and initiate multiplexing
                if (Enable) begin
                    Busy <= 1'b1;
                    internal <= PDataIn;
                    select <= 'b0;
                end
            end
            
            // {Busy, Enable} = {1, X} --> perform PISO operation by switching mux
            if (Busy) begin
                if (select < BITS - 2) begin
                    select <= select + 1'b1;
                // all bits switched out to serial -- turn off
                end else begin
                    select <= select + 1'b1;
                    Busy <= 1'b0;
                end
            end

        end
        
    end
    
    // this should implement a mux
    always_comb begin
        
        // the default case is an unknown and optimized
        // out at synthesis
        SDataOut = 'bx;
        
        // construct cases for mux
        for (int i = 0; i < BITS; i++) begin
            if (select == i) begin
                SDataOut = internal[BITS - i];
            end
        end

    end

endmodule


/******************************************************************************
**
** Name:   PISO_old
**
** Desc.:  Implemented as an internal data shift register; output is the MSB of the data at each shift.
**         Asynchronous sequential implementation. This module has been removed from the interposer block
**         in favor of an optimized module utilizing multiplexing.
**
** Author: Avinash Singh
**
******************************************************************************/

module PISO_old #(parameter BITS = 16) // number of bits; default is 16 
(
    input logic Clock,
    input logic Reset,
    input logic Enable,
    input logic [BITS:1] PDataIn,
    
    output logic Busy, // indicates when PISO is in operation -- When high, it ignores enable
    output logic SDataOut
);



    // counter for cycles --
    // need to optimize for a lower bit-count later.
    // Number of bits to allocate for counter counter optimization
    // defined as CEIL(LOG_2(BITS + 1)) or similar -- $clog() won't synthesize
    logic [BITS:1] ctr;
    
    // Internal shift register used for serializing data.
    // This loads input as soon as a busy signal is triggered
    logic [BITS:1] internal_shift;

    // the bit to be shifted out
    assign SDataOut = internal_shift[BITS];

    // Shift register operations
    always @(posedge Clock) begin
        if (Reset) begin
            Busy <= 1'b0;
        end else begin
            // {Busy, Enable} = {0, 1} --> set up for PISO operation
            // {Busy, Enable} = {0, 0} --> inactive
            if (~Busy) begin
                if (Enable) begin
                    // load input internally and start shifting
                    internal_shift <= PDataIn[BITS:1];
                    // reset counter and activate operation
                    ctr <= 1'b0;
                    Busy <= 1'b1;
                end
            end
            
            // {Busy, Enable} = {1, X} --> perform operation
            if (Busy) begin
                // shift if the counter hasn't reached max value
                if (ctr < BITS - 1) begin
                    ctr <= ctr + 1'b1;
                    internal_shift <= {internal_shift[BITS - 1:1], 1'b0};
                // disable PISO operation otherwise
                end else begin
                    Busy <= 1'b0;
                end
            end
        end
    end

endmodule


/******************************************************************************
**
** Name:   SIPO_synth_test
**
** Desc.:  Synthesis test for the current approved SIPO module; If all goes
**         right, the 4 switch LEDs should light up according to the switch
**         positions every 4 disclk (or sysclk) cycles on a Zybo Z7-20. Red on
**         LED 6 indicates an operation is in progress. Blue on LED 5 indicates
**         when disclk is positive.
**
** Author: Avinash Singh
**
******************************************************************************/

module SIPO_synth_test(
    input sysclk,
    input [3:0] sw,
    output [3:0] led,
    output led5_r,
    output led6_b
);

    int ctr; // 32 bit counter register
    logic disclk; // a display clock, running on a second-scale
    logic [2:1] disctr; // a display counter, running on a second-scale

    initial begin
        disctr = 'b0;
        disclk = 'b0;
    end

    assign led6_b = disclk; // scaled-down clock visible on board as a blinking blue LED

    logic ser; // serial input to SIPO

    // Convert switch input to serial input
    always_comb begin
        case (disctr)
            2'b00: ser = sw[3];
            2'b01: ser = sw[2];
            2'b10: ser = sw[1];
            2'b11: ser = sw[0];
        endcase
    end

    // scaling down disclk
    always @(posedge sysclk) begin
        if (ctr != 'd125000000) begin
            ctr <= ctr + 1'b1;
        end else begin
            disclk <= ~disclk;
            ctr <= 0;
        end
    end

    // change trigger to posedge disclk to see clock on the 1sec scale
    always @(posedge sysclk) begin
        disctr <= disctr + 1'b1;
    end

    // SIPO instantiation
    u_SIPO #(.BITS(4)) sammy
    (
        .Clock(sysclk), // change to disclk to see clock on the single-second scale
        .Reset(1'b0),   // a bit risky, but we assume Busy = 0 at bitstream upload
        .SDataI(ser),
        .Enable(1'b1),  // tied high
        .Busy(led5_r),  // signals when SIPO is in operation
        .PDataO(led[3:0])
    );

endmodule


/******************************************************************************
**
** Name:   PISO_synth_test
**
** Desc.:  Synthesis test for the current approved PISO module; If all goes
**         right, the switch LEDs should light up according to the switch
**         positions every disclk (or sysclk) cycle on a Zybo Z7-20. Red on
**         LED 6 indicates an operation is in progress. Blue on LED 5 indicates
**         when disclk is positive.
**
** Author: Avinash Singh
**
******************************************************************************/

module PISO_synth_test(
    input sysclk,
    input [3:0] sw,
    output logic [3:0] led,
    output led5_r,
    output led6_b
);

    int ctr; // 32 bit counter register
    logic disclk; // a display clock, running on a second-scale
    logic [2:1] disctr; // a display counter, running on a second-scale

    initial begin
        disctr = 2'b11;
        disclk =  'b0;
    end

    assign led6_b = disclk; // scaled-down clock visible on board as a blinking blue LED

    // scaling down disclk
    always @(posedge sysclk) begin
        if( ctr != 'd125000000) begin
            ctr <= ctr + 1'b1;
        end else begin
            disclk <= ~disclk;
            ctr <= 'b0;
        end
    end

    // change trigger to posedge disclk to see clock on the 1sec scale
    always @(posedge sysclk) begin
        disctr <= disctr + 1'b1;
    end
    
    logic ser; // output from PISO
    
    // mux the serial output to the appropriate LED
    always_comb begin
        casez (disctr)
            2'b00: led[3:0] = {  ser, 1'b0, 1'b0, 1'b0 };
            2'b01: led[3:0] = { 1'b0,  ser, 1'b0, 1'b0 };
            2'b10: led[3:0] = { 1'b0, 1'b0,  ser, 1'b0 };
            2'b11: led[3:0] = { 1'b0, 1'b0, 1'b0,  ser };
        endcase
    end

    u_PISO #(.BITS(4)) george(
        .Clock(sysclk),
        .Enable(1'b1),
        .PDataIn(sw[3:0]),
        
        .Busy(led5_r),
        .SDataOut(ser)
    );

endmodule


/******************************************************************************
**
** Name:   tb4_XIYO
**
** Desc.:  Executes full testbenches for the approved XIYO modules
**
** Author: Avinash Singh
**
******************************************************************************/

module tb4_XIYO();
    tb4_SIPO Simulated_SIPO(); // output is mapped to tb4_SIPO.wcfg
    tb4_PISO Simulated_PISO(); // output is mapped to tb4_PISO.wcfg
endmodule


/******************************************************************************
**
** Name:   tb4_SIPO
**
** Desc.:  Includes testbench for the approved SIPO module. Device is
**         instantiated with a width of 16 bits.
**
**
** Author: Avinash Singh
**
******************************************************************************/

module tb4_SIPO();

    logic clk = 1'b0; // clock starts low, but at initial t = 0 goes high
    initial begin
        forever #0.5us clk <= ~clk;  // 1us period
    end
    
    logic enb = 1'b1; // starting with a high enable during reset
    logic rst = 1'b1; // we start fresh with a reset signal on the SIPO
    logic bzs;        // our busy signal output
    
    // various codes used for testing
    logic [16:1] codeI   = 16'hABCD;
    logic [16:1] codeII  = 16'h1234;
    
    logic ser = 1'b1; // serial input
    logic plo;        // parallel output

    // SIPO instantiation
    u_SIPO #(.BITS(16)) tb_SIPO
    (
        .Clock(clk),
        .Reset(rst),
        .SDataI(ser),
        .Enable(enb),
        
        .Busy(bzs),
        .PDataO(plo)
    );
    
    initial begin

        // fire an enable during reset to see whaat happens
        enb <= 1'b1;
        #5us;
        enb <= 1'b0;
        
        #17us rst <= 1'b0; // drive reset low after 17 cycles
                
        // prep data at the edge for the enable
        #0.01us ser <= codeI[16];
        // now fire a valid enable
        #0.99us enb <= 1'b1;
        
        #0.01us;
        // feed codeI (0xABCD) into SIPO, MSB first 
        for (int i = 15; i > 0; i--) begin
            
            #1us ser <= codeI[i];
            
            // turn off enable randomly
            if(i == 7) begin
                enb <= 1'b0;
            end
        
        end
        
        // trying codeII now
        ser <= codeII[16];
        // align the enable edge back up and fire again
        #0.99us enb <= 1'b1;
        
        #0.01us;
        // feed codeII (0x1234) into SIPO, MSB first 
        for (int i = 15; i > 0; i--) begin
            
            #1us ser <= codeII[i];
            
            // turn off enable randomly
            if(i == 7) begin
                enb <= 1'b0;
            end
        
        end

        // fire a reset to make sure everything clears properly
        #5us rst <= 1'b1;
        #1us rst <= 1'b0;

        #5us; // verify that rst clears everything as intended
        $display("***SIPO test complete.***");
        $finish;
        
    end

endmodule


/******************************************************************************
**
** Name:   tb4_PISO
**
** Desc.:  Includes testbench for the approved PISO module.
**
** Author: Avinash Singh
**
******************************************************************************/

module tb4_PISO();


    logic clk = 1'b0; // clock starts low, but at initial t = 0 goes high
    initial begin
        forever #0.5us clk <= ~clk;  // 1us period
    end
    
    logic enb = 1'b1; // starting with a high enable during reset
    logic rst = 1'b1; // we start fresh with a reset signal on the SIPO
    logic bzs;        // our busy signal output
    
    // various codes used for testing
    logic [16:1] codeI   = 16'hABCD;
    logic [16:1] codeII  = 16'h1234;
    
    logic [16:1] pli = 16'hEEEE; // parallel input (init'd to an error code)
    logic ser;                   // serial output

    // SIPO instantiation
    u_PISO #(.BITS(16)) tb_PISO
    (
        .Clock(clk),
        .Reset(rst),
        .PDataIn(pli),
        .Enable(enb),
        
        .Busy(bzs),
        .SDataOut(ser)
    );
    
    initial begin
    
        // fire an enable during reset to see whaat happens
        enb <= 1'b1;
        #5us;
        enb <= 1'b0;
        
        #17us rst <= 1'b0; // drive reset low after 17 cycles

        // prep data at the edge for the enable
        #0.01us pli <= codeI;
        // now fire a valid enable
        #0.99us enb <= 1'b1;
        
        #0.01us;
        // feed codeI (0xABCD) into PISO 
        for (int i = 15; i > 0; i--) begin
            #1us;
            // switch off enable mid-operation
            if(i == 7) begin
                enb <= 1'b0;
            end
        end
        
        // trying codeII now
        pli <= codeII;
        // align the enable edge back up and fire again
        #0.99us enb <= 1'b1;
        
        #0.01us;
        // feed codeII (0x1234) into PISO 
        for (int i = 15; i > 0; i--) begin
            #1us;
            // switch off enable mid-operation
            if(i == 7) begin
                enb <= 1'b0;
            end
        end

        // fire a reset to make sure everything clears properly
        #5us rst <= 1'b1;
        #1us rst <= 1'b0;

        #5us; // verify that rst clears everything as intended
        $display("***PISO test complete.***");
        $finish;
        
    end

endmodule