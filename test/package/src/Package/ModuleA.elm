module Package.ModuleA exposing (..)

{-| Module comments.


# Types

@docs Record, Msg


# Api

@docs value , function

-}


{-| Record comments
-}
type alias Record a b =
    { field : a -> b
    , otherField : a -> b
    }


{-| Msg comments
-}
type Msg a b
    = Msg1 (a -> b)
    | Msg2 (a -> b)


{-| value comments
-}
value : String
value =
    "string"


{-| function comments
-}
function : a -> (a -> b) -> b
function a map =
    map a
