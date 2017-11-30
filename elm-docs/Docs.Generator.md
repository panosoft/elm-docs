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
    Decode.succeed Alias
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string |> Decode.andThen (Decode.succeed << fixCodeBlocks))
        |> Decode.andMap (Decode.field "args" <| Decode.list Decode.string)
        |> Decode.andMap (Decode.field "type" Decode.string)


aliasSignature : Dict Name Signature -> Alias -> String
aliasSignature signatures alias_ =
    (("type alias " ++ alias_.name)
        |> (definitionHeader << bold)
    )
        ++ (("type alias " ++ alias_.name ++ " " ++ (String.join " " alias_.args) ++ " =")
                ++ (Dict.get alias_.name signatures ?= (newLine ++ tab ++ alias_.type_))
                |> elmCode
           )


aliasToMarkdown : Dict Name Signature -> Alias -> String
aliasToMarkdown signatures alias_ =
    aliasSignature signatures alias_ ++ "\n\n" ++ (String.trim alias_.comment)



-- UNION



type alias Case =
    ( String, List String )


caseDecoder : Decode.Decoder Case
caseDecoder =
    Decode.map2 (\name args -> ( name, args ))
        (Decode.index 0 Decode.string)
        (Decode.index 1 <| Decode.list Decode.string)



type alias Union =
    { name : String
    , comment : String
    , args : List String
    , tags : List Case
    }
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
    Decode.succeed Value
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string |> Decode.andThen (Decode.succeed << fixCodeBlocks))
        |> Decode.andMap (Decode.field "type" Decode.string)


valueSignature : Dict Name Signature -> Value -> String
valueSignature signatures value =
    (operatorize value.name
        |> (definitionHeader << bold)
    )
        ++ ((operatorize value.name ++ " : " ++ (Dict.get value.name signatures ?= value.type_))
                |> elmCode
           )


valueToMarkdown : Dict Name Signature -> Value -> String
valueToMarkdown signatures value =
    valueSignature signatures value
        ++ "\n\n"
        ++ (String.trim value.comment)



type alias Module =
    { name : String
    , comment : String
    , aliases : List Alias
    , unions : List Union
    , values : List Value
    }
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
moduleDecoder : Decode.Decoder Module

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

