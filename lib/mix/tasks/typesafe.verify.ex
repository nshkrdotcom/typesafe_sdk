defmodule Mix.Tasks.Typesafe.Verify do
  use Mix.Task
  @moduledoc false
  @shortdoc "Verifies committed TypeSafeSDK generated artifacts"
  @impl true
  def run(args),
    do: Mix.Task.run("pristine.codegen.verify", ["TypeSafeSDK.Codegen.Provider" | args])
end
