//! Everything App Native Core Bridge
//! High-efficiency routines for text parsing and cryptographic offloading.

use hmac::Hmac;
use pbkdf2::pbkdf2;
use sha2::{Digest, Sha256};

/// Computes SHA-256 over `data[0..len]` and writes 32 bytes into `out`.
#[no_mangle]
pub extern "C" fn everything_sha256(data: *const u8, len: usize, out: *mut u8) -> i32 {
    if (data.is_null() && len > 0) || out.is_null() {
        return -1;
    }
    let slice = if len == 0 {
        &[][..]
    } else {
        unsafe { std::slice::from_raw_parts(data, len) }
    };
    let digest = Sha256::digest(slice);
    unsafe {
        std::ptr::copy_nonoverlapping(digest.as_ptr(), out, 32);
    }
    0
}

/// Computes 1-block (32-byte) PBKDF2-HMAC-SHA256 key derivation.
#[no_mangle]
pub extern "C" fn everything_pbkdf2_hmac_sha256(
    pass: *const u8,
    pass_len: usize,
    salt: *const u8,
    salt_len: usize,
    rounds: u32,
    out: *mut u8,
) -> i32 {
    if (pass.is_null() && pass_len > 0)
        || (salt.is_null() && salt_len > 0)
        || out.is_null()
        || rounds == 0
    {
        return -1;
    }
    let pass_slice = if pass_len == 0 {
        &[][..]
    } else {
        unsafe { std::slice::from_raw_parts(pass, pass_len) }
    };
    let salt_slice = if salt_len == 0 {
        &[][..]
    } else {
        unsafe { std::slice::from_raw_parts(salt, salt_len) }
    };
    let mut derived = [0u8; 32];
    if pbkdf2::<Hmac<Sha256>>(pass_slice, salt_slice, rounds, &mut derived).is_err() {
        return -1;
    }
    unsafe {
        std::ptr::copy_nonoverlapping(derived.as_ptr(), out, 32);
    }
    0
}

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
