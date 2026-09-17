defmodule Mix.Tasks.Typesafe.Ir do
  use Mix.Task
  @moduledoc false
  @shortdoc "Prints the compiled TypeSafeSDK ProviderIR"
  @impl true
  def run(args), do: Mix.Task.run("pristine.codegen.ir", ["TypeSafeSDK.Codegen.Provider" | args])
end
