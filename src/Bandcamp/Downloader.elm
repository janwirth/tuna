port module Bandcamp.Downloader exposing (..)
{-| This module handles the bandcamp download process which is quite complicated to automate.
Given that a url to the download page is available the steps are:
1. fetch download page and extract the URL to request a an asset in the chosen format
2. request the asset url for chosen format
3. download the asset
4. unzip the asset, if necessary
5. read the unzipped directory

@@TODO - readable file names
@@TODO - catch errors
@@TODO - integrity checks
-}
import Dict
import Element
import Color
import Element.Background
import Element.Input
import Element.Font
import Element.Border
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Bandcamp.Model
import FileSystem
import Element.Border
import Bandcamp.Id
import Html
import Html.Attributes
import Html.Events
import Bandcamp.Id


subscriptions : Bandcamp.Model.Downloads -> Sub Msg
subscriptions model =
    Sub.batch [
        bandcamp_downloader_in_download_progressed
            ((Tuple.mapFirst Bandcamp.Id.fromPort) >> DownloadProgressed)
      , bandcamp_downloader_in_download_failed
            (Bandcamp.Id.fromPort >> DownloadFailed)
      , bandcamp_downloader_in_download_completed
            (Bandcamp.Id.fromPort >> DownloadCompleted)
      , bandcamp_downloader_in_files_extracted
            (Bandcamp.Id.fromPort >> FilesExtracted)
      , bandcamp_downloader_in_files_scanned
            (Tuple.mapFirst Bandcamp.Id.fromPort >> FilesScanned)
    ]


-- out ports
port bandcamp_downloader_out_download_initiated : {item_id: Int, asset_url: String} -> Cmd msg
port bandcamp_downloader_out_unzip_initiated : Int -> Cmd msg
port bandcamp_downloader_out_scan_started : Int -> Cmd msg

-- in ports
port bandcamp_downloader_in_download_progressed
    : ((Bandcamp.Id.ForPort, Bandcamp.Model.DownloadProgress) -> msg)
    -> Sub msg

port bandcamp_downloader_in_download_completed
    : (Bandcamp.Id.ForPort -> msg)
    -> Sub msg

port bandcamp_downloader_in_files_extracted
    : (Bandcamp.Id.ForPort -> msg)
    -> Sub msg

port bandcamp_downloader_in_files_scanned
    : ((Bandcamp.Id.ForPort, List FileSystem.FileRef) -> msg)
    -> Sub msg

port bandcamp_downloader_in_download_failed
    : (Bandcamp.Id.ForPort -> msg)
    -> Sub msg

type Msg =
    DownloadButtonClicked Bandcamp.Id.Id
  | ClearButtonClicked Bandcamp.Id.Id
  | FormatterUrlRetrieved (Bandcamp.Id.Id, String)
  | AssetUrlRetrieved Bandcamp.Id.Id String
  | DownloadProgressed (Bandcamp.Id.Id, Bandcamp.Model.DownloadProgress)
  | DownloadCompleted Bandcamp.Id.Id
  | DownloadFailed Bandcamp.Id.Id
  | FilesExtracted Bandcamp.Id.Id
  | FilesScanned (Bandcamp.Id.Id, List FileSystem.FileRef)


