# Markdown

Éditeur Markdown macOS minimal construit avec SwiftUI et le système de documents natif de macOS. Je l'utilise pour intégrer des editeurs de texte dans des projets plus importants.

## Objectif

L'application vise à rester légère :

- une seule vue d'édition
- un document texte simple
- le minimum de logique nécessaire pour ouvrir, éditer et sauvegarder un fichier

## Architecture

Le projet sépare volontairement deux responsabilités :

- `EditorState` gère l'état d'édition en mémoire
- `MarkdownDocument` gère la lecture et l'écriture de fichiers via `FileDocument`

Cette séparation évite de mélanger la logique UI avec la logique de persistance et permet d'intégrer soit la partie édition soit la partie sauvegarde de fichier.

Les sources sont rangées en deux sous-dossiers :

- `Markdown/Editor/` pour tout ce qui concerne l'édition et le rendu live
- `Markdown/Document/` pour tout ce qui concerne le système de document et la sauvegarde

## Fichiers et rôles

### Application

- `Markdown/MarkdownApp.swift`
  Point d'entrée de l'application. Déclare `DocumentGroup`, injecte la vue d'édition et remplace les commandes de sauvegarde par les raccourcis voulus.

- `Markdown/Editor/ContentView.swift`
  Vue principale. Elle affiche l'éditeur Markdown stylé en direct et injecte la barre de formatage séparée entre paragraphes, caractères et insertion.

- `Markdown/Editor/EditorState.swift`
  Contient `EditorState`, c'est-à-dire l'état d'édition en mémoire.

- `Markdown/Document/MarkdownDocument.swift`
  Couche document/persistance. Lit le contenu d'un fichier texte ou Markdown et reconstruit l'état de l'éditeur. Écrit ensuite ce même état sur disque.

- `Markdown/Document/DocumentCommands.swift`
  Redéfinit les commandes de sauvegarde pour garantir :
  `⌘S` = Enregistrer
  `⌘⇧S` = Enregistrer sous…
  `⌘⇧E` = Exporter en PDF…
  `Duplicate` reste disponible séparément

- `Markdown/Document/MarkdownPDFRenderer.swift`
  Pipeline de rendu PDF. Transforme le Markdown en document paginé A4 avec formatage, police Baskerville, gestion des paragraphes et des sauts de ligne Markdown.

- `Markdown/Document/MarkdownPDFExporter.swift`
  Présente le panneau d’export PDF et écrit le fichier sur disque à partir du rendu généré.

- `Markdown/Editor/FormattingCommands.swift`
  Ajoute le menu `Format`, lui aussi séparé entre paragraphes, caractères et insertion.

- `Markdown/Editor/EditorFormattingBar.swift`
  Barre de formatage SwiftUI visible dans la fenêtre. Elle expose directement les boutons Markdown disponibles et les regroupe par type d'action.

- `Markdown/Editor/MarkdownFormattingActions.swift`
  Catalogue partagé des actions de formatage. Définit les libellés, aides, sélecteurs et raccourcis réutilisés par la barre SwiftUI et le menu `Format`.

- `Markdown/Editor/MarkdownEditor.swift`
  Pont SwiftUI/AppKit. Emballe un `NSTextView` dans SwiftUI pour permettre un vrai rendu riche en cours d'édition.

- `Markdown/Editor/MarkdownLayoutManager.swift`
  Layout manager AppKit dédié aux marqueurs visuels ajoutés uniquement à l'affichage, par exemple le symbole de retour chariot après un saut de ligne Markdown.

- `Markdown/Editor/MarkdownTextView.swift`
  Sous-classe `NSTextView` qui applique les actions de formatage sur la sélection courante, gère `⇧↩`, ouvre les liens au `⌘`+clic et permet de remplacer le chemin d'une image inline au clic.

- `Markdown/Editor/MarkdownTextStyler.swift`
  Logique de style live. Interprète les marqueurs Markdown visibles, applique les styles visuels correspondants et marque certains segments interactifs comme les chemins d'images inline.

