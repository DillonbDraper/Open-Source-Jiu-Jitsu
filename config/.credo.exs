%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["{lib,priv,test,config}/**/*.ex{,s}"],
        excluded: [".iex.exs", "config/runtime.exs", "priv/repo/old_migrations/"]
      },
      checks: [
        {Credo.Check.Design.AliasUsage, if_nested_deeper_than: 2, if_called_more_often_than: 1},
        {Credo.Check.Refactor.CyclomaticComplexity,
         max_complexity: 25, files: %{excluded: ["**/local_data/"]}},
        # make consistent with formatter only applying on 6+ digits
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 99999},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Refactor.LongQuoteBlocks, false},
        {Credo.Check.Refactor.Nesting, max_nesting: 4}
      ]
    }
  ]
}
