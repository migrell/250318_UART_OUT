// 버튼 디바운스 모듈
module btn_debounce(
    input clk,
    input reset,
    input i_btn,
    output o_btn
);
    // 내부 신호 선언
    reg [7:0] q_reg, q_next;  // 8비트 시프트 레지스터
    reg edge_detect;
    wire btn_debounce;
    
    // 1kHz 클럭 생성
    reg [$clog2(100_000) - 1:0] counter;
    reg r_1khz;
    
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            counter <= 0;
            r_1khz <= 0;
        end else begin
            if(counter == 100_000 - 1) begin  // 1kHz 주파수 생성
                counter <= 0;
                r_1khz <= 1'b1;
            end else begin
                counter <= counter + 1;
                r_1khz <= 1'b0;
            end
        end
    end
    
    // 시프트 레지스터 업데이트
    always @(posedge r_1khz, posedge reset) begin
        if(reset) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end
    
    // 다음 시프트 레지스터 값 계산
    always @(*) begin
        q_next = {i_btn, q_reg[7:1]};  // 최상위 비트에 새 입력, 나머지는 시프트
    end
    
    // 모든 비트가 1이면 안정적인 버튼 신호
    assign btn_debounce = &q_reg;
    
    // 엣지 검출 FF
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            edge_detect <= 1'b0;
        end else begin
            edge_detect <= btn_debounce;
        end
    end
    
    // 상승 엣지 검출 출력
    assign o_btn = btn_debounce & (~edge_detect);
endmodule