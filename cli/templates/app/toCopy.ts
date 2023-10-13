
import * as path from "path";
import * as fs from "fs";

export const copyTo = (baseDir: string, overwrite: boolean) => { 
  
  if (overwrite || !fs.existsSync(path.join(baseDir, "/App/Effect.elm"))) {
    fs.mkdirSync(path.dirname(path.join(baseDir, "/App/Effect.elm")), { recursive: true });
    fs.writeFileSync(path.join(baseDir, "/App/Effect.elm"), "port module App.Effect exposing\n    ( none, batch\n    , pushUrl, replaceUrl\n    , forward, back\n    , preload, load, reload\n    , Effect, toCmd, map\n    )\n\n{-|\n\n@docs none, batch\n\n@docs pushUrl, replaceUrl\n\n@docs forward, back\n\n@docs preload, load, reload\n\n\n# Effects\n\n@docs Effect, toCmd, map\n\n-}\n\nimport Browser\nimport Browser.Dom\nimport Browser.Navigation\nimport Html\nimport Http\nimport Json.Encode\nimport Route\nimport Task\n\n\nnone : Effect msg\nnone =\n    None\n\n\nbatch : List (Effect msg) -> Effect msg\nbatch =\n    Batch\n\n\npushUrl : String -> Effect msg\npushUrl =\n    PushUrl\n\n\nreplaceUrl : String -> Effect msg\nreplaceUrl =\n    ReplaceUrl\n\n\nload : String -> Effect msg\nload =\n    Load\n\n\npreload : Route.Route -> Effect msg\npreload =\n    Preload\n\n\nreload : Effect msg\nreload =\n    Reload\n\n\nforward : Int -> Effect msg\nforward =\n    Forward\n\n\nback : Int -> Effect msg\nback =\n    Back\n\n\ntype Effect msg\n    = None\n    | Batch (List (Effect msg))\n      --\n    | Callback msg\n      -- Urls\n    | PushUrl String\n    | ReplaceUrl String\n      -- Loading\n    | Preload Route.Route\n    | Load String\n    | Reload\n      -- History navigation\n    | Forward Int\n    | Back Int\n      -- JS interop\n    | SendToWorld\n        { tag : String\n        , details : Maybe Json.Encode.Value\n        }\n\n\nport outgoing : { tag : String, details : Maybe Json.Encode.Value } -> Cmd msg\n\n\ntoCmd : { options | navKey : Browser.Navigation.Key, preload : Route.Route -> msg } -> Effect msg -> Cmd msg\ntoCmd options effect =\n    case effect of\n        None ->\n            Cmd.none\n\n        Batch effects ->\n            Cmd.batch (List.map (toCmd options) effects)\n\n        PushUrl url ->\n            Browser.Navigation.pushUrl options.navKey url\n\n        ReplaceUrl url ->\n            Browser.Navigation.replaceUrl options.navKey url\n\n        Load url ->\n            Browser.Navigation.load url\n\n        Reload ->\n            Browser.Navigation.reload\n\n        Forward steps ->\n            Browser.Navigation.forward options.navKey steps\n\n        Back steps ->\n            Browser.Navigation.back options.navKey steps\n\n        SendToWorld outgoingMsg ->\n            outgoing outgoingMsg\n\n        Callback msg ->\n            Task.succeed ()\n                |> Task.perform (\\_ -> msg)\n\n        Preload route ->\n            Task.succeed ()\n                |> Task.perform (\\_ -> options.preload route)\n\n\nmap : (a -> b) -> Effect a -> Effect b\nmap f effect =\n    case effect of\n        None ->\n            None\n\n        Batch effects ->\n            Batch (List.map (map f) effects)\n\n        PushUrl url ->\n            PushUrl url\n\n        ReplaceUrl url ->\n            ReplaceUrl url\n\n        Load url ->\n            Load url\n\n        Reload ->\n            Reload\n\n        Forward n ->\n            Forward n\n\n        Back n ->\n            Back n\n\n        SendToWorld { tag, details } ->\n            SendToWorld { tag = tag, details = details }\n\n        Callback msg ->\n            Callback (f msg)\n\n        Preload route ->\n            Preload route\n");
  }


  if (overwrite || !fs.existsSync(path.join(baseDir, "/App/Page.elm"))) {
    fs.mkdirSync(path.dirname(path.join(baseDir, "/App/Page.elm")), { recursive: true });
    fs.writeFileSync(path.join(baseDir, "/App/Page.elm"), "module App.Page exposing\n    ( Page, page, authenticated\n    , Init, init, initWith, notFound, loadFrom, error\n    )\n\n{-|\n\n@docs Page, page, authenticated\n\n@docs Init, init, initWith, notFound, loadFrom, error\n\n-}\n\nimport App.Effect\nimport App.Engine.Page\nimport App.PageError\nimport App.Shared\nimport App.Sub\nimport App.View\n\n\n{-| -}\ntype alias Page params msg model =\n    App.Engine.Page.Page App.Shared.Shared params msg model\n\n\n{-| -}\npage :\n    { init : params -> App.Shared.Shared -> Maybe model -> Init msg model\n    , update : App.Shared.Shared -> msg -> model -> ( model, App.Effect.Effect msg )\n    , subscriptions : App.Shared.Shared -> model -> App.Sub.Sub msg\n    , view : App.Shared.Shared -> model -> App.View.View msg\n    }\n    -> Page params msg model\npage =\n    App.Engine.Page.page\n\n\n{-| -}\ntype alias Authenticated shared params msg model =\n    App.Engine.Page.Page shared params msg model\n\n\n{-| -}\nauthenticated :\n    { init : params -> App.Shared.Shared -> Maybe model -> Init msg model\n    , update : App.Shared.Shared -> msg -> model -> ( model, App.Effect.Effect msg )\n    , subscriptions : App.Shared.Shared -> model -> App.Sub.Sub msg\n    , view : App.Shared.Shared -> model -> App.View.View msg\n    }\n    -> Page params msg model\nauthenticated options =\n    App.Engine.Page.page options\n        |> App.Engine.Page.withGuard\n            (\\shared ->\n                case shared.authenticated of\n                    App.Shared.Authenticated ->\n                        Ok shared\n\n                    App.Shared.Unauthenticated ->\n                        Err App.PageError.Unauthenticated\n            )\n\n\ntype alias Init msg model =\n    App.Engine.Page.Init msg model\n\n\n{-| -}\ninit : model -> Init msg model\ninit =\n    App.Engine.Page.init\n\n\n{-| -}\ninitWith : model -> App.Effect.Effect msg -> Init msg model\ninitWith =\n    App.Engine.Page.initWith\n\n\n{-| -}\nnotFound : Init msg model\nnotFound =\n    App.Engine.Page.notFound\n\n\n{-| -}\nloadFrom : App.Effect.Effect (Init msg model) -> Init msg model\nloadFrom =\n    App.Engine.Page.loadFrom\n\n\n{-| -}\nerror : App.PageError.Error -> Init msg model\nerror =\n    App.Engine.Page.error\n");
  }


  if (overwrite || !fs.existsSync(path.join(baseDir, "/App/PageError.elm"))) {
    fs.mkdirSync(path.dirname(path.join(baseDir, "/App/PageError.elm")), { recursive: true });
    fs.writeFileSync(path.join(baseDir, "/App/PageError.elm"), "module App.PageError exposing (Error(..))\n\n{-| \nYou may want to protect a page with a certain error when it is first requested.\n\n- `NotFound` is built in to `elm-press`, so you don't need to capture that here.\n\nCommon errors are\n\n    - Unauthenticated — When you require someone to be signed in in order to see a page.\n    - Permission denied — When you require taht someone is both signed in and has certain permissions.\n\n\n-}\n\n\ntype Error =\n    Unauthenticated");
  }


  if (overwrite || !fs.existsSync(path.join(baseDir, "/App/Shared.elm"))) {
    fs.mkdirSync(path.dirname(path.join(baseDir, "/App/Shared.elm")), { recursive: true });
    fs.writeFileSync(path.join(baseDir, "/App/Shared.elm"), "module App.Shared exposing\n    ( Shared\n    , Authenticated(..)\n    )\n\n{-| Data that is shared between the global app and the individual pages.\n\n@docs Shared\n\n@docs Authenticated\n\n-}\n\n\ntype alias Shared =\n    { authenticated : Authenticated }\n\n\ntype Authenticated\n    = Authenticated\n    | Unauthenticated\n");
  }


  if (overwrite || !fs.existsSync(path.join(baseDir, "/App/Sub.elm"))) {
    fs.mkdirSync(path.dirname(path.join(baseDir, "/App/Sub.elm")), { recursive: true });
    fs.writeFileSync(path.join(baseDir, "/App/Sub.elm"), "port module App.Sub exposing\n    ( none, batch\n    , map, toSubscription\n    , Sub\n    )\n\n{-|\n\n\n# Subscriptions\n\n@docs Subscription\n\n@docs none, batch\n\n@docs map, toSubscription\n\n-}\n\nimport Json.Encode\nimport Platform.Sub\n\n\ntype Sub msg\n    = Sub (Platform.Sub.Sub msg)\n    | Batch (List (Sub msg))\n\n\n{-| -}\nnone : Sub msg\nnone =\n    Sub Platform.Sub.none\n\n\n{-| -}\nbatch : List (Sub msg) -> Sub msg\nbatch =\n    Batch\n\n\n{-| -}\nmap : (a -> b) -> Sub a -> Sub b\nmap func sub =\n    case sub of\n        Sub subscription ->\n            Sub (Platform.Sub.map func subscription)\n\n        Batch subs ->\n            Batch (List.map (map func) subs)\n\n\n{-| -}\ntoSubscription : Sub msg -> Platform.Sub.Sub msg\ntoSubscription sub =\n    case sub of\n        Sub subscription ->\n            subscription\n\n        Batch subs ->\n            Platform.Sub.batch (List.map toSubscription subs)\n\n\nport incoming :\n    ({ tag : String\n     , details : Maybe Json.Encode.Value\n     }\n     -> msg\n    )\n    -> Platform.Sub.Sub msg\n");
  }


  if (overwrite || !fs.existsSync(path.join(baseDir, "/App/View.elm"))) {
    fs.mkdirSync(path.dirname(path.join(baseDir, "/App/View.elm")), { recursive: true });
    fs.writeFileSync(path.join(baseDir, "/App/View.elm"), "module App.View exposing (View, map)\n\n{-|\n\n@docs View, map\n\n-}\n\nimport Html\n\n\ntype alias View msg =\n    { title : String\n    , body : Html.Html msg\n    }\n\n\nmap : (a -> b) -> View a -> View b\nmap fn myView =\n    { title = myView.title\n    , body = Html.map fn myView.body\n    }\n");
  }

}
