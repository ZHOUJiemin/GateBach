//gatebach_sieve.v

module gatebach_sieve(input clk,
                      input sys_rst_n,
                      input [64:0] start_addr,
                      //interrupt
                      output load_done,
                      output proc_done,
                      output store_done,
                      //input bus
                      input cs_in,
                      input [9:0] add_in,         //ranges from 0 to 999
                      input [31:0] data_in,
                      //output bus
                      output cs_out,
                      output [9:0] add_out,       //ranges from 0 to 999
                      output [31:0] data_out);    //each slice has the size of 1000*32 = 16000 bits

  reg           i_rst_n;

  reg           i_load_done;
  reg           i_proc_done;
  reg           i_store_done;
  reg           i_cs_out;
  reg [9:0]     i_add_out;
  reg [31:0]    i_data_out;

  reg [31:0]    prime_number [0:999];                //1000 parallelization
  reg           individual_load_flag [0:999];
  // reg [9:0]     load_cnt;

  reg [31:0]    remainder [0:999];
  reg [15999:0] tmp_data [0:999];
  wire[15999:0] wire_data [0:999];
  reg [15999:0] data;
  reg           individual_proc_flag [0:999];
  reg [14:0]    data_pointer [0:999];
  reg [31:0]    data_cnt_up [0:999];
  reg [9:0]     proc_cnt;

  reg [9:0]     store_cnt;

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
    else if(individual_load_flag[999] == 1)
      i_load_done <= 1;
  end

  // always @ (posedge clk) begin
  //   if(!rst_n)
  //     load_cnt <= 0;
  //   else if(cs_in)
  //     if(load_cnt == 999)
  //       load_cnt <= 0;
  //     else
  //       load_cnt <= load_cnt + 1;
  // end

  genvar i;
  generate
  for(i = 0; i < 999; i = i + 1) begin
    always @ (posedge clk) begin
      if(!rst_n) begin
        individual_load_flag[i] <= 0;
        prime_number[i] <= 0;
      end
      else if(cs_in & (add_in == i)) begin
        individual_load_flag[i] <= 1;
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
    else if(individual_proc_flag[999] == 1)
      i_proc_done <= 1;
  end

  always @ (posedge clk) begin
    if(!rst_n) begin
      data <= 16000'b 1;
      proc_cnt <= 0;
    end
    else
      if(individual_proc_flag[proc_cnt] == 1) begin
        data <= data & wire_data[proc_cnt];
        proc_cnt <= proc_cnt + 1;
      end
  end

  genvar j;
  generate
  for(j = 0; j < 999; j = j + 1) begin

    //combinatorial logic
    always @ (*) begin
      if(!rst_n)
        remainder[j] = 0;
      else if(individual_load_flag[j] == 1)
        remainder[j] = start_addr % prime_number[j];
    end

    //sequential logic
    always @ (posedge clk) begin
      if(!rst_n)
        data_cnt_up[j] <= prime_number[j] - 1;
      else
        if(data_cnt_up[j] == 0)
          data_cnt_up[j] <= prime_number[j] - 1;
        else
          data_cnt_up[j] <= data_cnt_up[j] - 1;
    end

    always @ (posedge clk) begin
      if(!rst_n)
        data_pointer[j] <= 0;
      else
        data_pointer[j] <= data_pointer[j] + 1;
    end

    always @ (posedge clk) begin
      if(!rst_n)
        individual_proc_flag[j] <= 0;
      else if(data_pointer[j] == 15999)
        individual_proc_flag[j] <= 1;
    end

    always @ (posedge clk) begin
      if(!rst_n)
        tmp_data[j] <= 16000'b 1;
      else if(individual_proc_flag[j] == 0)
        if(data_cnt_up[j] == 0)
          tmp_data[j][data_pointer[j]] <= 0;
    end

    //combinatorial logic
    // assign wire_data[j] = individual_proc_flag[j] ? {tmp_data[j][remainder[j] : 15999], tmp_data[j][0 : remainder[j] - 1]} : 16000'b 1;
    assign wire_data[j] = individual_proc_flag[j] ? ((tmp_data[j] << remainder[j]) | (tmp_data[j] >> (16000 - remainder[j]))) : 16000'b 1;

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
      store_cnt = 0;
    end
    else if(i_proc_done) begin
      i_add_out <= store_cnt;
      i_data_out <= data[ ((store_cnt + 1) << 5) -1 -: 32];
      store_cnt <= store_cnt + 1;
    end
  end

  always @ (posedge clk) begin
    if(!rst_n)
      i_store_done <= 0;
    else if(store_cnt == 999)
      i_store_done <= 1;
  end
  //----------------------------------------------------------

endmodule
