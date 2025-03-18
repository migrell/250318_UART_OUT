`timescale 1ns / 1ps

// 버튼 디바운스 모듈
module btn_debounce (
    input clk,
    input reset,
    input i_btn,
    output reg o_btn
);
    // 1MHz 클럭으로 변경된 디바운스 타이밍
    parameter DEBOUNCE_TIME = 5000; // 5ms (1MHz 기준)
    reg [12:0] counter; // 5000을 저장하기 위한 비트 수
    reg btn_state;
    
    // 클럭 분주기 - 100MHz를 1MHz로 변환
    reg [6:0] clk_div_counter;
    reg clk_1mhz;
    
    // 100MHz → 1MHz 클럭 분주
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div_counter <= 0;
            clk_1mhz <= 0;
        end else begin
            if (clk_div_counter >= 49) begin // 100MHz를 1MHz로 분주 (50분주)
                clk_div_counter <= 0;
                clk_1mhz <= ~clk_1mhz; // 클럭 토글
            end else begin
                clk_div_counter <= clk_div_counter + 1;
            end
        end
    end
    
    // 버튼 디바운스 로직 (1MHz 클럭 기준)
    always @(posedge clk_1mhz or posedge reset) begin
        if (reset) begin
            counter <= 0;
            btn_state <= 0;
            o_btn <= 0;
        end else begin
            // 버튼 상태와 입력이 다르면 카운터 증가
            if (btn_state != i_btn) begin
                counter <= counter + 1;
                // 카운터가 설정 시간에 도달하면 상태 변경
                if (counter >= DEBOUNCE_TIME) begin
                    btn_state <= i_btn;
                    counter <= 0;
                end
            end else begin
                counter <= 0; // 입력이 안정적이면 카운터 리셋
            end
            
            // 상승 에지 감지 (0->1 전이)
            if ((btn_state == 1) && (o_btn == 0)) begin
                o_btn <= 1;
            end else begin
                o_btn <= 0; // 버튼을 한 번만 감지하기 위해 리셋
            end
        end
    end
endmodule