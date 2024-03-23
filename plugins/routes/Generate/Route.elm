module Generate.Route exposing (generate)

import Elm
import Elm.Annotation as Type
import Elm.Case
import Elm.Case.Branch as Branch
import Elm.Let
import Elm.Op
import Gen.AppUrl
import Gen.Browser
import Gen.Browser.Navigation
import Gen.Dict
import Gen.Html
import Gen.Http
import Gen.Json.Encode
import Gen.List
import Gen.Markdown.Parser
import Gen.Markdown.Renderer
import Gen.Maybe
import Gen.Platform.Cmd
import Gen.Platform.Sub
import Gen.String
import Gen.Tuple
import Gen.Url
import Gen.Url.Parser
import Gen.Url.Parser.Query
import Json.Decode
import Options.Route
import Parser exposing ((|.), (|=))
import Path
import Set exposing (Set)


routeOrder : Options.Route.Page -> List ( Int, String )
routeOrder page =
    case page.url of
        Options.Route.UrlPattern { path } ->
            List.map
                (\piece ->
                    case piece of
                        Options.Route.Token token ->
                            ( 0, token )

                        Options.Route.Variable name ->
                            ( 1, name )
                )
                path


generate : List Options.Route.Page -> Elm.File
generate unsorted =
    let
        routes =
            List.sortBy routeOrder unsorted
    in
    Elm.fileWith [ "App", "Route" ]
        { docs =
            \groups ->
                groups
                    |> List.sortBy
                        (\doc ->
                            case doc.group of
                                Nothing ->
                                    0

                                Just "Route" ->
                                    1

                                Just "Params" ->
                                    2

                                Just "Encodings" ->
                                    3

                                _ ->
                                    4
                        )
                    |> List.map Elm.docs
        , aliases = []
        }
        (List.concat
            [ [ Elm.customType "Route"
                    (List.map
                        (\route ->
                            Elm.variantWith
                                route.id
                                [ paramType route
                                ]
                        )
                        routes
                    )
                    |> Elm.exposeWith
                        { exposeConstructor = True
                        , group = Just "Route"
                        }
              ]
            , List.map
                (\route ->
                    Elm.alias (route.id ++ "_Params")
                        (paramType route)
                        |> Elm.exposeWith
                            { exposeConstructor = False
                            , group = Just "Params"
                            }
                )
                routes
            , urlEncoder routes
            , urlParser routes
            , urlToId routes
            ]
        )


hasVars : List Options.Route.UrlPiece -> Bool
hasVars pieces =
    List.any
        (\piece ->
            case piece of
                Options.Route.Token _ ->
                    False

                Options.Route.Variable _ ->
                    True
        )
        pieces


hasNoParams : Options.Route.QueryParams -> Bool
hasNoParams params =
    Set.isEmpty params.specificFields
        && not params.includeCatchAll


paramType : Options.Route.Page -> Type.Annotation
paramType route =
    let
        (Options.Route.UrlPattern { queryParams, includePathTail, path }) =
            route.url
    in
    if hasNoParams queryParams && not includePathTail && route.assets == Nothing && not (hasVars path) then
        Type.record []

    else
        let
            addCatchall fields =
                if queryParams.includeCatchAll then
                    ( "params", Type.dict Type.string Type.string )
                        :: fields

                else
                    fields

            addFullTail fields =
                if includePathTail then
                    ( "path", Type.list Type.string ) :: fields

                else
                    fields
        in
        Type.record
            (List.concat
                [ case route.assets of
                    Nothing ->
                        []

                    Just assets ->
                        [ ( "src", Type.string ) ]
                , List.filterMap
                    (\piece ->
                        case piece of
                            Options.Route.Token _ ->
                                Nothing

                            Options.Route.Variable name ->
                                Just ( name, Type.string )
                    )
                    path
                    |> addFullTail
                , queryParams.specificFields
                    |> Set.toList
                    |> List.map
                        (\field ->
                            ( field, Type.maybe Type.string )
                        )
                    |> addCatchall
                ]
            )


