`timescale 1ns / 1ps

module send_tx_btn(
    input clk,
    input rst,
    input btn_start,
    output tx_done,
    output tx
);
    // 내부 신호 선언
    wire w_start, w_tx_done;
    reg [7:0] send_tx_data_reg, send_tx_data_next;
    
    // 버튼 디바운스 인스턴스화
    btn_debounce U_Start_btn(
        .clk(clk),
        .reset(rst),
        .i_btn(btn_start),
        .o_btn(w_start)
    );
    
    // UART 인스턴스화
    uart U_UART(
        .clk(clk),
        .rst(rst),
        .btn_start(w_start),
        .tx_data_in(send_tx_data_reg),
        .tx_done(w_tx_done),
        .tx(tx)
    );
    
    // tx_done 출력 신호 연결
    assign tx_done = w_tx_done;
    
    // 전송할 ASCII 코드 레지스터 업데이트
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            send_tx_data_reg <= 8'h30; // "0"
        end else begin
            send_tx_data_reg <= send_tx_data_next;
        end
    end
    
    // 다음 ASCII 코드 계산
    always @(*) begin
        send_tx_data_next = send_tx_data_reg;
        
        if(w_start == 1'b1) begin // 디바운스된 버튼 입력
            if(send_tx_data_reg == "z") begin
                send_tx_data_next = "0"; // 'z'에 도달하면 '0'으로 리셋
            end else begin
                send_tx_data_next = send_tx_data_reg + 1; // ASCII 코드 값 증가
            end
        end
    end
endmodule