update : Msg -> Bandcamp.Model.Model -> (Bandcamp.Model.Model, Cmd Msg)
update msg model =
    case model.cookie of
        Nothing -> (model, Cmd.none)
        Just (Bandcamp.Model.Cookie cookie) ->
            case msg of
                ClearButtonClicked item_id ->
                        ({ model
                        | downloads = Bandcamp.Id.removeBy item_id model.downloads
                        }, Cmd.none)
                DownloadButtonClicked item_id ->
                    let
                        mdl =
                            { model
                            | downloads = Bandcamp.Id.insertBy item_id Bandcamp.Model.initDownload model.downloads
                            }
                    in
                        (mdl, Cmd.none)
                FormatterUrlRetrieved (item_id, formatter_url) ->
                    let
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads = Bandcamp.Id.insertBy item_id Bandcamp.Model.RequestingAssetUrl model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                    in
                        (mdl
                        , Cmd.none
                        )
                AssetUrlRetrieved item_id asset_url ->
                    let
                        -- we will update the download once
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads =
                            Bandcamp.Id.insertBy
                                item_id Bandcamp.Model.waitingDownload
                                model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                        cmd =
                            bandcamp_downloader_out_download_initiated
                                { item_id = Bandcamp.Id.toPort item_id
                                , asset_url = asset_url
                                }
                    in
                        (mdl , cmd)
                DownloadProgressed (item_id, pct) ->
                    let
                        dl = Bandcamp.Model.Downloading (Bandcamp.Model.InProgress pct)
                        -- we will update the download once
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads =
                            Bandcamp.Id.insertBy item_id dl model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                    in
                        (mdl , Cmd.none)
                DownloadCompleted item_id ->
                    ({ model | downloads = Bandcamp.Id.insertBy item_id Bandcamp.Model.Unzipping model.downloads}
                    , bandcamp_downloader_out_unzip_initiated
                                (Bandcamp.Id.toPort item_id)
                    )
                DownloadFailed item_id ->
                    ({ model | downloads = Bandcamp.Id.insertBy item_id Bandcamp.Model.Error model.downloads}
                    , Cmd.none
                    )

                FilesExtracted item_id ->
                    (model
                    , bandcamp_downloader_out_scan_started (Bandcamp.Id.toPort item_id)
                    )
                FilesScanned (item_id, files) ->
                    ({ model
                    | downloads = Bandcamp.Id.insertBy item_id (Bandcamp.Model.Completed files) model.downloads
                    }
                    , Cmd.none
                    )




viewDownloadButton : Bandcamp.Model.Downloads -> Bandcamp.Model.Library -> Bandcamp.Id.Id -> Element.Element Msg
viewDownloadButton downloads library item_id =
    let
        url =
            Bandcamp.Id.getBy item_id library.download_urls
    in
        case Bandcamp.Id.getBy item_id downloads of
            Nothing -> viewButton item_id
            Just progress ->
                Element.el
                    [Element.spacing 5]
                    (viewProgress progress item_id url)

viewProgress : Bandcamp.Model.Download -> Bandcamp.Id.Id -> Maybe String -> Element.Element Msg
viewProgress p item_id downloadUrl =
    case p of
            Bandcamp.Model.RequestingAssetUrl ->
                case downloadUrl of
                    Just url -> downloadService item_id url
                    Nothing -> Element.text "no download url found"
            Bandcamp.Model.Downloading Bandcamp.Model.Waiting -> Element.text <| "Starting Download"
            Bandcamp.Model.Downloading (Bandcamp.Model.InProgress pct) -> Element.text <| "Downloading " ++ (String.fromInt pct)
            Bandcamp.Model.Unzipping -> Element.text "Extracting"
            Bandcamp.Model.Scanning -> Element.text "Importing"
            Bandcamp.Model.Completed files ->
                Element.text <| "Downloaded " ++ String.fromInt (List.length files) ++ " files"
            Bandcamp.Model.Error -> Element.column [] [viewError, clearButton item_id]
            Bandcamp.Model.NotAsked -> viewButton item_id

downloadService : Bandcamp.Id.Id -> String -> Element.Element Msg
downloadService id url =
    let
        bareId = Bandcamp.Id.toPort id
    in
    Html.node
        "bandcamp-download"
        [ Html.Attributes.src url
        , Html.Attributes.id (String.fromInt bareId)
        , Html.Events.on "asseturlretrieve" (Decode.map (AssetUrlRetrieved id) <| Decode.at ["detail", "url"] Decode.string)
        , Html.Events.on "downloadcomplete" (Decode.succeed (DownloadCompleted id))
        ] []
    |> Element.html

viewButton : Bandcamp.Id.Id -> Element.Element Msg
viewButton item_id =
    Element.Input.button
        [Element.padding 10, Element.Border.rounded 5, Element.Background.color Color.playerGrey]
        { label = Element.text "Download"
        , onPress = Just <| DownloadButtonClicked item_id
        }
clearButton : Bandcamp.Id.Id -> Element.Element Msg
clearButton item_id =
    Element.Input.button
        [Element.padding 10, Element.Border.rounded 5, Element.Background.color Color.playerGrey]
        { label = Element.text "Clear"
        , onPress = Just <| ClearButtonClicked item_id
        }
viewError =
    Element.el
        [ Element.Background.color Color.red
        , Element.Font.color Color.white
        , Element.padding 5
        , Element.Border.rounded 5
        ] (Element.text "Problem")

