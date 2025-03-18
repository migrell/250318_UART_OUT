`timescale 1ns / 1ps

module btn_debounce(
    input clk,
    input reset,
    input i_btn,
    output o_btn
  );

    //state 
    //reg state,next;
    reg [7:0] q_reg, q_next; //shift register
    reg edge_detect;
    wire btn_debounce;

    //1khz clk 

    reg [$clog2(100_000) - 1 :0]counter;
    reg r_1khz;
    always @(posedge clk, posedge reset) begin
        if(reset)begin
            counter <= 0;
            r_1khz <= 0; //출력 초기화 
        end else begin
              if(counter == 100_000 - 1) begin //1khz
                counter <= 0;
                r_1khz <= 1'b1; 
            end else begin // 1khz 1tick.
                counter = counter + 1;//다음번 카운트 = 현재카운트 값 + 1 
                r_1khz <= 1'b0;
            end
        end
    end
        
          
        
 
    // state logic ->shift register

    always @(posedge r_1khz, posedge reset) begin
        if(reset) begin
            q_reg <= 0;
        end else begin
           q_reg <= q_next;
      
    end
 end

    //next logic
    always @(i_btn, r_1khz) begin // eveent i_btn, r_1khz
        // q_reg 현재의 상위 7비트를 다음 하위 7비트에 넣고, 
        //최상위비트에는 i_btn을 넣어라 
 
       q_next = {i_btn, q_next[7:1]};  //shift의 동작 설명 8개-> 80bit
    end
 
    // 8 input AND gate -> shift register 8개사용해서 
    assign btn_debounce = &q_reg; //q_reg 7bit 


    //edge _detector ->FF사용, 100Mhz

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            edge_detect <= 1'b0;

        end else begin
            edge_detect <= btn_debounce;
    end
    end
    //edge detector의 최종 출력 

    assign o_btn = btn_debounce & (~edge_detect);



endmodule
