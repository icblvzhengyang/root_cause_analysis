#!/bin/csh

# source /opt/tools/env/cshrc.synopsys
source /home/project/sushi/Euclid/synopsys/cshrc.synopsys

verdi     \
  -2012   \
  -f ../fml/pkg.f \
  -f ../fml/dut.f \
  -f ../fml/sva.f \
  -ssf /home/project/zhengyang/hidden_bug_examples/cva6_mmu_ghost_response/fml/mmu_cex.fsdb
  # -ssf ../fml/mmu_cex.fsdb

