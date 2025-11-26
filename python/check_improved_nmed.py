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

def improved_dr_alm_mult(a, b, m_width=5):
    # a, b are signed 8-bit integers (-128 to 127)
    sign_a = (a >> 7) & 1
    sign_b = (b >> 7) & 1
    sign_z = sign_a ^ sign_b
    
    abs_a = abs(a)
    abs_b = abs(b)
    
    if a == -128: abs_a = 128
    if b == -128: abs_b = 128
    
    if abs_a == 0 or abs_b == 0:
        return 0
        
    k_a = get_k(abs_a)
    k_b = get_k(abs_b)
    
    # norm = abs << (7 - k)
    norm_a = (abs_a << (7 - k_a)) & 0xFF
    norm_b = (abs_b << (7 - k_b)) & 0xFF
    
    frac_a = norm_a & 0x7F
    frac_b = norm_b & 0x7F
    
    # Truncation
    shift_amount = 7 - m_width
    frac_a_trunc = frac_a >> shift_amount
    frac_b_trunc = frac_b >> shift_amount
    
    # Error Compensation Logic
    trunc_a = frac_a & ((1 << shift_amount) - 1)
    trunc_b = frac_b & ((1 << shift_amount) - 1)
    
    compensation = 0
    if shift_amount > 0:
        # Magnitude-aware compensation
        if (k_a >= 3) and (k_b >= 3):
            sum_trunc = trunc_a + trunc_b
            # 75% threshold
            threshold = (sum_trunc >> 1) + (sum_trunc >> 2)
            if sum_trunc >= threshold:
                compensation = 1
    
    sum_k = k_a + k_b
    sum_frac_trunc = frac_a_trunc + frac_b_trunc + compensation
    
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
            approx = improved_dr_alm_mult(a, b, m_width=5)
            
            error = abs(approx - exact)
            total_error += error
            
            if abs(exact) > max_exact:
                max_exact = abs(exact)
                
    nmed = (total_error / (256*256)) / max_exact
    print(f"NMED (All Inputs, M_WIDTH=5): {nmed:.6f}")

if __name__ == "__main__":
    calculate_nmed_all()
