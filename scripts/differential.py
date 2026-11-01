#!/usr/bin/env python3
"""Differential testing: the library against independent Python implementations on the same
random cases.

    python3 scripts/differential.py                       # 300 cases per section, every section
    python3 scripts/differential.py --cases 3000 --seed 7
    python3 scripts/differential.py --section tries --section lru

The library side is Differential/, an executable that reads a section's cases as JSON and
answers them; it is built with SwiftPM in release. The references run under `uv` with pinned
versions (the script re-executes itself through `uv run` when they are not importable), so
nothing is installed globally. Only answers are compared, never shapes: a tree's balance or a
cache's internal order are the library's own business. A failing case is written to
Differential/Failures/<section>-<n>.json for a regression test.
"""

import argparse
import itertools
import json
import os
import random
import subprocess
import sys

PINS = ["sortedcontainers==2.4.0", "pygtrie==2.5.0", "pyahocorasick==2.1.0", "dd==0.6.0",
        "intervaltree==3.1.0", "scipy==1.18.1", "cachetools==6.2.0"]

try:
    import ahocorasick
    import cachetools
    import intervaltree
    import numpy
    import pygtrie
    from dd import autoref
    from scipy.spatial import cKDTree
    from sortedcontainers import SortedDict, SortedSet
except ImportError:
    if os.environ.get("GRAFLUENT_COLLECTIONS_DIFFERENTIAL_UV"):
        raise
    os.environ["GRAFLUENT_COLLECTIONS_DIFFERENTIAL_UV"] = "1"
    os.execvp("uv", ["uv", "run", "--quiet", "--no-project", *itertools.chain.from_iterable(("--with", p) for p in PINS), "python3", *sys.argv])

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKAGE = os.path.join(ROOT, "Differential")
FAILURES = os.path.join(PACKAGE, "Failures")
BINARY = os.path.join(PACKAGE, ".build", "release", "GrafluentCollectionsDifferential")

SETS = ["AVLTree", "RedBlackTree", "Treap", "SplayTree", "BTree", "SkipList", "PersistentTreeSet"]
DICTIONARIES = ["AVLDictionary", "BTreeDictionary", "PersistentTreeDictionary"]


