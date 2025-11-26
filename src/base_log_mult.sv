module base_log_mult (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

  // ------------------------------------------------------------
  // Sign + Absolute
  // ------------------------------------------------------------
  logic sign_a, sign_b, sign_z;
  logic [15:0] abs_a, abs_b;

  assign sign_a = i_a[15];
  assign sign_b = i_b[15];
  assign sign_z = sign_a ^ sign_b;

  assign abs_a = sign_a ? -i_a : i_a;
  assign abs_b = sign_b ? -i_b : i_b;

  // ------------------------------------------------------------
  // Leading-One Detector  (returns position 15→0)
  // ------------------------------------------------------------
  function automatic [4:0] get_k(input logic [15:0] val);
    if (val[15]) return 15;
    if (val[14]) return 14;
    if (val[13]) return 13;
    if (val[12]) return 12;
    if (val[11]) return 11;
    if (val[10]) return 10;
    if (val[ 9]) return 9;
    if (val[ 8]) return 8;
    if (val[ 7]) return 7;
    if (val[ 6]) return 6;
    if (val[ 5]) return 5;
    if (val[ 4]) return 4;
    if (val[ 3]) return 3;
    if (val[ 2]) return 2;
    if (val[ 1]) return 1;
    return 0;
  endfunction

  logic [4:0] k_a, k_b;

  assign k_a = get_k(abs_a);
  assign k_b = get_k(abs_b);

  // ------------------------------------------------------------
  // Normalize and extract fractional mantissa (15 bits)
  // We shift so the leading 1 is at bit 15
  // Then take bits [14:0] as the fractional mantissa
  // ------------------------------------------------------------
  logic [15:0] norm_a, norm_b;
  logic [14:0] frac_a, frac_b;

  assign norm_a = abs_a << (15 - k_a);
  assign norm_b = abs_b << (15 - k_b);

  assign frac_a = norm_a[14:0];
  assign frac_b = norm_b[14:0];

  // ------------------------------------------------------------
  // Add characteristic + mantissas
  // frac sum must be 16 bits (1 extra bit to detect overflow)
  // ------------------------------------------------------------
  logic [5:0] sum_k;
  logic [15:0] sum_frac;

  assign sum_k   = k_a + k_b;
  assign sum_frac = {1'b0, frac_a} + {1'b0, frac_b};

  // ------------------------------------------------------------
  // Antilog (Mitchell approximation)
  // output magnitude up to 32 bits
  // ------------------------------------------------------------
  logic [31:0] result_mag;

  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 0;
    end else begin

      if (sum_frac[15]) begin
        // overflow: mantissa is 1.xxxxxxxxxxxxxxx (15 frac bits)
        // scaling = 2^(sum_k + 1)
        int shift_amount;
        shift_amount = (sum_k + 1) - 15;

        if (shift_amount >= 0)
            result_mag = {16'b0, sum_frac} << shift_amount;
        else
            result_mag = {16'b0, sum_frac} >> -shift_amount;

      end else begin
        // no overflow: value = 1 + fractional mantissa
        logic [15:0] mantissa;
        int shift_amount;
        mantissa = (16'h8000 | sum_frac);  // leading 1 + 15 frac bits
        shift_amount = sum_k - 15;

        if (shift_amount >= 0)
            result_mag = {16'b0, mantissa} << shift_amount;
        else
            result_mag = {16'b0, mantissa} >> -shift_amount;
      end
    end
  end

  // ------------------------------------------------------------
  // Apply sign
  // ------------------------------------------------------------
  assign o_z = sign_z ? -result_mag : result_mag;

endmodule
