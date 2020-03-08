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

import Browser.Navigation

type alias Flags = {restored : Decode.Value, seed : Int, seed_extension : List Int}

decodeOrInit : Flags -> Url.Url -> Browser.Navigation.Key -> Model
decodeOrInit flags url key =
    let
        seed = Random.Pcg.Extended.initialSeed flags.seed flags.seed_extension
        userModel : UserModel
        userModel =
            Decode.decodeValue decodeUserModel flags.restored
            |> Result.toMaybe
            |> Maybe.withDefault initUserModel
        { dropZone
            , tracks
            , tab
            , player
            , bandcamp
            } = userModel
    in
        { key = key
        , seed = seed
        , dropZone = dropZone
        , tracks = tracks
        , tab = tab
        , player = player
        , bandcamp = bandcamp
        }

initUserModel : UserModel
initUserModel =
    { dropZone = DropZone.init
    , tracks = Track.initTracks
    , tab = LocalTab
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
    , seed : Random.Pcg.Extended.Seed
    }
type alias Model = Internals UserModel
-- never persist bandcamp cookie
-- encodeBandcampCookie_ _ = Encode.null
-- decodeBandcampCookie_ = Decode.succeed Nothing
-- [generator-start]
{-| A track ID based on the hash of initial metadata -}
type Tab = BandcampTab | LocalTab


type alias UserModel =
    { dropZone : DropZoneModel
    , tracks : Track.Tracks
    , bandcamp : Bandcamp.Model.Model
    , tab : Tab
    , player : Player.Model
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
   Decode.map5
      UserModel
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "tracks" Track.decodeTracks )
         ( Decode.field "bandcamp" Bandcamp.Model.decodeModel )
         ( Decode.field "tab" decodeTab )
         ( Decode.field "player" Player.decodeModel )

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
      ] 
-- [generator-end]












