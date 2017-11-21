module Main exposing (..)

import Task exposing (Task)
import Docs.Generator as Docs


main : Program Never {} Msg
main =
    Platform.program
        { init = init
        , update = update
        , subscriptions = always Sub.none
        }


type Msg
    = Done (Result String ())


init : ( {}, Cmd Msg )
init =
    ({}
        ! [ Docs.generate "/" "./test/package/documentation.json" "./test/docs"
                |> Task.attempt Done
          ]
    )


update : Msg -> {} -> ( {}, Cmd Msg )
update msg _ =
    let
        m =
            Debug.log "Docs" msg
    in
        ( {}, Cmd.none )
