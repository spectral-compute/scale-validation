import argparse
import re
from pathlib import Path

def extract_executable_name(usage_text):
    matches = re.findall(r'```(?:[a-zA-Z0-9_-]*)\n(?:[./$\s]*)([a-z0-9]+_[a-z0-9_]+_example\b)', usage_text, re.DOTALL)
    return matches[0] if matches else None

def export_output_to_filecheck(repo, out, dir_filter=None):
    repo_dir, out_dir = Path(repo), Path(out)
    out_dir.mkdir(parents=True, exist_ok=True)
    filters = set(dir_filter) if dir_filter else None

    print(f"Scanning README.md files in {repo_dir.resolve()}, restricted to: {', '.join(filters) if filters else 'all'}...")

    for readme_path in sorted(repo_dir.glob("**/README.md")):
        if any(p.startswith('.') for p in readme_path.parts) or (filters and not filters.intersection(readme_path.parts)):
            continue

        content = readme_path.read_text(encoding='utf-8')
        usage_match = re.search(r'#+\s*Usage\b(.*?)(?=\n#+|\Z)', content, re.DOTALL)
        if not usage_match:
            continue

        usage_section = usage_match.group(1).strip()
        exec_name = extract_executable_name(usage_section)
        if not exec_name:
            continue

        code_block = re.findall(r'```(?:[a-zA-Z0-9_-]*)\n(.*?)```', usage_section, re.DOTALL)
        if not code_block:
            continue

        filecheck_lines = []
        for line in code_block[-1].splitlines():
            stripped = line.strip()
            if not stripped or any(stripped.startswith(x) for x in ('#', './', '$', exec_name)):
                continue
            if any(x in stripped.lower() for x in ('sample', 'output', 'expected')):
                continue
            filecheck_lines.append(f"CHECK: {line}")

        if filecheck_lines:
            (out_dir / f"{exec_name}.txt").write_text("\n".join(filecheck_lines) + "\n", encoding='utf-8')
            print(f"Exported assertions: {exec_name}.txt")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Parse CUDALibrarySamples README.md files into FileCheck assertions")
    parser.add_argument("repo_dir", type=str, help="Path to the CUDALibrarySamples repository")
    parser.add_argument("out_dir", type=str, help="Destination path for the generated FileCheck assertions")
    parser.add_argument("dir_filter", type=str, nargs='*', help="Optional directory restrictions (e.g. cuBLAS cuSOLVER)")

    args = parser.parse_args()
    export_output_to_filecheck(args.repo_dir, args.out_dir, args.dir_filter)
