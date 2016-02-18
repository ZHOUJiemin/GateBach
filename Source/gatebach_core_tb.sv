module tb_gatebach();

 localparam  HALF_CYCLE = 5;
 localparam  JOB_LENGTH = 2048;
 localparam  SLICE_LENGTH = 2048;
 localparam  CORE_NUM = 1;

 reg clk;
 reg rst_n;

 reg sieve_cs_out;
 reg [4:0] sieve_add_out;
 reg [31:0] sieve_data_out;

 wire sieve_cs_in;
 wire [5:0] sieve_add_in;
 wire [31:0] sieve_data_in;

 reg [31:0] byte_ram [64];

 wire gatebach_load_done;
 wire gatebach_proc_done;
 wire gatebach_store_done;

 reg store_done_flag;

 reg [31:0] start_addr0;
 reg [31:0] start_addr1;

 reg kick_start;
 reg enable;
 reg i_gatebach_intr;

 reg [21:0] frag_cnt;
 reg [5:0] out_cnt;

 reg [JOB_LENGTH-1 : 0] result;
 reg [SLICE_LENGTH-1: 0] result_frag;

 integer prime_list[32];

 //clock
 initial begin
   clk = 0;
   forever #HALF_CYCLE clk = ~clk;
 end

 //reset
 initial begin
   rst_n = 0;
   repeat(5) @(posedge clk);
   rst_n = 1;
   $display("@%0t: Reset released, Test Start!", $time);
 end

 //gatebach_core
 gatebach_core sieve(.clk(clk),
                     .rst_n(rst_n),
                     .start_addr({start_addr1, start_addr0}),
                     .load_done(gatebach_load_done),
                     .proc_done(gatebach_proc_done),
                     .store_done(gatebach_store_done),
                     .cs_in(sieve_cs_out),
                     .add_in(sieve_add_out),
                     .data_in(sieve_data_out),
                     .cs_out(sieve_cs_in),
                     .add_out(sieve_add_in),
                     .data_out(sieve_data_in),
                     .kick_start(kick_start));

  always @ (posedge clk) begin
    if(sieve_cs_in)
      byte_ram[sieve_add_in] <= sieve_data_in;
  end

  always @ (posedge clk) begin
    if(!rst_n)
      frag_cnt <= 0;
    else if(gatebach_store_done & !store_done_flag)
      frag_cnt <= frag_cnt + 1;
  end

  always @ (posedge clk) begin
    if(!rst_n)
      store_done_flag <= 0;
    else if(kick_start)
      store_done_flag <= 0;
    else if(gatebach_store_done)
      store_done_flag <= 1;
  end

  always @ (posedge clk) begin
    if(!rst_n)
      i_gatebach_intr <= 0;
    else if(frag_cnt == (JOB_LENGTH >> 11))
      i_gatebach_intr <= 1;
  end

  always @ (posedge clk) begin
    if(!rst_n)
      kick_start <= 0;
    else if(kick_start)
      kick_start <= 0;
    else if(enable & (frag_cnt < (JOB_LENGTH >> 11)) & gatebach_store_done) begin
      kick_start <= 1;
      $display("@%0t: Kick Start!", $time);
    end
  end

  always @ (posedge clk) begin
    if(!rst_n) begin
      sieve_cs_out <= 0;
      sieve_add_out <= 0;
      sieve_data_out <= 0;
    end
    else if(enable & (sieve_add_out < CORE_NUM) & (frag_cnt == 0)) begin
      sieve_cs_out <= 1;
      sieve_add_out <= out_cnt;
      sieve_data_out <= prime_list[out_cnt];
      $display("@%0t: Set %dth prime number = %d", $time, out_cnt, prime_list[out_cnt]);
    end
    else
      sieve_cs_out <= 0;
  end

  always @ (posedge clk) begin
    if(!rst_n) begin
      out_cnt <= 0;
    end
    else if(enable & (sieve_add_out < CORE_NUM))
      out_cnt <= out_cnt + 1;
  end

  initial begin
    prime_list[0] = 5;
    result = {JOB_LENGTH{1'b 1}};
    result_frag = {SLICE_LENGTH{1'b 1}};
    enable = 0;
    start_addr1 = 32'h 00000000;
    start_addr0 = 32'h 000000C9;

    repeat(10) @(posedge clk);

    #1 enable = 1;
    $display("@%0t: Enable asserted!", $time);

    for(int i = 0; i < JOB_LENGTH/SLICE_LENGTH; i++) begin
      while(!gatebach_store_done)
        @(posedge clk);
      $display("@%0t: Store Done detected! [Count %d]", $time, i);

      for(int j = 0; j < 64; j++) begin
        result_frag[(((j+1)<<5)-1) -: 32] &= byte_ram[i];
      end

      result[(i+1)*SLICE_LENGTH -1 -: SLICE_LENGTH] &= result_frag;
    end

    for(int i = 0; i < JOB_LENGTH; i++) begin
      if(result[i] == 1)
        $display("%d is not removed!", 2*i + 201);
      else if(result[i] == 0)
        $display("%d is removed!", 2*i + 201);
      else
        $display("Illegal result");
    end
  end

endmodule
