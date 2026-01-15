//------------------------------------------------
// cdc.v
//------------------------------------------------
//
// clock domain crossing
// clock signal safely in to clk domain
// note, you should not fan out signal_out to more than one place
//
//------------------------------------------------
// see version control for rev info
//------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module cdc #(
    parameter FANOUT = 1
)(
    input wire clk,
    input wire signal_in,
    output wire signal_out
);

  // https://forums.xilinx.com/t5/Timing-Analysis/Understanding-ASYNC-REG-attribute/td-p/774023
  // The back-to-back flip-flop synchronizer is a mechanism of reducing the probability of a metastable event getting into the main part of your logic. For the metastable event to resolve, you need to give the metastable flip-flop time - there needs to be time between when the first flip-flop goes metastable and the second flip-flop samples it.
  // Without anything else, the tools see this as a "normal" static timing path - therefore the requirement on the path is one clock period of the destination clock. However, if the tools take a significant portion of that for routing, then there is less time for the metastable event to resolve. For any pair of flip-flops that are connected directly to each other (Q to D) that both have ASYNC_REG property set, the placer puts the flip-flops "as close together as possible" in order to minimize the routing between them and hence give as much time to metastability resolution. "As close as possible" means in the same slice, unless there is a conflict in the control set (which there usually shouldn't be).
  // The ASYNC_REG property also does some other things
  //  - it marks the FFs don't touch (so as not to disrupt their metastability resolution function)
  //  - it informs the simulator to not have the outputs go to X (unknown) on a setup/hold violation
  //  - it is used by report_cdc and report_synchronizer_mtbf as part of the validation and analysis of CDCs
  // The path from the source domain to the destination domain is not affected by the ASYNC_REG property (in fact, no timing analysis is affected) - you still need a timing exception on this path.

  (* ASYNC_REG = "TRUE" *) reg signal_meta = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg signal_sync = 1'b0;
  reg r_signal = 1'b0;

  always @(posedge clk) begin
    signal_meta <= signal_in;
    signal_sync <= signal_meta;
    // we can only safely read the output in one place, so add a fanout
    // flop to get two
  end

  generate
    if (FANOUT == 0) begin : gen_direct
      assign signal_out = signal_sync;
    end else begin : gen_fanout
      // fanout after cdc
      always @(posedge clk) begin
        r_signal <= signal_sync;
      end
      assign signal_out = r_signal;
    end
  endgenerate

endmodule

`resetall