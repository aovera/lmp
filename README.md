# lmp (Lua Multiple Precision)

A pure Lua arbitrary-precision arithmetic library for Lua and LuaJIT, supporting unlimited-digit integers (**BigInt**) and high-precision floating-point numbers (**BigDecimal**).

## Features

- **Pure Lua Implementation:** Zero external C dependencies. Highly portable and works out-of-the-box on any platform supporting Lua.
- **Operator Overloading:** Full Metatable integration allowing natural mathematical syntax for `+`, `-`, `*`, `//`, `%`, `/`, `<`, `<=`, and `==`.
- **Dynamic Fixed-Point Arithmetic:** `BigDecimal` alignment respects the maximum scale during calculations to guarantee zero accidental precision loss.
- **LuaJIT Optimized:** Tailored data structures designed to leverage LuaJIT's high-performance compilation engine.

## Installation

Simply copy the `lmp` directory into your project root and use with
```local lmp = require("lmp")```


## Important Note on LuaJIT Compatibility

While this library is syntax-compatible with LuaJIT, LuaJIT represents numbers as **IEEE 754 double-precision floats**, which have a maximum safe integer limit of $2^{53} - 1$ (approx. $9 \times 10^{15}$). 

If you are running this library strictly under Lua 5.3+ (which natively supports 64-bit integers), you can maximize performance by setting `local n = 9` in `bigint.lua`. However, to ensure **100% precision safety under LuaJIT**, the internal chunk size (`n`) is set to `7` by default. This ensures that the internal multiplication operations ($10^7 \times 10^7 = 10^{14}$) never exceed the 53-bit floating-point boundary.
