module Msg exposing (..)
import Model exposing (..)
import DropZone exposing (..)
import Http
import Model exposing (..)

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesRead (Result Http.Error (List FileRef))
  | Play FileRef
  | Saved
  | Restored (Result Http.Error Model.Model)
