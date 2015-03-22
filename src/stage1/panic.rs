use sys;
use core::fmt;
use core::prelude::*;

pub struct SimpleWriter;
impl fmt::Write for SimpleWriter {
    #[inline]
    fn write_str(&mut self, x: &str) -> fmt::Result {
        sys::print_str(&x); Ok(())
    }
    #[inline]
    fn write_fmt(&mut self, f: fmt::Arguments) -> fmt::Result {
        sys::halt();
    }
}

#[lang = "panic_fmt"] #[cold] #[inline]
extern fn rust_panic_fmt(msg: fmt::Arguments, file: &'static str, line: usize) -> ! {
    fmt::write(&mut SimpleWriter, msg);
    sys::halt();
}
