#!/bin/csh

# source /opt/tools/env/cshrc.synopsys
source /home/project/sushi/Euclid/synopsys/cshrc.synopsys

verdi     \
  -2012   \
  -top tb \
  -dbdir ./simv.daidir/ \
  -ssf ./test.fsdb
