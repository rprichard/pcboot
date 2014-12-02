#![macro_escape]

macro_rules! panic(
    () => (
        ::lowlevel::panic(file!(), line!(), "panic", "")
    );
    ($msg:expr) => (
        ::lowlevel::panic(file!(), line!(), "panic: ", $msg)
    );
)

macro_rules! assert(
    ($cond:expr) => (
        if !$cond {
            ::lowlevel::panic(file!(), line!(), "assert fail: ", stringify!($cond))
        }
    );
    ($cond:expr, $msg:expr) => (
        if !$cond {
            ::lowlevel::panic(file!(), line!(), "assert fail: ", $msg)
        }
    );
)

macro_rules! assert_eq(
    ($cond1:expr, $cond2:expr) => ({
        let c1 = $cond1;
        let c2 = $cond2;
        if c1 != c2 || c2 != c1 {
            ::lowlevel::panic(file!(), line!(), "assert_eq fail: ", concat!("left: ", stringify!(c1), ", right: ", stringify!(c2)))
        }
    })
)
