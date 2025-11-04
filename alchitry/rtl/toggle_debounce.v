
// based on:
// https://www.ganssle.com/debouncing-pt2.htm

// note, this produces a clean continuous state output.
// it does not produce pulses on either edge
// it is good for toggle switches

// One bit of cleverness lurks in the algorithm. As long as the switch isn't closed ones shift through State. When
// the user pushes on the button the stream changes to a bouncy pattern of ones and zeroes, but at some point
// there's the last bounce (a one) followed by a stream of zeroes. We OR in 0xe000 to create a "don't care"
// condition in the upper bits. But as the button remains depressed State continues to propagate zeroes. There's
// just the one time, when the last bouncy "one" was in the upper bit position, that the code returns a TRUE. That
// bit of wizardry eliminates bounces and detects the edge, the transition from open to closed.
//
`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module toggle_debounce #(
        parameter integer N         = 8   // number of inputs
        //parameter integer L         = 16,  // shift register length (e.g., 16 like the 0xE000/0xF000 example)
        //parameter integer DC_BITS   = 3    // number of upper "don't care" bits set to 1 (e.g., 3 for 0xE000)
    )(
        input  wire                 clk,       // system clock        
        input  wire                 tick,      // one-clock-wide strobe at the desired sample rate
        input  wire [N-1:0]         raw_in,    // raw inputs: 0 = closed, 1 = open
        output wire [N-1:0]         state //  debounced level: 0 = closed, 1 = open
    );

    // Sanity checks (synthesis-time)
    // L must be >= (DC_BITS + 1) to form a valid compare constant
    // If your tool supports $error for parameters, you can add it, otherwise ensure parameters are set correctly.

    // Two-flop synchronizer for asynchronous inputs
    reg [N-1:0] sync1, sync2;

    initial begin
        // Initialize to "open" to avoid spurious pulses at startup
        sync1 = {N{1'b1}};
        sync2 = {N{1'b1}};
    end

    always @(posedge clk) begin
        sync1 <= raw_in;
        sync2 <= sync1;
    end

    // Create masks:
    // OR_MASK   = top DC_BITS set to 1, rest 0 (e.g., 0xE000 when L=16, DC_BITS=3)
    // COMP_MASK = top (DC_BITS+1) set to 1, rest 0 (e.g., 0xF000 when L=16, DC_BITS=3)
    localparam [15:0] OR_MASK   = 16'hE000;
    localparam [15:0] COMP_MASK = 16'hF000;

    // Per-channel shift registers
    // sh_press   operates on raw input (detects transition to 0 = pressed/closed)
    // sh_release operates on inverted input (detects transition to 1 = released/open)
    reg [15:0] sh_press   [0:N-1];
    reg [15:0] sh_release [0:N-1];

    // Debounced output register
    reg [N-1:0] state_reg;

    integer i;
    initial begin
        state_reg = {N{1'b1}}; // start "open"
        for (i = 0; i < N; i = i + 1) begin
            sh_press[i]   = 16'hFFFF;
            sh_release[i] = 16'hFFFF;
        end
    end
    
    always @(posedge clk) begin
        if (tick) begin
            for (i = 0; i < N; i = i + 1) begin
                // Press detection (closed = 0): last "1" followed by zeros
                sh_press[i]   <= ({sh_press[i][14:0], sync2[i]}) | OR_MASK;

                // Release detection (open = 1): mirror the trick with inverted input
                // Detect last "1" (in the inverted stream) followed by zeros,
                // which corresponds to last "0" followed by ones on the raw input.
                sh_release[i] <= ({sh_release[i][14:0], ~sync2[i]}) | OR_MASK;

                // Update the debounced level only when an edge is confirmed
                if (sh_press[i] == COMP_MASK) begin
                    state_reg[i] <= 1'b0; // debounced press: closed
                end else if (sh_release[i] == COMP_MASK) begin
                    state_reg[i] <= 1'b1; // debounced release: open
                end
            end
        end
    end

    assign state = state_reg;

endmodule
`resetall
