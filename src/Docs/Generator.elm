module Docs.Generator
    exposing
        ( Module
        , Alias
        , Union
        , Value
        , Case
        , moduleDecoder
        , generate
        )

{-| Render code documentation in Markdown.

@docs Module, Alias, Union, Value, Case, moduleDecoder, generate

-}

import Dict exposing (Dict)
import Json.Decode as Decode
import Json.Decode.Extra as Decode
import List.Extra as List
import Maybe.Extra as Maybe
import StringUtils exposing (..)
import Node.Encoding as Encoding
import Node.Error as Error
import Node.FileSystem as FileSystem
import Node.Path as NodePath
import Regex
import Result.Extra as Result
import Task exposing (Task)
import Utils.Ops exposing (..)
import Utils.Regex exposing (..)
import Utils.Match exposing (..)
import Utils.Dict exposing (..)
import Docs.SignatureExtractor exposing (..)


bold : String -> String
bold s =
    "**"
        ++ (s
                |> replaceAll "\\*" "\\*"
           )
        ++ "**"


definitionHeader : String -> String
definitionHeader s =
    "### " ++ s ++ "\n"


elmCode : String -> String
elmCode s =
    ("```elm\n" ++ s ++ "\n```")
        |> removeRedundantTypes


operatorize : String -> String
operatorize name =
    Regex.contains (Regex.regex "[a-z_A-Z]") name
        ? ( name, "(" ++ name ++ ")" )


{-| removeRedundantTypes like `Maybe.Maybe` and `Result.Result`, and just make them `Maybe` and `Result`
-}
removeRedundantTypes : String -> String
removeRedundantTypes code =
    code
        |> Regex.replace (Regex.All)
            (Regex.regex "(\\b\\w+\\b)\\.(\\b\\w+\\b)")
            (\match ->
                match
                    |> getSubmatches2
                    |> (\( w1, w2 ) -> (w1 == w2) ? ( w1, w1 ++ "." ++ w2 ))
            )


{-| Render code documentation files in Markdown.

    sourceDirectory : String
    sourceDirectory =
        "."

    destinationDirectory : String
    destinationDirectory =
        "elm-docs"

    generate "/" sourceDirectory destinationDirectory

-}
generate : String -> String -> String -> Task String ()
generate pathSep source destination =
    getSourceCodeFilenames (NodePath.dirname source)
        |> Task.andThen
            (\sourcePaths ->
                (FileSystem.readFileAsString source Encoding.Utf8 |> Task.mapError Error.message)
                    |> Task.andThen
                        (\content ->
                            Decode.decodeString (Decode.list moduleDecoder) content
                                -- |> Result.map (List.map moduleToMarkdown)
                                |> Result.map
                                    (\modules ->
                                        modules
                                            |> List.map
                                                (\module_ ->
                                                    getModuleSignatures sourcePaths module_.name
                                                        |> Task.andThen
                                                            (\moduleSignatures ->
                                                                moduleToMarkdown moduleSignatures module_
                                                                    |> Task.succeed
                                                            )
                                                )
                                    )
                                |> Result.unpack Task.fail Task.sequence
                        )
                    |> Task.andThen
                        (\files ->
                            files
                                |> List.map
                                    (\file ->
                                        FileSystem.writeFileFromString
                                            (destination ++ pathSep ++ (Tuple.first file) ++ ".md")
                                            FileSystem.defaultMode
                                            FileSystem.defaultEncoding
                                            (Tuple.second file)
                                            |> Task.mapError (\_ -> "File write error")
                                    )
                                |> Task.sequence
                        )
                    |> Task.andThen (\_ -> Task.succeed ())
            )



-- Module -> Markdown String
-- name becomes `# name`
-- comment needs each @docs line replaced


moduleToMarkdown : Dict ModuleName (Dict Name Signature) -> Module -> ( String, String )
moduleToMarkdown signatures module_ =
    ( module_.name
    , ("# " ++ module_.name ++ "\n\n")
        ++ (processComments (Dict.get module_.name signatures ?= Dict.empty) module_)
        ++ "\n\n"
    )


type alias LinkDict =
    Dict String ( String, Int )


