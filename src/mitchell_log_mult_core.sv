module mitchell_log_mult_core #(parameter KEEP_WIDTH = 8, parameter WIDTH = 16)(
    input  logic [15:0] i_a,
    input  logic [15:0] i_b,
    output logic [31:0] o_z
);
    logic [31:0] m;
    logic [4:0] k_a, k_b;
    logic [4:0] h_a, h_b;
    logic [15:0] x_a, x_b;
    logic [KEEP_WIDTH+$clog2(WIDTH):0] op1, op2;
    logic [KEEP_WIDTH+$clog2(WIDTH):0] L;
    logic [$clog2(WIDTH):0] charac;
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

    assign x_a = abs_a << (WIDTH - k_a - 1);
    assign x_b = abs_b << (WIDTH - k_b - 1);

    assign op1 = {1'b0, k_a, x_a[WIDTH-2:WIDTH-KEEP_WIDTH]};
    assign op2 = {1'b0, k_b, x_b[WIDTH-2:WIDTH-KEEP_WIDTH]};

    assign L = op1 + op2;

    assign charac = L[KEEP_WIDTH+$clog2(WIDTH)-1:KEEP_WIDTH-1];
    
    assign m = {1'b1, L[KEEP_WIDTH-2:0]}; // Reconstruct mantissa

    assign D = (charac >= (KEEP_WIDTH-1)) ? (m << (charac - (KEEP_WIDTH-1))) : (m >> ((KEEP_WIDTH-1) - charac));

    assign result_abs = ((abs_a == 0) || (abs_b == 0)) ? 32'd0 : D;
    
    // Restore sign
    assign o_z = sign_z ? (~result_abs + 1'b1) : result_abs;
    
endmodule
