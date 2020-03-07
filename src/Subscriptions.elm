module Subscriptions exposing (subscriptions)
import Model
import Msg
import Bandcamp
import FileSystem
import Json.Decode as Decode

subscriptions : Model.Model -> Sub Msg.Msg
subscriptions model =
    Sub.batch [bandcampSub, filesystemSub]

bandcampSub : Sub Msg.Msg
bandcampSub =
    let
        captureBandcampLib val =
            val
            |> Decode.decodeValue Bandcamp.extractModelFromBlob
            |> Msg.BandcampDataRetrieved
    in
            Bandcamp.bandcamp_library_retrieved captureBandcampLib



filesystemSub : Sub Msg.Msg
filesystemSub =
    let
        captureFileSystemScan val =
            val
            |> Decode.decodeValue (Decode.list Model.decodeFileRef)
            |> Msg.FilesRead
    in
      FileSystem.directories_scanned captureFileSystemScan
