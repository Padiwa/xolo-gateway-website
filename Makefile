SHELL := /usr/bin/env bash

PYTHON ?= python3
TOOLS_DIR := $(CURDIR)/tools
VENV_DIR := $(TOOLS_DIR)/.venv
BIN_DIR := $(VENV_DIR)/bin

PIP := $(BIN_DIR)/pip
ZENSICAL := $(BIN_DIR)/zensical
MIKE := $(BIN_DIR)/mike
# Le fork Mike adapté à Zensical appelle l'exécutable `zensical` dans son PATH.
export PATH := $(BIN_DIR):$(PATH)

XOLO_REPOSITORY ?= https://github.com/xolo-gateway/xolo.git
XOLO_REF ?= main
# Checkout local de Xolo à utiliser à la place du clone (voir
# scripts/prepare-source.sh).
XOLO_SOURCE ?=

# Fiches d'experts : dépôt privé xolo-gateway/org, lu avec EXPERTS_TOKEN.
# EXPERTS_SOURCE court-circuite le clone et pointe un dossier local, ce qui
# évite d'avoir besoin d'un jeton pour une préversion.
EXPERTS_REPOSITORY ?= https://github.com/xolo-gateway/org.git
EXPERTS_REF ?= main
EXPERTS_REQUIRED ?= false
# Un clone d'org à côté de celui-ci sert de source : « make serve » affiche
# alors la page sans jeton ni accès réseau. La CI n'a pas ce voisin et retombe
# sur le clone distant.
EXPERTS_SOURCE ?= $(wildcard $(CURDIR)/../xolo-org/experts)
VERSION ?=
ALIASES ?=
PUSH ?= false
# Les alias sont matérialisés par des pages de redirection HTML : GitHub Pages
# ne suit pas les liens symboliques (défaut de Mike) et les copies dupliquent
# inutilement le contenu.
ALIAS_TYPE ?= redirect
DEFAULT ?= latest
# Gabarit HTML des pages de redirection (racine, alias latest/dev...) : ajoute
# des métadonnées Open Graph / Twitter pour des aperçus de lien informatifs.
REDIRECT_TEMPLATE := $(CURDIR)/overrides/mike-redirect-template.html

# Chaque langue est un build Zensical indépendant (docs_dir=content/<lang>),
# déployé par Mike sous son propre --deploy-prefix. Le français reste sans
# préfixe pour préserver les URLs existantes (xolo-gateway.org/latest/,
# /main/, /X.Y.Z/) ; anglais et espagnol sont publiés sous /en/ et /es/.
LANGUAGES := fr en es
DOC_LANG ?= fr
CONFIG := zensical.$(DOC_LANG).toml
DEPLOY_PREFIX := $(if $(filter fr,$(DOC_LANG)),,$(DOC_LANG))

.PHONY: help
help:
	@printf '%s\n' \
		"Commandes disponibles (DOC_LANG=fr|en|es, défaut fr) :" \
		"" \
		"  make tools                      Installe Zensical et Mike localement" \
		"  make tools-lock                 Génère tools/requirements.lock" \
		"  make tools-sync                 Installe depuis tools/requirements.lock" \
		"  make tools-clean                Supprime l'environnement Python local" \
		"  make prepare XOLO_REF=...       Récupère les sources : Xolo et experts" \
		"  make prepare-experts            Régénère la seule page « Trouver un expert »" \
		"  make prepare-experts EXPERTS_SOURCE=...  Depuis un dossier local" \
		"  make build DOC_LANG=...             Construit une langue" \
		"  make check DOC_LANG=...             Construit une langue en mode strict" \
		"  make check-all                  Construit les 3 langues en mode strict" \
		"  make copy-llms-txt              Copie overrides/llms/<lang>/llms.txt vers site/<lang>/" \
		"  make serve DOC_LANG=...             Lance le serveur local pour une langue" \
		"  make preview DOC_LANG=... XOLO_REF=...  Prépare et sert une langue" \
		"  make publish DOC_LANG=... VERSION=...   Publie une langue avec Mike" \
		"  make publish-all VERSION=...    Publie les 3 langues" \
		"  make publish-latest DOC_LANG=... ...    Publie et déplace l'alias latest" \
		"  make alias DOC_LANG=... VERSION=... ALIASES=...  (Re)pointe un alias" \
		"  make set-default DOC_LANG=... DEFAULT=  Redirige / vers cet alias (latest)" \
		"  make set-default-all DEFAULT=   set-default sur les 3 langues" \
		"  make versions DOC_LANG=...          Liste les versions Mike d'une langue" \
		"  make delete DOC_LANG=... VERSION=...    Supprime une version" \
		"  make clean                      Supprime les fichiers générés"

$(VENV_DIR)/pyvenv.cfg:
	$(PYTHON) -m venv "$(VENV_DIR)"
	"$(PIP)" install --upgrade pip setuptools wheel

.PHONY: tools
tools: $(VENV_DIR)/pyvenv.cfg
	"$(PIP)" install --requirement "$(TOOLS_DIR)/requirements.txt"

.PHONY: tools-lock
tools-lock: $(VENV_DIR)/pyvenv.cfg
	"$(PIP)" install pip-tools
	"$(BIN_DIR)/pip-compile" \
		--resolver=backtracking \
		--output-file "$(TOOLS_DIR)/requirements.lock" \
		"$(TOOLS_DIR)/requirements.txt"

.PHONY: tools-sync
tools-sync: $(VENV_DIR)/pyvenv.cfg
	"$(PIP)" install --requirement "$(TOOLS_DIR)/requirements.lock"

.PHONY: tools-clean
tools-clean:
	rm -rf "$(VENV_DIR)"

.PHONY: prepare
prepare: prepare-source prepare-experts

