//! Everything App Native Core Bridge
//! High-efficiency routines for text parsing and cryptographic offloading.

/// Fast byte-level pre-filter to detect if an SMS contains any numerical digit (ASCII 0x30..0x39).
/// Returns 1 if candidate contains digits, 0 otherwise.
#[no_mangle]
pub extern "C" fn everything_fast_digit_scan(bytes: *const u8, len: usize) -> i32 {
    if bytes.is_null() || len == 0 {
        return 0;
    }
    let slice = unsafe { std::slice::from_raw_parts(bytes, len) };
    for &b in slice {
        if b >= b'0' && b <= b'9' {
            return 1;
        }
    }
    0
}
