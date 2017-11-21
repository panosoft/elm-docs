module Docs.SignatureExtractor
    exposing
        ( Path
        , Name
        , Signature
        , ModuleName
        , getSourceCodeFilenames
        , getModuleSignatures
        )

import Dict exposing (Dict)
import Task exposing (Task)
import Regex exposing (..)
import Json.Decode as JD exposing (field)
import StringUtils exposing (..)
import Node.Encoding as Encoding
import Node.Error as Error
import Node.Path as NodePath
import Node.FileSystem as FileSystem
import Utils.Ops exposing (..)
import Utils.Json exposing (..)
import Utils.Regex exposing (..)
import Utils.Match exposing (..)


type alias Path =
    String


type alias Name =
    String


type alias Signature =
    String


type alias ModuleName =
    String


type alias SourceInfo =
    { directories : List Path
    , moduleNames : List ModuleName
    }


sourceInfoDecoder : JD.Decoder SourceInfo
sourceInfoDecoder =
    JD.succeed SourceInfo
        <|| (field "source-directories" <| JD.list JD.string)
        <|| (field "exposed-modules" <| JD.list JD.string)


getMatchingBracketsInternal : List String -> Int -> String -> String
getMatchingBracketsInternal chars count str =
    case chars of
        c :: cs ->
            case c of
                "{" ->
                    getMatchingBracketsInternal cs (count + 1) (str ++ c)

                "}" ->
                    (count - 1 == 0)
                        ? ( str ++ c
                          , getMatchingBracketsInternal cs (count - 1) (str ++ c)
                          )

                c ->
                    getMatchingBracketsInternal cs count (str ++ c)

        [] ->
            str


getMatchingBrackets : String -> String
getMatchingBrackets s =
    getMatchingBracketsInternal (String.split "" s) 0 ""


getSignatures : Path -> Task String (Dict Name Signature)
getSignatures path =
    (FileSystem.readFileAsString path Encoding.Utf8 |> Task.mapError Error.message)
        |> Task.andThen
            (\code ->
                code
                    |> replaceAll "\\n" "†"
                    |> replaceAll "//.+?†" ""
                    |> replaceAll "{-.+?-}" ""
                    |> (\code ->
                            -- values
                            code
                                |> find All (regex "†([a-z][_A-Za-z0-9]*)\\s?:")
                                |> List.map getSubmatches1
                                |> (\valueNames ->
                                        valueNames
                                            |> List.map
                                                (\valueName ->
                                                    ( valueName
                                                    , (code
                                                        |> find (AtMost 1) (regex <| valueName ++ "\\s?:\\s?(.+?)" ++ valueName)
                                                        |> List.head
                                                      )
                                                        |?-> ( Nothing, getSubmatches1 >> Just )
                                                    )
                                                )
                                            |> List.filter (\( _, maybe ) -> maybe /= Nothing)
                                            |> List.map (\( valueName, maybe ) -> ( valueName, replaceAll "†" "\n" (maybe ?= "should never happen") ))
                                            |> Dict.fromList
                                   )
                                -- aliases
                                |> Dict.union
                                    (code
                                        |> find All (regex "†type\\s+alias\\s+([A-Z][_A-Za-z0-9]*)\\s.+?=(.+?\\{.+?)(?:[=$]|(?=†\\s*type\\s+alias\\s+[A-Z]))")
                                        |> List.map getSubmatches2
                                        |> List.map
                                            (\( alias_, codeSnippet ) ->
                                                codeSnippet
                                                    |> getMatchingBrackets
                                                    |> replaceAll "†" "\n"
                                                    |> (,) alias_
                                            )
                                        |> Dict.fromList
                                    )
                                -- unions
                                |> Dict.union
                                    (code
                                        |> find All (regex "†type\\s([A-Z][_A-Za-z0-9]*)\\s.+?(\\s*=.+?)(?:$|(?=†\\s*[a-z][_A-Za-z0-9]*\\s*=)|(?=†\\s*type\\s+(?:alias\\s+)?[A-Z]))")
                                        |> List.map getSubmatches2
                                        |> List.map
                                            (\( union, codeSnippet ) ->
                                                codeSnippet
                                                    |> replaceFirst "†\\s*[a-z][_A-Za-z0-9]*\\s*:.+?†\\s*[a-z][_A-Za-z0-9]*\\s*=" ""
                                                    |> replaceFirst "†+[^†]+$" "†"
                                                    |> replaceAll "†" "\n"
                                                    |> (,) union
                                            )
                                        |> Dict.fromList
                                    )
                                |> Task.succeed
                       )
            )



-- API


getSourceCodeFilenames : Path -> Task String (Dict ModuleName Path)
getSourceCodeFilenames path =
    (FileSystem.readFileAsString (NodePath.join [ path, "elm-package.json" ]) Encoding.Utf8 |> Task.mapError Error.message)
        |> Task.andThen
            (\json ->
                JD.decodeString sourceInfoDecoder json
                    |??->
                        ( Task.fail
                        , \sourceInfo ->
                            sourceInfo.directories
                                |> List.map
                                    (\directory ->
                                        sourceInfo.moduleNames
                                            |> List.map
                                                (\moduleName ->
                                                    moduleName
                                                        |> replaceAll "\\." NodePath.separator
                                                        |> flip (++) ".elm"
                                                        |> flip (::) [ directory, path ]
                                                        |> List.reverse
                                                        |> NodePath.join
                                                        |> (\path ->
                                                                path
                                                                    |> FileSystem.exists
                                                                    |> Task.mapError (\error -> "Unable to check existence of" +-+ path +-+ "Error:" +-+ Error.message error)
                                                                    |> Task.andThen (\exists -> exists ? ( Just ( moduleName, path ), Nothing ) |> Task.succeed)
                                                           )
                                                )
                                    )
                                |> List.concat
                                |> Task.sequence
                                |> Task.andThen (List.filterMap identity >> Dict.fromList >> Task.succeed)
                        )
            )


getModuleSignatures : Dict ModuleName Path -> ModuleName -> Task String (Dict ModuleName (Dict Name Signature))
getModuleSignatures modulePaths moduleName =
    (Dict.get moduleName modulePaths |?-> ( Task.succeed Dict.empty, getSignatures ))
        |> Task.andThen
            (\signatures ->
                Dict.insert moduleName signatures Dict.empty
                    |> Task.succeed
            )
