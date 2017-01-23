//////////////////////////////////////////////////////////////////////////////
//  Copyright 2017 Dov Stamler (dov.stamler@gmail.com)
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//////////////////////////////////////////////////////////////////////////////

`ifndef CLK_SRC__SV
`define CLK_SRC__SV

// module: clk_src
//
// clock output toggles at the requested frequency/duty cycle. Variables are
// set via the set_clk_frequency method, usage example for both TB and environment are below.
//
// An interface type was chosen over a module allowing clock_source's to be controlled
// in an environment via a virtual interface. 
//
// API Methods:
// set_clk_frequency - set/update variables controlling the clock generation
// start_clk         - enables clk_src, needed only if source is already disabled
// halt_clk          - halts clock_source, clk output ceases to toggle
interface clk_src( output logic clk
                    );

  timeunit 1ns/1ps;
  
  logic     is_enabled          = 0; 
  real      current_freq_mhz    = 0;
  int       current_duty_cycle  = 0;

  realtime  full_cycle_period;
  realtime  clk_high_time;
  realtime  clk_low_time;
//---------------------------------------------//  
// function: set_clk_frequency
// freq_mhz   - requested frequency value in MHz
// duty_cycle - requested duty cycle, value between 1-99
// enable_clk - set if the clocks should be enabled at the end of the configuration
function automatic set_clk_frequency(real freq_mhz = 10.0, int  duty_cycle = 50, bit enable_clk = 1);
  
  if (duty_cycle < 1 || duty_cycle > 99) $fatal("%m: duty_cycle must be between 1 and 99, value given is %0d", duty_cycle);
  
  full_cycle_period = (1s/(freq_mhz*1000000)) ;  // period is seconds. 

  clk_high_time = full_cycle_period * (real'(duty_cycle)/100);
  clk_low_time  = full_cycle_period * ( 1-(real'(duty_cycle)/100) );

  $display("%m: requested frequency = %0f full_cycle_period = %0fns, clk_high_time = %0fns, clk_low_time = %0fns", freq_mhz, full_cycle_period, clk_high_time, clk_low_time);
  
  if(enable_clk) start_clk();

  current_freq_mhz   = freq_mhz;
  current_duty_cycle = duty_cycle;

endfunction: set_clk_frequency
//---------------------------------------------//
// enables current clock_source if halted
function automatic start_clk();
  is_enabled = 1;
  $display("%m: clock enabled @ %0t ns", $time/1ns);
endfunction: start_clk
//---------------------------------------------//
// halts current clock_source
function automatic halt_clk();
  is_enabled = 0;
  $display("%m: clock halted @ %0t ns", $time/1ns);
endfunction: halt_clk
//---------------------------------------------//
task automatic create_random_phase();
  logic [31:0]  period_int;
  logic [31:0]  phase_delay_int;
  
  period_int = full_cycle_period * 1ns/1ps; // convert the period to an integer number, maintain decimal point values
  
  phase_delay_int = $urandom_range(0, period_int-1); // minus 1 since the full amount will be the full phase_delay
  
  $display("%m: waiting a phase delay of %0.3f", real'(phase_delay_int)/(1ns/1ps) );
  
  #(real'(phase_delay_int)/(1ns/1ps)); // wait the fractal value calculated
  
endtask: create_random_phase
//---------------------------------------------//
// clock generation thread
  initial begin : clock_toggle_thread
    clk <= 0;

    forever begin
      wait(is_enabled === 1'b1);
      create_random_phase();
      while(is_enabled === 1'b1) begin
        #(clk_low_time)  clk = ~clk;
        #(clk_high_time) clk = ~clk;
      end
    end
  end
  
endinterface:clk_src
//--------------------------------------------------------------------//
//---------------------------- Coding examples -----------------------//
//--------------------------------------------------------------------//
// example use of the clock source in a TB
//----------------------------------------
// 1. instantiate the clock source in the TB
// 2. in an initial statement, set the clock variables. clk2 is an example of
//    a delayed start of the clock source
//------------------//
// module tb();
//   timeunit 1ps/1ps;
//   wire clk1;
//   wire clk2;
//   
//   clk_src src_clk1(.clk(clk1) );
//   clk_src src_clk2(.clk(clk2) );
// 
//   initial begin
//     src_clk1.set_clk_frequency( .freq_mhz(100.0), .duty_cycle(50), .enable_clk(1) );
//     src_clk2.set_clk_frequency( .freq_mhz(41.5),  .duty_cycle(70), .enable_clk(0) );
//   end
//   
//   // wait N cycles before simulation finishes
//   initial begin
//     repeat(40) @(posedge clk1);
//     src_clk2.start_clk();
//     repeat(40) @(posedge clk2); // start clk2 after N cycles
//   end
// 
// endmodule: tb
//----------------------------//
// example of control via an environment (UVM based)
//i-------------------------------------------------
// 1. instantiate source in the TB
// 2. set the clock source to the config_db
// 3. in the environment, retrieve the virtual pointer 
// 4. set the clock frequency, in this example setting it @ t=0
// 5. clock settings can be modified by calling the "set_clk_frequency" at any time throughout
//    the simulation
//----------------------------//
// module tb();
//   timeunit 1ps/1ps;
//   wire clk1;
//   wire clk2;
//   
//   clk_src src_clk1(.clk(clk1) );
//   .
//   .
//   initial uvm_config_db #(virtual clk_src)::set(null, "uvm_test_top", "clk_src1", clk_src1);
//   
// endmodule: tb
//----------------------------//
// class my_env extends uvm_env;
// // boilerplate code excluded
// 
// virtual clk_src clk_src1;
//
//----------------------------//
// function void build_phase(uvm_phase phase);
//   super.build_phase(phase);
//   if (!uvm_config_db#(virtual clk_src)::get(null, "uvm_test_top", "clk_src1", clk_src1))
//    `uvm_fatal("CFGERR", "clk_src1 not set");
//   .
//   .
// endfunction: build_phase
//----------------------------//
// function void start_of_simulation_phase(uvm_phase phase);
//   super.start_of_simulation_phase(phase);
//  
//   clk_src1.set_clk_frequency( .freq_mhz(32.0), .duty_cycle(50), .enable_clk(1) );
//
// endfunction: start_of_simulation_phase
// .
// .
// endclass: my_env

`endif // CLK_SRC__SV
