// Basys3 보드용 TOP 모듈
module TOP_UART (
    input clk,
    input rst,
    input rx,
    input btnU, btnL, btnR, btnD,
    output tx,
    output [7:0] fnd_font,
    output [3:0] fnd_comm
);
    // UART 통신 관련 신호
    wire w_rx_done;          // 수신 완료 신호
    wire [7:0] w_rx_data;    // 수신된 데이터
    wire tx_done;            // 송신 완료 신호
    
    // 버튼 제어를 위한 변수
    reg [7:0] tx_data_reg;   // 송신할 데이터
    reg btn_trigger_reg;     // 버튼 누름 감지
    
    // 버튼 입력 처리
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_data_reg <= 8'h30;  // 기본값 '0'
            btn_trigger_reg <= 0;
        end else begin
            // 기본 상태
            btn_trigger_reg <= 0;
            
            // 버튼 입력에 따른 데이터 설정
            if (btnU) begin
                tx_data_reg <= 8'h41;  // 'A'
                btn_trigger_reg <= 1;
            end else if (btnL) begin
                tx_data_reg <= 8'h42;  // 'B'
                btn_trigger_reg <= 1;
            end else if (btnR) begin
                tx_data_reg <= 8'h43;  // 'C'
                btn_trigger_reg <= 1;
            end else if (btnD) begin
                tx_data_reg <= 8'h44;  // 'D'
                btn_trigger_reg <= 1;
            end
        end
    end
    
    // UART 모듈 인스턴스화 - primitive 블랙박스 문제 해결
    uart U_UART(
        .clk(clk),
        .rst(rst),
        .btn_start(btn_trigger_reg),
        .tx_data_in(tx_data_reg),
        .tx_done(tx_done),
        .tx(tx),
        .rx(rx),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

    // 7세그먼트 제어 모듈
    simple_fnd_controller U_FND_CTR(
        .clk(clk),
        .reset(rst),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done),
        .fnd_font(fnd_font),
        .fnd_comm(fnd_comm)
    );

endmodule

// UART 모듈 정의 (Black Box 오류 해결을 위해)
module uart(
    input clk,
    input rst,
    //tx
    input btn_start,
    input [7:0] tx_data_in,
    output reg tx_done,
    output reg tx, 
    //rx
    input rx,
    output reg rx_done,
    output reg [7:0] rx_data
);
    // 내부 신호 선언
    reg w_tick;
    
    // 실제 구현 (간단화)
    initial begin
        tx <= 1'b1;      // UART TX의 idle 상태는 HIGH
        tx_done <= 1'b0;
        rx_done <= 1'b0;
        rx_data <= 8'h30; // 기본값 '0'
    end
    
    // 실제 구현은 생략하고 기본 동작만 정의
    // 실제 프로젝트에서는 uart_tx, uart_rx, baud_tick_gen 모듈을 포함해야 함
    
    // 이 간단한 모델은 Black Box 오류를 해결하기 위한 것임
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            tx_done <= 1'b0;
        end else if (btn_start) begin
            // 버튼이 눌리면 데이터 전송 시작 (간단한 모델)
            tx <= 1'b0; // 시작 비트
            tx_done <= 1'b0;
            #10 tx <= tx_data_in[0]; // 데이터 비트
            #10 tx <= 1'b1; // 정지 비트
            #10 tx_done <= 1'b1; // 전송 완료
            #5 tx_done <= 1'b0;
        end
    end
endmodule



