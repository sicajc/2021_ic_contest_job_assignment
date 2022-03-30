module JAM (input CLK,
              input RST,
              output  [2:0] W,
              output  [2:0] J,
              input [6:0] Cost,
              output reg [3:0] MatchCount,
              output [9:0] MinCost,
              output reg Valid);


  //Parmaters
  parameter POINT_ADDR = 3;
  parameter SORT_TIMES = 40320;
  parameter DATA_WIDTH = 10;
  //States
  parameter  IDLE     = 'd0;
  parameter  RD_ROM   = 'd1;
  parameter  MIN_CAL  = 'd2;
  parameter  FIND_REF = 'd3;
  parameter  REPLACE  = 'd4;
  parameter  FLIP     = 'd5;
  parameter  DONE     = 'd6;


  //Registers
  reg[POINT_ADDR-1:0] j_seq_reg[0:7];
  reg[POINT_ADDR-1:0] counter_reg;
  reg[POINT_ADDR-1:0] ref_index_reg;
  reg[DATA_WIDTH-1:0] min_reg;
  reg[POINT_ADDR-1:0] min_index_reg ;
  reg[15:0] sort_times_reg;
  reg[DATA_WIDTH-1:0] min_work_reg;

  wire[POINT_ADDR-1:0] counter_pointer_val;
  wire[POINT_ADDR-1:0] head_pointer;
  wire[POINT_ADDR-1:0] end_pointer;
  wire[POINT_ADDR-1:0] ref_point_val;

  assign counter_pointer_val = j_seq_reg[counter_reg];
  assign ref_point_val       = j_seq_reg[ref_index_reg];

  //FLAGS
  wire rd_rom_done_flag;
  wire done_flag;
  wire find_ref_done_flag;
  wire replace_done_flag;
  wire flip_done_flag;
  wire compare_val_gt_flag;
  wire min_work_lt_flag;
  wire min_work_eq_flag;
  wire is_min_flag;

  wire[2:0] test_counts;

  assign min_work_eq_flag   =( min_reg == min_work_reg);
  assign rd_rom_done_flag   = (counter_reg == 'd7) ;
  assign done_flag          = (sort_times_reg == SORT_TIMES-'d1);
  assign find_ref_done_flag = (j_seq_reg[counter_reg] > j_seq_reg[test_counts]);
  assign replace_done_flag  = (counter_reg == (ref_index_reg + 'd1)) ;
  assign flip_done_flag     =( head_pointer <= end_pointer);
  assign test_counts =( counter_reg - 'd1);

  assign compare_val_gt_flag = (counter_pointer_val > ref_point_val);
  assign is_min_flag         = (counter_pointer_val <  min_reg);
  assign min_work_lt_flag    = (min_reg < min_work_reg) ;

  reg[2:0] current_state,next_state;

  wire state_IDLE     ;
  wire state_FIND_REF ;
  wire state_REPLACE  ;
  wire state_FLIP     ;
  wire state_RD_ROM   ;
  wire state_MIN_CAL  ;
  wire state_DONE     ;

  assign state_IDLE     = current_state == IDLE;
  assign state_FIND_REF = current_state == FIND_REF;
  assign state_REPLACE  = current_state == REPLACE;
  assign state_FLIP     = current_state == FLIP;
  assign state_RD_ROM   = current_state == RD_ROM;
  assign state_MIN_CAL  = current_state == MIN_CAL;
  assign state_DONE     = current_state == DONE;


  //MAIN CTR
  always @(posedge CLK or posedge RST)
  begin
    current_state <= RST ? IDLE : next_state;
  end

  always @(*)
  begin
    case(current_state)
      IDLE:
      begin
        next_state = RD_ROM ;
        Valid      = 0;
      end
      RD_ROM:
      begin
        next_state = rd_rom_done_flag ? MIN_CAL : RD_ROM;
        Valid      = 0;
      end
      MIN_CAL:
      begin
        next_state = done_flag ? DONE : FIND_REF;
        Valid      = 0;
      end
      FIND_REF:
      begin
        next_state = find_ref_done_flag ? REPLACE : FIND_REF;
        Valid      = 0;
      end
      REPLACE:
      begin
        next_state = replace_done_flag ? FLIP : REPLACE;
        Valid      = 0;
      end
      FLIP:
      begin
        next_state = flip_done_flag ? RD_ROM : FLIP;
        Valid      = 0;
      end
      DONE:
      begin
        next_state = IDLE;
        Valid      = 1;
      end
      default:
      begin
        next_state = IDLE;
        Valid      = 0;
      end
    endcase
  end

  //counter_reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      counter_reg <= 'd0;
    end
    else
    begin
      case(current_state)
        IDLE:
        begin
          counter_reg <= 'd0;
        end
        RD_ROM:
        begin
          counter_reg <= counter_reg + 'd1;
        end
        MIN_CAL:
        begin
          counter_reg <= 'd7;
        end
        FIND_REF:
        begin
          counter_reg <= find_ref_done_flag ? 'd7: counter_reg - 'd1;
        end
        REPLACE:
        begin
          counter_reg <= replace_done_flag ? 'd7 : counter_reg - 'd1;
        end
        FLIP:
        begin
          counter_reg <= flip_done_flag ? 'd0 : counter_reg - 'd1;
        end
        default:
        begin
          counter_reg <= counter_reg;
        end
      endcase
    end
  end
  wire [2:0] ref_index;
  assign ref_index = counter_reg - 'd1;
  //ref_index_reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      ref_index_reg <= 'd0;
    end
    else
    begin
      case(current_state)
        IDLE:
        begin
          ref_index_reg <= 'd0;
        end
        FIND_REF:
        begin
          ref_index_reg <=  ref_index;
        end
        FLIP:
        begin
          ref_index_reg <= flip_done_flag ? 'd0 : ref_index_reg + 'd1;
        end
        default:
        begin
          ref_index_reg <= ref_index_reg;
        end
      endcase
    end
  end

  integer i;
  //j_seq_reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      for(i = 0;i<8;i = i+1)
      begin
        j_seq_reg[i] <= 'd0;
      end
    end
    else
    begin
      case(current_state)
        IDLE:
        begin
          for(i = 0;i<8;i = i+1) //! Synthesizable?
          begin
            j_seq_reg[i] <= i;
          end
        end
        REPLACE:
        begin
          j_seq_reg[ref_index_reg] <= replace_done_flag ? j_seq_reg[min_index_reg] : j_seq_reg[ref_index_reg];
          j_seq_reg[min_index_reg] <= replace_done_flag ? j_seq_reg[ref_index_reg] : j_seq_reg[min_index_reg];
        end
        FLIP:
        begin
          j_seq_reg[head_pointer] <= j_seq_reg[end_pointer] ;
          j_seq_reg[end_pointer] <= j_seq_reg[head_pointer] ;
        end
        default:
        begin
          for (i = 0 ;i<8 ;i = i+1)
          begin
            j_seq_reg[i] <= j_seq_reg[i];
          end
        end
      endcase
    end
  end

  wire[9:0] test_min_reg = min_reg + {3'b000,Cost};


  //min_reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      min_reg <= 'd7;
    end
    else
    begin
      case(current_state)
        IDLE:
        begin
          min_reg <= 'd0;
        end
        RD_ROM:
        begin
          min_reg <= min_reg + {3'b000,Cost};
        end
        MIN_CAL:
        begin
          min_reg <= 'd7;
        end
        REPLACE:
        begin
          min_reg <= compare_val_gt_flag ? (is_min_flag ? counter_pointer_val : min_reg ): min_reg;
        end
        FLIP:
        begin
          min_reg <= flip_done_flag ? 'd0 : min_reg;
        end
        default:
        begin
          min_reg <= min_reg;
        end
      endcase
    end
  end

  //min_index_reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      min_index_reg <= 'd7;
    end
    else
    begin
      case(current_state)
        IDLE:
        begin
          min_index_reg <= 'd0;
        end
        FIND_REF:
        begin
          min_index_reg <= ref_index + 'd1;
        end
        REPLACE:
        begin
          min_index_reg <= is_min_flag ? counter_reg : min_index_reg;
        end
        FLIP:
        begin
          min_index_reg <= flip_done_flag ? 'd0 : min_index_reg;
        end
        default:
        begin
          min_index_reg <= min_index_reg;
        end
      endcase
    end
  end

  assign head_pointer = counter_reg ;
  assign end_pointer  = ref_index_reg + 'b1 ;

  //sort times reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      sort_times_reg <= 'd0;
    end
    else if (state_FLIP)
    begin
      sort_times_reg <= flip_done_flag ?  sort_times_reg + 1 : sort_times_reg;
    end
    else
    begin
      sort_times_reg <= sort_times_reg;
    end
  end

  //min_work_Reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      min_work_reg <= 'd1023;
    end
    else if (state_MIN_CAL)
    begin
      min_work_reg <= min_work_lt_flag ? min_reg : min_work_reg;
    end
    else
    begin
      min_work_reg <= min_work_reg;
    end
  end


  //Match count reg
  always @(posedge CLK or posedge RST)
  begin
    if (RST)
    begin
      MatchCount <= 'd0;
    end
    else if (state_MIN_CAL)
    begin
      MatchCount <= min_work_lt_flag ? 'd1 : min_work_eq_flag ? MatchCount + 'd1 : MatchCount;
    end
    else
    begin
      MatchCount <= MatchCount;
    end
  end

  assign MinCost = state_DONE ? min_work_reg : 'd0;

  assign W = counter_reg;
  assign J = j_seq_reg[counter_reg];



endmodule
