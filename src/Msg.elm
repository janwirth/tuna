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
import InfiniteList

-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage DropPayload)
  | FilesFound (List String)
  | FilesRead (Result Decode.Error (List FileSystem.ReadResult))
  | PlayerMsg Player.Msg

  | BandcampMsg Bandcamp.Msg

  | TabClicked Model.Tab

  | TagChanged Int String

  | UrlRequested
  | UrlChanged

  | InfiniteListMsg InfiniteList.Model