.PHONY: prepare-source
prepare-source:
	XOLO_REPOSITORY="$(XOLO_REPOSITORY)" \
	XOLO_REF="$(XOLO_REF)" \
	XOLO_SOURCE="$(XOLO_SOURCE)" \
		./scripts/prepare-source.sh

.PHONY: prepare-experts
prepare-experts:
	EXPERTS_REPOSITORY="$(EXPERTS_REPOSITORY)" \
	EXPERTS_REF="$(EXPERTS_REF)" \
	EXPERTS_SOURCE="$(EXPERTS_SOURCE)" \
	EXPERTS_REQUIRED="$(EXPERTS_REQUIRED)" \
		./scripts/prepare-experts.sh

.PHONY: build
build: tools
	"$(ZENSICAL)" build --clean --config-file "$(CONFIG)"

.PHONY: check
check: tools
	"$(ZENSICAL)" build --clean --strict --config-file "$(CONFIG)"

.PHONY: check-all
check-all: tools
	@for lang in $(LANGUAGES); do \
		echo "== check $$lang =="; \
		"$(ZENSICAL)" build --clean --strict --config-file "zensical.$$lang.toml" || exit 1; \
	done

# Pose les fichiers llms.txt à la racine de chaque build Zensical
# (site/<lang>/llms.txt). Les sources vivent dans overrides/llms/, versionnées
# dans ce dépôt, contrairement aux pages de contenu (qui viennent de
# xolo-gateway/xolo). Le script ne fait pas échouer le build quand un fichier
# manque : on préfère publier sans llms.txt pour cette langue plutôt que de
# bloquer un déploiement.
.PHONY: copy-llms-txt
copy-llms-txt:
	./scripts/copy-llms-txt.sh

# La page des experts est régénérée à chaque démarrage : elle vient d'un autre
# dépôt, Zensical ne sait pas la reconstruire tout seul. llms.txt est copié
# aussi : Zensical ne sert que les fichiers présents dans le docs_dir, et
# llms.txt vit dans overrides/, pas dans content/.
.PHONY: serve
serve: tools prepare-experts
	"$(ZENSICAL)" serve --config-file "$(CONFIG)"

.PHONY: preview
preview: prepare-source serve

# La publication pousse site/<lang>/ entier via mike deploy : il faut que
# llms.txt y soit déjà, sinon la page publiée est sans llms.txt. La
# dépendance le garantit pour publish et ses dérivés (publish-all,
# publish-latest, alias, set-default, set-default-all).
.PHONY: require-version
require-version:
	@test -n "$(VERSION)" || { \
		echo "VERSION est obligatoire, par exemple VERSION=1.4.0"; \
		exit 1; \
	}

.PHONY: publish
publish: require-version tools copy-llms-txt
	@args=(--deploy-prefix "$(DEPLOY_PREFIX)"); \
	if [[ "$(PUSH)" == "true" ]]; then \
		args+=(--push); \
	fi; \
	if [[ -n "$(ALIASES)" ]]; then \
		args+=(--update-aliases --alias-type="$(ALIAS_TYPE)" --template "$(REDIRECT_TEMPLATE)"); \
	fi; \
	"$(MIKE)" deploy --config-file "$(CONFIG)" "$${args[@]}" "$(VERSION)" $(ALIASES)

.PHONY: publish-all
publish-all: require-version tools
	@for lang in $(LANGUAGES); do \
		echo "== publish $$lang =="; \
		$(MAKE) publish DOC_LANG=$$lang VERSION="$(VERSION)" ALIASES="$(ALIASES)" PUSH="$(PUSH)" || exit 1; \
	done

.PHONY: publish-latest
publish-latest: ALIASES=latest
publish-latest: publish

.PHONY: alias
alias: require-version tools copy-llms-txt
	@test -n "$(ALIASES)" || { echo "ALIASES est obligatoire"; exit 1; }; \
	args=(--deploy-prefix "$(DEPLOY_PREFIX)" --update-aliases --alias-type="$(ALIAS_TYPE)" --template "$(REDIRECT_TEMPLATE)"); \
	if [[ "$(PUSH)" == "true" ]]; then \
		args+=(--push); \
	fi; \
	"$(MIKE)" alias --config-file "$(CONFIG)" "$${args[@]}" "$(VERSION)" $(ALIASES)

.PHONY: set-default
set-default: tools copy-llms-txt
	@args=(--deploy-prefix "$(DEPLOY_PREFIX)" --template "$(REDIRECT_TEMPLATE)"); \
	if [[ "$(PUSH)" == "true" ]]; then \
		args+=(--push); \
	fi; \
	"$(MIKE)" set-default --config-file "$(CONFIG)" "$${args[@]}" "$(DEFAULT)"

.PHONY: set-default-all
set-default-all: tools
	@for lang in $(LANGUAGES); do \
		echo "== set-default $$lang =="; \
		$(MAKE) set-default DOC_LANG=$$lang DEFAULT="$(DEFAULT)" PUSH="$(PUSH)" || exit 1; \
	done

.PHONY: versions
versions: tools
	"$(MIKE)" list --config-file "$(CONFIG)" --deploy-prefix "$(DEPLOY_PREFIX)"

.PHONY: delete
delete: require-version tools
	@args=(--deploy-prefix "$(DEPLOY_PREFIX)"); \
	if [[ "$(PUSH)" == "true" ]]; then \
		args+=(--push); \
	fi; \
	"$(MIKE)" delete --config-file "$(CONFIG)" "$${args[@]}" "$(VERSION)"

.PHONY: clean
clean:
	rm -rf \
		"$(CURDIR)/site" \
		"$(CURDIR)/.cache" \
		"$(CURDIR)/.cache-zensical"
