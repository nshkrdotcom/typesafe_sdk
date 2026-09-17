defmodule TypeSafeSDK.PreparedV030Test do
  use ExUnit.Case, async: true

  alias TypeSafeSDK.{Error, Prepared}

  defp q(label), do: TypeSafeSDK.noul(label)

  test "composition preserves deterministic execution order and caller keys" do
    prepared = TypeSafeSDK.prepare!(alpha: q("A?"), beta: q("B?"))
    assert Prepared.keys(prepared) == [:alpha, :beta]

    assert {:ok, replaced} = Prepared.put(prepared, :alpha, q("A2?"))
    assert Prepared.keys(replaced) == [:alpha, :beta]

    assert {:ok, appended} = Prepared.put(replaced, :gamma, q("G?"))
    assert Prepared.keys(appended) == [:alpha, :beta, :gamma]

    assert {:ok, deleted} = Prepared.delete(appended, :beta)
    assert Prepared.keys(deleted) == [:alpha, :gamma]

    assert {:ok, taken} = Prepared.take(appended, [:gamma, :alpha])
    assert Prepared.keys(taken) == [:alpha, :gamma]
  end

  test "merge is right-biased without moving duplicate left positions" do
    left = TypeSafeSDK.prepare!(a: q("left a"), b: q("left b"))
    right = TypeSafeSDK.prepare!(b: q("right b"), c: q("right c"))

    assert {:ok, merged} = Prepared.merge(left, right)
    assert Prepared.keys(merged) == [:a, :b, :c]
    assert merged.json =~ "right b"
    refute merged.json =~ "left b"
  end

  test "fingerprint is versioned, stable, semantic, and recomputed by composition" do
    one = TypeSafeSDK.prepare!(q: TypeSafeSDK.choice("Pick", [a: "A", b: "B"]))
    two = TypeSafeSDK.prepare!(q: TypeSafeSDK.choice("Pick", [a: "A", b: "B"]))
    reversed = TypeSafeSDK.prepare!(q: TypeSafeSDK.choice("Pick", [b: "B", a: "A"]))

    assert "typesafe-prepared-v1:" <> digest = Prepared.fingerprint(one)
    assert byte_size(digest) == 64
    assert Prepared.fingerprint(one) == Prepared.fingerprint(two)
    refute Prepared.fingerprint(one) == Prepared.fingerprint(reversed)

    assert {:ok, changed} = Prepared.put(one, :other, q("Other?"))
    refute Prepared.fingerprint(changed) == Prepared.fingerprint(one)
  end

  test "fingerprint has a stable golden vector" do
    prepared = TypeSafeSDK.prepare!(q: TypeSafeSDK.noul("Q?"))

    assert Prepared.fingerprint(prepared) ==
             "typesafe-prepared-v1:9b4d5f23c1b270c1e5c7b126f7dd0efe7f12a47f228b0aabfb5d4fa754f9d7ae"
  end

  test "composition re-runs semantic validation" do
    prepared = TypeSafeSDK.prepare!(q: q("Q?"))

    assert {:error, %TypeSafeSDK.Error{type: :invalid_request}} =
             Prepared.put(prepared, :bad, %{type: "choice", criteria: [only: nil]})
  end

  test "map-valued extras fingerprint independently of map iteration order" do
    q1 = TypeSafeSDK.Question.Noul.new!("Q?", extra: %{"z" => 1, "a" => %{"y" => 2, "x" => 1}})
    q2 = TypeSafeSDK.Question.Noul.new!("Q?", extra: %{"a" => %{"x" => 1, "y" => 2}, "z" => 1})
    assert Prepared.fingerprint(TypeSafeSDK.prepare!(q: q1)) == Prepared.fingerprint(TypeSafeSDK.prepare!(q: q2))
  end

  test "composition rejects invalid caller keys through the normal error surface" do
    prepared = Prepared.new!([a: TypeSafeSDK.noul("A?")])

    assert {:error, %Error{type: :invalid_request}} =
             Prepared.put(prepared, 123, TypeSafeSDK.noul("B?"))

    assert {:error, %Error{type: :invalid_request}} = Prepared.delete(prepared, 123)
    assert {:error, %Error{type: :invalid_request}} = Prepared.take(prepared, [123])
  end
end
