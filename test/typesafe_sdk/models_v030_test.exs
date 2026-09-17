defmodule TypeSafeSDK.ModelsV030Test do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Error, ModelMetadata, Models}

  defp model(name, date), do: %ModelMetadata{name: name, description: name, release_date: date}

  test "find is exact and ambiguity is explicit" do
    models = [model("alpha", "2026-01-01"), model("beta", "2026-02-01")]
    assert {:ok, %{name: "beta"}} = Models.find(models, "beta")
    assert {:error, %Error{type: :model_not_found}} = Models.find(models, "bet")
    assert_raise Error, fn -> Models.find!(models, "bet") end

    assert {:error, %Error{type: :ambiguous_model}} =
             Models.find([model("dup", "2026-01-01"), model("dup", "2026-02-01")], "dup")
  end

  test "latest uses release_date and supports exact structured selectors" do
    models = [model("old", "2026-01-01"), model("new", "2026-09-01")]
    assert {:ok, %{name: "new"}} = Models.latest(models, :all)
    assert {:ok, %{name: "old"}} = Models.latest(models, name: "old")
  end

  test "latest fails rather than guessing when objective ordering is invalid" do
    assert {:error, %Error{type: :unordered_model_catalog}} =
             Models.latest([model("a", "unknown"), model("b", "also-unknown")], :all)
  end

  test "latest treats missing release dates as unordered instead of raising" do
    broken = %ModelMetadata{name: "broken", description: "broken", release_date: nil}

    assert {:error, %Error{type: :unordered_model_catalog}} = Models.latest([broken], :all)
  end
end
