use std;
use sys;

#[lang = "panic_fmt"] #[cold] #[inline(never)]
extern fn rust_panic_fmt(_msg: &std::fmt::Arguments, file: &'static str, line: usize) -> ! {
    // TODO: The argument type is wrong, but if we fix it, the code size increases.
    // If we don't fix it, then the file/line arguments are garbage.

    // For size optimization, avoid using the "_msg" argument.  We build stage1
    // with -C lto, which is apparently smart enough to figure out that _msg is
    // unused and remove the caller formatting code involved in creating
    // "_msg".  This is a huge size savings (e.g. several kilobytes).
    sys::simple_panic(&file, line as u32, &"rust_panic_fmt", &"")
}