urlToId : List Options.Route.Page -> List Elm.Declaration
urlToId routes =
    [ Elm.declaration "toId"
        (Elm.fn ( "route", Just (Type.named [] "Route") )
            (\route ->
                Elm.Case.custom route
                    (Type.named [] "Route")
                    (routes
                        |> List.map
                            (\individualRoute ->
                                Elm.Case.branch1 individualRoute.id
                                    ( "params", paramType individualRoute )
                                    (\params ->
                                        let
                                            variables =
                                                getParamVariableList individualRoute
                                                    |> List.map
                                                        (\name ->
                                                            Elm.get name params
                                                        )
                                        in
                                        case variables of
                                            [] ->
                                                Elm.string individualRoute.id

                                            _ ->
                                                Gen.String.call_.join (Elm.string "/")
                                                    (Elm.list
                                                        (Elm.string individualRoute.id
                                                            :: variables
                                                        )
                                                    )
                                    )
                            )
                    )
            )
            |> Elm.withType
                (Type.function [ Type.named [] "Route" ] Type.string)
        )
        |> Elm.exposeWith
            { exposeConstructor = True
            , group = Just "Encodings"
            }
    ]


getParamVariableList : Options.Route.Page -> List String
getParamVariableList page =
    case page.url of
        Options.Route.UrlPattern { path } ->
            List.filterMap
                (\piece ->
                    case piece of
                        Options.Route.Token _ ->
                            Nothing

                        Options.Route.Variable name ->
                            Just name
                )
                path


urlEncoder : List Options.Route.Page -> List Elm.Declaration
urlEncoder routes =
    [ Elm.declaration "toString"
        (Elm.fn ( "route", Just (Type.named [] "Route") )
            (\route ->
                Elm.Case.custom route
                    (Type.named [] "Route")
                    (routes
                        |> List.map
                            (\individualRoute ->
                                Elm.Case.branch1 individualRoute.id
                                    ( "params", paramType individualRoute )
                                    (\params ->
                                        let
                                            (Options.Route.UrlPattern { path, includePathTail, queryParams }) =
                                                individualRoute.url
                                        in
                                        renderPath path includePathTail queryParams params
                                    )
                            )
                    )
            )
            |> Elm.withType
                (Type.function [ Type.named [] "Route" ] Type.string)
        )
        |> Elm.exposeWith
            { exposeConstructor = True
            , group = Just "Encodings"
            }
    ]


renderPath : List Options.Route.UrlPiece -> Bool -> Options.Route.QueryParams -> Elm.Expression -> Elm.Expression
renderPath path includePathTail queryParams paramValues =
    let
        base =
            path
                |> List.map
                    (\piece ->
                        case piece of
                            Options.Route.Token token ->
                                Elm.string token

                            Options.Route.Variable var ->
                                Elm.get var paramValues
                    )
                |> Elm.list

        fullPath =
            if includePathTail then
                Elm.Op.append base
                    (Elm.get "path" paramValues)

            else
                base

        allParams =
            if hasNoParams queryParams then
                Gen.Dict.empty

            else if queryParams.includeCatchAll then
                Elm.get "params" paramValues

            else
                Set.foldl
                    (\field dict ->
                        dict
                            |> Elm.Op.pipe
                                (Elm.apply
                                    Gen.Dict.values_.insert
                                    [ Elm.string field
                                    , Elm.Case.maybe (Elm.get field paramValues)
                                        { nothing = Elm.list []
                                        , just =
                                            ( "param"
                                            , \param ->
                                                Elm.list [ param ]
                                            )
                                        }
                                    ]
                                )
                    )
                    Gen.Dict.empty
                    queryParams.specificFields
    in
    Gen.AppUrl.toString
        (Elm.record
            [ ( "path", fullPath )
            , ( "queryParameters", allParams )
            , ( "fragment", Elm.nothing )
            ]
        )


