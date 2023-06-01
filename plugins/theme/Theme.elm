module Theme exposing (..)

{-| First, a basic language for our design system
-}

import Elm
import Gen.CodeGen.Generate as Generate
import Json.Decode
import Parser exposing ((|.), (|=))


type Name
    = Name String


nameToString : Name -> String
nameToString (Name str) =
    str


decode : Json.Decode.Decoder Theme
decode =
    Json.Decode.map5 Theme
        (Json.Decode.field "backgrounds"
            (Json.Decode.succeed [])
        )
        (Json.Decode.field "spacing"
            (decodeNamed Json.Decode.int)
        )
        (Json.Decode.field "typography"
            (decodeNamed decodeTypeface)
        )
        (Json.Decode.field "borders"
            (decodeNamed decodeBorderVariant)
        )
        (Json.Decode.field "shadows"
            (Json.Decode.succeed [])
        )


type alias Named thing =
    { name : Name
    , item : thing
    }


type Color
    = Color Int Int Int


decodeColor : Json.Decode.Decoder Color
decodeColor =
    Json.Decode.string
        |> Json.Decode.andThen
            (\string ->
                case Parser.run parseColor string of
                    Ok color ->
                        Json.Decode.succeed color

                    Err err ->
                        let
                            _ =
                                Debug.log "ERR" err
                        in
                        Json.Decode.fail ("I 1don't recognize this color: " ++ string)
            )


decodeNamed : Json.Decode.Decoder a -> Json.Decode.Decoder (List (Named a))
decodeNamed inner =
    Json.Decode.keyValuePairs inner
        |> Json.Decode.map
            (List.map
                (\( key, value ) ->
                    { name = Name key
                    , item = value
                    }
                )
            )


type alias Theme =
    { backgrounds : List (Named Color)
    , spacing : List (Named Int)
    , typography : List (Named Typeface)
    , borders : List (Named BorderVariant)
    , shadows : List (Named Shadow)
    }


type alias Typeface =
    { face : String
    , fallback : List String
    , weight : Int
    , size : Int
    , lineSpacing : Int
    , colors : Palette Color
    }


decodeTypeface : Json.Decode.Decoder Typeface
decodeTypeface =
    Json.Decode.map6 Typeface
        (Json.Decode.field "face" Json.Decode.string)
        (Json.Decode.field "fallback" (Json.Decode.list Json.Decode.string))
        (Json.Decode.maybe (Json.Decode.field "weight" Json.Decode.int)
            |> Json.Decode.map (Maybe.withDefault 400)
        )
        (Json.Decode.field "size" Json.Decode.int)
        (Json.Decode.maybe (Json.Decode.field "lineSpacing" Json.Decode.int)
            |> Json.Decode.map (Maybe.withDefault 1)
        )
        (Json.Decode.field "color"
            (decodePalette decodeColor)
        )


decodePalette : Json.Decode.Decoder thing -> Json.Decode.Decoder (Palette thing)
decodePalette decodeThing =
    Json.Decode.oneOf
        [ Json.Decode.map Single decodeThing
        , Json.Decode.map Palette (decodeNamed decodeThing)
        ]


type Palette thing
    = Single thing
    | Palette (List (Named thing))


type alias BorderVariant =
    { rounded : Int
    , color : Color
    , width : Int
    }


decodeBorderVariant : Json.Decode.Decoder BorderVariant
decodeBorderVariant =
    Json.Decode.map3 BorderVariant
        (Json.Decode.maybe (Json.Decode.field "rounded" Json.Decode.int)
            |> Json.Decode.map (Maybe.withDefault 0)
        )
        (Json.Decode.field "color" decodeColor)
        (Json.Decode.maybe (Json.Decode.field "width" Json.Decode.int)
            |> Json.Decode.map (Maybe.withDefault 1)
        )


parseColor : Parser.Parser Color
parseColor =
    Parser.oneOf
        [ parseRgb
        , parseHex
        ]


parseRgb : Parser.Parser Color
parseRgb =
    Parser.succeed Color
        |. Parser.symbol "rgb("
        |. Parser.spaces
        |= Parser.int
        |. Parser.spaces
        |. Parser.symbol ","
        |. Parser.spaces
        |= Parser.int
        |. Parser.spaces
        |. Parser.symbol ","
        |. Parser.spaces
        |= Parser.int
        |. Parser.spaces
        |. Parser.symbol ")"


