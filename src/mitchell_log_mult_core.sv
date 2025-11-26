module mitchell_log_mult_core #(parameter W = 8, parameter N = 16)(
    input  logic [15:0] i_a,
    input  logic [15:0] i_b,
    output logic [31:0] o_z
);

    logic [15:0] m_a, m_b;
    logic [15:0] m;
    logic [4:0] k_a, k_b;
    logic [4:0] k;
    logic [4:0] shamt_l, shamt_r;
    logic [31:0] result;

    function automatic [4:0] find_leading_one(input logic [15:0] data);
        casez (data)
            16'b1???????????????: find_leading_one = 5'd15;
            16'b01??????????????: find_leading_one = 5'd14;
            16'b001?????????????: find_leading_one = 5'd13;
            16'b0001????????????: find_leading_one = 5'd12;
            16'b00001???????????: find_leading_one = 5'd11;
            16'b000001??????????: find_leading_one = 5'd10;
            16'b0000001?????????: find_leading_one = 5'd9;
            16'b00000001????????: find_leading_one = 5'd8;
            16'b000000001???????: find_leading_one = 5'd7;
            16'b0000000001??????: find_leading_one = 5'd6;
            16'b00000000001?????: find_leading_one = 5'd5;
            16'b000000000001????: find_leading_one = 5'd4;
            16'b0000000000001???: find_leading_one = 5'd3;
            16'b00000000000001??: find_leading_one = 5'd2;
            16'b000000000000001?: find_leading_one = 5'd1;
            16'b0000000000000001: find_leading_one = 5'd0;
            default:              find_leading_one = 5'd0;
        endcase
    endfunction
    // Get the leading one of i_a and i_b
    assign h_a = find_leading_one(i_a);
    assign h_b = find_leading_one(i_b);

    k_a = h_a - N - 1;
    k_b = h_b - N - 1;

    x_a = i_a << (N - k_a - 1);
    x_b = i_b << (N - k_b - 1);

    op1 = {1'b0, k_a, x_a[N-2:N-W]};
    op2 = {1'b0, k_b, x_b[N-2:N-W]};

    L = op1 + op2;

    charac = L[W+log2(N)-1:W-1];
    lr = charac[log2(N)];
    
    m = {1'b1, L[W-2:0]}

    if lr == 1'b1 then
        shmamtL = {1'b0, charac[log2(N)-1:0]} + 1'b1;
        D = m << shamtL;
    else
        shamtR = n - charac[log2(N)-1:0] - 1'b1;
        D = m >> shamtR[log2(N):log2(N)-log2(W)];

    if i_a == 0 | i_b == 0 then
        o_z = 32'd0;
    else
        o_z = D;

    
endmodule