#![macro_escape]

macro_rules! print(
    ($msg:expr) => (::io::print_str($msg));
    ($fmt:expr, $($arg:tt)*) => (
        format_args!(::io::print_args, $fmt, $($arg)*)
    );
)

macro_rules! println(
    ($msg:expr) => (
        print!(concat!($msg, "\r\n"))
    );
    ($fmt:expr, $($arg:tt)*) => (
        print!(concat!($fmt, "\r\n"), $($arg)*)
    );
)
