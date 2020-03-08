module Msg exposing (..)
import Model exposing (..)
import DropZone exposing (..)
import Model exposing (..)
import Bandcamp
import RemoteData
import Json.Decode as Decode
import FileSystem
import Player
import Url
import Browser

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesRead (Result Decode.Error (List FileSystem.FileRef))
  | PlayerMsg Player.Msg

  | BandcampMsg Bandcamp.Msg

  | TabClicked Model.Tab

  | UrlRequested
  | UrlChanged
