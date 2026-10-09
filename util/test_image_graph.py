import random
from collections import Counter
from pathlib import Path

import image_graph
import pytest
from image_graph import (
    BaseImage,
    LayerImage,
    ProjectImage,
    build_graph,
    check_exact,
    install_commands,
    merge_single_children,
    optimise,
    plan,
    read_dependencies,
    remove_empty,
    remove_unused,
    split,
    write_dockerfiles,
)


@pytest.fixture
def repo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """An empty repo for `build_graph` to read projects from."""
    monkeypatch.setattr(image_graph, "REPO_BASE", tmp_path)
    return tmp_path


def add_project(repo: Path, name: str, *lines: str) -> None:
    (repo / name).mkdir()
    (repo / name / ".dependencies").write_text("".join(f"{line}\n" for line in lines))


def assert_not_none[T](x: T | None) -> T:
    assert x is not None
    return x


def optimised() -> dict[tuple[str, str], str]:
    """Build and optimise the graph. Returns each base's name by (project, distro)."""
    roots, projects = build_graph()
    optimise(roots, projects)
    return {(p.project, p.distro): assert_not_none(p.base).name for p in projects}


def test_read_dependencies(tmp_path: Path) -> None:
    path = tmp_path / ".dependencies"
    path.write_text(
        "ubuntu24.04:apt:bc\n"
        "\n"
        "ubuntu24.04:apt:libfoo=1:2.3\n"
        "ubuntu24.04:ext:cmake=4.0.3\n"
        "rocky9:dnf:bc\n"
    )
    assert read_dependencies(path) == {
        "ubuntu24.04": {"apt:bc", "apt:libfoo=1:2.3", "ext:cmake=4.0.3"},
        "rocky9": {"dnf:bc"},
    }


def test_read_dependencies_empty(tmp_path: Path) -> None:
    path = tmp_path / ".dependencies"
    path.write_text("")
    assert read_dependencies(path) == {}


def test_build_graph_starts_from_scale_test(repo: Path) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x")
    add_project(repo, "b", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y", "rocky9:dnf:x")
    roots, projects = build_graph()
    assert roots == {
        "ubuntu24.04": BaseImage("ubuntu24.04"),
        "rocky9": BaseImage("rocky9"),
    }
    assert {(p.project, p.distro) for p in projects} == {
        ("a", "ubuntu24.04"),
        ("b", "ubuntu24.04"),
        ("b", "rocky9"),
    }
    for p in projects:
        assert p.base is roots[p.distro]


def test_build_graph_empty_file_is_on_every_distro(repo: Path) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x", "rocky9:dnf:x")
    add_project(repo, "empty")
    _, projects = build_graph()
    empty = [p for p in projects if p.project == "empty"]
    assert {p.distro for p in empty} == {"ubuntu24.04", "rocky9"}
    assert all(p.installed == frozenset() for p in empty)


def test_is_ancestor() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset(), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset(), a)
    assert b.is_ancestor_of(b)
    assert a.is_ancestor_of(b)
    assert root.is_ancestor_of(b)
    assert not b.is_ancestor_of(a)
    assert not b.is_ancestor_of(root)


def test_to_install() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x"}), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), a)
    assert a.to_install() == {"apt:x"}
    assert b.to_install() == {"apt:y"}


def test_split_installs_one_package_per_image() -> None:
    root = BaseImage("ubuntu24.04")
    packages = frozenset({"apt:x", "apt:y", "apt:z"})
    project = ProjectImage("a", "ubuntu24.04", packages, root)
    nodes = split([project], random.Random(0))
    assert len(nodes) == 3
    assert nodes[-1] is project
    assert [n.name for n in nodes] == ["a-layer1", "a-layer2", "a"]
    assert all(isinstance(n, LayerImage) for n in nodes[:-1])
    assert nodes[0].base is root
    for n in nodes:
        assert len(n.to_install()) == 1
    assert project.installed == packages


