//Project DevCamp Gatebach -- (TB)
//Test bench
//Modification History
//Date      Author        Note
//20160124  ZHOU Jiemin   Frame Creation
//20160131  ZHOU Jiemin   New Feature : Starts from a specified number
//20160214  ZHOU Jiemin   Gatebach Core v1.0

//Source code starts here----------------------------------
module tb_gatebach();

 `timescale 1ns / 1ps

 localparam HALF_CYCLE = 5;               //clock 100MHz

 localparam JOB_LENGTH = 3200;
 localparam unsigned START = 4000000000000000001;
 localparam SLICE_LENGTH = 3200;

 reg                      clk;
 reg                      rst_n;

 reg                      cs_in;
 reg [6:0]                add_in;
 reg [31:0]               data_in;

 wire                     cs_out;
 wire [6:0]               add_out;
 wire [31:0]              data_out;

 wire                     load_done;
 wire                     proc_done;
 wire                     store_done;

 reg [JOB_LENGTH-1: 0]    result;

 integer                  prime_list[0:99];

 //Clock
 initial begin
   clk = 0;
   forever #HALF_CYCLE clk = ~clk;
 end

 //instantiation
 gatebach_core sieve( .clk(clk),
                      .sys_rst_n(rst_n),
                      .start_addr(START),
                      .load_done(load_done),
                      .proc_done(proc_done),
                      .store_done(store_done),
                      .cs_in(cs_in),
                      .add_in(add_in),         //ranges from 0 to 99
                      .data_in(data_in),
                      .cs_out(cs_out),
                      .add_out(add_out),       //ranges from 0 to 99
                      .data_out(data_out));

 //Sequence
 initial begin
   $dumpfile("~/portal/devcamp/dump.vcd");
   $dumpon;

   //initialization
   rst_n = 0;
   prime_list[0] = 3;
   prime_list[1] = 5;
   for(int i = 2; i < 100; i++)
     prime_list[i] = 2;
   result = 'b 1;

   repeat(2) @(posedge clk); //release reset after 2 cycles
   rst_n = 1;
   $display("@%0t: Reset De-asserted! Test Start!", $time);

   repeat(2) @(posedge clk); //after 2 cycles

   //set prime number
   for(int i = 0; i < 100; i++) begin
     cs_in = 1;
     add_in = i;
     data_in = prime_list[i];
     @(posedge clk);
    //  $display("@%0t: Set %dth prime number: %d", $time, i, prime_list[i]);
   end

   while(!load_done)
     @(posedge clk);
   $display("@%0t: Flag load_done detected!", $time);

   while (!proc_done)
     @(posedge clk);
   $display("@%0t: Flag proc_done detected!", $time);

   while(!store_done) begin
     if(cs_out) begin
       result[(((add_out + 1)<<5)-1) -: 32] &= data_out;
       $display("@%0t: Acquiring Data from %d to %d", $time, (int'(add_out)<<5), ((add_out + 1)<<5)-1);
     end
     @(posedge clk);
   end
   $display("@%0t: Flag store_done detected, Test Done!", $time);

   for(int i = 0; i < SLICE_LENGTH; i++) begin
     if(result[i] == 1)
       $display("%4d is not removed", 2*i + START);
     else if(result[i] == 0)
       $display("%4d is removed", 2*i + START);
     else
       $display("WTF?!");
   end
   $dumpoff;
   $finish;
 end

endmodule