def build():
    command = ["env", "-u", "TOOLCHAINS", "xcrun", "--toolchain", "default", "swift", "build", "-c", "release"] \
        if sys.platform == "darwin" else ["swift", "build", "-c", "release"]
    result = subprocess.run(command, cwd=PACKAGE, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("The differential build failed:\n" + (result.stdout + result.stderr)[-4000:])


def library(section, cases):
    result = subprocess.run([BINARY], input=json.dumps({"section": section, "cases": cases}),
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"The library side crashed on section {section}:\n{result.stderr[-4000:]}")
    return json.loads(result.stdout)


# MARK: - Sections: (generate a case, answer it with the references, compare)

def sorted_sets(rng):
    span = rng.choice([8, 64, 4096])
    ops = [[rng.choice(["insert", "insert", "insert", "remove", "contains", "lowerBound", "at"]), rng.randrange(span)]
           for _ in range(rng.randrange(400))]
    return {"structure": rng.choice(SETS), "ops": ops}


def sorted_sets_reference(case):
    s = SortedSet()
    answers = []
    for op, k in case["ops"]:
        if op == "insert":
            answers.append(k not in s)
            s.add(k)
        elif op == "remove":
            answers.append(k in s)
            s.discard(k)
        elif op == "contains":
            answers.append(k in s)
        elif op == "lowerBound":
            answers.append(s.bisect_left(k))
        else:
            answers.append(s[k % len(s)] if s else None)
    return {"answers": answers, "elements": list(s)}


def sorted_dictionaries(rng):
    span = rng.choice([8, 64, 4096])
    ops = []
    for serial in range(rng.randrange(300)):
        op = rng.choice(["set", "set", "remove", "get"])
        ops.append([op, rng.randrange(span)] + ([serial] if op == "set" else []))
    return {"structure": rng.choice(DICTIONARIES), "ops": ops}


def sorted_dictionaries_reference(case):
    d = SortedDict()
    answers = []
    for op in case["ops"]:
        k = op[1]
        old = d.get(k)
        answers.append(old)
        if op[0] == "set":
            d[k] = op[2]
        elif op[0] == "remove":
            d.pop(k, None)
    return {"answers": answers, "pairs": [[k, v] for k, v in d.items()]}


def word(rng, alphabet="abc", longest=5):
    return "".join(rng.choice(alphabet) for _ in range(rng.randrange(longest + 1)))


def tries(rng):
    return {"ops": [[rng.choice(["insert", "insert", "remove", "contains", "prefix", "longest"]), word(rng)]
                    for _ in range(rng.randrange(200))]}


def tries_reference(case):
    trie = pygtrie.CharTrie()
    answers = []
    for op, key in case["ops"]:
        if op == "insert":
            answers.append(key not in trie)
            trie[key] = True
        elif op == "remove":
            answers.append(key in trie)
            trie.pop(key, None)
        elif op == "contains":
            answers.append(key in trie)
        elif op == "prefix":
            answers.append(sorted(trie.keys(prefix=key)) if trie.has_node(key) else [])
        else:
            step = trie.longest_prefix(key)
            answers.append(step.key if step else None)
    return {"Trie": answers, "RadixTree": answers}


def aho_corasick(rng):
    patterns = sorted({word(rng, "ab", 4) or "a" for _ in range(1 + rng.randrange(8))})
    return {"patterns": patterns, "text": word(rng, "abc", 60)}


def aho_corasick_reference(case):
    automaton = ahocorasick.Automaton()
    for index, pattern in enumerate(case["patterns"]):
        automaton.add_word(pattern, index)
    automaton.make_automaton()
    matches = [[index, end - len(case["patterns"][index]) + 1, end + 1] for end, index in automaton.iter(case["text"])]
    return sorted(matches)


def suffix(rng):
    alphabet = "abcd"[: 1 + rng.randrange(4)]
    return {"text": word(rng, alphabet, 80), "patterns": [word(rng, alphabet, 4) for _ in range(10)]}


def suffix_reference(case):
    text = case["text"]
    positions = sorted(range(len(text)), key=lambda i: text[i:])
    substrings = {text[i:j] for i in range(len(text)) for j in range(i + 1, len(text) + 1)}
    longest = max((len(s) for s in substrings if text.find(s) != text.rfind(s)), default=0)
    counts = [sum(text.startswith(p, i) for i in range(len(text) - len(p) + 1)) if p else len(text) for p in case["patterns"]]
    # The suffix tree and automaton count the empty pattern's occurrences their own way.
    return {"positions": positions, "distinct": len(substrings), "longestRepeat": longest,
            "arrayCounts": counts, "treeCounts": counts, "automatonCounts": counts}


def binary_decision_diagram(rng):
    n = 1 + rng.randrange(10)
    steps = [["var", v] for v in range(n)]
    for _ in range(rng.randrange(40)):
        k = len(steps)
        op = rng.choice(["and", "or", "xor", "not", "ite", "exists"])
        if op == "not":
            steps.append([op, rng.randrange(k)])
        elif op == "ite":
            steps.append([op, rng.randrange(k), rng.randrange(k), rng.randrange(k)])
        elif op == "exists":
            steps.append([op, rng.randrange(k), rng.randrange(n)])
        else:
            steps.append([op, rng.randrange(k), rng.randrange(k)])
    return {"variables": n, "steps": steps}


def binary_decision_diagram_reference(case):
    n = case["variables"]
    bdd = autoref.BDD()
    names = [f"x{v}" for v in range(n)]
    bdd.declare(*names)
    functions = []
    for step in case["steps"]:
        op, args = step[0], step[1:]
        if op == "var":
            u = bdd.var(names[args[0]])
        elif op == "and":
            u = functions[args[0]] & functions[args[1]]
        elif op == "or":
            u = functions[args[0]] | functions[args[1]]
        elif op == "xor":
            u = bdd.apply("xor", functions[args[0]], functions[args[1]])
        elif op == "not":
            u = ~functions[args[0]]
        elif op == "ite":
            u = bdd.ite(functions[args[0]], functions[args[1]], functions[args[2]])
        else:
            u = bdd.exist([names[args[1]]], functions[args[0]])
        functions.append(u)
    return [float(bdd.count(u, nvars=n)) for u in functions]


def intervals(rng):
    ops = []
    for serial in range(rng.randrange(200)):
        a, b = sorted(rng.sample(range(30), 2))
        op = rng.choice(["insert", "insert", "remove", "overlap", "at", "contained"])
        ops.append([op, a, b] + ([serial] if op == "insert" else []))
    return {"ops": ops}


def intervals_reference(case):
    tree = intervaltree.IntervalTree()
    answers = []
    for op in case["ops"]:
        kind, a, b = op[0], op[1], op[2]
        if kind == "insert":
            tree.addi(a, b, op[3])
            answers.append(None)
        elif kind == "remove":
            # The library removes the earliest inserted interval with these bounds.
            same = sorted(i.data for i in tree.envelop(a, b) if i.begin == a and i.end == b)
            if same:
                tree.removei(a, b, same[0])
            answers.append(same[0] if same else None)
        elif kind == "overlap":
            answers.append(sorted(i.data for i in tree.overlap(a, b)))
        elif kind == "at":
            answers.append(sorted(i.data for i in tree.at(a)))
        else:
            answers.append(sorted(i.data for i in tree.envelop(a, b)))
    return answers


def spatial(rng):
    # A coarse grid in half the cases, so points coincide and distances tie.
    grid = rng.random() < 0.5
    point = (lambda: [rng.randrange(9) / 8, rng.randrange(9) / 8]) if grid else (lambda: [rng.random(), rng.random()])
    return {"points": [point() for _ in range(rng.randrange(300))],
            "queries": [{"point": point(), "k": rng.randrange(6), "radius": rng.choice([0.0, 0.05, 0.125, 0.3])} for _ in range(10)]}


def spatial_reference(case):
    points = numpy.array(case["points"]).reshape(-1, 2)
    tree = cKDTree(points) if len(points) else None
    answers = []
    for query in case["queries"]:
        k, radius = query["k"], query["radius"]
        if tree is None:
            answers.append({"nearest": [], "within": []})
            continue
        nearest = []
        if k > 0:
            distances, _ = tree.query(query["point"], k=k)
            nearest = [d for d in numpy.atleast_1d(distances).tolist() if d != float("inf")]
        answers.append({"nearest": nearest, "within": sorted(tree.query_ball_point(query["point"], radius))})
    return {"KDTree": answers, "Quadtree": answers}


def lru(rng):
    return {"capacity": rng.randrange(1, 6),
            "ops": [[rng.choice([0, 0, 1, 1, 1, 2, 3]), rng.randrange(10), serial] for serial in range(rng.randrange(300))]}


def lru_reference(case):
    cache = cachetools.LRUCache(maxsize=case["capacity"])
    answers = []
    for op, key, value in case["ops"]:
        if op == 0:
            answers.append(cache.get(key))
        elif op == 1:
            cache[key] = value
            answers.append(None)
        elif op == 2:
            answers.append(cache.pop(key, None))
        else:
            answers.append(key in cache)
    return {"answers": answers, "keys": sorted(cache.keys())}


def close(a, b):
    """Equal, with floating-point values within 1e-9."""
    if isinstance(a, float) or isinstance(b, float):
        return isinstance(a, (int, float)) and isinstance(b, (int, float)) and abs(a - b) <= 1e-9 * max(1, abs(a), abs(b))
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(close(x, y) for x, y in zip(a, b))
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(close(a[k], b[k]) for k in a)
    return a == b


SECTIONS = {
    "sortedsets": (sorted_sets, sorted_sets_reference),
    "sorteddicts": (sorted_dictionaries, sorted_dictionaries_reference),
    "tries": (tries, tries_reference),
    "ahocorasick": (aho_corasick, aho_corasick_reference),
    "suffix": (suffix, suffix_reference),
    "bdd": (binary_decision_diagram, binary_decision_diagram_reference),
    "intervals": (intervals, intervals_reference),
    "spatial": (spatial, spatial_reference),
    "lru": (lru, lru_reference),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cases", type=int, default=300, help="cases per section")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--section", action="append", choices=sorted(SECTIONS), help="repeatable; default every section")
    args = parser.parse_args()
    seed = args.seed if args.seed is not None else random.randrange(1 << 30)
    print(f"Seed {seed}, {args.cases} cases per section", flush=True)
    build()
    failed = False
    for name in args.section or list(SECTIONS):
        generate, reference = SECTIONS[name]
        rng = random.Random(f"{seed}-{name}")
        cases = [generate(rng) for _ in range(args.cases)]
        answers = library(name, cases)
        failures = [(case, got, reference(case)) for case, got in zip(cases, answers)]
        failures = [f for f in failures if not close(f[1], f[2])]
        print(f"{name:<12} {len(cases):>5} cases  " + ("ok" if not failures else f"{len(failures)} FAILED"), flush=True)
        if failures:
            failed = True
            os.makedirs(FAILURES, exist_ok=True)
            for n, (case, got, expected) in enumerate(failures[:5]):
                path = os.path.join(FAILURES, f"{name}-{n}.json")
                with open(path, "w") as out:
                    json.dump({"seed": seed, "case": case, "library": got, "reference": expected}, out, indent=1)
                print(f"    {os.path.relpath(path, ROOT)}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
