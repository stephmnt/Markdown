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

## Fichiers et rôles

### Application

- `Markdown/MarkdownApp.swift`
  Point d'entrée de l'application. Déclare `DocumentGroup`, injecte la vue d'édition et remplace les commandes de sauvegarde par les raccourcis voulus.

- `Markdown/ContentView.swift`
  Vue principale. Elle affiche uniquement un `TextEditor` lié à l'état courant du document.

- `Markdown/EditorState.swift`
  Contient `EditorState`, c'est-à-dire l'état d'édition en mémoire.

- `Markdown/MarkdownDocument.swift`
  Couche document/persistance. Lit le contenu d'un fichier texte ou Markdown et reconstruit l'état de l'éditeur. Écrit ensuite ce même état sur disque.

- `Markdown/DocumentCommands.swift`
  Redéfinit les commandes de sauvegarde pour garantir :
  `⌘S` = Enregistrer
  `⌘⇧S` = Enregistrer sous…
  `Duplicate` reste disponible séparément

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
  Cible de tests unitaires. Elle vérifie la création d'un document vide, la lecture UTF-8, l'écriture UTF-8 et le round-trip du contenu Markdown.

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
- l'intégration correcte avec les menus système
- une meilleure stabilité qu'une gestion manuelle de `NSSavePanel`

## Entitlements macOS

Comme l'application utilise le sandbox, l'accès utilisateur aux fichiers doit être configuré en lecture/écriture.

Point important :

- `User Selected File` doit être réglé sur `Read/Write`

Sinon, le panneau `Save` peut échouer à s'afficher.

## Lancer le projet

1. Ouvrir `Markdown.xcodeproj` dans Xcode.
2. Sélectionner le scheme `Markdown`.
3. Lancer l'application sur `My Mac`.

## Raccourcis

- `⌘S` : Enregistrer
- `⌘⇧S` : Enregistrer sous…

## Pistes d'amélioration

- ajouter une prévisualisation Markdown si l'application doit évoluer au-delà d'un éditeur texte minimal
