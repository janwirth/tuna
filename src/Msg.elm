module Msg exposing (..)
import Model exposing (..)
import DropZone exposing (..)
import Http
import Model exposing (..)
import Bandcamp
import RemoteData
import Json.Decode as Decode

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesRead (Result Http.Error (List FileRef))
  | Play FileRef
  | Saved
  | Restored (Result Http.Error Model.Model)
  | Paused

  | BandcampCookieRetrieved Bandcamp.Cookie
  | BandcampDataRetrieved (Result Decode.Error Bandcamp.Model)
