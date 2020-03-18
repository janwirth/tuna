module Device exposing (init, viewDevices, Devices, decodeDevices, encodeDevices)

import Json.Decode as Decode
import Json.Encode as Encode
import Element

viewDevices : List String -> Devices -> Element.Element Msg
viewDevices quickTags devices = Element.text "hi"
init = []

type Msg =
    Connect
    | Disconnect
    | SyncProcess
    | SyncStart
    | SyncComplet

-- [generator-start]
type alias Devices = List Device
type Status = Disconnected | NotSynced | Syncing | Synced

type alias Device =
    { name: String
    , tagsToSync: List String
    , status : Status
    }


-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeDevice =
   Decode.map3
      Device
         ( Decode.field "name" Decode.string )
         ( Decode.field "tagsToSync" (Decode.list Decode.string) )
         ( Decode.field "status" decodeStatus )

decodeDevices =
   Decode.list decodeDevice

decodeStatus =
   let
      recover x =
         case x of
            "Disconnected"->
               Decode.succeed Disconnected
            "NotSynced"->
               Decode.succeed NotSynced
            "Syncing"->
               Decode.succeed Syncing
            "Synced"->
               Decode.succeed Synced
            other->
               Decode.fail <| "Unknown constructor for type Status: " ++ other
   in
      Decode.string |> Decode.andThen recover

encodeDevice a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("tagsToSync", (Encode.list Encode.string) a.tagsToSync)
      , ("status", encodeStatus a.status)
      ]

encodeDevices a =
   (Encode.list encodeDevice) a

encodeStatus a =
   case a of
      Disconnected ->
         Encode.string "Disconnected"
      NotSynced ->
         Encode.string "NotSynced"
      Syncing ->
         Encode.string "Syncing"
      Synced ->
         Encode.string "Synced" 
-- [generator-end]
