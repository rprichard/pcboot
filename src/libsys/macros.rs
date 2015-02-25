// Define two macros that will allow switching the program between &str and
// &&str as the canonical string type.

// Use this macro around static strings (i.e. literals) to convert them to
// StrLit type.
#[cfg(strref)]
#[macro_export]
macro_rules! strlit {
    ($literal:expr) => {{
        static STR_REF: ::sys::StrLit = &$literal;
        STR_REF
    }}
}

// Use this macro around non-static strings to convert them to StrRef type.
#[cfg(strref)]
#[macro_export]
macro_rules! strref {
    ($x:expr) => { &$x }
}

#[cfg(not(strref))] #[macro_export] macro_rules! strlit { ($x:expr) => { $x } }
#[cfg(not(strref))] #[macro_export] macro_rules! strref { ($x:expr) => { $x } }
