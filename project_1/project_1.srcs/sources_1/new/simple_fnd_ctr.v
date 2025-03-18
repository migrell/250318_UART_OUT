module simple_fnd_controller (
    input clk,
    input reset,
    input [7:0] rx_data,
    input rx_done,
    output [7:0] fnd_font,
    output [3:0] fnd_comm
);
    // 마지막 자리만 활성화 (active low)
    assign fnd_comm = 4'b1110;
    
    // 수신 데이터 저장 레지스터
    reg [7:0] display_data_reg;
    
    // 수신 완료 시 데이터 업데이트
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            display_data_reg <= 8'h30; // 기본값 '0'
        end else if (rx_done) begin
            display_data_reg <= rx_data; // 수신 데이터 저장 
        end
    end
    // single clock 처리 -> 현재상태가지고 처리함 
        

    // 표시할 BCD 데이터 변환
    reg [3:0] display_bcd;
    
    // ASCII 코드를 BCD로 변환 (0-9, A-F 범위만 처리)
    always @(*) begin
        if (display_data_reg >= 8'h30 && display_data_reg <= 8'h39) begin
            // ASCII '0'-'9' -> BCD 0-9
            display_bcd = display_data_reg[3:0];
        end else if (display_data_reg >= 8'h41 && display_data_reg <= 8'h46) begin
            // ASCII 'A'-'F' -> BCD 10-15
            display_bcd = display_data_reg - 8'h41 + 4'd10;
        end else if (display_data_reg >= 8'h61 && display_data_reg <= 8'h66) begin
            // ASCII 'a'-'f' -> BCD 10-15
            display_bcd = display_data_reg - 8'h61 + 4'd10;
        end else begin
            // 다른 문자는 0으로 표시
            display_bcd = 4'h0;
        end
    end

    // BCD를 7세그먼트 패턴으로 변환
    reg [6:0] seg_pattern;
    
    // BCD를 7세그먼트 패턴으로 변환
    always @(*) begin
        case (display_bcd)
            4'h0: seg_pattern = 7'b1000000;  // 0
            4'h1: seg_pattern = 7'b1111001;  // 1
            4'h2: seg_pattern = 7'b0100100;  // 2
            4'h3: seg_pattern = 7'b0110000;  // 3
            4'h4: seg_pattern = 7'b0011001;  // 4
            4'h5: seg_pattern = 7'b0010010;  // 5
            4'h6: seg_pattern = 7'b0000010;  // 6
            4'h7: seg_pattern = 7'b1111000;  // 7
            4'h8: seg_pattern = 7'b0000000;  // 8
            4'h9: seg_pattern = 7'b0010000;  // 9
            4'hA: seg_pattern = 7'b0001000;  // A
            4'hB: seg_pattern = 7'b0000011;  // b
            4'hC: seg_pattern = 7'b1000110;  // C
            4'hD: seg_pattern = 7'b0100001;  // d
            4'hE: seg_pattern = 7'b0000110;  // E
            4'hF: seg_pattern = 7'b0001110;  // F
            default: seg_pattern = 7'b1111111; // 모든 세그먼트 끄기
        endcase
    end
    
    // 최종 출력: 소수점은 끔(1), seg_pattern(7비트)
    assign fnd_font = {1'b1, seg_pattern};
endmodule