%{
  configs: [
    %{
      name: "default",
      files: %{included: ["lib/", "codegen/", "test/"]},
      strict: true,
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 110}
      ]
    }
  ]
}
