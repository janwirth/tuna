module Model exposing (..)
import File
import DropZone
import Json.Decode as Decode
import Json.Encode as Encode
import Bandcamp
import Bandcamp.Model
import Time
import Dict
import Json.Decode.Extra as Extra
import FileSystem


init : Model
init =
    { dropZone = DropZone.init
    , files = []
    , tab = LocalTab
    , playing = False
    , playback = Nothing
    , playlists = ["House" , "Jazz"]
    , activePlaylist = Just "Jazz"
    , bandcamp = Bandcamp.Model.initModel
    }

type alias DropPayload = List TransferItem

encodeDropZoneModel _ = Encode.null
decodeDropZoneModel = Decode.succeed DropZone.init

type alias DropZoneModel = DropZone.Model

type alias File = File.File
encodeFile _ = Encode.null
decodeFile = File.decoder

type TransferItem =
    DroppedFile FileSystem.FileRef
    | DroppedDirectory String

-- never persist bandcamp cookie
-- encodeBandcampCookie_ _ = Encode.null
-- decodeBandcampCookie_ = Decode.succeed Nothing
-- [decgen-start]
type Tab = BandcampTab | LocalTab


type alias Model =
    { dropZone : DropZoneModel
    , files : List FileSystem.FileRef
    , bandcamp : Bandcamp.Model.Model
    , tab : Tab
    , playback : Maybe FileSystem.FileRef
    , playing : Bool
    , playlists : List String
    , activePlaylist : Maybe String
    }

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeModel =
   Decode.map8
      Model
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "files" (Decode.list FileSystem.decodeFileRef) )
         ( Decode.field "bandcamp" Bandcamp.Model.decodeModel )
         ( Decode.field "tab" decodeTab )
         ( Decode.field "playback" (Decode.maybe FileSystem.decodeFileRef) )
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

encodeMaybeFileSystem_FileRef a =
   case a of
      Just b->
         FileSystem.encodeFileRef b
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
      , ("files", (Encode.list FileSystem.encodeFileRef) a.files)
      , ("bandcamp", Bandcamp.Model.encodeModel a.bandcamp)
      , ("tab", encodeTab a.tab)
      , ("playback", encodeMaybeFileSystem_FileRef a.playback)
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






