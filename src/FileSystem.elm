port module FileSystem exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode


port paths_scanned : (Decode.Value -> a) -> Sub a
port scan_paths : List String -> Cmd msg

-- [decgen-start]
type alias Path = String
type alias FileRef = {name : String, path: Path}

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeFileRef =
   Decode.map2
      FileRef
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" decodePath )

decodePath =
   Decode.string

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", encodePath a.path)
      ]

encodePath a =
   Encode.string a 
-- [decgen-end]