makeUnique : LinkDict -> Int -> String -> String
makeUnique dict index name =
    (name ++ "-" +++ index)
        |> (\newName ->
                (newName
                    |> flip Dict.get dict
                )
                    |?-> ( newName, \_ -> makeUnique dict (index + 1) name )
           )


{-| Follow link name logic described here: <https://gist.github.com/asabaylus/3071099>
-}
makeLinkName : LinkDict -> String -> String
makeLinkName dict name =
    name
        |> String.toLower
        |> replaceAll "[^a-zA-Z0-9- ]" ""
        |> (\linkName ->
                (linkName
                    |> flip Dict.get dict
                )
                    |?-> ( linkName, \_ -> makeUnique dict 1 linkName )
           )


makeLink : ( String, String ) -> String
makeLink ( link, name ) =
    "- [" ++ name ++ "]" ++ "(#" ++ link ++ ")"


makeTableOfContents : LinkDict -> Int -> List String -> String
makeTableOfContents dict index names =
    (dict
        |> Dict.filter (\_ ( _, index2 ) -> index2 == index)
        |> Dict.map (\key ( name, _ ) -> name)
        |> swap
    )
        |??->
            ( \_ -> Debug.crash "BUG: non-unique name"
            , \dict ->
                names
                    |> List.filterMap (\name -> Dict.get name dict |?-> ( Nothing, \link -> Just ( link, name ) ))
                    |> List.map makeLink
                    |> String.join "\n"
                    |> flip (++) "\n\n"
            )


docsRegex : Regex.Regex
docsRegex =
    Regex.regex "\\@docs (.*)?,?"


processComments : Dict Name Signature -> Module -> String
processComments signatures { comment, aliases, unions, values } =
    comment
        |> String.trim
        |> Regex.find Regex.All docsRegex
        |> List.foldl
            (\match dict ->
                (match
                    |> extract1
                )
                    |?!->
                        ( \_ -> Debug.crash "BUG: bad regex"
                        , flip (|?->)
                            ( dict
                            , \matchStr ->
                                matchStr
                                    |> Regex.replace Regex.All (Regex.regex "\\@docs\\s*") (always "")
                                    |> Regex.split Regex.All (Regex.regex "\\s*,\\s*")
                                    |> List.unique
                                    |> List.foldl (\name dict -> Dict.insert (makeLinkName dict name) ( name, match.index ) dict) dict
                            )
                        )
            )
            Dict.empty
        |> (\pageDict ->
                (Regex.replace Regex.All docsRegex)
                    (\match ->
                        match.match
                            |> Regex.replace Regex.All (Regex.regex "\\@docs\\s*") (always "")
                            |> Regex.split Regex.All (Regex.regex "\\s*,\\s*")
                            |> List.unique
                            |> (\names ->
                                    names
                                        |> makeTableOfContents pageDict match.index
                                        |> (\tableOfContents ->
                                                -- take each name
                                                -- find which type name is
                                                tableOfContents
                                                    ++ (List.map
                                                            (\name ->
                                                                name
                                                                    |> replaceFirst "^\\(" ""
                                                                    |> replaceFirst "\\)$" ""
                                                                    |> (\name ->
                                                                            Maybe.values
                                                                                [ List.find (.name >> (==) name) aliases |> Maybe.map (aliasToMarkdown signatures)
                                                                                , List.find (.name >> (==) name) unions |> Maybe.map (unionToMarkdown signatures)
                                                                                , List.find (.name >> (==) name) values |> Maybe.map (valueToMarkdown signatures)
                                                                                ]
                                                                                |> List.head
                                                                                |> Maybe.withDefault (name ++ " : Not Found!!!")
                                                                       )
                                                            )
                                                            names
                                                            |> String.join "\n\n---\n\n"
                                                       )
                                           )
                               )
                    )
                    (String.trim comment)
           )



-- ALIAS


{-| Exposed type aliases
-}
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


{-| Case of a union type
-}
type alias Case =
    ( String, List String )


caseDecoder : Decode.Decoder Case
caseDecoder =
    Decode.map2 (\name args -> ( name, args ))
        (Decode.index 0 Decode.string)
        (Decode.index 1 <| Decode.list Decode.string)


