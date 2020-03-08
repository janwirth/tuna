module Queue exposing (new)

import Model
import List.Extra
import List.Zipper
import Dict
import Track

type alias Queue = List.Zipper.Zipper Track.Id

new : Track.Id -> Model.Model -> Maybe Queue
new track_id model =
    Track.tracksToList model.tracks
        |> List.map Track.getId
        -- keep tracks after the selected one, drop tracks before
        |> List.Extra.dropWhile ((/=) track_id)
        |> List.Zipper.fromList
