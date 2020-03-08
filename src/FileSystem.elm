port module FileSystem exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode

port directories_scanned : (Decode.Value -> a) -> Sub a
port scan_directories : List String -> Cmd msg

-- [decgen-start]
type alias FileRef = {name : String, path: String}

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeFileRef =
   Decode.map2
      FileRef
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" Decode.string )

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", Encode.string a.path)
      ] 
-- [decgen-end]

