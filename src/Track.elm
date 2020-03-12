module Track exposing (..)
{-| A module for keeping all the data around a track and operating on it
Note that a track may either come from bandamp or a local file
-}
import Prng.Uuid
import Random.Pcg.Extended
import Json.Encode as Encode
import Json.Decode as Decode
import FileSystem
import Bandcamp.Model
import Dict
import Bandcamp.Id

type alias Id = Int
initTracks = []

addBandcamp
     : (Bandcamp.Id.Id, List FileSystem.FileRef)
    -> Tracks
    -> Tracks
addBandcamp (purchase_id, newPurchases) tracks =
    tracks ++ (List.indexedMap (refineBandcampPurchase purchase_id) newPurchases)

refineBandcampPurchase : Bandcamp.Id.Id -> Int -> FileSystem.FileRef -> Track
refineBandcampPurchase purchase_id trackNumber file_ref =
    {source = BandcampPurchase purchase_id trackNumber
    , title = file_ref.name
    , artist = ""
    , tags = ""
    , album = ""
    , albumArtist = ""
    }

addLocal : List FileSystem.ReadResult -> Tracks -> Tracks
addLocal readResult tracks =
        tracks ++ (List.map refineLocalImport readResult)

refineLocalImport : FileSystem.ReadResult -> Track
refineLocalImport result =
    { title = result.name
    , artist = result.artist
    , source= LocalFile {name = result.name, path = result.path}
    , tags = ""
    , album = result.album
    , albumArtist = result.albumartist
    }


-- [generator-start]

type alias Tracks = List Track
type alias Track =
    { title : String
    , artist: String
    , album: String
    , albumArtist : String
    , source: TrackSource
    , tags: String
    }

type TrackSource =
    LocalFile FileSystem.FileRef
  | BandcampPurchase Bandcamp.Id.Id Int

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeTrack =
   Decode.map6
      Track
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "album" Decode.string )
         ( Decode.field "albumArtist" Decode.string )
         ( Decode.field "source" decodeTrackSource )
         ( Decode.field "tags" Decode.string )

decodeTrackSource =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeTrackSourceHelp

decodeTrackSourceHelp constructor =
   case constructor of
      "LocalFile" ->
         Decode.map
            LocalFile
               ( Decode.field "A1" FileSystem.decodeFileRef )
      "BandcampPurchase" ->
         Decode.map2
            BandcampPurchase
               ( Decode.field "A1" Bandcamp.Id.decodeId )
               ( Decode.field "A2" Decode.int )
      other->
         Decode.fail <| "Unknown constructor for type TrackSource: " ++ other

decodeTracks =
   Decode.list decodeTrack

encodeTrack a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("album", Encode.string a.album)
      , ("albumArtist", Encode.string a.albumArtist)
      , ("source", encodeTrackSource a.source)
      , ("tags", Encode.string a.tags)
      ]

encodeTrackSource a =
   case a of
      LocalFile a1->
         Encode.object
            [ ("Constructor", Encode.string "LocalFile")
            , ("A1", FileSystem.encodeFileRef a1)
            ]
      BandcampPurchase a1 a2->
         Encode.object
            [ ("Constructor", Encode.string "BandcampPurchase")
            , ("A1", Bandcamp.Id.encodeId a1)
            , ("A2", Encode.int a2)
            ]

encodeTracks a =
   (Encode.list encodeTrack) a 
-- [generator-end]
