# TCL File Generated by Component Editor 15.1
# Fri Nov 03 10:05:09 PDT 2017
# DO NOT MODIFY


#
# interrupt_generator "Interrupt Generator" v1.0
#  2017.11.03.10:05:09
#
#

#
# request TCL package from ACDS 15.1
#
package require -exact qsys 15.1


#
# module interrupt_generator
#
set_module_property DESCRIPTION ""
set_module_property NAME interrupt_generator
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property GROUP "VectorBlox Computing Inc./Test Components"
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME "Interrupt Generator"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false


#
# file sets
#
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL interrupt_generator
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file interrupt_generator.vhd VHDL PATH interrupt_generator.vhd TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE true
add_fileset_file interrupt_generator.vhd VHDL PATH interrupt_generator.vhd TOP_LEVEL_FILE

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VHDL ENABLE_FILE_OVERWRITE_MODE true
add_fileset_file interrupt_generator.vhd VHDL PATH interrupt_generator.vhd TOP_LEVEL_FILE


#
# parameters
#


#
# display items
#


#
# connection point clock
#
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


#
# connection point reset
#
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset reset reset Input 1


#
# connection point s0
#
add_interface s0 avalon end
set_interface_property s0 addressUnits WORDS
set_interface_property s0 associatedClock clock
set_interface_property s0 associatedReset reset
set_interface_property s0 bitsPerSymbol 8
set_interface_property s0 burstOnBurstBoundariesOnly false
set_interface_property s0 burstcountUnits WORDS
set_interface_property s0 explicitAddressSpan 0
set_interface_property s0 holdTime 0
set_interface_property s0 linewrapBursts false
set_interface_property s0 maximumPendingReadTransactions 0
set_interface_property s0 maximumPendingWriteTransactions 0
set_interface_property s0 readLatency 0
set_interface_property s0 readWaitTime 1
set_interface_property s0 setupTime 0
set_interface_property s0 timingUnits Cycles
set_interface_property s0 writeWaitTime 0
set_interface_property s0 ENABLED true
set_interface_property s0 EXPORT_OF ""
set_interface_property s0 PORT_NAME_MAP ""
set_interface_property s0 CMSIS_SVD_VARIABLES ""
set_interface_property s0 SVD_ADDRESS_GROUP ""

add_interface_port s0 address address Input 2
add_interface_port s0 chipselect chipselect Input 1
add_interface_port s0 write write Input 1
add_interface_port s0 writedata writedata Input 32
add_interface_port s0 waitrequest waitrequest Output 1
set_interface_assignment s0 embeddedsw.configuration.isFlash 0
set_interface_assignment s0 embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment s0 embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment s0 embeddedsw.configuration.isPrintableDevice 0


#
# connection point int_out
#
add_interface int_out interrupt end
set_interface_property int_out associatedAddressablePoint ""
set_interface_property int_out associatedClock clock
set_interface_property int_out associatedReset reset
set_interface_property int_out bridgedReceiverOffset ""
set_interface_property int_out bridgesToReceiver ""
set_interface_property int_out ENABLED true
set_interface_property int_out EXPORT_OF ""
set_interface_property int_out PORT_NAME_MAP ""
set_interface_property int_out CMSIS_SVD_VARIABLES ""
set_interface_property int_out SVD_ADDRESS_GROUP ""

add_interface_port int_out int_out irq Output 1
