#!/bin/csh
# source /opt/tools/env/cshrc.synopsys
source /home/project/sushi/Euclid/synopsys/cshrc.synopsys

# echo "======== assertEval ========"
# assertEval -help
# echo "======== fsdbdebug ========"
# fsdbdebug -help
# echo "======== fsdbreport ========"
# fsdbreport -help
# echo "======== fsdbSwAnalysis ========"
# fsdbSwAnalysis -help

fsdbreport cases/cva6_mmu_ghost_response/fml/mmu_cex.fsdb -s "*" -csv -o wave.csv -strobe "mmu/clk_i==1"
