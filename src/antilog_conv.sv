module antilog_conv #(
    parameter integer DWIDTH = 16,      // Data Width (8 or 16)
    parameter integer M_WIDTH = 6   // 't' in the paper. t=6 is best tradeoff [cite: 320]
)(
    input logic [$clog2(DWIDTH):0] sum_k,
    input logic [M_WIDTH:0] sum_x,
    output logic [$clog2(DWIDTH):0] final_k,
    output logic [DWIDTH*2-1:0] mantissa_reconst

);

    logic carry_x;
    logic [M_WIDTH-1:0] final_x;

    assign carry_x = sum_x[M_WIDTH];
    assign final_k = sum_k + carry_x;
    assign final_x = sum_x[M_WIDTH-1:0];
    assign mantissa_reconst = {1'b1, final_x};


endmodule