#!/usr/bin/env python3
"""bin2c-compatible shim.

LAMMPS's GPU package needs bin2c to turn each compiled .cu kernel into a C
header it can #include, invoked as:
    bin2c -c -n ${CU_NAME} ${CU_OBJ} > ${CU_NAME}_cubin.h

This reimplements that one transformation and is pointed to via LAMMPS's
own `-DBIN2C=` rather than patching LAMMPS.
Delete both once SCALE ships a full working bin2c (awaiting -fatbin?).
The bin2c fix in Scale wasn't enough on its own.

Output format (`const char NAME[] = {...};`, no length symbol) is verified
against the LAMMPS source consuming it
"""
import os
import sys


def main(argv: list[str]) -> int:
    name = None
    path = None
    const = False

    args = argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "-c":
            const = True
        elif arg == "-n":
            i += 1
            name = args[i]
        else:
            path = arg
        i += 1

    if name is None or path is None:
        sys.stderr.write("usage: bin2c -c -n NAME FILE\n")
        return 1

    if not os.path.isfile(path):
        sys.stderr.write(f"bin2c-shim: no such file: {path}\n")
        return 1

    with open(path, "rb") as f:
        data = f.read()

    qualifier = "const char" if const else "char"
    out = sys.stdout
    out.write(f"{qualifier} {name}[] = {{\n")
    for offset in range(0, len(data), 20):
        chunk = data[offset:offset + 20]
        # Plain hex literals (0x00-0xff) are ints, and values above 0x7f are a
        # narrowing conversion into a (signed-by-default) `char` element in a
        # braced initializer list -- C++ rejects it even though the bit
        # pattern is exactly what's wanted. Converting each byte to its
        # signed-char-equivalent decimal value keeps the same bits (two's
        # complement) while being directly representable in `char`, so no
        # narrowing conversion occurs.
        values = [b - 256 if b >= 128 else b for b in chunk]
        out.write("  " + ", ".join(str(v) for v in values) + ",\n")
    out.write("};\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
