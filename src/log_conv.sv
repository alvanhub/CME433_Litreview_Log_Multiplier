module log_conv #(
    parameter integer WIDTH = 16,      // Data Width (8 or 16)
    parameter integer KEEP_WIDTH = 5   // 't' in the paper. t=6 is best tradeoff [cite: 320]
)(
    input  logic [KEEP_WIDTH-1:0] x1_t, x2_t,
    input logic [$clog2(WIDTH)-1:0] k1, k2,
    output logic [$clog2(WIDTH):0] sum_k,
    output logic [KEEP_WIDTH:0] sum_x
);

assign sum_k = k1 + k2;
assign sum_x = x1_t + x2_t + 1'b1;


endmodule