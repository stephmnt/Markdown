# Cheatsheet Markdown

Basée sur la syntaxe Markdown originale de Daring Fireball.

---

## 1. Paragraphes

Un paragraphe est une ou plusieurs lignes de texte séparées par une ligne vide.

```markdown
Ceci est un paragraphe.

Ceci est un autre paragraphe.
```

Pour forcer un saut de ligne, terminer la ligne par deux espaces ou plus.

```markdown
Première ligne.  
Deuxième ligne.
```

---

## 2. Titres

### Style ATX

```markdown
# Titre niveau 1
## Titre niveau 2
### Titre niveau 3
#### Titre niveau 4
##### Titre niveau 5
###### Titre niveau 6
```

Les titres peuvent être “fermés” avec des `#`, uniquement pour l’esthétique.

```markdown
# Titre niveau 1 #
## Titre niveau 2 ##
```

### Style Setext

```markdown
Titre niveau 1
==============

Titre niveau 2
--------------
```

---

## 3. Emphase

```markdown
*italique*
_italique_

**gras**
__gras__
```

Résultat :

*italique*  
_italique_  

**gras**  
__gras__

Pour afficher un astérisque ou underscore littéral :

```markdown
\*pas en italique\*
\_pas en italique\_
```

---

## 4. Citations

```markdown
> Ceci est une citation.
> Elle peut tenir sur plusieurs lignes.
```

Citation avec plusieurs paragraphes :

```markdown
> Premier paragraphe.
>
> Deuxième paragraphe.
```

Citation imbriquée :

```markdown
> Citation niveau 1
>
> > Citation niveau 2
>
> Retour au niveau 1
```

Une citation peut contenir d’autres éléments Markdown :

```markdown
> ## Titre dans une citation
>
> - Élément de liste
> - Autre élément
>
>     Bloc de code dans une citation
```

---

## 5. Listes

### Liste non ordonnée

Les trois syntaxes suivantes sont équivalentes :

```markdown
* Rouge
* Vert
* Bleu
```

```markdown
+ Rouge
+ Vert
+ Bleu
```

```markdown
- Rouge
- Vert
- Bleu
```

### Liste ordonnée

```markdown
1. Premier élément
2. Deuxième élément
3. Troisième élément
```

Les nombres exacts n’affectent pas forcément le rendu HTML :

```markdown
1. Premier élément
1. Deuxième élément
1. Troisième élément
```

### Liste avec plusieurs paragraphes

```markdown
1. Premier élément avec un paragraphe.

    Deuxième paragraphe du même élément.

2. Deuxième élément.
```

### Citation dans une liste

```markdown
- Élément avec une citation :

    > Ceci est une citation
    > dans un élément de liste.
```

### Bloc de code dans une liste

```markdown
- Élément avec du code :

        code ici
```

### Éviter une liste ordonnée accidentelle

```markdown
1986\. Quelle belle saison.
```

---

## 6. Blocs de code

Un bloc de code se crée avec une indentation de 4 espaces ou 1 tabulation.

```markdown
Voici un paragraphe normal :

    Ceci est un bloc de code.
    Les caractères <, > et & y sont échappés automatiquement.
```

Markdown n’interprète pas la syntaxe Markdown à l’intérieur d’un bloc de code.

---

## 7. Code inline

```markdown
Utilisez la fonction `printf()`.
```

Résultat :

Utilisez la fonction `printf()`.

Pour inclure un backtick dans du code inline, utiliser plusieurs backticks :

