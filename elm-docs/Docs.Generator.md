# Docs.Generator

Render code documentation in Markdown.

- [generate](#generate)

### **generate**
```elm
generate : String -> String -> String -> Task String ()
```

Render code documentation files in Markdown.

```elm
sourceDirectory : String
sourceDirectory =
    "."

destinationDirectory : String
destinationDirectory =
    "elm-docs"

generate "/" sourceDirectory destinationDirectory
```

