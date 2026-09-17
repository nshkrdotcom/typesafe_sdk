defmodule TypeSafeSDK.SemanticDoctestTest do
  use ExUnit.Case, async: true
  doctest TypeSafeSDK.Question.Noul
  doctest TypeSafeSDK.Question.Choice
  doctest TypeSafeSDK.Question.Score
end
