extern crate core;
use core::prelude::*;

// Add no_split_stack to disable stack checking.  This function is used during
// stack overflow handling.
#[no_stack_check]
fn halt() -> ! {
    extern "C" {
        fn halt_16bit();
        fn call_real_mode(callee: *mut ()) -> !;
    }
    unsafe {
        call_real_mode(halt_16bit as *mut ());
    }
}

#[lang = "eh_personality"]
extern fn eh_personality() {}

#[lang = "stack_exhausted"]
extern fn stack_exhausted() {
    ::io::print_str("internal error: stack exhausted! halting!\r\n");
    halt();
}

#[lang = "fail_fmt"]
extern fn fail_fmt(msg: &::std::fmt::Arguments, file: &'static str, line: uint) -> ! {
    print!("{}:{}: internal error: {}", file, line, msg);
    halt();
}