module uart(
    input clk,
    input rst,
    //tx
    input btn_start,
    input [7:0] tx_data_in,
    output tx_done,
    output tx, 
    //rx
    input rx,
    output rx_done,
    output [7:0] rx_data
);
    // 내부 신호 선언
    wire w_tick;
    // wire w_tx_done; // o_tx_done 신호를 받기 위한 와이어 추가

    

    // UART 송신기 인스턴스화
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .start_trigger(btn_start),
        .data_in(tx_data_in),
        .o_tx_done(tx_done), // o_tx_done 연결
        .o_tx(tx)
    );

    // 보드레이트 생성기 인스턴스화
    baud_tick_gen U_BAUD_Tick_Gen (
        .clk(clk),
        .rst(rst),
        .baud_tick(w_tick)
    );

    uart_rx U_UART_RX(
        .clk(clk),
        .rst(rst),
        .tick(w_tick),
        .rx(rx),
        .rx_done(rx_done),
        .rx_data(rx_data)
);

endmodule 

module uart_tx (
    input clk,
    input rst,
    input tick,
    input start_trigger,
    input [7:0] data_in,
    output o_tx_done,
    output o_tx
);
    //FSM 상태 정의
    parameter IDLE = 0, SEND = 1, START = 2, DATA = 3, STOP = 4;
    
    reg [3:0] state, next;
    reg tx_reg, tx_next;
    reg tx_done_reg, tx_done_next;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [3:0] tick_count_reg, tick_count_next;
    
    assign o_tx_done = tx_done_reg;
    assign o_tx = tx_reg;
    
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_reg <= 1'b1;  // UART의 기본 idle 상태는 high
            tx_done_reg <= 0;
            bit_count_reg <= 0;
            tick_count_reg <= 0;
        end else begin
            state <= next;
            tx_reg <= tx_next;
            tx_done_reg <= tx_done_next;
            bit_count_reg <= bit_count_next;
            tick_count_reg <= tick_count_next;
        end
    end
    
    always @(*) begin
        // 기본값 설정 - 중요한 부분
        next = state;
        tx_next = tx_reg;
        tx_done_next = tx_done_reg;
        bit_count_next = bit_count_reg;
        tick_count_next = tick_count_reg;

        case (state)
            IDLE: begin    
                tx_next = 1'b1; // output setting
                tx_done_next = 1'b0; 
                tick_count_next = 4'h0;
                if(start_trigger) begin
                    next = SEND;
                end
            end
            
            SEND: begin
                if(tick == 1'b1) begin
                    next = START;
                end
            end
            
            START: begin
                tx_next = 1'b0; // 출력을 0으로 유지 (시작 비트)
                tx_done_next = 1'b0; // 수정: 시작 상태에서는 tx_done을 비활성화
                if(tick == 1'b1) begin 
                    if(tick_count_reg == 15) begin
                        next = DATA;
                        bit_count_next = 3'b000; // 3비트 폭으로 수정
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_in[bit_count_reg]; // uart LSB first
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        tick_count_next = 1'b0;
                        if (bit_count_reg == 3'b111) begin
                            next = STOP;
                        end else begin
                            next = DATA;
                            bit_count_next = bit_count_reg + 1; // bit count 증가
                        end
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1; // 정지 비트는 1
                if (tick == 1'b1) begin
                    if (tick_count_reg == 15) begin
                        next = IDLE;
                        tx_done_next = 1'b1; // 수정: STOP 비트 전송이 완료된 후에만 tx_done 활성화
                        tick_count_next = 0;
                    end else begin
                        tick_count_next = tick_count_reg + 1;
                    end
                end
            end
            
            default: begin
                next = IDLE;
                tx_next = 1'b1;
            end
        endcase
    end
endmodule

//UART RX
module uart_rx (
    input clk,
    input rst,
    input tick,
    input rx,
    output rx_done,
    output [7:0] rx_data
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3 ;
    reg[1:0] state, next;
    reg rx_done_reg, rx_done_next;
    reg[2:0] bit_count_reg, bit_count_next;
    reg[4:0] tick_count_reg, tick_count_next; //rx tick max count 24.
    reg[7:0] rx_data_reg, rx_data_next; 

    // output
    assign rx_done = rx_done_reg;
    assign rx_data = rx_data_reg;

    //state
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state <= 0;
            rx_done_reg <= 0;
            rx_data_reg <= 0;
            bit_count_reg <=0;
            tick_count_reg <=0;
        end else begin
            state <= next;
            rx_done_reg <= rx_done_next;
            rx_data_reg <= rx_data_next;
            bit_count_reg <=bit_count_next;
            tick_count_reg <=tick_count_next;
        end
    end

    //next
    always @(*) begin
        next = state;
        tick_count_next = tick_count_reg;
        bit_count_next = bit_count_reg;
        rx_done_next = 1'b0;
        case (state)
            IDLE:begin
                tick_count_next = 0;
                bit_count_next = 0;
                rx_done_next = 1'b0;
                if(rx == 1'b0)begin
                    next = START;
                end
            end
            START:begin
                if(tick == 1'b1)begin
                    if(tick_count_reg == 7)begin
                        next = DATA; 
                        tick_count_next = 0; //tick count 초기화 
                    end else begin
                        tick_count_next = tick_count_reg+1;
                    end
                end
            end
            DATA:begin
                if(tick == 1'b1)begin
                    if(tick_count_reg == 15)begin
                        rx_data_next[bit_count_reg] = rx; // read data
                        if(bit_count_reg == 7)begin
                            next = STOP;
                            tick_count_next = 0; // tick count 초기화 
                        end else begin
                            next = DATA;
                            bit_count_next = bit_count_reg +1;
                            tick_count_next = 0; // tick count 초기화 
                        end
                    end else begin
                        tick_count_next = tick_count_reg+1;
                    end
                end
            end
            STOP:begin
                if(tick == 1'b1)begin
                    if (tick_count_reg == 23) begin
                        rx_done_next = 1'b1;
                        next = IDLE;
                    end else begin
                        tick_count_next = tick_count_reg +1;
                    end
                end
            end
        endcase
    end


endmodule

module baud_tick_gen (  // 모듈 이름 수정
    input clk,
    input rst,
    output baud_tick
);
    //100Mhz 1tick generator
    parameter BAUD_RATE = 9600, BAUD_RATE_19200 = 19200;
    localparam BAUD_COUNT = (100_000_000/ BAUD_RATE)/16; //주파수 계산
    reg [$clog2(BAUD_COUNT) - 1 : 0] count_reg, count_next;
    reg tick_reg, tick_next;
    
    //output
    assign baud_tick = tick_reg;
    
    always @(posedge clk, posedge rst) begin
        if(rst == 1) begin
            count_reg <= 0;
            tick_reg <= 0;
        end else begin
            count_reg <= count_next;
            tick_reg <= tick_next;
        end
    end
    
    //next
    always @(*) begin
        count_next = count_reg;
        tick_next = tick_reg;
        
        if (count_reg == BAUD_COUNT - 1) begin
            count_next = 0;
            tick_next = 1'b1;
        end else begin
            count_next = count_reg + 1;
            tick_next = 1'b0;
        end
    end
endmodule




// module bcdtoseg (
//     input [3:0] bcd,
//     output reg [6:0] seg  // 7개 세그먼트만 (도트 제외)
// );
//     always @(bcd) begin
//         case (bcd)
//             4'h0: seg = 7'b1000000;  // 도트 비트 제외
//             4'h1: seg = 7'b1111001;
//             4'h2: seg = 7'b0100100;
//             4'h3: seg = 7'b0110000;
//             4'h4: seg = 7'b0011001;
//             4'h5: seg = 7'b0010010;
//             4'h6: seg = 7'b0000010;
//             4'h7: seg = 7'b1111000;
//             4'h8: seg = 7'b0000000;
//             4'h9: seg = 7'b0010000;
//             4'hA: seg = 7'b0001000;
//             4'hB: seg = 7'b0000011;
//             4'hC: seg = 7'b1000110;
//             4'hD: seg = 7'b0100001;
//             4'hE: seg = 7'b0000110;
//             4'hF: seg = 7'b0001110;
//             default: seg = 7'b1111111;
//         endcase
//     end
// endmodule