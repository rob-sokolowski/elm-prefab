module Generate exposing (main)

{-| -}

import Elm
import Gen.CodeGen.Generate as Generate
import Generate.Assets
import Json.Decode
import Options.Assets


main : Program Json.Decode.Value () ()
main =
    Generate.withFeedback
        (\flags ->
            case Json.Decode.decodeValue Options.Assets.decode flags of
                Ok input ->
                    Ok
                        { info = []
                        , files = Generate.Assets.generate input
                        }

                Err e ->
                    Err
                        [ { title = "Assets: I don't understand this config"
                          , description = Json.Decode.errorToString e
                          }
                        ]
        )
