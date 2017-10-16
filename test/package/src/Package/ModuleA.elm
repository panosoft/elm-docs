module Package.ModuleA exposing (..)

{-| Module comments.

  - [Types](#types)
  - [Api](#api)


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
