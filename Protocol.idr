module Protocol
import Data.List

%access public export
%default total

-- A discrete set of alternatives.
data Choice : List a -> Type
where Choose : (alternative : a) ->
               {alternatives : List a} ->
               {auto membership : Elem alternative alternatives} ->
               Choice alternatives

-- A path between a source and a destination state.
Path : Type
Path = (String, String)

-- A named path.
Transition : Type
Transition = (String, Path)

-- Use a membership proof to reliably find a tuple in a list.
locate : (key : a) -> (entries : List (a, b)) -> {auto membership : Elem key (map Prelude.Basics.fst entries)} -> b
locate _ [] {membership} = absurd membership
locate key ((key, value) :: _) {membership = Here} = value
locate key (_ :: entries) {membership = (There later)} = locate key entries {membership = later}

-- Use the allowed transitions to define a finite state machine type.
data Command : Type -> Type -> Path -> Type
where
  Action  : (name : String) ->
            {transitions : List Transition} ->
            {auto membership : Elem name (map Prelude.Basics.fst transitions)} ->
            Command () (Choice transitions) (locate name transitions)

  (>>=)   : Command a transition (beginning, middle) ->
            (a -> Command b transition (middle, end)) ->
            Command b transition (beginning, end)

-- Encode a list of transitions into a session type.
encode : List Transition -> Path -> Type
encode transitions = Command () (Choice transitions)

-- Read a list of transitions from a file.
readTransitions : String -> IO (Either FileError (List Transition))
readTransitions filename =
  do result <- readFile filename
     pure $ map (pair . words) result
  where pair : List String -> List Transition
        pair (name::source::destination::rest) = (name, (source, destination))::(pair rest)
        pair _ = []

-- A type provider providing a list of steps.
Protocol : String -> IO (Provider (Path -> Type))
Protocol filename =
  do result <- readTransitions filename
     pure $
       case result of
         Left error => Error $ "Unable to read transitions file: " ++ filename
         Right transitions => Provide $ encode transitions
