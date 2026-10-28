# Plans the per-project builder images so they share as many docker layers as possible.
#
# Builds a graph where each node is a project builder image or a scale-test-$distro
# image. An edge from A to B means A's dockerfile uses B's image as its base. Each
# project image starts out based on scale-test-$distro. It is then split into a chain of
# layer images that each install one package. Packages more projects need go first, so
# projects can share them. Next, each image is
# repointed at the image whose installed packages are the largest subset of its own.
# Then layer images that install nothing or that no image uses are removed. Last, each
# layer image used by only one image is merged into that image.
#
# Each image is written twice: once based on scale-test-$distro, and once, for NVIDIA
# targets, based on scale-test-nv-$distro, with -nv before the distro in its name.
#
# Reads the `.dependencies` file in each project directory (see README.md for the format).
# Writes a dockerfile for each project and layer image to images/ in the current
# directory, replacing any dockerfiles already there, and images/build.sh, which builds
# them in order. `ext` packages are installed by images/install-ext.sh. Run from the root
# of test/thirdparty.
#
# If the DISTROS environment variable is set, it is a JSON list of the distros to write
# images for. Otherwise, images are written for every distro a `.dependencies` file names.

import json
import os
import random
import shlex
from abc import ABC, abstractmethod
from collections import Counter
from collections.abc import Collection
from dataclasses import dataclass
from pathlib import Path

REPO_BASE = Path.cwd()

# The distro CI runs thirdparty tests on. Its images are built first.
PRIMARY_DISTRO = "ubuntu24.04"

# Where `ext:rust=` entries install rustup, as stressedtuna. See images/install-ext.sh.
RUST_HOME = "/home/stressedtuna"

# The order that sources install in. Later sources may need packages from earlier ones,
# e.g. `pipx:` needs `apt:pipx`.
SOURCE_ORDER = {"apt": 0, "dnf": 0, "pip": 1, "pipx": 1, "ext": 2}


def project_image(name: str, distro: str, nv: bool = False) -> str:
    """The docker image name for a project's builder image, without the registry or tag.

    `nv` selects the variant based on scale-test-nv-$distro, for NVIDIA targets.
    """
    # Docker image names must be lowercase.
    return f"thirdparty-{name.lower()}-{'nv-' if nv else ''}{distro}"


# Data structures for our graph
class Node(ABC):
    @property
    @abstractmethod
    def name(self) -> str:
        pass

    @property
    @abstractmethod
    def installed(self) -> frozenset[str]:
        pass

    @property
    @abstractmethod
    def base(self) -> "Node | None":
        pass

    def is_ancestor_of(self, node: "Node") -> bool:
        """True if `self` is `node` or one of its bases."""
        curr_node = node
        while curr_node is not None:
            if self is curr_node:
                return True
            curr_node = curr_node.base
        return False

    @abstractmethod
    def image(self, nv: bool = False) -> str:
        """The docker image name, without the registry or tag.

        `nv` selects the variant based on scale-test-nv-$distro, for NVIDIA targets.
        """

    @abstractmethod
    def dockerfile(self, nv: bool = False) -> str | None:
        """The dockerfile that builds this image, or None if it is built elsewhere."""

    @abstractmethod
    def to_install(self) -> frozenset[str]:
        pass

    def contents(self) -> frozenset[str]:
        """The packages actually in `node`'s image: what it and all of its bases install."""
        return (
            self.base.contents() if self.base is not None else frozenset()
        ) | self.to_install()


@dataclass(frozen=True)
class BaseImage(Node):
    """A scale-test-$distro image. This is the root of the graph: it has no outgoing edge."""

    distro: str

    @property
    def base(self) -> "Node | None":
        return None

    @property
    def name(self) -> str:
        return f"scale-test-{self.distro}"

    def image(self, nv: bool = False) -> str:
        return f"scale-test-nv-{self.distro}" if nv else self.name

    def dockerfile(self, nv: bool = False) -> str | None:
        # Built from ci/images.
        return None

    @property
    def installed(self) -> frozenset[str]:
        return frozenset()

    def to_install(self) -> frozenset[str]:
        return frozenset()