```markdown
``Il y a un ` backtick ici.``
```

---

## 8. Lignes horizontales

Trois caractères ou plus sur une ligne seule :

```markdown
***
```

```markdown
* * *
```

```markdown
---
```

```markdown
- - -
```

```markdown
___
```

---

## 9. Liens

### Lien inline

```markdown
Ceci est [un lien](https://example.com/).
```

Avec un titre optionnel :

```markdown
Ceci est [un lien](https://example.com/ "Titre optionnel").
```

Lien relatif :

```markdown
Voir la page [À propos](/about/).
```

---

## 10. Liens par référence

```markdown
Ceci est [un lien][id].

[id]: https://example.com/ "Titre optionnel"
```

La définition peut être placée ailleurs dans le document.

Autres formes valides :

```markdown
[id]: https://example.com/ 'Titre optionnel'
[id]: https://example.com/ (Titre optionnel)
[id]: <https://example.com/> "Titre optionnel"
```

Définition sur deux lignes :

```markdown
[id]: https://example.com/chemin/tres/long
    "Titre optionnel"
```

### Référence implicite

```markdown
Visitez [Daring Fireball][].

[Daring Fireball]: https://daringfireball.net/
```

---

## 11. Images

### Image inline

```markdown
![Texte alternatif](/chemin/image.jpg)
```

Avec un titre optionnel :

```markdown
![Texte alternatif](/chemin/image.jpg "Titre optionnel")
```

### Image par référence

```markdown
![Texte alternatif][image-id]

[image-id]: /chemin/image.jpg "Titre optionnel"
```

Markdown original ne prévoit pas de syntaxe pour définir la taille d’une image. Utiliser HTML si nécessaire :

```html
<img src="/chemin/image.jpg" alt="Texte alternatif" width="300">
```

---

## 12. Liens automatiques

Pour transformer directement une URL ou une adresse email en lien :

```markdown
<https://example.com/>
```

```markdown
<adresse@example.com>
```

---

## 13. HTML inline

Markdown permet d’utiliser directement du HTML.

```markdown
Ceci est un paragraphe avec <span>du HTML inline</span>.
```

Les éléments HTML de bloc doivent être séparés du texte par des lignes vides :

```markdown
Ceci est un paragraphe.

<table>
    <tr>
        <td>Contenu</td>
    </tr>
</table>

Ceci est un autre paragraphe.
```

Attention : la syntaxe Markdown n’est pas traitée à l’intérieur des blocs HTML.

---

## 14. Échappement automatique

Markdown échappe automatiquement certains caractères spéciaux HTML comme `<` et `&` lorsqu’ils ne font pas partie d’un élément HTML ou d’une entité.

```markdown
4 < 5
AT&T
```

Dans les blocs de code et le code inline, les caractères comme `<`, `>` et `&` sont aussi échappés automatiquement.

---

## 15. Échapper les caractères Markdown

Utiliser `\` devant un caractère spécial Markdown.

```markdown
\*astérisques littéraux\*
\# pas un titre
\[pas un lien\]
```

Caractères échappables :

```markdown
\   backslash
`   backtick
*   astérisque
_   underscore
{}  accolades
[]  crochets
()  parenthèses
#   dièse
+   plus
-   tiret
.   point
!   point d’exclamation
```

---

## 16. Indice

```markdown
H~2~O
```

Résultat possible :

H~2~O

Alternative avec HTML :

```markdown
H<sub>2</sub>O
```

Résultat :

H<sub>2</sub>O

---

## 17. Exposant

```markdown
X^2^
```

Résultat possible :

X^2^

Alternative avec HTML :

```markdown
X<sup>2</sup>
```

Résultat :

X<sup>2</sup>

---

## 18. Résumé rapide

| Élément | Syntaxe |
|---|---|
| Titre H1 | `# Titre` |
| Titre H2 | `## Titre` |
| Italique | `*texte*` ou `_texte_` |
| Gras | `**texte**` ou `__texte__` |
| Citation | `> texte` |
| Liste non ordonnée | `- item` |
| Liste ordonnée | `1. item` |
| Code inline | `` `code` `` |
| Bloc de code | indentation de 4 espaces ou \`\`\` |
| Lien | `[texte](url)` |
| Lien avec titre | `[texte](url "titre")` |
| Image | `![alt](url)` |
| Ligne horizontale | `---`, `***`, `___` |
| Lien automatique | `<https://example.com/>` |
| Échappement | `\*texte\*` |
| Indice / Subscript | `H~2~O` ou `H<sub>2</sub>O` |
| Exposant / Superscript | `X^2^` ou `X<sup>2</sup>` |
