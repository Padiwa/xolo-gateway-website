# xolo-gateway/docs

Construit, versionne et déploie la documentation de
[Xolo](https://github.com/xolo-gateway/xolo) sur
[xolo-gateway.org](https://xolo-gateway.org).

Le Markdown vit dans `xolo-gateway/xolo`, sous `docs/fr/`, `docs/en/` et
`docs/es/`. Ce dépôt ne contient que le rendu (Zensical) et le versionnement
(Mike, branche `gh-pages`).

## Trois langues, trois builds

Zensical ne rend qu'une langue par build. Chaque langue a donc sa configuration
(`zensical.<lang>.toml`) et son `docs_dir` (`content/<lang>`). Le français est
publié sans préfixe pour garder les URLs existantes, l'anglais et l'espagnol
sous `/en/` et `/es/`. Le sélecteur de langue envoie vers `/latest/` de la
langue cible, pas vers la page équivalente.

## En local

Python 3.10 ou plus et Git. `DOC_LANG` (défaut `fr`) choisit la langue.

```bash
make tools-sync                        # installe Zensical et Mike dans tools/.venv/
make preview XOLO_REF=main             # sert le français de xolo@main
make preview DOC_LANG=en XOLO_REF=main
make check-all XOLO_REF=main           # build strict des trois langues
make help                              # toutes les cibles
```

## Liens hors documentation

Les pages de Xolo renvoient aux fichiers de la racine du dépôt (`LICENSE.md`,
`GOVERNANCE.md`, `SECURITY.md`...) par des chemins relatifs : valides sur
GitHub, introuvables sur le site. `scripts/rewrite-repo-links.py`, appelé par
`scripts/prepare-source.sh`, transforme toute cible qui sort de `docs/<lang>`
en URL absolue vers le dépôt source, à la référence préparée
(`.../blob/vX.Y.Z/GOVERNANCE.md`) : la doc publiée pointe alors vers les
fichiers de sa propre version, et le build strict ne signale plus de page
manquante.

## Ce qui est publié

| URL | Contenu |
| --- | --- |
| `/X.Y.Z/` | Doc FR du tag `vX.Y.Z` |
| `/main/` | Doc FR de `xolo@main` |
| `/latest/`, `/dev/`, `/` | Redirections vers le dernier tag, `/main/`, `/latest/` |
| `/en/…`, `/es/…` | Même chose en anglais et en espagnol |

Seuls les tags `vMAJEUR.MINEUR.PATCH` publient, sans le `v`. Les redirections
sont des pages HTML, pas des liens symboliques : GitHub Pages ne suit pas ces
derniers. Une version publiée ne se réécrit pas ; une faute dans `0.55.0` se
corrige en publiant `0.55.1`.

## Déclenchement

`xolo-gateway/xolo` envoie un `repository_dispatch` à chaque push. Un tag
lance `publish-version.yml` (`/X.Y.Z/`, `/latest/`, `/`), un push sur `main`
lance `publish-main.yml` (`/main/`, `/dev/`). Ce dernier tourne aussi tous les
jours à 06:00 UTC pour rattraper un dispatch perdu.

Le dispatch a besoin du secret `DOCS_DISPATCH_TOKEN` côté Xolo, avec
`Contents: read & write` sur ce dépôt.

Publication à la main, depuis l'onglet Actions (« Publish Xolo
documentation ») ou en ligne de commande :

```bash
make publish-all VERSION=0.55.1 ALIASES=latest PUSH=true
make set-default-all DEFAULT=latest PUSH=true
make versions DOC_LANG=en
make delete DOC_LANG=en VERSION=0.55.0 PUSH=true
```

## Trouver un expert

La page « Trouver un expert » liste les entreprises qui accompagnent Xolo. Les
fiches vivent dans `xolo-gateway/org`, sous `experts/`, à raison d'un YAML par
entreprise ; leur format est documenté dans le README de ce dossier.

`scripts/prepare-experts.sh` clone ce dépôt à chaque build et
`scripts/render-experts.py` en tire `content/<lang>/experts.md`, dans les trois
langues. Les libellés de la page (titre, chapeau, pastille) sont dans
`[project.extra.experts]` de chaque `zensical.<lang>.toml`.

Les sponsors passent devant, puis le poids croissant, puis le nom. Leur lien
sort en `rel="noopener"` ; les autres gardent `nofollow`. Une fiche
`disabled: true` reste dans le dépôt sans apparaître sur le site, et n'est pas
relue : elle peut être incomplète.

`xolo-gateway/org` étant privé, les workflows lui passent le secret
`EXPERTS_TOKEN` : un PAT fine-grained ou un token de GitHub App avec
`Contents: read` sur ce dépôt. Sans jeton, la page est absente du build au lieu
de le casser. En publication, `EXPERTS_REQUIRED` vaut `true` dès que le secret
existe : un jeton expiré ou un dossier `experts/` disparu arrêtent alors le
build, plutôt que de retirer la page du site sans prévenir.

En local, `make serve` régénère la page à chaque démarrage à partir du clone
d'`org` posé à côté de celui-ci (`../xolo-org/experts`), sans jeton ni accès
réseau. `EXPERTS_SOURCE` pointe ailleurs si votre clone est autre part :

```bash
make serve                                              # utilise ../xolo-org/experts
make serve EXPERTS_SOURCE=/chemin/vers/experts
```

Sans ce voisin, la page est absente du rendu local : le reste du site se
construit normalement.

## Habillage

Le thème `modern` de Zensical est surchargé depuis `overrides/`, sans réécrire
ses gabarits :

- `stylesheets/extra.css` reporte les tokens du produit (IBM Plex, primaire
  `oklch(0.487 0.0973 236.2)`, rayon 9 px) sur les variables `--md-*`, puis
  ajuste en-tête, navigation, sommaire, code, tableaux et admonitions. Les
  blocs `bash`, `sh`, `shell`, `zsh` et `console` passent en terminal sombre.
- `main.html` rend la page d'accueil (hero, trois parcours, démarrage rapide,
  encart libre) depuis `[project.extra.home]` de chaque `zensical.<lang>.toml`.
  Le corps de `index.md` n'apparaît donc plus ; retirer ce bloc rend le rendu
  Markdown standard.
- `partials/xolo-illustration.html` dessine le schéma animé du hero (clients,
  Xolo, fournisseurs) en SVG et `@keyframes`, sans script ni image. Ses
  libellés viennent de `[project.extra.home.illustration]` ; sans ce bloc, le
  hero retombe sur la capture `image` si elle est définie. L'animation
  s'arrête avec `prefers-reduced-motion`.
- `partials/logo.html` et `partials/alternate.html` remplacent le logo et le
  sélecteur de langue du thème.

Les cartes de la page « Trouver un expert » sont stylées dans le même fichier,
sous `.xolo-expert`.

Les liens des parcours d'accueil sont écrits à la main dans les `.toml` et
`make check` ne les vérifie pas. À contrôler après un remaniement de `docs/`
côté Xolo.

## Licence

Celle du projet Xolo.