@dataclass
class ProjectImage(Node):
    """A project builder image. It always has exactly one base image."""

    project: str
    distro: str
    _installed: frozenset[str]
    _base: "Node"

    @property
    def name(self) -> str:
        return self.project

    @property
    def installed(self) -> frozenset[str]:
        return self._installed

    @property
    def base(self) -> "Node | None":
        return self._base

    def image(self, nv: bool = False) -> str:
        return project_image(self.name, self.distro, nv)

    def dockerfile(self, nv: bool = False) -> str | None:
        lines = [
            "# Generated by test/thirdparty/util/image_graph.py. Do not edit.",
            "ARG PRIVATE_DOCKER_REGISTRY",
            "ARG BASE_DOCKER_TAG",
            f"FROM ${{PRIVATE_DOCKER_REGISTRY}}spectral/{self._base.image(nv)}:$BASE_DOCKER_TAG",
        ]
        if commands := install_commands(self.to_install()):
            lines += ["", "USER root", *commands, "USER stressedtuna"]
        return "\n".join(lines) + "\n"

    def to_install(self) -> frozenset[str]:
        """The packages this image installs on top of its base."""
        return self.installed - self._base.installed


@dataclass
class LayerImage(ProjectImage):
    """An intermediate image split out of a project image. It installs one package."""

    layer: int

    @property
    def name(self) -> str:
        return f"{self.project}-layer{self.layer}"


# Parsing and initial construction stuff
def install_commands(packages: frozenset[str]) -> list[str]:
    """Dockerfile commands that install `<source>:<package>` strings, run as root."""
    by_source: dict[str, list[str]] = {}
    for entry in sorted(packages):
        source, package = entry.split(":", 1)
        by_source.setdefault(source, []).append(package)

    commands: list[str] = []
    # Distro packages go first, because pip and pipx may come from them. The apt lists are
    # kept, because CI installs the SCALE package with apt-get without updating them.
    if apt := by_source.pop("apt", None):
        commands.append(
            f"RUN apt-get update && apt-get install -y {shlex.join(apt)} && rm -rf /var/lib/apt/lists/"
        )
    if dnf := by_source.pop("dnf", None):
        commands.append(f"RUN dnf install -y {shlex.join(dnf)} && dnf clean all")
    if pip := by_source.pop("pip", None):
        # Older pip versions ignore this variable, so it is safe on every distro.
        commands.append(
            f"RUN PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install {shlex.join(pip)}"
        )
    if pipx := by_source.pop("pipx", None):
        # Install outside any home directory, so every user can run them.
        commands.append(
            "RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin"
            f" pipx install {shlex.join(pipx)}"
        )
    for package in by_source.pop("ext", []):
        commands.append(
            "RUN --mount=type=bind,source=install-ext.sh,target=/install-ext.sh"
            f" /install-ext.sh {shlex.quote(package)}"
        )
        if package.startswith("rust="):
            # rustup only adds itself to PATH in shell startup files, which CI never reads.
            commands.append(
                f"ENV CARGO_HOME={RUST_HOME}/.cargo RUSTUP_HOME={RUST_HOME}/.rustup"
                f" PATH={RUST_HOME}/.cargo/bin:$PATH"
            )
    if by_source:
        raise ValueError(f"Unknown package sources: {sorted(by_source)}")
    return commands


def read_dependencies(path: Path) -> dict[str, frozenset[str]]:
    """Read a `.dependencies` file. Returns `<source>:<package>` strings by distro."""
    by_distro: dict[str, set[str]] = {}
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        distro, source, package = line.split(":", 2)
        by_distro.setdefault(distro, set()).add(f"{source}:{package}")
    return {distro: frozenset(packages) for distro, packages in by_distro.items()}


