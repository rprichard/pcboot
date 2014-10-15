#![crate_type = "rlib"]
#![no_std]
#![feature(globs)]
#![feature(lang_items)]
#![feature(macro_rules)]

extern crate core;
use core::prelude::*;
use core::fmt::FormatWriter;

// Define a dummy std module that contains libcore's fmt module.  The fmt
// module is needed to satisfy the fail macro's std::fmt::Arguments reference.
mod std {
    pub use core::fmt;
}

// Copied from libcore/macros.rs
macro_rules! fail(
    () => (
        fail!("{}", "explicit failure")
    );
    ($msg:expr) => ({
        static _MSG_FILE_LINE: (&'static str, &'static str, uint) = ($msg, file!(), line!());
        ::core::failure::fail(&_MSG_FILE_LINE)
    });
    ($fmt:expr, $($arg:tt)*) => ({
        // a closure can't have return type !, so we need a full
        // function to pass to format_args!, *and* we need the
        // file and line numbers right here; so an inner bare fn
        // is our only choice.
        //
        // LLVM doesn't tend to inline this, presumably because begin_unwind_fmt
        // is #[cold] and #[inline(never)] and because this is flagged as cold
        // as returning !. We really do want this to be inlined, however,
        // because it's just a tiny wrapper. Small wins (156K to 149K in size)
        // were seen when forcing this to be inlined, and that number just goes
        // up with the number of calls to fail!()
        //
        // The leading _'s are to avoid dead code warnings if this is
        // used inside a dead function. Just `#[allow(dead_code)]` is
        // insufficient, since the user may have
        // `#[forbid(dead_code)]` and which cannot be overridden.
        #[inline(always)]
        fn _run_fmt(fmt: &::std::fmt::Arguments) -> ! {
            static _FILE_LINE: (&'static str, uint) = (file!(), line!());
            ::core::failure::fail_fmt(fmt, &_FILE_LINE)
        }
        format_args!(_run_fmt, $fmt, $($arg)*)
    });
)

extern "C" {
    pub fn printchar_32bit(x: u8);
    pub fn halt_32bit() -> !;
}

// Add no_split_stack to disable stack checking.  This function is used during
// stack overflow handling.
#[no_stack_check] #[inline]
fn halt() -> ! {
    unsafe { halt_32bit(); }
}

// Disable stack checking, because this function is used during stack overflow
// handling.
#[no_stack_check] #[inline]
fn printchar(ch: u8) {
    unsafe { printchar_32bit(ch); }
}

#[lang = "eh_personality"]
extern fn eh_personality() {}

#[lang = "stack_exhausted"]
extern fn stack_exhausted() {
    printstr("internal error: stack exhausted! halting!\r\n");
    halt();
}

#[lang = "fail_fmt"]
extern fn fail_fmt(msg: &std::fmt::Arguments, file: &'static str, line: uint) -> ! {
    struct PrintWriter;
    impl core::fmt::FormatWriter for PrintWriter {
        fn write(&mut self, buf: &[u8]) -> core::fmt::Result {
            for ch in buf.iter() {
                printchar(*ch);
            }
            Ok(())
        }
    }
    let _ = format_args_method!(&mut PrintWriter, write_fmt, "{}:{}: internal error: {}", file, line, msg);
    halt();
}

// Disable stack checking, because this function is used during stack overflow
// handling.  Disable inlining to discourage loop unrolling.
#[no_stack_check] #[inline(never)]
fn printstr(text: &str) {
    for ch in text.as_bytes().iter() {
        printchar(*ch);
    }
}

#[no_mangle]
pub extern "C" fn pcboot_main() -> ! {
    printstr("pcboot loading...\r\n");
    fail!();
}
