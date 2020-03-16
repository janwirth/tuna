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
import Track
import Json.Decode as Decode
import Random.Pcg.Extended
import Url
import Player
import Set exposing (Set)
import InfiniteList

import Browser.Navigation

type alias Flags = {restored : Decode.Value}

encodeSetString = Encode.set Encode.string
decodeSetString = Decode.list Decode.string
    |> Decode.map Set.fromList

decodeOrInit : Flags -> Model
decodeOrInit flags =
    Decode.decodeValue decodeModel flags.restored
    -- |> Debug.log "restored"
    |> Result.toMaybe
    |> Maybe.withDefault initModel
initModel : Model
initModel =
    { dropZone = DropZone.init
    , infiniteList = InfiniteList.init
    , tracks = Track.initTracks
    , tab = LocalTab
    , pendingFiles = Set.empty
    , player = Player.init
    , bandcamp = Bandcamp.Model.initModel
    , quickTag = "❤️"
    , quickTagOnly = False
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

type alias InfiniteList = InfiniteList.Model

decodeInfiniteList = Decode.succeed InfiniteList.init
encodeInfiniteList _ = Encode.string "InfiniteList is not persisted"


-- [generator-start]
{-| A track ID based on the hash of initial metadata -}
type Tab = BandcampTab | LocalTab


type alias Model =
    { dropZone : DropZoneModel
    , tracks : Track.Tracks
    , bandcamp : Bandcamp.Model.Model
    , tab : Tab
    , player : Player.Model
    , pendingFiles : Set String
    , infiniteList : InfiniteList
    , quickTag : String
    , quickTagOnly : Bool
    }

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeModel =
   Decode.succeed
      Model
         |> Extra.andMap (Decode.field "dropZone" decodeDropZoneModel)
         |> Extra.andMap (Decode.field "tracks" Track.decodeTracks)
         |> Extra.andMap (Decode.field "bandcamp" Bandcamp.Model.decodeModel)
         |> Extra.andMap (Decode.field "tab" decodeTab)
         |> Extra.andMap (Decode.field "player" Player.decodeModel)
         |> Extra.andMap (Decode.field "pendingFiles" decodeSetString)
         |> Extra.andMap (Decode.field "infiniteList" decodeInfiniteList)
         |> Extra.andMap (Decode.field "quickTag" Decode.string)
         |> Extra.andMap (Decode.field "quickTagOnly" Decode.bool)

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

encodeModel a =
   Encode.object
      [ ("dropZone", encodeDropZoneModel a.dropZone)
      , ("tracks", Track.encodeTracks a.tracks)
      , ("bandcamp", Bandcamp.Model.encodeModel a.bandcamp)
      , ("tab", encodeTab a.tab)
      , ("player", Player.encodeModel a.player)
      , ("pendingFiles", encodeSetString a.pendingFiles)
      , ("infiniteList", encodeInfiniteList a.infiniteList)
      , ("quickTag", Encode.string a.quickTag)
      , ("quickTagOnly", Encode.bool a.quickTagOnly)
      ]

encodeTab a =
   case a of
      BandcampTab ->
         Encode.string "BandcampTab"
      LocalTab ->
         Encode.string "LocalTab" 
-- [generator-end]
