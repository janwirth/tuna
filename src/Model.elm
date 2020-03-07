module Model exposing (..)
import File
import DropZone
import Json.Decode as Decode
import Json.Encode as Encode
import Bandcamp
import Time
import Dict

init : Model
init =
    {dropZone = DropZone.init
    , files = []
    , bandcampCookie = Nothing
    , playing = False
    , playback = Nothing
    , playlists = ["House" , "Jazz"]
    , activePlaylist = Just "Jazz"
    , bandcampData = Bandcamp.initModel
    }

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

-- never persist bandcamp cookie
-- encodeBandcampCookie_ _ = Encode.null
-- decodeBandcampCookie_ = Decode.succeed Nothing
-- [decgen-start]

type alias FileRef = {name : String, path: String}

type alias Model =
    { dropZone : DropZoneModel
    , files : List FileRef
    , bandcampCookie : Maybe Bandcamp.Cookie
    , playback : Maybe FileRef
    , playing : Bool
    , playlists : List String
    , activePlaylist : Maybe String
    , bandcampData : Bandcamp.Model
    }

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeFileRef =
   Decode.map2
      FileRef
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" Decode.string )

decodeModel =
   Decode.map8
      Model
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "files" (Decode.list decodeFileRef) )
         ( Decode.field "bandcampCookie" (Decode.maybe Bandcamp.decodeCookie) )
         ( Decode.field "playback" (Decode.maybe decodeFileRef) )
         ( Decode.field "playing" Decode.bool )
         ( Decode.field "playlists" (Decode.list Decode.string) )
         ( Decode.field "activePlaylist" (Decode.maybe Decode.string) )
         ( Decode.field "bandcampData" Bandcamp.decodeModel )

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", Encode.string a.path)
      ]

encodeMaybeBandcamp_Cookie a =
   case a of
      Just b->
         Bandcamp.encodeCookie b
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
      , ("bandcampCookie", encodeMaybeBandcamp_Cookie a.bandcampCookie)
      , ("playback", encodeMaybeFileRef a.playback)
      , ("playing", Encode.bool a.playing)
      , ("playlists", (Encode.list Encode.string) a.playlists)
      , ("activePlaylist", encodeMaybeString a.activePlaylist)
      , ("bandcampData", Bandcamp.encodeModel a.bandcampData)
      ] 
-- [decgen-end]
