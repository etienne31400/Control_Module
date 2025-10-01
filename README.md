run testbench:

ghdl -a --std=08 CONTROL_MODULE.vhd
ghdl -a --std=08 tb_CONTROL_MODULE.vhd
ghdl -e --std=08 tb_CONTROL_MODULE
ghdl -r --std=08 tb_CONTROL_MODULE --stop-time=20ms --vcd=wave.vcd
