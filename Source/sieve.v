//Project DevCamp Gatebach -- isPrime
//Sieve of Erastotenis
//Modification History
//Date      Author        Note
//20160124  ZHOU Jiemin   Frame Creation
//20160131  ZHOU Jiemin   New Feature : Starts from a specified number

//Source code starts here------------------------------------
module isPrime#(parameter OUT_WIDTH = 10000)(input  wire                  clk,
                                             input  wire                  rst_n,
                                             output wire[OUT_WIDTH-1 : 0] result);

  parameter RANGE       = 10000;  //search for prime number up to 10000
  parameter RANGE_W     = 14;     //range width 10000 => 14 bits
  parameter UPPER_BOUND = 100;    //sieve by using the primes that range from 0 ~ 100
  parameter UPPER_BND_W = 7;      //upper bound width 100 => 7 bits
  parameter START       = 10;    //starts from a specified number

  localparam ISPRIME     = 1;
  localparam NOTPRIME    = 0;

  //prime list from 0 ~ 100
  //  1   2   3   4   5   6   7   8
  //  0   1   1   0   1   0   1   0
  //  9   10  11  12  13  14  15  16
  //  0   0   1   0   1   0   0   0
  //  17  18  19  20  21  22  23  24
  //  1   0   1   0   0   0   1   0
  //  25  26  27  28  29  30  31  32
  //  0   0   0   0   1   0   1   0
  //  33  34  35  36  37  38  39  40
  //  0   0   0   0   1   0   0   0
  //  41  42  43  44  45  46  47  48
  //  1   0   1   0   0   0   1   0
  //  49  50  51  52  53  54  55  56
  //  0   0   0   0   1   0   0   0
  //  57  58  59  60  61  62  63  64
  //  0   0   1   0   1   0   0   0
  //  65  66  67  68  69  70  71  72
  //  0   0   1   0   0   0   1   0
  //  73  74  75  76  77  78  79  80
  //  1   0   0   0   0   0   1   0
  //  81  82  83  84  85  86  87  88
  //  0   0   1   0   0   0   0   0
  //  89  90  91  92  93  94  95  96
  //  1   0   0   0   0   0   0   0
  //  97  98  99  100
  //  1   0   0   0
  parameter reg[UPPER_BOUND-1 : 0] sieve_list = 100'h 6a28a20a08a20828222820808;

  reg                          do_sieve[UPPER_BOUND];      // "do sieve" flag
  reg [RANGE-1 + START: START] i_result;                   // result 101 ~ 10000
  reg [RANGE-1 + START: START] tmp_result[UPPER_BOUND];    // sieve result for every number in the list
  reg [UPPER_BND_W-1:       0] cnt[UPPER_BOUND];           // counters for every number in the list
  reg [RANGE_W-1:           0] index[UPPER_BOUND];         // index for each number in the search range
  integer j;

  //process
  assign result = i_result;

  always @(*) begin
    if(!rst_n)
      i_result = {RANGE{1'b 1}};                        //set all bits to 1 when reset
    else begin
      for(j = 1; j <= UPPER_BOUND; j++)
        i_result = i_result & tmp_result[j];            //AND operation with each tmp result
    end
  end

  genvar i;
  generate
  for(i = 2; i <= UPPER_BOUND; i++) begin

    assign do_sieve[i-1] = sieve_list[UPPER_BOUND-i] ? 1 : 0;  //do sieving when the number in the list is prime

    //counter
    always @ (posedge clk) begin
      if(!rst_n)                                  //counter set to i when being reset
        cnt[i-1] <= START % i;
      else
        if(cnt[i-1] != 0)
          cnt[i-1] <= cnt[i-1] - 1;               //counter decrements by each clock cycle
        else
          cnt[i-1] <= i - 1;
    end

    //index
    always @ (posedge clk) begin
      if(!rst_n)
        index[i-1] <= i - 2;                       //index set to 2 when being reset
      else
        index[i-1] <= index[i-1] + 1;              //index increments by each clock cycle
    end

    //sieveing
    always @ (posedge clk) begin
      if(!rst_n) begin                           //set all bits to 1 when being reset
        tmp_result[i-1] <= {RANGE{1'b 1}};
      end
      else if(!do_sieve[i-1]) begin                //if not do_sieve
        tmp_result[i-1] <= {RANGE{1'b 1}};
      end
      else begin                                 //do sieve
        if(cnt[i-1] == 0)
          tmp_result[i-1][index[i-1]] <= NOTPRIME;
        else
          tmp_result[i-1][index[i-1]] <= ISPRIME;
      end
    end

  end
  endgenerate

endmodule