- `Markdown/Editor/MarkdownFormatting.swift`
  Logique pure de transformation de texte utilisée par toutes les actions Markdown, aussi bien inline que paragraphe.

### Ressources

- `Markdown/Assets.xcassets/`
  Contient les ressources visuelles de l'application, notamment l'icône et la couleur d'accentuation.

### Projet Xcode

- `Markdown.xcodeproj/project.pbxproj`
  Configuration principale du projet Xcode : targets, build settings, sandbox et entitlements générés.

- `Markdown.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
  Fichier de workspace Xcode minimal.

- `Markdown.xcodeproj/xcuserdata/...`
  Préférences locales Xcode liées à l'utilisateur. Ces fichiers sont utiles à l'IDE, mais n'ont pas de rôle fonctionnel dans l'application.

### Tests

- `MarkdownTests/MarkdownTests.swift`
  Cible de tests unitaires. Elle vérifie la lecture/écriture du document, les transformations Markdown pures et quelques comportements clés du rendu live.

- `MarkdownUITests/MarkdownUITests.swift`
  Cible de tests UI pour les interactions globales de l'application.

- `MarkdownUITests/MarkdownUITestsLaunchTests.swift`
  Test de lancement séparé, utile pour valider l'ouverture de l'application et produire une capture de référence.

## Sauvegarde

L'application utilise le système de documents natif de macOS avec `DocumentGroup`.

Cela apporte directement :

- l'ouverture de fichiers
- l'enregistrement
- l'enregistrement sous
- l'export PDF
- l'intégration correcte avec les menus système
- une meilleure stabilité qu'une gestion manuelle de `NSSavePanel`

L'export PDF repose sur un rendu dédié :

- pagination A4
- marges de 2,5 cm sur les quatre côtés
- texte en Baskerville 12 comme base
- interligne 1,5
- paragraphes avec 0 pt avant et 6 pt après
- premier `#` en tête de document traité comme titre d’article : 16 pt gras, 12 pt après
- `#` suivants : 14 pt gras, 18 pt avant, 6 pt après
- `##` : 12 pt gras, 12 pt avant, 6 pt après
- `###` et niveaux suivants : 12 pt gras italique, 6 pt avant, 3 pt après
- titres et emphases rendus dans le PDF
- listes ordonnées et non ordonnées rendues avec indentation
- ligne horizontale rendue comme une vraie barre sur toute la largeur utile
- indices et exposants rendus dans le PDF
- images locales rendues simplement, centrées, avec le texte avant et après
- gestion explicite des lignes vides entre paragraphes
- gestion des sauts de ligne Markdown à l’intérieur d’un paragraphe
- blocs LaTeX ignorés pour l’instant lors du rendu PDF

## Édition Markdown

L'éditeur garde les marqueurs Markdown visibles pendant la saisie, mais applique un rendu riche en direct.

L'interface sépare maintenant clairement :

- le formatage de paragraphes : titres ATX, citations, listes, blocs LaTeX et blocs de code
- le formatage de caractères : gras, italique, code inline, indice et exposant
- l'insertion : liens, images, sauts de ligne Markdown et séparateurs horizontaux

Quand un style de paragraphe remplace un autre, l'ancien marqueur est retiré avant d'appliquer le nouveau.

Exemples :

- `# Titre` : la ligne reste visible avec `#`, mais le contenu est affiché comme un vrai titre
- `Titre` suivi de `===` ou `---` : rendu titre style Setext
- `**gras**` : le texte est affiché en gras
- `__gras__` : variante underscore du gras
- `*italique*` ou `_italique_` : le texte est affiché en italique
- `***mixte***` : le texte est affiché en gras et en italique
- `H~2~O` : le contenu entre `~` est affiché comme un indice
- `X^2^` : le contenu entre `^` est affiché comme un exposant
- `$$ ... $$` : bloc LaTeX littéral, le Markdown interne n'est pas interprété
- deux espaces en fin de ligne ou `⇧↩` : saut de ligne Markdown, affiché avec les deux espaces surlignés et un symbole `↩`
- `![alt](chemin)` : le chemin est remplaçable via `⌘`+clic sur l'image inline
- `` `code` ``, les blocs indentés et les blocs ``` : rendu monospace
- `> citation` : rendu citation sans indentation supplémentaire
- `- item` et `1. item` : rendu liste avec indentation
- `HR` : insertion de `---` avec 0, 1 ou 2 sauts de ligne selon le contexte pour éviter la confusion avec un titre Setext
- `[texte](url)`, `[texte][id]` et `<https://...>` : rendu lien