surround first last middle =
    first ++ middle ++ last


wrapRecord fields =
    case fields of
        [] ->
            "{}"

        _ ->
            surround "\n                { "
                "\n                }"
                (fields
                    |> String.join "\n                , "
                )


wrapOpenList remaining fields =
    case fields of
        [] ->
            "[]"

        _ ->
            String.join " :: " fields
                ++ " :: "
                ++ remaining


wrapList fields =
    case fields of
        [] ->
            "[]"

        _ ->
            surround "[ "
                " ]"
                (fields
                    |> String.join ", "
                )


sameRoute : List Options.Route.Page -> Elm.Declaration
sameRoute routes =
    if List.length routes <= 1 then
        Elm.declaration "sameRouteBase"
            (Elm.fn2
                ( "one", Just (Type.named [] "Route") )
                ( "two", Just (Type.named [] "Route") )
                (\one two ->
                    Elm.bool True
                )
            )
            |> Elm.exposeWith
                { exposeConstructor = False
                , group = Just "Route"
                }

    else
        Elm.declaration "sameRouteBase"
            (Elm.fn2
                ( "one", Just (Type.named [] "Route") )
                ( "two", Just (Type.named [] "Route") )
                (\one two ->
                    Elm.Case.custom one
                        (Type.named [] "Route")
                        (routes
                            |> List.map
                                (\route ->
                                    Elm.Case.branch1 route.id
                                        ( "params", Type.var "params" )
                                        (\_ ->
                                            Elm.Case.custom two
                                                (Type.named [] "Route")
                                                [ Elm.Case.branch1 route.id
                                                    ( "params2", Type.var "params2" )
                                                    (\_ ->
                                                        Elm.bool True
                                                    )
                                                , Elm.Case.otherwise
                                                    (\_ ->
                                                        Elm.bool False
                                                    )
                                                ]
                                        )
                                )
                        )
                )
            )
            |> Elm.exposeWith
                { exposeConstructor = False
                , group = Just "Route"
                }


urlParser : List Options.Route.Page -> List Elm.Declaration
urlParser routes =
    [ Elm.declaration "parse"
        (Elm.fn ( "url", Just Gen.Url.annotation_.url )
            (\url ->
                let
                    appUrl =
                        Gen.AppUrl.fromUrl url
                in
                Elm.apply
                    (Elm.val "parseAppUrl")
                    [ appUrl ]
            )
            |> Elm.withType
                (Type.function [ Gen.Url.annotation_.url ]
                    (Type.maybe
                        (Type.record
                            [ ( "route", Type.named [] "Route" )
                            , ( "isRedirect", Type.bool )
                            ]
                        )
                    )
                )
        )
        |> Elm.exposeWith
            { exposeConstructor = True
            , group = Just "Encodings"
            }
    , sameRoute routes
    , parseAppUrl routes
    , Elm.unsafe """
getSingle : String -> AppUrl.QueryParameters -> Maybe String
getSingle field appUrlParams =
    case Dict.get field appUrlParams of
        Nothing ->
            Nothing

        Just [] ->
            Nothing

        Just (single :: _) ->
            Just single


getList : String -> AppUrl.QueryParameters -> List String
getList field appUrlParams =
    Dict.get field appUrlParams
        |> Maybe.withDefault []

"""
    ]


parseAppUrl : List Options.Route.Page -> Elm.Declaration
parseAppUrl routes =
    Elm.declaration "parseAppUrl"
        (Elm.fn
            ( "appUrl", Just Gen.AppUrl.annotation_.appUrl )
            (\appUrl ->
                Elm.Case.custom
                    (Elm.get "path" appUrl)
                    (Type.list Type.string)
                    (List.concatMap (toBranchPattern appUrl) routes
                        ++ [ Branch.ignore Elm.nothing
                           ]
                    )
                    |> Elm.withType
                        (Type.maybe
                            (Type.record
                                [ ( "route", Type.named [] "Route" )
                                , ( "isRedirect", Type.bool )
                                ]
                            )
                        )
            )
        )


