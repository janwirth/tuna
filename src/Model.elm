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

-- [decgen-start]

type BandcampCookie = BandcampCookie String
type alias FileRef = {name : String, path: String}

type alias Model =
    { dropZone : DropZoneModel
    , files : List FileRef
    , bandcampCookie : Maybe BandcampCookie
    , playback : Maybe FileRef
    , playing : Bool
    , playlists : List String
    , activePlaylist : Maybe String
    }

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeBandcampCookie =
   Decode.map BandcampCookie Decode.string

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
         ( Decode.field "bandcampCookie" (Decode.maybe decodeBandcampCookie) )
         ( Decode.field "playback" (Decode.maybe decodeFileRef) )
         ( Decode.field "playing" Decode.bool )
         ( Decode.field "playlists" (Decode.list Decode.string) )
         ( Decode.field "activePlaylist" (Decode.maybe Decode.string) )

encodeBandcampCookie (BandcampCookie a1) =
   Encode.string a1

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", Encode.string a.path)
      ]

encodeMaybeBandcampCookie a =
   case a of
      Just b->
         encodeBandcampCookie b
      Nothing->
         Encode.null

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
      , ("bandcampCookie", encodeMaybeBandcampCookie a.bandcampCookie)
      , ("playback", encodeMaybeFileRef a.playback)
      , ("playing", Encode.bool a.playing)
      , ("playlists", (Encode.list Encode.string) a.playlists)
      , ("activePlaylist", encodeMaybeString a.activePlaylist)
      ] 
-- [decgen-end]




