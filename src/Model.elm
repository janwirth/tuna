module Model exposing (..)
import File
import DropZone
import Json.Decode as Decode
import Json.Encode as Encode
import Bandcamp
import Time
import Dict
import Json.Decode.Extra as Extra

init : Model
init =
    { dropZone = DropZone.init
    , files = []
    , tab = LocalTab
    , playing = False
    , playback = Nothing
    , playlists = ["House" , "Jazz"]
    , activePlaylist = Just "Jazz"
    , bandcamp = Bandcamp.initModel
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
type Tab = BandcampTab | LocalTab

type alias FileRef = {name : String, path: String}

type alias Model =
    { dropZone : DropZoneModel
    , files : List FileRef
    , bandcamp : Bandcamp.Model
    , tab : Tab
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
   Decode.map8
      Model
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "files" (Decode.list decodeFileRef) )
         ( Decode.field "bandcamp" Bandcamp.decodeModel )
         ( Decode.field "tab" decodeTab )
         ( Decode.field "playback" (Decode.maybe decodeFileRef) )
         ( Decode.field "playing" Decode.bool )
         ( Decode.field "playlists" (Decode.list Decode.string) )
         ( Decode.field "activePlaylist" (Decode.maybe Decode.string) )

decodeTab =
   let
      recover x =
         case x of
            "BandcampTab"->
               Decode.succeed BandcampTab
            "LocalTab"->
               Decode.succeed LocalTab
            other->
               Decode.fail <| "Unknown constructor for type Tab: " ++ other
   in
      Decode.string |> Decode.andThen recover

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
      , ("bandcamp", Bandcamp.encodeModel a.bandcamp)
      , ("tab", encodeTab a.tab)
      , ("playback", encodeMaybeFileRef a.playback)
      , ("playing", Encode.bool a.playing)
      , ("playlists", (Encode.list Encode.string) a.playlists)
      , ("activePlaylist", encodeMaybeString a.activePlaylist)
      ]

encodeTab a =
   case a of
      BandcampTab ->
         Encode.string "BandcampTab"
      LocalTab ->
         Encode.string "LocalTab" 
-- [decgen-end]