def build_graph(
    distros: Collection[str] | None = None,
) -> tuple[dict[str, BaseImage], list[ProjectImage]]:
    """Make one node per project and distro, each based on scale-test-$distro.

    Only `distros` get nodes, or every distro a `.dependencies` file names if it is None.
    """
    deps = {
        path.parent.name: read_dependencies(path)
        for path in sorted(REPO_BASE.glob("*/.dependencies"))
    }
    if distros is None:
        distros = {distro for by_distro in deps.values() for distro in by_distro}
    roots = {distro: BaseImage(distro) for distro in distros}
    projects: list[ProjectImage] = []
    for project, by_distro in deps.items():
        # An empty file means the project needs only scale-test, on every distro.
        if not by_distro:
            by_distro = {distro: frozenset() for distro in roots}
        for distro, packages in by_distro.items():
            if distro in roots:
                projects.append(ProjectImage(project, distro, packages, roots[distro]))
    return roots, projects


# Optimisation passes
def split(projects: list[ProjectImage], rng: random.Random) -> list[ProjectImage]:
    """Split each project into a chain of images that each install one package.

    Packages install in `SOURCE_ORDER`, so e.g. `apt:pipx` comes before any `pipx:`
    package. Within a source, packages that more projects on the same distro need are
    installed first. Ties are broken by a random order, which is the same for every
    project. Returns the projects and the new layer images.
    """
    users = Counter((p.distro, package) for p in projects for package in p.installed)
    # Sort first, so the order depends only on `rng`.
    tie_break = sorted(users)
    rng.shuffle(tie_break)
    rank = {key: i for i, key in enumerate(tie_break)}

    nodes: list[ProjectImage] = []
    for p in projects:
        packages = sorted(
            p.installed,
            key=lambda package: (
                SOURCE_ORDER.get(package.split(":", 1)[0], 0),
                -users[p.distro, package],
                rank[p.distro, package],
            ),
        )
        base = p._base
        # The project image itself installs the last package.
        for i, package in enumerate(packages[:-1], 1):
            base = LayerImage(p.project, p.distro, base.installed | {package}, base, i)
            nodes.append(base)
        p._base = base
        nodes.append(p)
    return nodes


def optimise(roots: dict[str, BaseImage], projects: list[ProjectImage]) -> None:
    """Repoint each project at the image whose packages are the largest subset of its own.

    Repeats until nothing changes. A node may not be based on itself or its descendants,
    so the graph stays a tree.
    """
    changed = True
    while changed:
        changed = False
        for x in projects:
            candidates: list[Node] = [roots[x.distro]]
            candidates += [
                y
                for y in projects
                if y.distro == x.distro
                and y.installed <= x.installed
                and not x.is_ancestor_of(y)
            ]
            # On a tie, prefer the scale-test image, then the first project by name.
            best = min(
                candidates,
                key=lambda y: (-len(y.installed), isinstance(y, ProjectImage), y.name),
            )
            if best is not x.base:
                x._base = best
                changed = True


def remove_empty(nodes: list[ProjectImage]) -> list[ProjectImage]:
    """Remove layer images that install nothing. Their children use their base instead.

    Project images are always kept, because they are the images we need.
    """

    def is_empty(node: Node) -> bool:
        return isinstance(node, LayerImage) and not node.to_install()

    for n in nodes:
        while isinstance(n.base, LayerImage) and is_empty(n.base):
            assert n.base is not None
            assert n.base.base is not None
            n._base = n.base.base
    return [n for n in nodes if not is_empty(n)]


def remove_unused(nodes: list[ProjectImage]) -> list[ProjectImage]:
    """Remove layer images that no image uses as a base, until none are left."""
    while True:
        bases = {id(n.base) for n in nodes}
        kept = [n for n in nodes if not isinstance(n, LayerImage) or id(n) in bases]
        if len(kept) == len(nodes):
            return kept
        nodes = kept


