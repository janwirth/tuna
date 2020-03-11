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

getById : Id -> Tracks -> Maybe Track
getById (Id id) (Tracks t) =
    Dict.get (Prng.Uuid.toString id) t
    |> Maybe.map (Tuple.pair (Id id) >> Track)

noTracks : Tracks -> Bool
noTracks (Tracks t) =
    Dict.isEmpty t

addBandcamp
    : Random.Pcg.Extended.Seed
    -> (Bandcamp.Id.Id, List FileSystem.FileRef)
    -> Tracks
    -> (Tracks, Random.Pcg.Extended.Seed)
addBandcamp seed (purchase_id, file_refs) (Tracks tracks)=
    let
        refToPurchase : Int -> FileSystem.FileRef -> TrackData
        refToPurchase trackNumber file_ref =
            {source = BandcampPurchase purchase_id trackNumber
            , title = file_ref.name
            , artist = ""
            , tags = ""
            }
        (newBandcampTracks, newSeed) =
            file_refs
            |> List.indexedMap refToPurchase
            |> addUuidString seed
        newTracks : Tracks
        newTracks =
            newBandcampTracks
            |> Dict.fromList
            |> Dict.union tracks
            |> Tracks
    in
        (newTracks, newSeed)

addLocal : Random.Pcg.Extended.Seed -> List FileSystem.FileRef -> Tracks -> (Tracks, Random.Pcg.Extended.Seed)
addLocal seed fileRefs tracks =
    let
        existingLocalPaths : List String
        existingLocalPaths = locals tracks
            |> List.map (Tuple.second >> .path)
        (withoutDupes, newSeed) =
            fileRefs
            |> List.filter (\{path} -> not <| List.member path existingLocalPaths)
            |> addUuidString seed

        dataFromRef : FileSystem.FileRef -> TrackData
        dataFromRef ref = {title = ref.name, artist = "", source= LocalFile ref, tags = ""}
        unpacked_new_tracks : Dict.Dict String TrackData
        unpacked_new_tracks =
            withoutDupes
            |> List.map (Tuple.mapSecond dataFromRef)
            |> Dict.fromList
        (Tracks unpacked_tracks) = tracks
        newTracks =
            Dict.union unpacked_new_tracks unpacked_tracks
            |> Tracks
    in
        (newTracks, newSeed)

addUuidString : Random.Pcg.Extended.Seed -> List a -> (List (String, a), Random.Pcg.Extended.Seed)
addUuidString seed list =
    let
        init_accum = ([], seed)
        reducer : a -> (List (String, a), Random.Pcg.Extended.Seed) -> (List (String, a), Random.Pcg.Extended.Seed)
        reducer item (items, seed_) =
            let
                ( newUuid, newSeed ) =
                        Random.Pcg.Extended.step Prng.Uuid.stringGenerator seed_
            in
                ((newUuid, item) :: items, newSeed)
    in
        List.foldl reducer init_accum list


locals : Tracks -> List (Id, FileSystem.FileRef)
locals tracks =
    tracksToList tracks
    |> List.filterMap (\(Track (id, data)) -> case data.source of
        LocalFile ref -> Just (id, ref)
        _ -> Nothing
    )

initTracks = Tracks Dict.empty

tracksToList : Tracks -> List Track
tracksToList (Tracks tr) =
    Dict.toList tr
    |> List.filterMap (\(id, t) -> case Prng.Uuid.fromString id of
        Just i -> Just (Track (Id i, t))
        Nothing -> Nothing
        )

type alias Meta = ()

source : Track -> TrackSource
source (Track (_, data)) = data.source

getId (Track (id, data)) = id

-- [generator-start]
type Track =
    Track TrackWithId

type alias TrackWithId = (Id, TrackData)

type Tracks = Tracks (Dict.Dict String TrackData)
type alias TrackData = {title : String, artist: String, source: TrackSource, tags: String}

type TrackSource =
    LocalFile FileSystem.FileRef
  | BandcampPurchase Bandcamp.Id.Id Int

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeDictStringTrackData =
   let
      decodeDictStringTrackDataTuple =
         Decode.map2
            (\a1 a2 -> (a1, a2))
               ( Decode.field "A1" Decode.string )
               ( Decode.field "A2" decodeTrackData )
   in
      Decode.map Dict.fromList (Decode.list decodeDictStringTrackDataTuple)

decodeTrack =
   Decode.map Track decodeTrackWithId

decodeTrackData =
   Decode.map4
      TrackData
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
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

decodeTrackWithId =
   Decode.map2
      (\a1 a2 -> (a1, a2))
         ( Decode.field "A1" decodeId )
         ( Decode.field "A2" decodeTrackData )

decodeTracks =
   Decode.map Tracks decodeDictStringTrackData

encodeDictStringTrackData a =
   let
      encodeDictStringTrackDataTuple (a1,a2) =
         Encode.object
            [ ("A1", Encode.string a1)
            , ("A2", encodeTrackData a2) ]
   in
      (Encode.list encodeDictStringTrackDataTuple) (Dict.toList a)

encodeTrack (Track a1) =
   encodeTrackWithId a1

encodeTrackData a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
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

encodeTrackWithId (a1, a2) =
   Encode.object
      [ ("A1", encodeId a1)
      , ("A2", encodeTrackData a2)
      ]

encodeTracks (Tracks a1) =
   encodeDictStringTrackData a1 
-- [generator-end]
{-| A hash of initial metadata -}
type Id = Id Prng.Uuid.Uuid

encodeId : Id -> Encode.Value
encodeId (Id uuid) = Prng.Uuid.toString uuid |> Encode.string

decodeId : Decode.Decoder Id
decodeId = Decode.string
    |> Decode.andThen (\uuid -> case Prng.Uuid.fromString uuid of
        Just u -> Decode.succeed (Id u)
        Nothing -> Decode.fail "could not parse uuid"
        )







