#!/usr/bin/env python3
"""
Scale ships no `bin2c`, unlike Nvidia nvcc. LAMMPS's GPU package needs it
to turn each compiled .cu kernel into a C header it can #include, invoked as:
    bin2c -c -n ${CU_NAME} ${CU_OBJ} > ${CU_NAME}_cubin.h
This reimplements that, and is pointed to via LAMMPS's `-DBIN2C=` (02-build.sh) rather than patching LAMMPS

Output format is `const char NAME[] = {...};`, no length symbol
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
        values = [b - 256 if b >= 128 else b for b in chunk]
        out.write("  " + ", ".join(str(v) for v in values) + ",\n")
    out.write("};\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
