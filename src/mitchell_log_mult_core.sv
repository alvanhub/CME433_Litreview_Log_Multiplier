module mitchell_log_mult_core #(parameter W = 8, parameter N = 16)(
    input  logic [15:0] i_a,
    input  logic [15:0] i_b,
    output logic [31:0] o_z
);
    logic [31:0] m;
    logic [4:0] k_a, k_b;
    logic [4:0] h_a, h_b;
    logic [15:0] x_a, x_b;
    logic [W+$clog2(N):0] op1, op2;
    logic [W+$clog2(N):0] L;
    logic [$clog2(N):0] charac;
    logic [31:0] D;
    
    logic [15:0] abs_a, abs_b;
    logic sign_a, sign_b, sign_z;
    logic [31:0] result_abs;

    // Handle signed inputs
    assign sign_a = i_a[15];
    assign sign_b = i_b[15];
    assign sign_z = sign_a ^ sign_b;
    
    assign abs_a = sign_a ? (~i_a + 1'b1) : i_a;
    assign abs_b = sign_b ? (~i_b + 1'b1) : i_b;

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
    
    // Get the leading one of absolute values
    assign h_a = find_leading_one(abs_a);
    assign h_b = find_leading_one(abs_b);

    assign k_a = h_a;
    assign k_b = h_b;

    assign x_a = abs_a << (N - k_a - 1);
    assign x_b = abs_b << (N - k_b - 1);

    assign op1 = {1'b0, k_a, x_a[N-2:N-W]};
    assign op2 = {1'b0, k_b, x_b[N-2:N-W]};

    assign L = op1 + op2;

    assign charac = L[W+$clog2(N)-1:W-1];
    
    assign m = {1'b1, L[W-2:0]}; // Reconstruct mantissa (1.fraction)

    // Shift amount calculation: shift = charac - (W-1)
    // W=8, W-1=7
    assign D = (charac >= (W-1)) ? (m << (charac - (W-1))) : (m >> ((W-1) - charac));

    assign result_abs = ((abs_a == 0) || (abs_b == 0)) ? 32'd0 : D;
    
    // Restore sign
    assign o_z = sign_z ? (~result_abs + 1'b1) : result_abs;
    
endmodule
