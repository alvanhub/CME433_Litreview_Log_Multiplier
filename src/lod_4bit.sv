// 4-bit Leading One Detector (LOD)
module lod4_bit (
    input  logic [3:0] a,
    output logic [3:0] d,
    output logic       or_out
);
    assign or_out = |a;

    assign d[3] = a[3];
    assign d[2] = ~a[3] & a[2];
    assign d[1] = ~a[3] & ~a[2] & a[1];
    assign d[0] = ~a[3] & ~a[2] & ~a[1] & a[0];
endmodule