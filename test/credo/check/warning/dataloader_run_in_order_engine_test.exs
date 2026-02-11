defmodule Credo.Check.Warning.DataloaderRunInOrderEngineTest do
  use Credo.Test.Case

  @described_check Credo.Check.Warning.DataloaderRunInOrderEngine

  #
  # cases NOT raising issues
  #

  test "it should NOT report when file path doesn't match patterns" do
    """
    defmodule CredoSampleModule do
      def some_function(ctx) do
        ctx.dataloader
        |> Dataloader.load(:source, :key, arg)
        |> Dataloader.run()
        |> Dataloader.get(:source, :key, arg)
      end
    end
    """
    |> to_source_file("lib/some_other_module.ex")
    |> run_check(@described_check)
    |> refute_issues()
  end

  test "it should NOT report for non-Dataloader modules with run function" do
    """
    defmodule CredoSampleModule do
      def some_function(ctx) do
        SomeOtherModule.run(ctx)
      end
    end
    """
    |> to_source_file("lib/order_engine/commands/some_command.ex")
    |> run_check(@described_check)
    |> refute_issues()
  end

  test "it should NOT report when no Dataloader.run calls exist" do
    """
    defmodule CredoSampleModule do
      def some_function(ctx) do
        Dataloader.load(ctx.dataloader, :source, :key, arg)
        |> Dataloader.get(:source, :key, arg)
      end
    end
    """
    |> to_source_file("lib/order_engine/commands/some_command.ex")
    |> run_check(@described_check)
    |> refute_issues()
  end

  #
  # cases raising issues
  #

  test "it should report a violation when Dataloader.run() is used in order_engine" do
    """
    defmodule CredoSampleModule do
      def some_function(ctx) do
        ctx.dataloader
        |> Dataloader.load(:source, :key, arg)
        |> Dataloader.run()
        |> Dataloader.get(:source, :key, arg)
      end
    end
    """
    |> to_source_file("lib/order_engine/commands/some_command.ex")
    |> run_check(@described_check)
    |> assert_issue()
  end

  test "it should report a violation with aliased Dataloader" do
    """
    defmodule CredoSampleModule do
      alias Dataloader

      def some_function(ctx) do
        Dataloader.run(ctx.dataloader)
      end
    end
    """
    |> to_source_file("lib/checkout/order_engine/helper.ex")
    |> run_check(@described_check)
    |> assert_issue()
  end

  test "it should report a violation in nested order_engine path" do
    """
    defmodule CredoSampleModule do
      def tax_helper(ctx) do
        result =
          ctx.dataloader
          |> Dataloader.load(:billing, :tax_rates, params)
          |> Dataloader.run()
          |> Dataloader.get(:billing, :tax_rates, params)

        %{tax_rate: result}
      end
    end
    """
    |> to_source_file("lib/checkout/order_engine/commands/add_offer_item/tax_rate_helper.ex")
    |> run_check(@described_check)
    |> assert_issue()
  end

  test "it should report multiple violations" do
    """
    defmodule CredoSampleModule do
      def function_one(ctx) do
        Dataloader.run(ctx.dataloader)
      end

      def function_two(ctx) do
        ctx.dataloader
        |> Dataloader.run()
      end
    end
    """
    |> to_source_file("lib/order_engine/module.ex")
    |> run_check(@described_check)
    |> assert_issues(fn issues -> length(issues) == 2 end)
  end

  #
  # custom file patterns
  #

  test "it should respect custom file_patterns parameter" do
    """
    defmodule CredoSampleModule do
      def some_function(ctx) do
        Dataloader.run(ctx.dataloader)
      end
    end
    """
    |> to_source_file("lib/custom_engine/processor.ex")
    |> run_check(@described_check, file_patterns: [~r/custom_engine/])
    |> assert_issue()
  end

  test "it should match multiple file patterns" do
    """
    defmodule CredoSampleModule do
      def some_function(ctx) do
        Dataloader.run(ctx.dataloader)
      end
    end
    """
    |> to_source_file("lib/billing_engine/processor.ex")
    |> run_check(@described_check, file_patterns: [~r/order_engine/, ~r/billing_engine/])
    |> assert_issue()
  end
end
