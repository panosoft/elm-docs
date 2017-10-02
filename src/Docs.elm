module Docs
    exposing
        ( generate
        )

import Json.Decode as Decode
import Json.Decode.Extra as Decode
import List.Extra as List
import Maybe.Extra as Maybe
import Node.Encoding as Encoding
import Node.Error as Error
import Node.FileSystem as FileSystem
import Regex
import Result.Extra as Result
import Task exposing (Task)


generate : String -> String -> Task String ()
generate source destination =
    (FileSystem.readFileAsString source Encoding.Utf8 |> Task.mapError Error.message)
        |> Task.andThen
            (\content ->
                Decode.decodeString (Decode.list moduleDecoder) content
                    |> Result.map (List.map moduleToMarkdown)
                    |> Result.unpack Task.fail Task.succeed
            )
        |> Task.andThen
            (\files ->
                List.map
                    (\file ->
                        FileSystem.writeFileFromString
                            (destination ++ "/" ++ (Tuple.first file) ++ ".md")
                            FileSystem.defaultMode
                            FileSystem.defaultEncoding
                            (Tuple.second file)
                            |> Task.mapError (\_ -> "File write error")
                    )
                    files
                    |> Task.sequence
                    |> Task.andThen (\_ -> Task.succeed ())
            )



-- Module -> Markdown String
-- name becomes `# name`
-- comment needs each @docs line replaced


moduleToMarkdown : Module -> ( String, String )
moduleToMarkdown module_ =
    ( module_.name
    , ("# " ++ module_.name ++ "\n\n")
        ++ (processComments module_)
        ++ "\n\n"
    )


processComments : Module -> String
processComments { comment, aliases, unions, values } =
    let
        regex =
            Regex.regex "\\@docs (.*)?,?"
    in
        Regex.replace
            Regex.All
            regex
            (.match
                >> Regex.replace Regex.All (Regex.regex "\\@docs\\s*") (always "")
                >> Regex.split Regex.All (Regex.regex "\\s*,\\s*")
                >> (\names ->
                        -- take each name
                        -- find which type name is
                        List.map
                            (\name ->
                                Maybe.values
                                    [ List.find (.name >> (==) name) aliases |> Maybe.map aliasToMarkdown
                                    , List.find (.name >> (==) name) unions |> Maybe.map unionToMarkdown
                                    , List.find (.name >> (==) name) values |> Maybe.map valueToMarkdown
                                    ]
                                    |> List.head
                                    |> Maybe.withDefault (name ++ " : Not Found!!!")
                            )
                            names
                            |> String.join "\n\n---\n\n"
                   )
            )
            (String.trim comment)



-- ALIAS


type alias Alias =
    { name : String
    , comment : String
    , args : List String
    , type_ : String
    }


aliasDecoder : Decode.Decoder Alias
aliasDecoder =
    Decode.succeed Alias
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string)
        |> Decode.andMap (Decode.field "args" <| Decode.list Decode.string)
        |> Decode.andMap (Decode.field "type" Decode.string)


aliasSignature : Alias -> String
aliasSignature alias_ =
    ("**type alias " ++ alias_.name ++ " " ++ (String.join " " alias_.args) ++ " =" ++ newLine)
        ++ (tab ++ alias_.type_)
        ++ "**"


aliasToMarkdown : Alias -> String
aliasToMarkdown alias_ =
    aliasSignature alias_ ++ "\n\n" ++ (String.trim alias_.comment)



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


unionDecoder : Decode.Decoder Union
unionDecoder =
    Decode.succeed Union
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string)
        |> Decode.andMap (Decode.field "args" <| Decode.list Decode.string)
        |> Decode.andMap (Decode.field "cases" <| Decode.list caseDecoder)


caseToMarkdown : Case -> String
caseToMarkdown tag =
    (Tuple.first tag) ++ " " ++ (String.join " " <| Tuple.second tag)


unionSignature : Union -> String
unionSignature union =
    ("**type " ++ union.name ++ " " ++ (String.join " " union.args) ++ newLine)
        ++ tab
        ++ "= "
        ++ (List.map caseToMarkdown union.tags
                |> String.join (newLine ++ tab ++ "| ")
           )
        ++ "**"


unionToMarkdown : Union -> String
unionToMarkdown union =
    unionSignature union
        ++ "\n\n"
        ++ (String.trim union.comment)



-- VALUE


type alias Value =
    { name : String
    , comment : String
    , type_ : String
    }


valueDecoder : Decode.Decoder Value
valueDecoder =
    Decode.succeed Value
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string)
        |> Decode.andMap (Decode.field "type" Decode.string)


valueSignature : Value -> String
valueSignature value =
    ("**" ++ value.name ++ " : " ++ value.type_ ++ "**")


valueToMarkdown : Value -> String
valueToMarkdown value =
    valueSignature value
        ++ "\n\n"
        ++ (String.trim value.comment)


type alias Module =
    { name : String
    , comment : String
    , aliases : List Alias
    , unions : List Union
    , values : List Value
    }


moduleDecoder : Decode.Decoder Module
moduleDecoder =
    Decode.succeed Module
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string)
        |> Decode.andMap (Decode.field "aliases" <| Decode.list aliasDecoder)
        |> Decode.andMap (Decode.field "types" <| Decode.list unionDecoder)
        |> Decode.andMap (Decode.field "values" <| Decode.list valueDecoder)



-- UTILS


newLine : String
newLine =
    "  \n"


space : Int -> String
space number =
    List.repeat number "&nbsp;"
        |> String.join ""


tab : String
tab =
    space 4
