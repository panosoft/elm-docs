module Package.ModuleA exposing (..)

{-| Module comments.

  - [Types](#types)
      - [Api](#api)


# Types

@docs Record, Record2, Msg, Msg2


# Api

@docs value , function, value
@docs value , function, functionWithBigRecord

-}


{-| Record comments
-}
type alias Record a b =
    { field : a -> b, otherField : a -> b }


{-| Record2 comments
-}
type alias Record2 a b =
    { field : a -> b
    , record :
        { a : String
        , b : String
        }
    }


{-| Msg comments
-}
type Msg a b
    = Msg1 (a -> b)
    | Msg2 (a -> b)
    | Msg3


{-| Msg2 comments
-}
type Msg2 a b
    = Msg4 (a -> b)
    | Msg5 { a : Int, b : String }
    | Msg6


{-| value comments
-}
value : String
value =
    "string"


{-| function comments

    x : String
    x =
        "abc"

    y : String

```js
var x = 1;
```

    z : String
    z =
        "stuff"

-}
function : a -> (a -> b) -> b
function a map =
    map a


{-| function with big record
-}
functionWithBigRecord :
    a
    ->
        { x : String
        , y : Int
        , z : Int
        }
functionWithBigRecord _ =
    { x = "", y = 0, z = 0 }
