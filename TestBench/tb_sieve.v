//Project DevCamp Gatebach -- isPrime(TB)
//Test bench
//Modification History
//Date      Author        Note
//20160124  ZHOU Jiemin   Frame Creation

//Source code starts here----------------------------------
module tb_isPrime();

  `timescale 1ns / 1ps

  parameter HALF_CYCLE = 5;    //clock 100MHz
  parameter OUT_WIDTH  = 10000;
  parameter RANGE = 10000;


  reg                   clk;
  reg                   rst_n;
  wire [OUT_WIDTH-1: 0] result;
  integer               cnt;

  //Clock
  initial begin
    clk = 0;
    forever #HALF_CYCLE clk = ~clk;
  end

  //instantiation
  isPrime isPrime_inst(.clk(clk), .rst_n(rst_n), .result(result));

  //Sequence
  initial begin
    cnt = 0;
    rst_n = 0;
    repeat(2) @(posedge clk); //release reset after 2 cycles
    rst_n = 1;
    $display("@%0t: Reset De-asserted! Test Start!", $time);
    repeat(RANGE) @(posedge clk); //run 10000 cycle
    $display("@%0t: Test Done!", $time);
    $display("    1 is not a Prime");
    for(cnt=2; cnt<=RANGE; cnt++) begin
      if(result[cnt-1] == 1)
        $display("%5d is a Prime", cnt);
      else if(result[cnt-1] == 0)
        $display("%5d is not a Prime", cnt);
      else
        $display("WTF?!");
    end
    $finish;
  end

endmodule
