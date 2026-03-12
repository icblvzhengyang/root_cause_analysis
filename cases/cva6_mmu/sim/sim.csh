#!/bin/csh

# source /opt/tools/env/cshrc.synopsys
source /home/project/sushi/Euclid/synopsys/cshrc.synopsys

vcs \
  -f pkg.f \
  -f dut.f \
  tb.sv \
  -debug_access+all \
  -sv=2012 \
  -timescale=1ns/1ns \
  -kdb \
  -o simv

./simv | tee sim.log

# echo "Comparing diff ..."
# diff sim.log.ok sim.log
