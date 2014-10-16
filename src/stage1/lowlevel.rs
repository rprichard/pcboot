extern crate core;
use core::prelude::*;

extern "C" {
    pub fn halt_32bit() -> !;
}

// Add no_split_stack to disable stack checking.  This function is used during
// stack overflow handling.
#[no_stack_check] #[inline]
fn halt() -> ! {
    unsafe { halt_32bit(); }
}

#[lang = "eh_personality"]
extern fn eh_personality() {}

#[lang = "stack_exhausted"]
extern fn stack_exhausted() {
    print!("internal error: stack exhausted! halting!\r\n");
    halt();
}

#[lang = "fail_fmt"]
extern fn fail_fmt(msg: &::std::fmt::Arguments, file: &'static str, line: uint) -> ! {
    print!("{}:{}: internal error: {}", file, line, msg);
    halt();
}