def test_split_order_depends_on_seed() -> None:
    def order(seed: int) -> list[str]:
        root = BaseImage("ubuntu24.04")
        packages = frozenset(f"apt:{i}" for i in range(10))
        project = ProjectImage("a", "ubuntu24.04", packages, root)
        return [
            next(iter(n.to_install())) for n in split([project], random.Random(seed))
        ]

    assert order(0) == order(0)
    assert order(0) != order(1)


def test_split_puts_most_shared_packages_first() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y", "apt:z"}), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:y", "apt:z"}), root)
    c = ProjectImage("c", "ubuntu24.04", frozenset({"apt:z"}), root)
    # Projects on other distros don't count.
    d = ProjectImage("d", "rocky9", frozenset({"apt:x"}), BaseImage("rocky9"))
    e = ProjectImage("e", "rocky9", frozenset({"apt:x"}), BaseImage("rocky9"))
    nodes = split([a, b, c, d, e], random.Random(0))
    a_order = [next(iter(n.to_install())) for n in nodes if n.project == "a"]
    assert a_order == ["apt:z", "apt:y", "apt:x"]


@pytest.mark.parametrize("seed", range(20))
def test_split_breaks_ties_the_same_way_for_every_project(seed: int) -> None:
    root = BaseImage("ubuntu24.04")
    packages = frozenset({"apt:x", "apt:y", "apt:z"})
    a = ProjectImage("a", "ubuntu24.04", packages, root)
    b = ProjectImage("b", "ubuntu24.04", packages | {"apt:w"}, root)
    nodes = split([a, b], random.Random(seed))
    a_order = [next(iter(n.to_install())) for n in nodes if n.project == "a"]
    b_order = [next(iter(n.to_install())) for n in nodes if n.project == "b"]
    assert b_order[:3] == a_order
    assert b_order[3] == "apt:w"


def test_split_leaves_small_projects_alone() -> None:
    root = BaseImage("ubuntu24.04")
    empty = ProjectImage("empty", "ubuntu24.04", frozenset(), root)
    single = ProjectImage("single", "ubuntu24.04", frozenset({"apt:x"}), root)
    assert split([empty, single], random.Random(0)) == [empty, single]
    assert empty.base is root
    assert single.base is root


def test_split_then_optimise_makes_a_tree(repo: Path) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    add_project(
        repo, "b", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y", "ubuntu24.04:apt:z"
    )
    add_project(repo, "c", "ubuntu24.04:apt:y", "rocky9:dnf:y", "rocky9:dnf:w")
    roots, projects = build_graph()
    nodes = split(projects, random.Random(0))
    optimise(roots, nodes)
    for n in nodes:
        assert roots[n.distro].is_ancestor_of(n)
        assert n.base is not None
        assert n.base.installed <= n.installed


def test_remove_empty_skips_empty_layers() -> None:
    root = BaseImage("ubuntu24.04")
    x = frozenset({"apt:x"})
    a = ProjectImage("a", "ubuntu24.04", x, root)
    empty1 = LayerImage("b", "ubuntu24.04", x, a, 1)
    empty2 = LayerImage("b", "ubuntu24.04", x, empty1, 2)
    b = ProjectImage("b", "ubuntu24.04", x | {"apt:y"}, empty2)
    assert remove_empty([a, empty1, empty2, b]) == [a, b]
    assert b.base is a


def test_remove_empty_keeps_empty_projects() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset(), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x"}), a)
    assert remove_empty([a, b]) == [a, b]
    assert b.base is a


def test_remove_unused_removes_unused_chains() -> None:
    root = BaseImage("ubuntu24.04")
    used = LayerImage("a", "ubuntu24.04", frozenset({"apt:x"}), root, 1)
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), used)
    unused1 = LayerImage("b", "ubuntu24.04", frozenset({"apt:z"}), root, 1)
    unused2 = LayerImage("b", "ubuntu24.04", frozenset({"apt:z", "apt:y"}), unused1, 2)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x", "apt:y", "apt:z"}), a)
    assert remove_unused([used, a, unused1, unused2, b]) == [used, a, b]