{-| Exposed union types
-}
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
        |> Decode.andMap (Decode.field "comment" Decode.string |> Decode.andThen (Decode.succeed << fixCodeBlocks))
        |> Decode.andMap (Decode.field "args" <| Decode.list Decode.string)
        |> Decode.andMap (Decode.field "cases" <| Decode.list caseDecoder)


caseToMarkdown : Case -> String
caseToMarkdown tag =
    (Tuple.first tag) ++ " " ++ (String.join " " <| Tuple.second tag)


unionSignature : Dict Name Signature -> Union -> String
unionSignature signatures union =
    (("type " ++ union.name)
        |> (definitionHeader << bold)
    )
        ++ (("type " ++ union.name ++ " " ++ (String.join " " union.args) ++ newLine)
                ++ Dict.get union.name signatures
                ?= (tab
                        ++ "= "
                        ++ (List.map caseToMarkdown union.tags
                                |> String.join (newLine ++ tab ++ "| ")
                           )
                   )
                |> elmCode
           )


unionToMarkdown : Dict Name Signature -> Union -> String
unionToMarkdown signatures union =
    unionSignature signatures union
        ++ "\n\n"
        ++ (String.trim union.comment)



-- VALUE


{-| Exposed values
-}
type alias Value =
    { name : String
    , comment : String
    , type_ : String
    }


valueDecoder : Decode.Decoder Value
valueDecoder =
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


{-| Module doc info
-}
type alias Module =
    { name : String
    , comment : String
    , aliases : List Alias
    , unions : List Union
    , values : List Value
    }


{-| Decoder for a single module

Use with Json.Decode.list since Elm's output for documentation JSON is a list of Modules.

-}
moduleDecoder : Decode.Decoder Module
moduleDecoder =
    Decode.succeed Module
        |> Decode.andMap (Decode.field "name" Decode.string)
        |> Decode.andMap (Decode.field "comment" Decode.string |> Decode.andThen (Decode.succeed << fixCodeBlocks))
        |> Decode.andMap (Decode.field "aliases" <| Decode.list aliasDecoder)
        |> Decode.andMap (Decode.field "types" <| Decode.list unionDecoder)
        |> Decode.andMap (Decode.field "values" <| Decode.list valueDecoder)


{-| Fix code blocks
elm-format removes ```elm blocks for syntax coloring so we want to put that back
-}
type alias EditCodeBlockState =
    { inBlock : Bool
    , comment : List String
    , trailingBlankLineCount : Int
    }


fixCodeBlocks : String -> String
fixCodeBlocks comment =
    ( String.length >> (==) 0
    , String.startsWith "    "
    , (==) "†"
    , \state -> { state | comment = List.append (List.repeat state.trailingBlankLineCount "") state.comment, trailingBlankLineCount = 0 }
    , \state -> { state | inBlock = False, comment = "```\n" :: state.comment }
    , String.dropLeft 4
    )
        |> (\( isBlank, isCode, isEnd, addTrailing, endBlock, unindent ) ->
                comment
                    |> String.split "\n"
                    |> flip List.append [ "†" ]
                    |> List.foldl
                        (\line state ->
                            isEnd line
                                ? ( state.inBlock
                                        ? ( state |> endBlock |> addTrailing
                                          , state
                                          )
                                  , state.inBlock
                                        ? ( isBlank line
                                                ? ( { state | trailingBlankLineCount = state.trailingBlankLineCount + 1 }
                                                  , isCode line
                                                        ? ( state |> addTrailing |> \state -> { state | comment = unindent line :: state.comment }
                                                          , state |> addTrailing |> endBlock |> \state -> { state | comment = line :: state.comment }
                                                          )
                                                  )
                                          , isCode line
                                                ? ( { state | inBlock = True, comment = ("```elm\n" ++ unindent line) :: state.comment, trailingBlankLineCount = 0 }
                                                  , { state | comment = line :: state.comment }
                                                  )
                                          )
                                  )
                        )
                        (EditCodeBlockState False [] 0)
                    |> .comment
                    |> List.reverse
                    |> String.join "\n"
           )



-- UTILS


newLine : String
newLine =
    "  \n"


space : Int -> String
space number =
    List.repeat number " "
        |> String.join ""


tab : String
tab =
    space 4
