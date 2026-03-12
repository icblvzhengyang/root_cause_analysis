# The Task: Find the Root Cause of the violation

## The Case

The RTL design is located at `cases/cva6_mmu/rtl/`, with the top module as `mmu`.
And the SystemVerilog Assertion (SVA) properties are defined under `cases/cva6_mmu/sva/mmu_prop.sv`

The following Assertion as__dtlb_lookup_transid_was_a_request is violated:

```systemverilog
// Assert that every request has a response and that every reponse has a request
// as__dtlb_lookup_transid_eventual_response: assert property (|dtlb_lookup_transid_sampled |-> s_eventually(dtlb_res_val));
as__dtlb_lookup_transid_was_a_request: assert property (dtlb_lookup_transid_response |-> dtlb_lookup_transid_set || dtlb_lookup_transid_sampled);

```

And the waveform of the counter example has been transformed into the .csv format under `wave.csv`.

## How to do?

Track the signals from the point where the assertion violation happens, and keep going back to see why the assertion is triggerred. 
This is a iterative process: check the RTL, check the waveform, and check the RTL, ...
Summarize the reason that cause the trigger. Is it somewhere wrong in the RTL? Or is the assertion wrong? Or, are some neccessary SVA assumption properties missing? Or other reasons?

To achieve this, you need to build a toolkit to extract the informations you want from the waveform during the analyzing process.

Just perform the tracing-back, summarize and convince your judgement, and summarize it into a final report.

