macro_rules! panic {
    () => (
        ::sys::simple_panic(strlit!(file!()), line!(), strlit!("panic"), strlit!(""))
    );
    ($msg:expr) => (
        ::sys::simple_panic(strlit!(file!()), line!(), strlit!("panic: "), strref!($msg))
    );
}

macro_rules! assert {
    ($cond:expr) => (
        if !$cond {
            ::sys::simple_panic(strlit!(file!()),
                                line!(),
                                strlit!("assert fail: "),
                                strlit!(stringify!($cond)))
        }
    );
    ($cond:expr, $msg:expr) => (
        if !$cond {
            ::sys::simple_panic(strlit!(file!()),
                                line!(),
                                strlit!("assert fail: "),
                                strref!($msg))
        }
    );
}

macro_rules! assert_eq {
    ($cond1:expr, $cond2:expr) => ({
        let c1 = $cond1;
        let c2 = $cond2;
        if c1 != c2 || c2 != c1 {
            ::sys::simple_panic(strlit!(file!()),
                                line!(),
                                strlit!("assert_eq fail: "),
                                strlit!(concat!("left: ", stringify!(c1), ", right: ", stringify!(c2))))
        }
    })
}
