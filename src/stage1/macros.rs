#![macro_escape]

// Copied from libcore/macros.rs
macro_rules! fail(
    () => (
        fail!("{}", "explicit failure")
    );
    ($msg:expr) => ({
        static _MSG_FILE_LINE: (&'static str, &'static str, uint) = ($msg, file!(), line!());
        ::core::failure::fail(&_MSG_FILE_LINE)
    });
    ($fmt:expr, $($arg:tt)*) => ({
        // a closure can't have return type !, so we need a full
        // function to pass to format_args!, *and* we need the
        // file and line numbers right here; so an inner bare fn
        // is our only choice.
        //
        // LLVM doesn't tend to inline this, presumably because begin_unwind_fmt
        // is #[cold] and #[inline(never)] and because this is flagged as cold
        // as returning !. We really do want this to be inlined, however,
        // because it's just a tiny wrapper. Small wins (156K to 149K in size)
        // were seen when forcing this to be inlined, and that number just goes
        // up with the number of calls to fail!()
        //
        // The leading _'s are to avoid dead code warnings if this is
        // used inside a dead function. Just `#[allow(dead_code)]` is
        // insufficient, since the user may have
        // `#[forbid(dead_code)]` and which cannot be overridden.
        #[inline(always)]
        fn _run_fmt(fmt: &::std::fmt::Arguments) -> ! {
            static _FILE_LINE: (&'static str, uint) = (file!(), line!());
            ::core::failure::fail_fmt(fmt, &_FILE_LINE)
        }
        format_args!(_run_fmt, $fmt, $($arg)*)
    });
)

macro_rules! print(
    ($msg:expr) => (::io::printstr($msg));
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
