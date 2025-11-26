module base_log_mult (
    input  logic signed [ 7:0] i_a,
    input  logic signed [ 7:0] i_b,
    output logic signed [15:0] o_z
);

  logic [7:0] abs_a, abs_b;
  logic sign_a, sign_b, sign_z;
  logic [2:0] k_a, k_b;
  logic [6:0] frac_a, frac_b;
  logic [3:0] sum_k;
  logic [7:0] sum_frac;
  logic [15:0] result_mag;

  // Sign and Absolute Value
  assign sign_a = i_a[7];
  assign sign_b = i_b[7];
  assign sign_z = sign_a ^ sign_b;

  // Handle -128 edge case or just negate
  assign abs_a = sign_a ? -i_a : i_a;
  assign abs_b = sign_b ? -i_b : i_b;

  // Leading One Detector
  function automatic [2:0] get_k(input logic [7:0] val);
    if (val[7]) return 7;
    if (val[6]) return 6;
    if (val[5]) return 5;
    if (val[4]) return 4;
    if (val[3]) return 3;
    if (val[2]) return 2;
    if (val[1]) return 1;
    return 0;
  endfunction

  assign k_a = get_k(abs_a);
  assign k_b = get_k(abs_b);

  // Mantissa Extraction (normalized to 1.xxxxxxx, we keep xxxxxxx)
  // Shift left so the leading one is at bit 7, then take bits 6:0
  // Actually, if k=7, val=1xxxxxxx, frac=xxxxxxx.
  // If k=0, val=00000001, frac=0000000.
  // If val=0, k=0, frac=0.
  
  logic [7:0] norm_a, norm_b;
  assign norm_a = abs_a << (7 - k_a);
  assign norm_b = abs_b << (7 - k_b);
  
  assign frac_a = norm_a[6:0];
  assign frac_b = norm_b[6:0];

  // Sum of characteristics and mantissas
  assign sum_k = k_a + k_b;
  assign sum_frac = {1'b0, frac_a} + {1'b0, frac_b};

  // Antilogarithm Approximation (Mitchell's)
  // If sum_frac >= 1.0 (bit 7 set), result = sum_frac * 2^(sum_k + 1)
  // Else result = (1.0 + sum_frac) * 2^sum_k
  // Note: 1.0 in 7-bit fraction is 128.
  
  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 0;
    end else begin
      if (sum_frac[7]) begin
        // sum_frac >= 1.0. The value is 1.xxxxxxx (where xxxxxxx are bits 6:0)
        // We use the value directly as mantissa.
        // Shift amount: sum_k + 1.
        // But we need to adjust for the fractional point (7 bits).
        // result = sum_frac << (sum_k + 1 - 7)
        // If shift is negative, we shift right.
        if (sum_k + 1 >= 7)
            result_mag = {8'b0, sum_frac} << (sum_k + 1 - 7);
        else
            result_mag = {8'b0, sum_frac} >> (7 - (sum_k + 1));
      end else begin
        // sum_frac < 1.0. Value is 0.xxxxxxx
        // We add 1.0 (128) -> 1.xxxxxxx
        // Shift amount: sum_k.
        if (sum_k >= 7)
            result_mag = {8'b0, (8'd128 | sum_frac)} << (sum_k - 7);
        else
            result_mag = {8'b0, (8'd128 | sum_frac)} >> (7 - sum_k);
      end
    end
  end

  assign o_z = sign_z ? -result_mag : result_mag;

endmodule