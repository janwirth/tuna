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
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Bandcamp.Model
import FileSystem
import Element.Border
import Bandcamp.Id


subscriptions : Bandcamp.Model.Downloads -> Sub Msg
subscriptions model =
    Sub.batch [
        bandcamp_downloader_in_formatter_url_retrieved
            ((Tuple.mapFirst Bandcamp.Id.fromPort) >> FormatterUrlRetrieved)
      , bandcamp_downloader_in_asset_url_retrieved
            ((Tuple.mapFirst Bandcamp.Id.fromPort) >> AssetUrlRetrieved)
      , bandcamp_downloader_in_download_progressed
            ((Tuple.mapFirst Bandcamp.Id.fromPort) >> DownloadProgressed)
      , bandcamp_downloader_in_download_completed
            (Bandcamp.Id.fromPort >> DownloadCompleted)
      , bandcamp_downloader_in_files_extracted
            (Bandcamp.Id.fromPort >> FilesExtracted)
      , bandcamp_downloader_in_files_scanned
            (Tuple.mapFirst Bandcamp.Id.fromPort >> FilesScanned)
    ]


-- out ports
port bandcamp_downloader_out_formatter_url_requested : {cookie: String, item_id: Int, download_page_url: String} -> Cmd msg
port bandcamp_downloader_out_asset_url_requested : {cookie: String, item_id: Int, formatter_url: String} -> Cmd msg
port bandcamp_downloader_out_download_initiated : {item_id: Int, asset_url: String} -> Cmd msg
port bandcamp_downloader_out_unzip_initiated : Int -> Cmd msg
port bandcamp_downloader_out_scan_started : Int -> Cmd msg

-- in ports
port bandcamp_downloader_in_formatter_url_retrieved
    : ((Bandcamp.Id.ForPort, String) -> msg)
    -> Sub msg

port bandcamp_downloader_in_asset_url_retrieved
    : ((Bandcamp.Id.ForPort, String) -> msg)
    -> Sub msg

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

type Msg =
    DownloadButtonClicked Bandcamp.Id.Id
  | ClearButtonClicked Bandcamp.Id.Id
  | FormatterUrlRetrieved (Bandcamp.Id.Id, String)
  | AssetUrlRetrieved (Bandcamp.Id.Id, String)
  | DownloadProgressed (Bandcamp.Id.Id, Bandcamp.Model.DownloadProgress)
  | DownloadCompleted Bandcamp.Id.Id
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
                        return =
                            model.library
                            |> RemoteData.toMaybe
                            |> Maybe.andThen (\{download_urls} -> Bandcamp.Id.getBy item_id download_urls)
                            |> Maybe.map startdownload
                            |> Maybe.withDefault (model, Cmd.none)
                        startdownload download_page_url =
                            let
                                downloadCmd =
                                    bandcamp_downloader_out_formatter_url_requested
                                        { cookie = cookie
                                        , item_id = Bandcamp.Id.toPort item_id
                                        , download_page_url = download_page_url
                                        }
                                mdl =
                                    { model
                                    | downloads = Bandcamp.Id.insertBy item_id Bandcamp.Model.initDownload model.downloads
                                    }
                            in
                                (mdl, downloadCmd)
                    in
                        return
                FormatterUrlRetrieved (item_id, formatter_url) ->
                    let
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads = Bandcamp.Id.insertBy item_id Bandcamp.Model.RequestingAssetUrl model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                        cmd =
                            bandcamp_downloader_out_asset_url_requested
                                { cookie = cookie
                                , item_id = Bandcamp.Id.toPort item_id
                                , formatter_url = formatter_url
                                }
                    in
                        (mdl
                        , cmd
                        )
                AssetUrlRetrieved (item_id, asset_url) ->
                    let
                        -- we will update the download once
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads =
                            Bandcamp.Id.insertBy item_id Bandcamp.Model.waitingDownload model.downloads
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




viewDownloadButton : Bandcamp.Model.Downloads -> Bandcamp.Id.Id -> Element.Element Msg
viewDownloadButton downloads item_id =
    let
        viewButton =
            Element.Input.button
                [Element.padding 10, Element.Border.rounded 5, Element.Background.color Color.playerGrey]
                { label = Element.text "Download"
                , onPress = Just <| DownloadButtonClicked item_id
                }
        clearButton =
            Element.Input.button
                [Element.padding 10, Element.Border.rounded 5, Element.Background.color Color.playerGrey]
                { label = Element.text "Clear"
                , onPress = Just <| ClearButtonClicked item_id
                }
    in
        case Bandcamp.Id.getBy item_id downloads of
            Nothing -> viewButton
            Just progress -> Element.column [Element.spacing 5] [clearButton, viewProgress progress]

viewProgress : Bandcamp.Model.Download -> Element.Element msg
viewProgress p =
    case p of
            Bandcamp.Model.RequestingFormatUrl -> Element.text "1/5 - Probing"
            Bandcamp.Model.RequestingAssetUrl -> Element.text "2/5 - Formatting"
            Bandcamp.Model.Downloading Bandcamp.Model.Waiting -> Element.text <| "3/5 - Downloading..."
            Bandcamp.Model.Downloading (Bandcamp.Model.InProgress pct) -> Element.text <| "3/5 - Downloading " ++ (String.fromInt pct)
            Bandcamp.Model.Unzipping -> Element.text "4/5 - Extracting"
            Bandcamp.Model.Scanning -> Element.text "5/5 - Scanning"
            Bandcamp.Model.Completed files ->
                Element.text <| "Downloaded " ++ String.fromInt (List.length files) ++ " files"
            Bandcamp.Model.Error -> Element.text "Problem"