parseHex : Parser.Parser Color
parseHex =
    Parser.succeed Color
        |. Parser.symbol "#"
        |= parseHex16
        |= parseHex16
        |= parseHex16


parseHex16 : Parser.Parser Int
parseHex16 =
    Parser.succeed
        (\one two ->
            (one * 16) + two
        )
        |= hex8
        |= hex8


hex8 : Parser.Parser Int
hex8 =
    Parser.oneOf
        [ Parser.succeed 0
            |. Parser.symbol "0"
        , Parser.succeed 1
            |. Parser.symbol "1"
        , Parser.succeed 2
            |. Parser.symbol "2"
        , Parser.succeed 3
            |. Parser.symbol "3"
        , Parser.succeed 4
            |. Parser.symbol "4"
        , Parser.succeed 5
            |. Parser.symbol "5"
        , Parser.succeed 6
            |. Parser.symbol "6"
        , Parser.succeed 7
            |. Parser.symbol "7"
        , Parser.succeed 8
            |. Parser.symbol "8"
        , Parser.succeed 9
            |. Parser.symbol "9"
        , Parser.succeed 10
            |. Parser.oneOf
                [ Parser.symbol "a"
                , Parser.symbol "A"
                ]
        , Parser.succeed 11
            |. Parser.oneOf
                [ Parser.symbol "b"
                , Parser.symbol "B"
                ]
        , Parser.succeed 12
            |. Parser.oneOf
                [ Parser.symbol "c"
                , Parser.symbol "C"
                ]
        , Parser.succeed 13
            |. Parser.oneOf
                [ Parser.symbol "d"
                , Parser.symbol "D"
                ]
        , Parser.succeed 14
            |. Parser.oneOf
                [ Parser.symbol "e"
                , Parser.symbol "E"
                ]
        , Parser.succeed 15
            |. Parser.oneOf
                [ Parser.symbol "f"
                , Parser.symbol "F"
                ]
        ]


type alias Shadows =
    { shadows : List (Named Shadow)
    }


type alias Shadow =
    { x : Int
    , y : Int
    , color : Color
    , opacity : Int
    }



{- Helpers -}


tshirtSizesInt : Int -> List Int -> List (Named Int)
tshirtSizesInt middle vals =
    tshirtSizes
        { sort = List.sort
        , middle = middle
        , overrideName =
            \i ->
                case i of
                    0 ->
                        Just (Name "zero")

                    _ ->
                        Nothing
        }
        vals


tshirtSizes :
    { middle : value
    , sort : List value -> List value
    , overrideName : value -> Maybe Name
    }
    -> List value
    -> List (Named value)
tshirtSizes opts values =
    let
        sorted =
            (opts.middle :: values)
                |> opts.sort

        middleIndex =
            List.foldl
                (\item (( index, maybeMiddleIndex ) as gathered) ->
                    case maybeMiddleIndex of
                        Nothing ->
                            if item == opts.middle then
                                ( index, Just index )

                            else
                                ( index + 1, maybeMiddleIndex )

                        Just _ ->
                            gathered
                )
                ( 0, Nothing )
                sorted
                |> Tuple.second
                |> Maybe.withDefault 0
    in
    List.indexedMap (tagTShirtSizes opts.overrideName middleIndex) values


tagTShirtSizes :
    (item -> Maybe Name)
    -> Int
    -> Int
    -> item
    ->
        { item : item
        , name : Name
        }
tagTShirtSizes overrideName middleIndex index item =
    { name =
        case overrideName item of
            Just name ->
                name

            Nothing ->
                Name <|
                    if index == middleIndex then
                        "md"

                    else if index > middleIndex then
                        let
                            xCount =
                                abs (index - (middleIndex + 1))
                        in
                        case xCount of
                            0 ->
                                "lg"

                            1 ->
                                "xl"

                            _ ->
                                "xl" ++ String.fromInt xCount

                    else
                        -- is below
                        let
                            xCount =
                                abs (index - (middleIndex - 1))
                        in
                        case xCount of
                            0 ->
                                "sm"

                            1 ->
                                "xs"

                            _ ->
                                "xs" ++ String.fromInt xCount
    , item = item
    }



{- Generate an example view -}
-- viewHeader : String -> Theme -> Ui.Element msg
-- viewHeader name theme =
--     Debug.todo ""
-- viewCard : Theme -> Ui.Element msg
-- viewCard =
--     Debug.todo ""