toBranchPattern : Elm.Expression -> Options.Route.Page -> List (Branch.Pattern Elm.Expression)
toBranchPattern appUrl page =
    urlToPatterns False appUrl page page.url
        :: List.map (urlToPatterns True appUrl page) page.redirectFrom


urlToPatterns : Bool -> Elm.Expression -> Options.Route.Page -> Options.Route.UrlPattern -> Branch.Pattern Elm.Expression
urlToPatterns isRedirect appUrl page (Options.Route.UrlPattern pattern) =
    let
        toResult route =
            Elm.record
                [ ( "route", route )
                , ( "isRedirect", Elm.bool isRedirect )
                ]
                |> Elm.just
    in
    if pattern.includePathTail then
        Branch.listWithRemaining
            { patterns = List.map toTokenPattern pattern.path
            , remaining = Branch.var "andPathTail"
            , startWith = []
            , gather =
                \fields gathered ->
                    fields ++ gathered
            , finally =
                \pathFields remaining ->
                    let
                        fields =
                            pathFields ++ queryParamFields

                        queryParamFields =
                            pattern.queryParams.specificFields
                                |> Set.foldl
                                    (\queryField gathered ->
                                        ( queryField
                                        , Elm.get "queryParameters" appUrl
                                            |> Gen.Dict.get (Elm.string queryField)
                                            |> Gen.Maybe.call_.andThen Gen.List.values_.head
                                        )
                                            :: gathered
                                    )
                                    []
                    in
                    case page.assets of
                        Nothing ->
                            Elm.apply
                                (Elm.val page.id)
                                [ Elm.record (( "path", remaining ) :: fields)
                                ]
                                |> toResult

                        Just assets ->
                            let
                                lookupAsset =
                                    Elm.apply (Elm.val "lookupAsset")
                                        [ Elm.Op.append
                                            (Elm.string "/")
                                            (Gen.String.call_.join (Elm.string "/") remaining)
                                        ]
                            in
                            Elm.Case.custom lookupAsset
                                (Type.maybe Type.string)
                                [ Branch.just (Branch.var "src")
                                    |> Branch.map
                                        (\src ->
                                            Elm.apply
                                                (Elm.val page.id)
                                                [ Elm.record
                                                    (( "src", src )
                                                        :: ( "path", remaining )
                                                        :: fields
                                                    )
                                                ]
                                                |> toResult
                                        )
                                , Branch.nothing Elm.nothing
                                ]
            }

    else
        Branch.list
            { patterns = List.map toTokenPattern pattern.path
            , startWith = []
            , gather =
                \fields gathered ->
                    fields ++ gathered
            , finally =
                \pathFields ->
                    let
                        fields =
                            pathFields ++ queryParamFields

                        queryParamFields =
                            pattern.queryParams.specificFields
                                |> Set.foldl
                                    (\queryField gathered ->
                                        ( queryField
                                        , Elm.get "queryParameters" appUrl
                                            |> Gen.Dict.get (Elm.string queryField)
                                            |> Gen.Maybe.call_.andThen Gen.List.values_.head
                                        )
                                            :: gathered
                                    )
                                    []
                    in
                    Elm.apply
                        (Elm.val page.id)
                        [ Elm.record fields
                        ]
                        |> toResult
            }


toTokenPattern : Options.Route.UrlPiece -> Branch.Pattern (List ( String, Elm.Expression ))
toTokenPattern token =
    case token of
        Options.Route.Token string ->
            Branch.string string []

        Options.Route.Variable varname ->
            Branch.var varname
                |> Branch.map
                    (\var ->
                        [ ( varname, var ) ]
                    )
