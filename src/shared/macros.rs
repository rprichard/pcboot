#![macro_escape]

macro_rules! print(
    ($($arg:tt)*) => (format_args!(::io::print_args, $($arg)*));
)

macro_rules! println(
    ($fmt:expr) => (print!(concat!($fmt, "\r\n")));
    ($fmt:expr, $($arg:tt)*) => (print!(concat!($fmt, "\r\n"), $($arg)*));
)
