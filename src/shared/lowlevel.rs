extern crate core;
use core::prelude::*;

extern "C" {
    fn call_real_mode(callee: unsafe extern "C" fn(), ...) -> u64;
    fn halt_16bit();
}

// Add no_split_stack to disable stack checking.  This function is used during
// stack overflow handling.
#[no_stack_check]
pub fn halt() -> ! {
    unsafe {
        call_real_mode(halt_16bit);

        // Make the rustc compiler happy.  It thinks call_real_mode can return.
        // Changing the declaration of call_real_mode is hard -- rust issue
        // #12707.
        loop {}
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
