defmodule Credo.Check.Warning.DataloaderRunInOrderEngine do
  use Credo.Check,
    base_priority: :high,
    param_defaults: [
      file_patterns: [~r/order_engine/]
    ],
    explanations: [
      check: """
      Dataloader.run() should generally be executed during a load phase.

      When Dataloader.run() is called on-demand (outside a load phase) and the
      resulting dataloader instance is not stored back in the context, all entities
      loaded during that run are lost. The loaded data is stored in the dataloader
      instance itself.

      Instead of:

          def some_function(ctx) do
            result =
              ctx.dataloader
              |> Dataloader.load(:source, :key, arg)
              |> Dataloader.run()
              |> Dataloader.get(:source, :key, arg)

            # dataloader changes are lost!
            %{result: result}
          end

      Prefer:

          def some_function(ctx) do
            dataloader =
              ctx.dataloader
              |> Dataloader.load(:source, :key, arg)
              |> Dataloader.run()

            result = Dataloader.get(dataloader, :source, :key, arg)

            # return the updated dataloader in the context
            %{result: result, dataloader: dataloader}
          end

      If you have reviewed this usage and confirmed it is intentional, you can
      acknowledge it by adding a comment above the line:

          # credo:disable-for-next-line Credo.Check.Warning.DataloaderRunInOrderEngine

      """,
      params: [
        file_patterns: """
        List of regex patterns to match file paths where this check should apply.
        Defaults to files containing "order_engine" in their path.
        """
      ]
    ]

  @call_string "Dataloader.run"

  @doc false
  def run(%SourceFile{filename: filename} = source_file, params \\ []) do
    file_patterns = Params.get(params, :file_patterns, __MODULE__)

    if file_matches_patterns?(filename, file_patterns) do
      issue_meta = IssueMeta.for(source_file, params)
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp file_matches_patterns?(filename, patterns) do
    Enum.any?(patterns, fn pattern ->
      Regex.match?(pattern, filename)
    end)
  end

  # Match Dataloader.run/1 call: Dataloader.run(dataloader)
  defp traverse(
         {{:., _, [{:__aliases__, _, [:Dataloader]}, :run]}, meta, _arguments} = ast,
         issues,
         issue_meta
       ) do
    {ast, issues_for_call(meta, issues, issue_meta)}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issues_for_call(meta, issues, issue_meta) do
    [issue_for(issue_meta, meta[:line], @call_string) | issues]
  end

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message:
        "Dataloader.run() detected. Ensure the dataloader instance is stored back in the context, " <>
          "or acknowledge this usage with a credo:disable comment if intentional.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
