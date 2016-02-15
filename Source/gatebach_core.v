//gatebach_core.v
//multiple cores
//each core is responsible for the sieving by using 1 prime number

module gatebach_core(input clk,
                      input sys_rst_n,
                      input [64:0] start_addr,
                      //interrupt
                      output load_done,
                      output proc_done,
                      output store_done,
                      //input bus
                      input cs_in,
                      input [6:0] add_in,         //ranges from 0 to 99
                      input [31:0] data_in,
                      //output bus
                      output cs_out,
                      output [6:0] add_out,       //ranges from 0 to 99
                      output [31:0] data_out);

  localparam  SLICE_LENGTH = 3200;                //each slice has the size of 100*32 = 3200 bits
  localparam  CORE_NUM = 100;                     //100 virtual cores, each handles 1 prime number

  //system signals, shared by all cores
  reg           i_rst_n;                          //internal reset signal, asserts when the current job is finished
  reg           i_load_done;                      //for debugging, external signal
  reg           i_proc_done;                      //for debugging, external signal
  reg           i_store_done;                     //for debugging, external signal
  reg           i_cs_out;                         //register interface
  reg [6:0]     i_add_out;                        //register interface
  reg [31:0]    i_data_out;                       //register interface

  reg [6:0]     proc_cnt;                         //internal counter, counts up when the output of a core is merged to the output data

  //each core is composed in the following way
  //private memory belongs to each core
  reg [31:0]    prime_number   [0:CORE_NUM-1];    //used to store the 32-bit prime number
  reg [31:0]    remainder      [0:CORE_NUM-1];    //used to store the 32-bit remainder, which is supposed to be calculated by the DSP block
  reg           core_load_flag [0:CORE_NUM-1];    //used to store the load-complete-flag, shows the core has recieved a prime number
  reg           core_proc_flag [0:CORE_NUM-1];    //used to store the proc-complete-flag, shows the core has completed the sieving process
  reg [12:0]    core_pointer   [0:CORE_NUM-1];    //used to store the pointer of each core, pointers increment by each clock cycle and each time points to a number in the floor
  reg [31:0]    core_sieve_cnt [0:CORE_NUM-1];    //used to store the counter for each prime number, counters decrement by each clock cycle and resets when they reache 0

  //things that take huge amount of FPGA resources
  reg [SLICE_LENGTH-1:0] tmp_data [0:CORE_NUM-1]; //private memory belongs to each core, big enough to store the 3200-bit long slice
  wire[SLICE_LENGTH-1:0] wire_data [0:CORE_NUM-1];//tmp_data shifited by the amount of remainder

  //possibly the bottle neck
  reg [SLICE_LENGTH-1:0] data;                    //the final result

  assign load_done = i_load_done;
  assign proc_done = i_proc_done;
  assign store_done = i_store_done;
  assign cs_out = i_cs_out;
  assign add_out = i_add_out;
  assign data_out = i_data_out;
  assign rst_n = sys_rst_n & i_rst_n;

  //reset
  always @ (posedge clk) begin
    if(i_store_done == 1)
      i_rst_n <= 1;
    else if(i_rst_n)
      i_rst_n <= 0;
  end

  //load data-------------------------------------------------
  always @ (posedge clk) begin
    if(!rst_n)
      i_load_done <= 0;
    else if(core_load_flag[CORE_NUM-1] == 1)  //load_done asserts when the last core has finished loading data
      i_load_done <= 1;
  end

  genvar i;
  generate
  for(i = 0; i < CORE_NUM; i = i + 1) begin
    always @ (posedge clk) begin
      if(!rst_n) begin
        core_load_flag[i] <= 0;
        prime_number[i] <= 0;
      end
      else if(cs_in & (add_in == i)) begin
        core_load_flag[i] <= 1;
        prime_number[i] <= data_in;
      end
    end
  end
  endgenerate
  //----------------------------------------------------------

  //process data----------------------------------------------
  always @ (posedge clk) begin
    if(!rst_n)
      i_proc_done <= 0;
    else if(core_proc_flag[CORE_NUM-1] == 1)
      i_proc_done <= 1;
  end

  always @ (posedge clk) begin
    if(!rst_n) begin
      data <= {SLICE_LENGTH{1'b 1}};
      proc_cnt <= 0;
    end
    else
      if(core_proc_flag[proc_cnt] == 1) begin
        data <= data & wire_data[proc_cnt];
        proc_cnt <= proc_cnt + 1;
      end
  end

  genvar j;
  generate
  for(j = 0; j < CORE_NUM; j = j + 1) begin

    //combinatorial logic
    always @ (*) begin
      if(!rst_n)
        remainder[j] = 0;
      else if(core_load_flag[j] == 1)
        remainder[j] = start_addr % prime_number[j];
    end

    //sequential logic
    always @ (posedge clk) begin
      if(!rst_n)
        core_sieve_cnt[j] <= prime_number[j] - 1;
      else if(core_load_flag[j] == 1) begin
        if(core_sieve_cnt[j] == 0)
          core_sieve_cnt[j] <= prime_number[j] - 1;
        else
          core_sieve_cnt[j] <= core_sieve_cnt[j] - 1;
      end
    end

    always @ (posedge clk) begin
      if(!rst_n)
        core_pointer[j] <= 0;
      else if(core_load_flag[j] == 1) begin
        if(core_pointer[j] == SLICE_LENGTH-1)
          core_pointer[j] <= 0;
        else
          core_pointer[j] <= core_pointer[j] + 1;
      end
    end

    always @ (posedge clk) begin
      if(!rst_n)
        core_proc_flag[j] <= 0;
      else if(core_pointer[j] == SLICE_LENGTH-1)
        core_proc_flag[j] <= 1;
    end

    always @ (posedge clk) begin
      if(!rst_n)
        tmp_data[j] <= {SLICE_LENGTH{1'b 1}};
      else if(core_proc_flag[j] == 0)
        if(core_sieve_cnt[j] == 0)
          tmp_data[j][core_pointer[j]] <= 0;
    end

    //combinatorial logic
    assign wire_data[j] = core_proc_flag[j] ? ((tmp_data[j] << remainder[j]) | (tmp_data[j] >> (SLICE_LENGTH - remainder[j]))) : {SLICE_LENGTH{1'b 1}};

  end
  endgenerate
  //----------------------------------------------------------

  //store data------------------------------------------------
  always @ (posedge clk) begin
    if(!rst_n)
      i_cs_out <= 0;
    else if(i_proc_done == 1)
      i_cs_out <=1;
  end

  always @ (posedge clk) begin
    if(!rst_n) begin
      i_add_out <= 0;
      i_data_out <= 0;
    end
    else if(i_proc_done == 1) begin
      i_add_out <= i_add_out + 1;
      i_data_out <= data[ ((i_add_out + 1) << 5) -1 -: 32];
    end
  end

  always @ (posedge clk) begin
    if(!rst_n)
      i_store_done <= 0;
    else if(i_add_out == (SLICE_LENGTH>>5)-1)
      i_store_done <= 1;
  end
  //----------------------------------------------------------

endmodule
