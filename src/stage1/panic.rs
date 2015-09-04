use sys;
use core::fmt;

pub struct SimpleWriter;
impl fmt::Write for SimpleWriter {
    #[inline]
    fn write_str(&mut self, x: &str) -> fmt::Result {
        sys::print_str(&x); Ok(())
    }
    #[inline]
    fn write_fmt(&mut self, f: fmt::Arguments) -> fmt::Result {
        fmt::write(self, f)
    }
}

#[lang = "panic_fmt"] #[cold] #[inline]
extern fn rust_panic_fmt(msg: fmt::Arguments, file: &'static str, line: usize) -> ! {
    sys::print_str(&"internal error: ");
    sys::print_str(&file);
    sys::print_str(&":");
    sys::print_u32(line as u32);
    sys::print_str(&": ");
    let _ = fmt::write(&mut SimpleWriter, msg);
    sys::halt();
}
