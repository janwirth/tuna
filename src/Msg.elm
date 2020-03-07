module Msg exposing (..)
import Model exposing (..)
import DropZone exposing (..)
import Model exposing (..)
import Bandcamp
import RemoteData
import Json.Decode as Decode

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesRead (Result Decode.Error (List FileRef))
  | Play FileRef
  | Saved
  | Paused

  | BandcampMsg Bandcamp.Msg

  | TabClicked Model.Tab