def merge_single_children(nodes: list[ProjectImage]) -> list[ProjectImage]:
    """Merge each layer image that only one image uses into that image, until none are left.

    The child is rebased onto the layer's base, so it installs the layer's packages too.
    """
    while True:
        children = Counter(id(n.base) for n in nodes)
        for x in nodes:
            if isinstance(x, LayerImage) and children[id(x)] == 1:
                y = next(n for n in nodes if n.base is x)
                y._base = x._base
                nodes = [n for n in nodes if n is not x]
                break
        else:
            return nodes


# Correctness checks
def write_dockerfiles(
    node: Node, nodes: list[ProjectImage], out_dir: Path, nv: bool = False
) -> list[str]:
    """Write the dockerfile for `node` and every image based on it, recursively.

    `nv` writes the variants based on scale-test-nv-$distro. Returns the images written,
    with each image after its base.
    """
    written: list[str] = []
    if (text := node.dockerfile(nv)) is not None:
        (out_dir / f"{node.image(nv)}.dockerfile").write_text(text)
        written.append(node.image(nv))
    for child in nodes:
        if child.base is node:
            written += write_dockerfiles(child, nodes, out_dir, nv)
    return written


def build_script(images: list[str]) -> str:
    """A script that builds `images` in order, with util/mkImage.sh."""
    lines = [
        "#!/usr/bin/env bash",
        "# Generated by test/thirdparty/util/image_graph.py. Do not edit.",
        "# Builds every image in images/, each after its base. The scale-test-$distro and",
        "# scale-test-nv-$distro images must already exist. Arguments are passed to each",
        "# docker build.",
        "set -ETeuo pipefail",
        'IMAGES="$(dirname "$0")"',
        *(
            f'"$IMAGES/../util/mkImage.sh" "$IMAGES/{image}.dockerfile" "$@"'
            for image in images
        ),
    ]
    return "\n".join(lines) + "\n"


def check_exact(projects: list[ProjectImage]) -> None:
    """Raise if any project's image has packages other than the ones it needs."""
    for p in projects:
        if p.contents() != p.installed:
            raise RuntimeError(
                f"{p.name} on {p.distro} would contain {sorted(p.contents())},"
                f" but needs exactly {sorted(p.installed)}"
            )


# Driving code
def plan(
    rng: random.Random, distros: Collection[str] | None = None
) -> tuple[dict[str, BaseImage], list[ProjectImage], list[ProjectImage]]:
    """Run every pass, for `distros` (see `build_graph`).

    Returns the roots, the project images and all the images.
    """
    roots, projects = build_graph(distros)
    nodes = split(projects, rng)
    optimise(roots, nodes)
    nodes = merge_single_children(remove_unused(remove_empty(nodes)))
    check_exact(projects)
    return roots, projects, nodes


def print_tree(node: Node, projects: list[ProjectImage], depth: int = 0) -> None:
    line = "    " * depth + node.name
    if isinstance(node, ProjectImage):
        line += ": " + " ".join(sorted(node.to_install()))
    print(line.rstrip())
    for child in sorted(projects, key=lambda p: p.name):
        if child.base is node:
            print_tree(child, projects, depth + 1)


def main(seed: int | None = None) -> None:
    distros = json.loads(os.environ["DISTROS"]) if "DISTROS" in os.environ else None
    roots, _, nodes = plan(random.Random(seed), distros)
    out_dir = Path.cwd() / "images"
    out_dir.mkdir(exist_ok=True)
    # Layer images change between runs, so remove old dockerfiles.
    for old in out_dir.glob("*.dockerfile"):
        old.unlink()
    images: list[str] = []
    for distro in sorted(roots, key=lambda d: (d != PRIMARY_DISTRO, d)):
        print_tree(roots[distro], nodes)
        for nv in (False, True):
            images += write_dockerfiles(roots[distro], nodes, out_dir, nv)
    script = out_dir / "build.sh"
    script.write_text(build_script(images))
    script.chmod(0o755)


if __name__ == "__main__":
    main()
