module Msg exposing (..)
import Model exposing (..)
import DropZone exposing (..)
import Model exposing (..)
import Bandcamp
import RemoteData
import Json.Decode as Decode
import FileSystem

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesRead (Result Decode.Error (List FileSystem.FileRef))
  | Play FileSystem.FileRef
  | Saved
  | Paused

  | BandcampMsg Bandcamp.Msg

  | TabClicked Model.Tab
