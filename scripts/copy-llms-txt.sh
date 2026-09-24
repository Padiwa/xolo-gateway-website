#!/usr/bin/env bash

# Copie les fichiers llms.txt versionnés dans ce dépôt (overrides/llms/<lang>/)
# à la racine de chaque build Zensical (site/<lang>/llms.txt), après le build
# et avant la publication Mike.
#
# Les llms.txt sont propres à ce dépôt : ils ne sont pas régénérés depuis
# xolo-gateway/xolo, contrairement aux pages de contenu. Cela permet de
# maintenir une version stable des pointeurs même quand la structure de la
# documentation évolue, et de servir un llms.txt adapté à la couverture réelle
# de chaque langue (FR complet, EN/ES partiels).
#
# Le script ne fait pas échouer le build si un fichier manque pour une langue :
# on préfère publier sans llms.txt pour cette langue plutôt que de bloquer un
# déploiement. Le mode strict de Zensical (`make check`) reste inchangé.

set -euo pipefail

languages=(fr en es)

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${root_dir}/overrides/llms"
site_dir="${root_dir}/site"

if [[ ! -d "${source_dir}" ]]; then
  echo "llms.txt: ${source_dir} introuvable, étape ignorée." >&2
  exit 0
fi

copied=()
missing=()

for lang in "${languages[@]}"; do
  src="${source_dir}/${lang}/llms.txt"
  dst_dir="${site_dir}/${lang}"
  if [[ ! -d "${dst_dir}" ]]; then
    echo "llms.txt: site/${lang} absent (langue non construite ?), ignoré." >&2
    continue
  fi
  if [[ ! -f "${src}" ]]; then
    missing+=("${lang}")
    echo "llms.txt: overrides/llms/${lang}/llms.txt absent, ignoré." >&2
    continue
  fi
  cp -a "${src}" "${dst_dir}/llms.txt"
  copied+=("${lang}")
done

if [[ ${#copied[@]} -eq 0 && ${#missing[@]} -gt 0 ]]; then
  echo "llms.txt: aucun fichier copié (toutes les langues sont sans source)." >&2
  exit 0
fi

echo "llms.txt copiés pour : ${copied[*]}" \
  "(source : ${source_dir})"
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "llms.txt absents (langue sans source) : ${missing[*]}" >&2
fi
