extern crate core;
use io;
use std;

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
    io::print_str("internal error: stack exhausted!");
    halt();
}

#[lang = "panic_fmt"] #[cold] #[inline(never)]
extern fn rust_panic_fmt(_msg: &std::fmt::Arguments, file: &'static str, line: usize) -> ! {
    // For size optimization, avoid using the "_msg" argument.  We build stage1
    // with -C lto, which is apparently smart enough to figure out that _msg is
    // unused and remove the caller formatting code involved in creating
    // "_msg".  This is a huge size savings (e.g. several kilobytes).
    panic(file, line, "rust_panic_fmt", "")
}

pub fn panic(file: &'static str, line: usize, err1: &'static str, err2: &'static str) -> ! {
    io::print_str("internal error: ");
    io::print_str(file);
    io::print_char(b':');
    io::print_u32(line as u32);
    io::print_str(": ");
    io::print_str(err1);
    io::print_str(err2);
    halt();
}
