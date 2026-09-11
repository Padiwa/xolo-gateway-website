#!/usr/bin/env python3

"""Réécrit les liens qui sortent du répertoire de documentation.

Les pages de Xolo pointent vers des fichiers de la racine du dépôt
(LICENSE.md, GOVERNANCE.md...) par des chemins relatifs valides sur GitHub
mais absents du site : Zensical les signale, et « --strict » échoue. Ces
liens sont donc transformés en URLs absolues vers le dépôt source, à la
référence utilisée pour la préparation.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from urllib.parse import quote

# Liens Markdown en ligne « [texte](cible) » et définitions de référence
# « [clé]: cible ». Le titre facultatif est conservé tel quel.
INLINE = re.compile(r"(?<!\!)(\[(?:[^\]\\]|\\.)*\]\()(\s*)(<[^>\s]+>|[^()\s]+)")
REFERENCE = re.compile(r"(?m)^(\s{0,3}\[(?:[^\]\\]|\\.)+\]:\s+)(<[^>\s]+>|\S+)")

SKIPPED_SCHEMES = ("http://", "https://", "mailto:", "tel:", "ftp://", "data:")


def repository_base_url(repository: str, ref: str) -> str:
    """URL « blob » du dépôt source, pour les deux formes d'URL Git usuelles."""
    url = repository.removesuffix(".git")
    if url.startswith("git@"):
        host, _, path = url.partition(":")
        url = f"https://{host.removeprefix('git@')}/{path}"
    return f"{url}/blob/{quote(ref, safe='')}"


def rewrite_target(target: str, page: Path, docs_dir: Path, base_url: str) -> str | None:
    """Renvoie l'URL absolue d'une cible sortant de « docs_dir », sinon None."""
    bare = target[1:-1] if target.startswith("<") and target.endswith(">") else target
    if not bare or bare.startswith("#") or bare.startswith("/"):
        return None
    if bare.lower().startswith(SKIPPED_SCHEMES):
        return None

    path, separator, suffix = bare.partition("#")
    if not path:
        return None

    resolved = os.path.normpath(page.parent / path)
    if not os.path.relpath(resolved, docs_dir).startswith(".."):
        return None

    # La copie conserve la profondeur du dépôt source : content/<lang> occupe
    # la place de docs/<lang>, donc content/ celle de docs/ et son parent celle
    # de la racine du dépôt Xolo.
    relative = os.path.relpath(resolved, docs_dir.parent.parent)
    if relative.startswith(".."):
        return None
    quoted = quote(relative.replace(os.sep, "/"), safe="/")
    return f"{base_url}/{quoted}{separator}{suffix}"


def rewrite_page(page: Path, docs_dir: Path, base_url: str) -> int:
    original = page.read_text(encoding="utf-8")
    rewritten = 0

    def replace(match: re.Match[str], target_group: int) -> str:
        nonlocal rewritten
        target = match.group(target_group)
        url = rewrite_target(target, page, docs_dir, base_url)
        if url is None:
            return match.group(0)
        rewritten += 1
        return match.group(0)[: match.start(target_group) - match.start(0)] + url

    content = INLINE.sub(lambda match: replace(match, 3), original)
    content = REFERENCE.sub(lambda match: replace(match, 2), content)

    if content != original:
        page.write_text(content, encoding="utf-8")
    return rewritten


def main() -> int:
    try:
        docs_dir = Path(sys.argv[1]).resolve()
        repository = sys.argv[2]
        ref = sys.argv[3]
    except IndexError:
        print("usage: rewrite-repo-links.py <docs_dir> <repository> <ref>", file=sys.stderr)
        return 2

    base_url = repository_base_url(repository, ref)
    total = 0
    for page in sorted(docs_dir.rglob("*.md")):
        total += rewrite_page(page, docs_dir, base_url)

    print(f"Liens hors documentation réécrits vers {base_url} : {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
