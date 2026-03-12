fsdbreport - fsdb reportor, Release Verdi_N-2017.12-SP2 (RH Linux x86_64/64bit) -- Sun May 27 03:57:32 PDT 2018

Copyright (c) 1996 - 2018 Synopsys, Inc.
This software and the associated documentation are proprietary to Synopsys, Inc. 
This software may only be used in accordance with the terms and conditions of a written license agreement with Synopsys, Inc. 
All other use, reproduction, or distribution of this software is strictly prohibited.


Usage: fsdbreport fsdb_file_name [-f config_file]
       [-bt time[unit]] [-et time[unit]] 
       [-nocase] [-w column_width] [-of output_format] [-verilog|-vhdl]
       -s {signal [-level level_depth] [-a name] [-w column_width] 
                  [-af alias_file] [-of [b|o|d|u|h]] [-verilog|-vhdl] 
                  [-precision precision_value] } 
       [-strobe [signal=="value"] [-a name] [-w column_width] 
                                    [-verilog|-vhdl] ]
       [-exp expression [-a name] [-w column_width] ]
       [-levelstrobe signal=="value" [-a name] [-w column_width] 
                                       [-verilog|-vhdl] ]
       [-shift shift_time | -shiftneg shiftneg_time]
       [-partition_sig_list file_name file_count]
       [-period period_time]
       [-cn column_number] [-o reported_file_name]
       [-pt time_precision]
       [-log [log_file_name]]
       [-find_forces  [-no_value] [-no_fdr_glitch]]

Options:
  -a alias_name
       Define the alias for the output signal.
  -af alias_file
       Specify an nWave waveform alias file.
  -bt time[unit]
       Specify the begin time of the report. If omitted, the begin time of the
       FSDB file is used. The time-unit can be Ms, Ks, s, ms, us, ns, ps, or fs.
       The default time unit is ns.
  -cn column_number
       Define the number of columns for the report, including the time 
       column. Column number can be set to be 0 or an integer larger than 1.
       When setting to 0, the signal name and its value will not be printed 
       in the format of a table, but line by line.
       This option will be ignored if the -csv option is also specified.
  -csv
       Save the output report file in CSV format.
       If this option is specified with -cn and -w, the -cn and -w options 
       will be ignored. 
       If the selected signals contain stream, coverage, or SVA type signals, 
       the -csv option is ignored and non-csv format will be output.
  -et time[unit]
       Specify the end time of the report. If omitted, the end time of the FSDB
       is used. The time-unit can be Ms, Ks, s, ms, us, ns, ps, or fs.
       The default time unit is ns.
  -exclude_scope scope_name
       Exclude signals under the specified scopes. Each scope should be enclosed with
       double quotes. To exclude sub-scopes of the specified scopes, the wildcard 
       character "*" must be appended in the end of the scopes.
       This option must be used with the -find_forces option.
       Example:
       ##comment
       -find_forces -exclude_scope "/system/i_cpu/*" "/system/s1" 
       #comment
  -exp expression
       Report values when the expression changes to true(==1).
  -f config_file
       Specify a text file which defines all the options except -h and -f.
       The pound sign (#) can be added to the beginning of a line as a comment line.
       Example:
       ##comment
       -bt 10 -et 100 -s "/system/i_cpu/*"
       #comment
  -find_forces
       Show signals with force, release, or deposit events and the signal values.
  -help | -h 
       Print out this usage.
  -level level_depth
       Specify the number of levels to be dumped under the specified scope. This option
       must be used with -s.
       When setting to 0, all signals below the specified scope are dumped.
  -levelstrobe "expression"
       Dump values when the strobe signal value is the same
       as the specified value (level sampling).
       -strobe and -levelstrobe cannot be used together.
  -log [log_file_name] 
       Specify the output log file.
       The default file name is err.log.
  -no_fdr_glitch
       Show the stable value for force, release, and deposit events. This option is
       optional and must be used with -find_forces; otherwise, it will be ignored.
  -no_value
       Disable value display of force, release, and deposit events. This option is
       optional and must be used with -find_forces; otherwise, it will be ignored.
  -nocase
       When included, the mapping of signal names will not be case sensitive.
  -nolog
       Disable generation of the fsdbreportLog log directory.
  -o reported_file_name 
       Specify the output report file name.
  -of [b|o|d|u|h]
       Define the output display format as binary, octal,
       decimal, unsigned decimal or hexadecimal.
  -partition_sig_list
       Specify partition signal list and counts.
  -period period_time
       Dump values at each specified time.
  -precision precision_value
       Define the precision (the number of decimal places to include) of
       output values for analog signal types. This option is ignored for
       digital signal types.
  -pt time_precision
       Define the time precision (the number of decimal places to include)
       of output values for analog signal types. This option is ignored for
       digital signal types.
  -s {signal_name [options]}
       Specify the signals or scopes to be reported.
       When specifying a scope name, the wildcard character "*" must
       be appended to the end with double quotes. Refer to the Examples
       section for usage examples.
  -shift | -shiftneg time[unit]
       Specify to shift (puls) or shiftneg (minus) the report time when the strobe
       signal matches the specified value. The option must be used with -strobe.
  -strobe "expression"
       Report values when the value of the strobe signal changes to the
       specified value (edge sampling).
  -verilog | -vhdl
       Specify the output format as Verilog or VHDL format.
  -w column_width
       Define the width of the signal column. For the strobe, level_strobe or expression signal, if the width
       is less than the maximum time width, the width will be automatically expanded to the maximum time width.
       This option will be ignored if the -csv option is also specified.

Examples:
  1. Assign the begin time and end time for the report.
     %fsdbreport verilog.fsdb -s /system/addr -bt 1000ps -et 2000ps 

  2. Report a slice of a bus signal. 
     %fsdbreport verilog.fsdb -s "/system/addr[7:4]"

  3. Report signals in the signal list with different formats.
     %fsdbreport fsdb/vhdl_typecase.fsdb -nocase -s top/A_SIMPLE_REC.FIELD3
      -a simple.field3 -w 15 TOP/A_COMPLEX_REC.F1.FIELD3 -a complex.f1.field3
      -w 20 top/a_std_logic_vector -af sean2.alias -of a -o output.txt
      -bt 1000 -et 2000

  4. Report a scope and its descendants. Multiple scopes may be specified.
     %fsdbreport rtl.dump.fsdb -bt 10 -et 100 -s "/system/i_cpu/*" 
      -level 3 /system/i_pram/clock -cn 0

  5. Report the results for the specified strobe point using -strobe.
     %fsdbreport verilog.fsdb -strobe "/system/clock==1" -s /system/data 
      /system/addr

  6. Report the results when the expression value changes to true.
     %fsdbreport verilog.fsdb -exp "/system/addr=='h30 & /system/clock==1"
      -s /system/data 

  7. Report the force, release or deposit information of the specified signals using -find_forces.
     %fsdbreport rtl.fsdb -find_forces -s "/system/i_cpu/*" -level 2 -o report.txt

  8. Report the force of the specified signals using -find_forces and -exclude_scope.
     %fsdbreport rtl.fsdb -find_forces -s "/system/i_cpu/*" -exclude_scope "/system/i_cpu/s1/*" "/system/i_cpu/s2" -o report.txt