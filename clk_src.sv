//////////////////////////////////////////////////////////////////////////////
//  Copyright 2016 Dov Stamler (dov.stamler@gmail.com)
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

// module: clk_source
// Create a clock source for the requested frequency/duty cycle. The clock starts
// toggling at a random phase. 
module clk_source(  input  real  freq_mhz,    // requested frequency value. Always use a real value even for an integer value (100.0)
                    input  int   duty_cycle,  // value between 1 and 99
                    input  logic enable_clk,  // one shot, once enabled, the clock toggles forever
                    output logic clk          // output clock
                 );

  timeunit 1ns/1ps;
  
  realtime  full_cycle_period;
  realtime  clk_high_time;
  realtime  clk_low_time;
  
//---------------------------------------------//  
function calc_clk_period();
  
  if (duty_cycle < 1 || duty_cycle > 99) $fatal("%m: duty_cycle must be between 1 and 99, value given is %0d", duty_cycle);
  
  full_cycle_period = (1s/(freq_mhz*1000000)) ;  // period is seconds. 

  clk_high_time = full_cycle_period * (real'(duty_cycle)/100);
  clk_low_time  = full_cycle_period * ( 1-(real'(duty_cycle)/100) );

  $display("%m: requested frequency = %0f full_cycle_period = %0fns, clk_high_time = %0fns, clk_low_time = %0fns", freq_mhz, full_cycle_period, clk_high_time, clk_low_time);
  
endfunction: calc_clk_period
//---------------------------------------------//
task create_random_phase();
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

    // values given at the port module are not always initialized at t=0 when this code begins execution. 
    // move the time 1 step to limit this propagation error 
    #1ps; 
    calc_clk_period();

    wait(enable_clk === 1'b1);

    create_random_phase();
    forever begin
      #(clk_low_time)  clk = ~clk;
      #(clk_high_time) clk = ~clk;
    end
  end
  
endmodule:clk_source
//--------------------------------------------------------------------//
//--------------------------------------------------------------------//
// example use of the clock source in a TB
// module tb();
//   timeunit 1ps/1ps;
//   wire clk1;
//   wire clk2;
//   
//   clk_source src_clk1(.freq_mhz(100.0), .duty_cycle(50), .enable_clk(1'b1), .clk(clk1) );
//   clk_source src_clk2(.freq_mhz(41.5),  .duty_cycle(70), .enable_clk(1'b1), .clk(clk2) );
// 
//   // wait N cycles before simulation finishes
//   initial begin
//     repeat(10) begin @(posedge clk1); $display("%t: clk1 posedge", $time); end
//     $finish;
//   end
// 
// endmodule: tb

`endif // CLK_SRC__SV