def test_remove_unused_keeps_unused_projects() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x"}), root)
    assert remove_unused([a]) == [a]


def test_merge_single_children_merges_chains() -> None:
    root = BaseImage("ubuntu24.04")
    layer1 = LayerImage("a", "ubuntu24.04", frozenset({"apt:x"}), root, 1)
    layer2 = LayerImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), layer1, 2)
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y", "apt:z"}), layer2)
    assert merge_single_children([layer1, layer2, a]) == [a]
    assert a.base is root
    assert a.to_install() == {"apt:x", "apt:y", "apt:z"}


def test_merge_single_children_keeps_shared_layers() -> None:
    root = BaseImage("ubuntu24.04")
    shared = LayerImage("a", "ubuntu24.04", frozenset({"apt:x"}), root, 1)
    single = LayerImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), shared, 2)
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y", "apt:z"}), single)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x", "apt:w"}), shared)
    assert merge_single_children([shared, single, a, b]) == [shared, a, b]
    assert a.base is shared
    assert a.to_install() == {"apt:y", "apt:z"}


def test_merge_single_children_keeps_projects() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x"}), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), a)
    assert merge_single_children([a, b]) == [a, b]
    assert b.base is a


@pytest.mark.parametrize("seed", range(20))
def test_full_pipeline_leaves_only_useful_layers(repo: Path, seed: int) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    add_project(
        repo, "b", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y", "ubuntu24.04:apt:z"
    )
    add_project(repo, "c", "ubuntu24.04:apt:y", "ubuntu24.04:apt:w")
    add_project(repo, "d", "ubuntu24.04:apt:y")
    roots, projects, nodes = plan(random.Random(seed))
    assert {id(p) for p in projects} <= {id(n) for n in nodes}
    children = Counter(id(n.base) for n in nodes)
    for n in nodes:
        assert roots[n.distro].is_ancestor_of(n)
        assert n.base is not None
        assert n.base.installed <= n.installed
        if isinstance(n, LayerImage):
            assert n.to_install()
            assert children[id(n)] >= 2
        if isinstance(n.base, ProjectImage):
            assert any(m is n.base for m in nodes)


def declared(repo: Path) -> dict[tuple[str, str], frozenset[str]]:
    """The packages each project's `.dependencies` file asks for, by (project, distro)."""
    by_project = {
        path.parent.name: read_dependencies(path)
        for path in repo.glob("*/.dependencies")
    }
    distros = {distro for by_distro in by_project.values() for distro in by_distro}
    result: dict[tuple[str, str], frozenset[str]] = {}
    for project, by_distro in by_project.items():
        for distro in distros:
            result[project, distro] = by_distro.get(distro, frozenset())
        if by_distro:
            # Projects that list packages only exist on the distros they list.
            for distro in distros - by_distro.keys():
                del result[project, distro]
    return result


def assert_exact(repo: Path, seed: int) -> None:
    _, projects, _ = plan(random.Random(seed))
    assert {(p.project, p.distro): p.contents() for p in projects} == declared(repo)


