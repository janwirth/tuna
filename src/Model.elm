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

decodeOrInit : Flags -> Url.Url -> Browser.Navigation.Key -> Model
decodeOrInit flags url key =
    let
        userModel : UserModel
        userModel =
            Decode.decodeValue decodeUserModel flags.restored
            -- |> Debug.log "restored"
            |> Result.toMaybe
            |> Maybe.withDefault initUserModel
        { dropZone
            , tracks
            , tab
            , player
            , bandcamp
            , infiniteList
            , pendingFiles
            } = userModel
    in
        { key = key
        , dropZone = dropZone
        , tracks = tracks
        , pendingFiles = pendingFiles
        , infiniteList = InfiniteList.init
        , tab = tab
        , player = player
        , bandcamp = bandcamp
        }

initUserModel : UserModel
initUserModel =
    { dropZone = DropZone.init
    , infiniteList = InfiniteList.init
    , tracks = Track.initTracks
    , tab = LocalTab
    , pendingFiles = Set.empty
    , player = Player.init
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

type alias Internals mdl =
    { mdl
    | key : Browser.Navigation.Key
    }

type alias Model = Internals UserModel
type alias InfiniteList = InfiniteList.Model

decodeInfiniteList = Decode.succeed InfiniteList.init
encodeInfiniteList _ = Encode.string "InfiniteList is not persisted"


-- [generator-start]
{-| A track ID based on the hash of initial metadata -}
type Tab = BandcampTab | LocalTab


type alias UserModel =
    { dropZone : DropZoneModel
    , tracks : Track.Tracks
    , bandcamp : Bandcamp.Model.Model
    , tab : Tab
    , player : Player.Model
    , pendingFiles : Set String
    , infiniteList : InfiniteList
    }

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
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

decodeUserModel =
   Decode.map7
      UserModel
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "tracks" Track.decodeTracks )
         ( Decode.field "bandcamp" Bandcamp.Model.decodeModel )
         ( Decode.field "tab" decodeTab )
         ( Decode.field "player" Player.decodeModel )
         ( Decode.field "pendingFiles" decodeSetString )
         ( Decode.field "infiniteList" decodeInfiniteList )

encodeTab a =
   case a of
      BandcampTab ->
         Encode.string "BandcampTab"
      LocalTab ->
         Encode.string "LocalTab"

encodeUserModel a =
   Encode.object
      [ ("dropZone", encodeDropZoneModel a.dropZone)
      , ("tracks", Track.encodeTracks a.tracks)
      , ("bandcamp", Bandcamp.Model.encodeModel a.bandcamp)
      , ("tab", encodeTab a.tab)
      , ("player", Player.encodeModel a.player)
      , ("pendingFiles", encodeSetString a.pendingFiles)
      , ("infiniteList", encodeInfiniteList a.infiniteList)
      ] 
-- [generator-end]
