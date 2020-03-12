port module FileSystem exposing (..)
import Json.Decode as Decode
import Json.Encode as Encode


port filesystem_in_files_parsed : (Decode.Value -> a) -> Sub a
port filesystem_in_paths_scanned : (List String -> a) -> Sub a
port scan_paths : List String -> Cmd msg

-- [generator-start]
type alias Path = String
type alias FileRef = {name : String, path: Path}
type alias ReadResult =
    { name : String
    , path: Path
    , albumartist : String
    , album : String
    , artist : String
    , track : {no: Maybe Int}
    }

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
type alias Record_no_MaybeInt_ = {no: Maybe Int}

decodeFileRef =
   Decode.map2
      FileRef
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" decodePath )

decodePath =
   Decode.string

decodeReadResult =
   Decode.map6
      ReadResult
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" decodePath )
         ( Decode.field "albumartist" Decode.string )
         ( Decode.field "album" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "track" decodeRecord_no_MaybeInt_ )

decodeRecord_no_MaybeInt_ =
   Decode.map
      Record_no_MaybeInt_
         ( Decode.field "no" (Decode.maybe Decode.int) )

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", encodePath a.path)
      ]

encodeMaybeInt a =
   case a of
      Just b->
         Encode.int b
      Nothing->
         Encode.null

encodePath a =
   Encode.string a

encodeReadResult a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", encodePath a.path)
      , ("albumartist", Encode.string a.albumartist)
      , ("album", Encode.string a.album)
      , ("artist", Encode.string a.artist)
      , ("track", encodeRecord_no_MaybeInt_ a.track)
      ]

encodeRecord_no_MaybeInt_ a =
   Encode.object
      [ ("no", encodeMaybeInt a.no)
      ] 
-- [generator-end]


