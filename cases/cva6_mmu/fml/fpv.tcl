analyze -clear
analyze -sv12 \
  -f pkg.f \
  -f sva.f \
  -f dut.f

elaborate  \
  -top mmu

clock clk_i
reset ~rst_ni

autoprove -all -time_limit 15s
report

set_trace_optimization standard
visualize -violation -property mmu.u_mmu_sva.as__dtlb_lookup_transid_was_a_request -batch
visualize -save -fsdb mmu_cex.fsdb -force
