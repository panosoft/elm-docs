# Docs.Generator

Render code documentation in Markdown.

- [Module](#module)
- [Alias](#alias)
- [Union](#union)
- [Value](#value)
- [Case](#case)
- [moduleDecoder](#moduledecoder)
- [generate](#generate)

### **type alias Module**
```elm
type alias Module  =  
    { name : String , comment : String , aliases : List Docs.Generator.Alias , unions : List Docs.Generator.Union , values : List Docs.Generator.Value }
```

Module doc info

---

### **type alias Alias**
```elm
type alias Alias  =  
    { name : String , comment : String , args : List String , type_ : String }
```

Exposed type aliases

---

### **type alias Union**
```elm
type alias Union  =  
    { name : String , comment : String , args : List String , tags : List Docs.Generator.Case }
```

Exposed union types

---

### **type alias Value**
```elm
type alias Value  =  
    { name : String, comment : String, type_ : String }
```

Exposed values

---

### **type alias Case**
```elm
type alias Case  =  
    ( String, List String )
```

Case of a union type

---

### **moduleDecoder**
```elm
moduleDecoder : Json.Decode.Decoder Docs.Generator.Module
```

Decoder for a single module

Use with Json.Decode.list since Elm's output for documentation JSON is a list of Modules.

---

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