@pytest.mark.parametrize("seed", range(20))
def test_projects_contain_exactly_their_dependencies(repo: Path, seed: int) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    add_project(repo, "b", *(f"ubuntu24.04:apt:{p}" for p in "xyz"))
    add_project(repo, "c", "ubuntu24.04:apt:y", "ubuntu24.04:apt:w")
    add_project(repo, "d", "ubuntu24.04:apt:y")
    add_project(repo, "e", "ubuntu24.04:apt:x", "rocky9:dnf:x", "rocky9:dnf:y")
    add_project(repo, "f", "rocky9:dnf:y")
    add_project(repo, "same-as-a", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    add_project(repo, "empty")
    assert_exact(repo, seed)


@pytest.mark.parametrize("seed", range(20))
def test_real_projects_contain_exactly_their_dependencies(
    monkeypatch: pytest.MonkeyPatch, seed: int
) -> None:
    repo = Path(__file__).resolve().parent.parent
    monkeypatch.setattr(image_graph, "REPO_BASE", repo)
    assert_exact(repo, seed)


def test_contents_includes_packages_from_bases() -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x", "apt:z"}), a)
    # b's base has apt:y, which b doesn't need.
    assert b.contents() == {"apt:x", "apt:y", "apt:z"}
    with pytest.raises(RuntimeError, match="b on ubuntu24.04"):
        check_exact([a, b])
    check_exact([a])


def test_optimise_picks_largest_subset(repo: Path) -> None:
    add_project(repo, "small", "ubuntu24.04:apt:x")
    add_project(repo, "medium", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    add_project(
        repo, "big", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y", "ubuntu24.04:apt:z"
    )
    assert optimised() == {
        ("small", "ubuntu24.04"): "scale-test-ubuntu24.04",
        ("medium", "ubuntu24.04"): "small",
        ("big", "ubuntu24.04"): "medium",
    }


def test_optimise_ignores_non_subsets(repo: Path) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    add_project(repo, "b", "ubuntu24.04:apt:x", "ubuntu24.04:apt:z")
    assert optimised() == {
        ("a", "ubuntu24.04"): "scale-test-ubuntu24.04",
        ("b", "ubuntu24.04"): "scale-test-ubuntu24.04",
    }


def test_optimise_keeps_distros_separate(repo: Path) -> None:
    add_project(repo, "a", "rocky9:apt:x")
    add_project(repo, "b", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    assert optimised() == {
        ("a", "rocky9"): "scale-test-rocky9",
        ("b", "ubuntu24.04"): "scale-test-ubuntu24.04",
    }


def test_optimise_empty_projects_use_scale_test(repo: Path) -> None:
    add_project(repo, "a")
    add_project(repo, "b")
    add_project(repo, "c", "ubuntu24.04:apt:x")
    assert optimised() == {
        ("a", "ubuntu24.04"): "scale-test-ubuntu24.04",
        ("b", "ubuntu24.04"): "scale-test-ubuntu24.04",
        ("c", "ubuntu24.04"): "scale-test-ubuntu24.04",
    }


def test_optimise_tie_prefers_first_name(repo: Path) -> None:
    add_project(repo, "b", "ubuntu24.04:apt:x")
    add_project(repo, "a", "ubuntu24.04:apt:y")
    add_project(repo, "c", "ubuntu24.04:apt:x", "ubuntu24.04:apt:y")
    assert optimised()[("c", "ubuntu24.04")] == "a"


def test_optimise_identical_sets_make_no_cycle(repo: Path) -> None:
    add_project(repo, "a", "ubuntu24.04:apt:x")
    add_project(repo, "b", "ubuntu24.04:apt:x")
    add_project(repo, "c", "ubuntu24.04:apt:x")
    roots, projects = build_graph()
    optimise(roots, projects)
    for p in projects:
        assert roots[p.distro].is_ancestor_of(p)
    assert sum(p.base is roots[p.distro] for p in projects) == 1


def test_main(
    repo: Path, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.chdir(repo)
    (repo / "images").mkdir()
    (repo / "images" / "stale.dockerfile").write_text("")
    # Each project installs at most one package, so the random split changes nothing.
    add_project(repo, "a", "ubuntu24.04:apt:x")
    add_project(repo, "b", "ubuntu24.04:apt:y")
    add_project(repo, "c")
    image_graph.main()
    assert capsys.readouterr().out == (
        "scale-test-ubuntu24.04\n    a: apt:x\n    b: apt:y\n    c:\n"
    )
    assert sorted(f.name for f in (repo / "images").iterdir()) == [
        "thirdparty-a-ubuntu24.04.dockerfile",
        "thirdparty-b-ubuntu24.04.dockerfile",
        "thirdparty-c-ubuntu24.04.dockerfile",
    ]


HEADER = (
    "# Generated by test/thirdparty/util/image_graph.py. Do not edit.\n"
    "ARG PRIVATE_DOCKER_REGISTRY\n"
    "ARG BASE_DOCKER_TAG\n"
)


def test_install_commands() -> None:
    assert install_commands(
        frozenset(
            {
                "pipx:dvc[s3]==3.67.1",
                "apt:pipx",
                "apt:bc",
                "pip:numpy==2.1.0",
                "dnf:bc",
                "ext:cmake=4.0.3",
            }
        )
    ) == [
        "RUN apt-get update && apt-get install -y bc pipx && rm -rf /var/lib/apt/lists/*",
        "RUN dnf install -y bc && dnf clean all",
        "RUN PIP_BREAK_SYSTEM_PACKAGES=1 pip3 install numpy==2.1.0",
        "RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install 'dvc[s3]==3.67.1'",
        (
            "RUN --mount=type=bind,source=install-ext.sh,target=/install-ext.sh"
            " /install-ext.sh cmake=4.0.3"
        ),
    ]


def test_install_commands_rejects_unknown_sources() -> None:
    with pytest.raises(ValueError, match="snap"):
        install_commands(frozenset({"snap:foo"}))


def test_base_image_has_no_dockerfile() -> None:
    assert BaseImage("ubuntu24.04").dockerfile() is None


def test_dockerfile_installs_only_what_base_lacks() -> None:
    root = BaseImage("ubuntu24.04")
    layer = LayerImage("Foo", "ubuntu24.04", frozenset({"apt:x"}), root, 1)
    project = ProjectImage("Foo", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), layer)
    assert layer.dockerfile() == HEADER + (
        "FROM ${PRIVATE_DOCKER_REGISTRY}spectral/scale-test-ubuntu24.04:$BASE_DOCKER_TAG\n"
        "\n"
        "USER root\n"
        "RUN apt-get update && apt-get install -y x && rm -rf /var/lib/apt/lists/*\n"
        "USER stressedtuna\n"
    )
    assert project.dockerfile() == HEADER + (
        "FROM ${PRIVATE_DOCKER_REGISTRY}spectral/thirdparty-foo-layer1-ubuntu24.04"
        ":$BASE_DOCKER_TAG\n"
        "\n"
        "USER root\n"
        "RUN apt-get update && apt-get install -y y && rm -rf /var/lib/apt/lists/*\n"
        "USER stressedtuna\n"
    )


def test_dockerfile_for_empty_project_is_just_from() -> None:
    project = ProjectImage("foo", "ubuntu24.04", frozenset(), BaseImage("ubuntu24.04"))
    assert project.dockerfile() == HEADER + (
        "FROM ${PRIVATE_DOCKER_REGISTRY}spectral/scale-test-ubuntu24.04:$BASE_DOCKER_TAG\n"
    )


def test_write_dockerfiles_writes_whole_tree(tmp_path: Path) -> None:
    root = BaseImage("ubuntu24.04")
    a = ProjectImage("a", "ubuntu24.04", frozenset({"apt:x"}), root)
    b = ProjectImage("b", "ubuntu24.04", frozenset({"apt:x", "apt:y"}), a)
    other = ProjectImage("c", "rocky9", frozenset(), BaseImage("rocky9"))
    write_dockerfiles(root, [a, b, other], tmp_path)
    assert sorted(f.name for f in tmp_path.iterdir()) == [
        "thirdparty-a-ubuntu24.04.dockerfile",
        "thirdparty-b-ubuntu24.04.dockerfile",
    ]
    assert (
        tmp_path / "thirdparty-b-ubuntu24.04.dockerfile"
    ).read_text() == b.dockerfile()
