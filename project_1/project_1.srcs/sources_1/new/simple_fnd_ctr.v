// 7세그먼트 디스플레이 제어 모듈
module simple_fnd_controller (
    input clk,
    input reset,
    input [7:0] rx_data,
    input rx_done,
    output reg [7:0] fnd_font,
    output reg [3:0] fnd_comm
);
    // 초기화
    initial begin
        fnd_comm = 4'b1110; // 마지막 자리만 활성화 (active low)
        fnd_font = 8'b10000001; // '0' 표시
    end
    
    // 수신 데이터 저장 레지스터
    reg [7:0] display_data_reg;
    
    // 수신 완료 시 데이터 업데이트
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            display_data_reg <= 8'h30; // 기본값 '0'
            fnd_font <= 8'b10000001; // '0' 표시
        end else if (rx_done) begin
            display_data_reg <= rx_data; // 수신 데이터 저장
            
            // ASCII 코드를 7세그먼트 패턴으로 변환 (간단한 구현)
            case (rx_data)
                8'h30: fnd_font <= 8'b10000001; // '0'
                8'h31: fnd_font <= 8'b11001111; // '1'
                8'h32: fnd_font <= 8'b10010010; // '2'
                8'h33: fnd_font <= 8'b10000110; // '3'
                8'h41: fnd_font <= 8'b10001000; // 'A'
                8'h42: fnd_font <= 8'b10000011; // 'B'
                8'h43: fnd_font <= 8'b11000110; // 'C'
                8'h44: fnd_font <= 8'b10100001; // 'D'
                default: fnd_font <= 8'b11111111; // 모든 세그먼트 끄기
            endcase
        end
    end
endmodule