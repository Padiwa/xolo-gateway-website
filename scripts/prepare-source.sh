#!/usr/bin/env bash

set -euo pipefail

repository="${XOLO_REPOSITORY:-https://github.com/xolo-gateway/xolo.git}"
ref="${XOLO_REF:?XOLO_REF doit contenir un tag, une branche ou un SHA}"
# Court-circuite le clone : les sources sont lues dans un checkout existant de
# Xolo. C'est ce que fait la CI de Xolo pour valider la documentation d'une PR
# avant sa publication. XOLO_REF sert alors uniquement à construire les liens
# GitHub réécrits.
source_dir="${XOLO_SOURCE:-}"

xolo_logo_src="${XOLO_LOGO_PATH:-internal/http/handler/webui/common/assets/logo.svg}"

# Langues publiées. Chaque langue est un docs_dir Zensical indépendant
# (content/<lang>), avec sa propre copie du logo : voir zensical.<lang>.toml.
languages=(fr en es)

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache_dir="${root_dir}/.cache/xolo"
content_dir="${root_dir}/content"

# Nettoie les répertoires de langue générés sans toucher à .gitkeep.
for lang in "${languages[@]}"; do
  rm -rf "${content_dir}/${lang}"
done

mkdir -p "${root_dir}/.cache" "${content_dir}"

if [[ -n "${source_dir}" ]]; then
  if [[ ! -d "${source_dir}" ]]; then
    echo "XOLO_SOURCE=${source_dir} introuvable" >&2
    exit 1
  fi
  cache_dir="$(cd "${source_dir}" && pwd)"
  origin="${cache_dir}"
else
  origin="${repository}@${ref}"
  rm -rf "${cache_dir}"
  git clone \
    --depth 1 \
    --branch "${ref}" \
    "${repository}" \
    "${cache_dir}"
fi

if [[ ! -d "${cache_dir}/docs/fr" ]]; then
  echo "Le répertoire docs/fr est absent de ${origin}" >&2
  exit 1
fi

if [[ -f "${cache_dir}/${xolo_logo_src}" ]]; then
  logo_src="${cache_dir}/${xolo_logo_src}"
else
  echo "Logo absent: ${cache_dir}/${xolo_logo_src}" >&2
  exit 1
fi

prepared=()
for lang in "${languages[@]}"; do
  src="${cache_dir}/docs/${lang}"
  if [[ ! -d "${src}" ]]; then
    echo "docs/${lang} absent de ${origin}, langue ignorée" >&2
    continue
  fi
  mkdir -p "${content_dir}/${lang}"
  cp -a "${src}/." "${content_dir}/${lang}/"
  # Logo versionné par langue, réécrasé à chaque prepare pour suivre les
  # évolutions éventuelles du fichier source.
  cp -a "${logo_src}" "${content_dir}/${lang}/logo.svg"
  # Les pages renvoient aux fichiers de la racine du dépôt Xolo (LICENSE.md,
  # GOVERNANCE.md...), absents du site : ces liens deviennent des URLs GitHub.
  "${root_dir}/scripts/rewrite-repo-links.py" \
    "${content_dir}/${lang}" \
    "${repository}" \
    "${ref}"
  prepared+=("${lang}")
done

if [[ ${#prepared[@]} -eq 0 ]]; then
  echo "Aucune langue n'a pu être préparée depuis ${origin}" >&2
  exit 1
fi

# Évite une publication Jekyll accidentelle.
touch "${content_dir}/.nojekyll"

echo "Documentation préparée depuis ${origin} pour : ${prepared[*]}"
