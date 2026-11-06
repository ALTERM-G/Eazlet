# Native number tools

`numbertools.cpp` implements the 64-bit integer core used by `NumberToolsVM`:

- deterministic **Miller–Rabin** primality testing
- **Pollard's rho** (Brent variant) factorization with incremental progress
- divisor generation from the prime factorization (no second trial division)
- base formatting without `0b` / `0x` / `0o` prefixes
- gcd / lcm / Bézout

## Build

Linux:

```sh
g++ -shared -fPIC -O2 -std=c++17 -Wall \
  -o src/eazlet/backend/native/libnumbertools.so \
  src/eazlet/backend/native/numbertools.cpp
```

If the shared library is missing or cannot be loaded, `number_tools_vm.py`
falls back to the same Miller–Rabin / Pollard's rho approach in Python, which
also supports integers larger than 64 bits.
