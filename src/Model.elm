module Model exposing (..)
import File
import DropZone
import Json.Decode as Decode
import Json.Encode as Encode

type alias DropPayload = List TransferItem

encodeDropZoneModel _ = Encode.null
decodeDropZoneModel = Decode.succeed DropZone.init

type alias DropZoneModel = DropZone.Model

type alias File = File.File
encodeFile _ = Encode.null
decodeFile = File.decoder

type TransferItem =
    DroppedFile FileRef
    | DroppedDirectory String

type BandcampCookie = BandcampCookie String
type alias BandcampCookie_ = Maybe BandcampCookie
encodeBandcampCookie_ _ = Encode.null
decodeBandcampCookie_ = Decode.succeed Nothing

-- [decgen-start]

type alias FileRef = {name : String, path: String}

type alias Model =
    { dropZone : DropZoneModel
    , files : List FileRef
    , bandcampCookie : BandcampCookie_
    , playback : Maybe FileRef
    , playing : Bool
    , playlists : List String
    , activePlaylist : Maybe String
    }

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeFileRef =
   Decode.map2
      FileRef
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" Decode.string )

decodeModel =
   Decode.map7
      Model
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "files" (Decode.list decodeFileRef) )
         ( Decode.field "bandcampCookie" decodeBandcampCookie_ )
         ( Decode.field "playback" (Decode.maybe decodeFileRef) )
         ( Decode.field "playing" Decode.bool )
         ( Decode.field "playlists" (Decode.list Decode.string) )
         ( Decode.field "activePlaylist" (Decode.maybe Decode.string) )

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", Encode.string a.path)
      ]

encodeMaybeFileRef a =
   case a of
      Just b->
         encodeFileRef b
      Nothing->
         Encode.null

encodeMaybeString a =
   case a of
      Just b->
         Encode.string b
      Nothing->
         Encode.null

encodeModel a =
   Encode.object
      [ ("dropZone", encodeDropZoneModel a.dropZone)
      , ("files", (Encode.list encodeFileRef) a.files)
      , ("bandcampCookie", encodeBandcampCookie_ a.bandcampCookie)
      , ("playback", encodeMaybeFileRef a.playback)
      , ("playing", Encode.bool a.playing)
      , ("playlists", (Encode.list Encode.string) a.playlists)
      , ("activePlaylist", encodeMaybeString a.activePlaylist)
      ] 
-- [decgen-end]

