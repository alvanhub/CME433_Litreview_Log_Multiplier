import numpy as np

def get_k(val):
    # val is 8-bit integer (0-255)
    if val & 0x80: return 7
    if val & 0x40: return 6
    if val & 0x20: return 5
    if val & 0x10: return 4
    if val & 0x08: return 3
    if val & 0x04: return 2
    if val & 0x02: return 1
    return 0

def dr_alm_mult(a, b, m_width=5):
    # a, b are signed 8-bit integers (-128 to 127)
    sign_a = (a >> 7) & 1
    sign_b = (b >> 7) & 1
    sign_z = sign_a ^ sign_b
    
    abs_a = abs(a)
    abs_b = abs(b)
    
    # Handle -128 (which is 128 in abs if we treat as 8-bit unsigned magnitude for a moment, 
    # but in 8-bit signed, -128 is 10000000. Abs is not representable in positive 8-bit signed.
    # SV: assign abs_a = sign_a ? -i_a : i_a;
    # If i_a = -128 (10000000), -i_a = 10000000 (128).
    # So abs_a becomes 128 (unsigned 8-bit).
    if a == -128: abs_a = 128
    if b == -128: abs_b = 128
    
    if abs_a == 0 or abs_b == 0:
        return 0
        
    k_a = get_k(abs_a)
    k_b = get_k(abs_b)
    
    # norm = abs << (7 - k)
    # In python, we mask to 8 bits
    norm_a = (abs_a << (7 - k_a)) & 0xFF
    norm_b = (abs_b << (7 - k_b)) & 0xFF
    
    frac_a = norm_a & 0x7F
    frac_b = norm_b & 0x7F
    
    # Truncation
    # Keep top m_width bits of frac (which is 7 bits)
    # frac has bits 6..0
    # We want bits 6..(7-m_width)
    # Shift right by (7-m_width) then shift back?
    # SV: frac_a[6 : 7-M_WIDTH]
    shift_amount = 7 - m_width
    frac_a_trunc = frac_a >> shift_amount
    frac_b_trunc = frac_b >> shift_amount
    
    sum_k = k_a + k_b
    sum_frac_trunc = frac_a_trunc + frac_b_trunc
    
    # Restore
    sum_frac_restored = (sum_frac_trunc << shift_amount) & 0xFF
    
    # Antilog
    result_mag = 0
    if sum_frac_restored & 0x80: # bit 7 set (>= 128)
        # sum >= 1.0
        shift = sum_k + 1 - 7
        val = sum_frac_restored
        if shift >= 0:
            result_mag = val << shift
        else:
            result_mag = val >> (-shift)
    else:
        # sum < 1.0
        shift = sum_k - 7
        val = 128 | sum_frac_restored
        if shift >= 0:
            result_mag = val << shift
        else:
            result_mag = val >> (-shift)
            
    # Result is 16-bit signed
    if sign_z:
        return -result_mag
    else:
        return result_mag

def exact_mult(a, b):
    return a * b

def calculate_nmed_all():
    total_error = 0
    max_exact = 0
    
    # Iterate -128 to 127
    for a in range(-128, 128):
        for b in range(-128, 128):
            exact = exact_mult(a, b)
            approx = dr_alm_mult(a, b, m_width=5)
            
            error = abs(approx - exact)
            total_error += error
            
            if abs(exact) > max_exact:
                max_exact = abs(exact)
                
    nmed = (total_error / (256*256)) / max_exact
    print(f"NMED (All Inputs, M_WIDTH=5): {nmed:.6f}")

if __name__ == "__main__":
    calculate_nmed_all()