## Interactions

- `⌘`+clic sur un lien ouvre l'URL dans l'application par défaut.
- `⌘`+clic sur le chemin d'une image inline `![alt](...)` ouvre un sélecteur d'image et remplace le chemin dans le texte Markdown.
- `Entrée` en fin d'élément de liste poursuit automatiquement la liste.
- `Entrée` sur une puce vide supprime cette puce et revient à un paragraphe normal.

## Entitlements macOS

Comme l'application utilise le sandbox, l'accès utilisateur aux fichiers doit être configuré en lecture/écriture.

Point important :

- `User Selected File` doit être réglé sur `Read/Write`

Sinon, le panneau `Save` peut échouer à s'afficher.

- garder les diagnostics PDF désactivés hors debug pour ne pas réintroduire de bruit CPU, mémoire ou I/O

## Lancer le projet

1. Ouvrir `Markdown.xcodeproj` dans Xcode.
2. Sélectionner le scheme `Markdown`.
3. Lancer l'application sur `My Mac`.

## Raccourcis

- `⌘N` : Nouveau document, via `DocumentGroup`
- `⌘O` : Ouvrir…, via `DocumentGroup`
- `⌘S` : Enregistrer
- `⌘⇧S` : Enregistrer sous…
- `⌘B` : Gras
- `⌘I` : Italique
- `⌃⌘C` : Code inline
- `⌃⌘-` : Indice
- `⌃⌘+` : Exposant
- `⌘K` : Lien inline
- `⇧↩` : Saut de ligne Markdown
- `⌥⌘1` : Titre H1
- `⌥⌘2` : Titre H2
- `⌥⌘3` : Titre H3
- `⌥⌘4` : Titre H4
- `⌥⌘5` : Titre H5
- `⌥⌘6` : Titre H6
- `⌥⌘Q` : Citation
- `⌘⇧8` : Liste non ordonnée
- `⌘⇧7` : Liste ordonnée
- `⌥⌘L` : Bloc LaTeX
- `⌥⌘C` : Bloc de code
- `⌥⌘I` : Image
- `⌥⌘R` : Ligne horizontale
- `⌘⇧E` : Exporter en PDF…

## Menus

- `Fichier` : `Enregistrer`, `Enregistrer sous…` et `Exporter en PDF…` sont redéfinis explicitement. `Dupliquer` reste disponible dans ce groupe, sans raccourci dédié.
- `Format > Paragraphes` : titres H1 à H6, citation, liste non ordonnée, liste ordonnée, bloc LaTeX, bloc de code.
- `Format > Caractères` : gras, italique, code inline, indice, exposant.
- `Format > Insertion` : lien, image, saut de ligne, ligne horizontale.

## État actuel

- L'application fonctionne comme un éditeur Markdown hybride : le code Markdown reste visible, mais le rendu WYSIWYG s'applique en direct.
- La sauvegarde passe par le système de documents natif de macOS.
- L'export PDF génère un document paginé avec rendu Markdown, Baskerville 12 en base et gestion des paragraphes.
- Les tests couvrent la persistance, les transformations de texte, le rendu PDF et plusieurs comportements de rendu live.

## Petites pistes

- ajouter des réglages d'interface claire ou sombre
- rendre le projet compatible Liquid Glass

## Grosses maj futures

- un gestionnaire de section
- un gestionnaire de bibliographie avec la liste des références dans les annexes
- une base de données qui gère les images, et un simple @image1 qui affiche l'image et sa légende, avec une liste des images automatiques dans les annexes
- notes de bas de page avec [[]] et une numérotation automatique
- des paramètres de projet avec la typo, les marges, les en-têtes et pieds de page
- quelque chose à faire avec R et python ?
