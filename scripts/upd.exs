#!/usr/bin/env -S mise x erlang elixir -- elixir

defmodule Upd do
  # ── TOML Parser (handles our dotfiles.toml subset) ────

  defmodule TOML do
    def parse_file(path) do
      path |> File.read!() |> parse()
    end

    def parse(content) do
      content
      |> String.split("\n")
      |> Enum.reduce({%{}, nil}, fn line, {acc, table_path} ->
        line = String.trim(line)

        cond do
          line == "" or String.starts_with?(line, "#") ->
            {acc, table_path}

          match?("[[" <> _, line) ->
            path = line |> String.slice(2..-3//1) |> String.trim() |> String.split(".")
            {append_table(acc, path), path}

          String.contains?(line, "=") ->
            case String.split(line, "=", parts: 2) do
              [key, value] ->
                key = String.trim(key)
                value = String.trim(value) |> parse_value()
                {set_value(acc, table_path, key, value), table_path}

              _ ->
                {acc, table_path}
            end

          true ->
            {acc, table_path}
        end
      end)
      |> elem(0)
    end

    defp parse_value("\"" <> _ = v), do: String.slice(v, 1..-2//1)

    defp parse_value("[" <> _ = v) do
      ~r/"([^"]*)"/ |> Regex.scan(v) |> Enum.map(&Enum.at(&1, 1))
    end

    defp parse_value(v), do: v

    defp append_table(map, [key]), do: Map.update(map, key, [%{}], &(&1 ++ [%{}]))

    defp append_table(map, [key | rest]) do
      sub = Map.get(map, key, %{})
      Map.put(map, key, append_table(sub, rest))
    end

    defp set_value(map, nil, _k, _v), do: map

    defp set_value(map, [key], k, v) do
      Map.update!(map, key, fn list ->
        List.update_at(list, -1, &Map.put(&1, k, v))
      end)
    end

    defp set_value(map, [key | rest], k, v) do
      Map.update!(map, key, &set_value(&1, rest, k, v))
    end

    def deep_merge(a, b) do
      Map.merge(a, b, fn
        _, v1, v2 when is_list(v1) and is_list(v2) -> v1 ++ v2
        _, v1, v2 when is_map(v1) and is_map(v2) -> deep_merge(v1, v2)
        _, _, v2 -> v2
      end)
    end
  end

  # ── Helpers ───────────────────────────────────────────

  defp home, do: System.user_home!()
  defp dotfiles, do: Path.join(home(), ".dotfiles")
  defp has?(cmd), do: System.find_executable(cmd) != nil
  defp macos?, do: :os.type() == {:unix, :darwin}

  defp green(t), do: IO.ANSI.green() <> to_string(t) <> IO.ANSI.reset()
  defp red(t), do: IO.ANSI.red() <> to_string(t) <> IO.ANSI.reset()
  defp yellow(t), do: IO.ANSI.yellow() <> to_string(t) <> IO.ANSI.reset()
  defp cyan(t), do: IO.ANSI.cyan() <> to_string(t) <> IO.ANSI.reset()
  defp magenta(t), do: IO.ANSI.magenta() <> to_string(t) <> IO.ANSI.reset()
  defp blue(t), do: IO.ANSI.blue() <> to_string(t) <> IO.ANSI.reset()
  defp bold(t), do: IO.ANSI.bright() <> to_string(t) <> IO.ANSI.reset()

  defp cmd(name, executable, args, opts \\ []) do
    case System.cmd(executable, args, [stderr_to_stdout: true] ++ opts) do
      {_, 0} ->
        :ok

      {out, _} ->
        first_line = out |> String.trim() |> String.split("\n") |> hd()
        {:error, "#{name}: #{first_line}"}
    end
  end

  defp load_config do
    base = TOML.parse_file(Path.join(dotfiles(), "dotfiles.toml"))
    local_path = Path.join(dotfiles(), "dotfiles.local.toml")

    if File.exists?(local_path),
      do: TOML.deep_merge(base, TOML.parse_file(local_path)),
      else: base
  end

  # ── Entry Point ───────────────────────────────────────

  def main(["completion", "zsh"]), do: IO.puts(zsh_completion())
  def main(["completion", _]), do: IO.puts(:stderr, "only zsh supported")
  def main(argv), do: run("--verbose" in argv)

  defp run(_verbose) do
    config = load_config()

    IO.puts("\n#{bold("/// .SYSTEM UPDATE")}\n")

    # Link dotfiles via mise task
    case System.cmd("mise", ["run", "link"], cd: dotfiles(), stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> IO.puts("#{red("✗")} mise run link failed") && System.halt(1)
    end

    # Auth status (macOS)
    auth = if macos?(), do: check_auth_status(), else: %{}

    # Fonts (macOS)
    if macos?(), do: install_fonts(config)

    # Sudo
    has_sudo = acquire_sudo()
    keepalive = if has_sudo, do: spawn(fn -> sudo_keepalive_loop() end)

    # Brew bundle — interactive, runs before parallel tasks
    if has?("brew") do
      IO.puts(blue("/// .BREW BUNDLE (may prompt for sudo)"))

      case System.cmd("brew", ["bundle", "--quiet"], cd: home(), stderr_to_stdout: true) do
        {_, 0} -> IO.puts("#{green("✓")} brew bundle complete")
        _ -> IO.puts("#{red("✗")} brew bundle failed (continuing)")
      end

      IO.puts("")
    end

    # Parallel update tasks
    results =
      build_tasks()
      |> Enum.map(fn {name, fun} -> Task.async(fn -> {name, fun.()} end) end)
      |> Task.await_many(:infinity)

    if keepalive, do: Process.exit(keepalive, :kill)

    any_failed = Enum.any?(results, fn {_, r} -> r != :ok end)

    for {name, result} <- results do
      case result do
        :ok -> IO.puts("  #{green("✓")} #{name}")
        {:error, msg} -> IO.puts("  #{red("✗")} #{msg}")
      end
    end

    # Completions
    IO.puts("\n#{bold("/// .REGENERATING ZSH COMPLETIONS")}\n")
    regen_completions(config)

    # Status
    IO.puts("\n#{bold("/// .STATUS")}\n")
    manual_steps = build_manual_steps(auth)

    if manual_steps == [] do
      IO.puts("  #{green("✓")} all good")
    else
      IO.puts("  #{yellow("→")} remaining manual steps:")
      for step <- manual_steps, do: IO.puts("    · #{step}")
    end

    IO.puts("")

    if any_failed,
      do: IO.puts(yellow(bold("/// .SYSTEM UPDATE COMPLETE (with errors)"))),
      else: IO.puts(bold("/// .SYSTEM UPDATE COMPLETE"))

    IO.puts("")
  end

  # ── Auth Check ────────────────────────────────────────

  defp check_auth_status do
    IO.puts(bold("/// .AUTH STATUS"))

    gh_ok =
      has?("gh") and
        match?({_, 0}, System.cmd("gh", ["auth", "status"], stderr_to_stdout: true))

    if has?("gh") do
      if gh_ok,
        do: IO.puts("  #{green("✓")} gh"),
        else: IO.puts("  #{yellow("!")} gh not authenticated\n     run: #{cyan("gh auth login")}")
    end

    op_ok =
      has?("op") and
        match?({_, 0}, System.cmd("op", ["account", "list"], stderr_to_stdout: true))

    if has?("op") do
      if op_ok do
        IO.puts("  #{green("✓")} 1password cli")
      else
        IO.puts("  #{yellow("!")} 1password cli not integrated")
        IO.puts("     1. open 1Password -> Settings -> Developer -> CLI Integration")
        IO.puts("     2. run: #{cyan("op plugin init")}")
      end
    end

    IO.puts("")
    %{gh_ok: gh_ok, op_ok: op_ok}
  end

  # ── Sudo ──────────────────────────────────────────────

  defp acquire_sudo do
    needs = has?("apt-get") or has?("dnf") or (macos?() and has?("brew"))

    if needs do
      case System.cmd("sudo", ["-v"], stderr_to_stdout: true) do
        {_, 0} ->
          true

        _ ->
          if has?("apt-get") or has?("dnf") do
            IO.puts("#{red("✗")} Failed to get sudo authentication")
            System.halt(1)
          end

          IO.puts("  #{yellow("!")} sudo auth failed, brew bundle/casks may be skipped")
          false
      end
    else
      false
    end
  end

  defp sudo_keepalive_loop do
    Process.sleep(60_000)
    System.cmd("sudo", ["-v"], stderr_to_stdout: true)
    sudo_keepalive_loop()
  end

  # ── Parallel Tasks ────────────────────────────────────

  defp build_tasks do
    []
    |> maybe_task(has?("apt-get"), "apt", fn ->
      with :ok <- cmd("apt:update", "sudo", ["apt-get", "update"]),
           :ok <- cmd("apt:upgrade", "sudo", ["apt-get", "upgrade", "-y"]) do
        cmd("apt:autoremove", "sudo", ["apt-get", "autoremove", "-y"])
      end
    end)
    |> maybe_task(has?("dnf"), "dnf", fn ->
      cmd("dnf:update", "sudo", ["dnf", "update", "-y"])
    end)
    |> maybe_task(has?("mise"), "mise", fn ->
      with :ok <- cmd("mise:up", "mise", ["up"], cd: home()) do
        cmd("mise:reshim", "mise", ["reshim"], cd: home())
      end
    end)
    |> maybe_task(has?("claude"), "claude", fn ->
      cmd("claude:update", "claude", ["--update"])
    end)
    |> add_tmux_task()
    |> maybe_task(has?("brew"), "brew", fn ->
      with :ok <- cmd("brew:update", "brew", ["update", "--quiet"]),
           :ok <- cmd("brew:upgrade", "brew", ["upgrade", "--greedy", "--quiet"]) do
        cmd("brew:cleanup", "brew", ["cleanup", "--quiet"])
      end
    end)
  end

  defp maybe_task(tasks, true, name, fun), do: tasks ++ [{name, fun}]
  defp maybe_task(tasks, false, _name, _fun), do: tasks

  defp add_tmux_task(tasks) do
    plugins = [
      {"tmux-resurrect", "https://github.com/tmux-plugins/tmux-resurrect.git"},
      {"tmux-fzf-url", "https://github.com/wfxr/tmux-fzf-url.git"}
    ]

    tasks ++
      [
        {"tmux-plugins",
         fn ->
           plugins_dir = Path.join([home(), ".tmux", "plugins"])
           File.mkdir_p!(plugins_dir)

           Enum.reduce_while(plugins, :ok, fn {name, url}, :ok ->
             dest = Path.join(plugins_dir, name)

             result =
               if File.exists?(dest),
                 do: cmd("tmux:#{name}:pull", "git", ["pull", "--quiet"], cd: dest),
                 else: cmd("tmux:#{name}:clone", "git", ["clone", "--quiet", url, dest])

             case result do
               :ok -> {:cont, :ok}
               err -> {:halt, err}
             end
           end)
         end}
      ]
  end

  # ── Font Installation ─────────────────────────────────

  defp install_fonts(config) do
    fonts = Map.get(config, "fonts", [])
    if fonts != [], do: do_install_fonts(fonts)
  end

  defp do_install_fonts(fonts) do
    fonts_dir = Path.join([home(), "Library", "Fonts"])
    File.mkdir_p!(fonts_dir)

    missing =
      Enum.filter(fonts, fn f ->
        not File.exists?(Path.join(fonts_dir, f["marker_file"]))
      end)

    if missing != [] do
      Application.ensure_all_started(:inets)
      Application.ensure_all_started(:ssl)

      ssl_opts = [
        ssl: [verify: :verify_peer, cacerts: :public_key.cacerts_get(), depth: 3]
      ]

      for font <- missing do
        IO.puts("#{magenta("→")} installing #{font["name"]}...")

        case download_and_extract_font(font["url"], fonts_dir, ssl_opts) do
          {:ok, count} -> IO.puts("#{green("✓")} #{font["name"]} (#{count} files)")
          {:error, reason} -> IO.puts("#{yellow("⚠")} #{font["name"]} (#{reason})")
        end
      end
    end
  end

  defp download_and_extract_font(url, fonts_dir, ssl_opts) do
    case :httpc.request(:get, {String.to_charlist(url), []}, ssl_opts, body_format: :binary) do
      {:ok, {{_, 200, _}, _, body}} ->
        extract_fonts(body, fonts_dir)

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp extract_fonts(zip_data, fonts_dir) do
    case :zip.unzip(zip_data, [:memory]) do
      {:ok, files} ->
        count =
          files
          |> Enum.filter(fn {name, _} ->
            n = name |> to_string() |> String.downcase()
            String.ends_with?(n, ".otf") or String.ends_with?(n, ".ttf")
          end)
          |> Enum.map(fn {name, data} ->
            filename = name |> to_string() |> Path.basename()
            File.write!(Path.join(fonts_dir, filename), data)
          end)
          |> length()

        {:ok, count}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # ── Completion Regeneration ───────────────────────────

  defp regen_completions(config) do
    completions_dir = Path.join([home(), ".config", "zsh", "completions"])

    IO.puts("Generating completions to #{completions_dir}")
    File.rm(Path.join(home(), ".zcompdump"))

    # Clean or create completions dir
    if File.exists?(completions_dir) do
      completions_dir |> File.ls!() |> Enum.each(&File.rm(Path.join(completions_dir, &1)))
    else
      File.mkdir_p!(completions_dir)
    end

    tools =
      (get_in(config, ["completions", "tools"]) || [])
      |> Enum.filter(fn t -> has?(t["name"]) end)

    {prebuilt, rest} = Enum.split_with(tools, &(&1["type"] == "prebuilt"))
    {sourced, default_tools} = Enum.split_with(rest, &(&1["type"] == "sourced"))

    # Prebuilt — serial, copy from relative to binary
    for tool <- prebuilt do
      case tool["source"] do
        nil ->
          IO.puts("  #{red("✗")} #{tool["name"]}: prebuilt missing source")

        source ->
          bin_path = System.find_executable(tool["name"])
          src = Path.join(Path.dirname(bin_path), source)

          if File.exists?(src) do
            File.cp!(src, Path.join(completions_dir, "_#{tool["name"]}"))
            IO.puts("  #{green("✓")} #{tool["name"]} (pre-built)")
          end
      end
    end

    # Sourced — serial, run command and write to output path
    for tool <- sourced do
      with cmd when cmd != nil <- tool["command"],
           out_rel when out_rel != nil <- tool["output"] do
        output_path = Path.join(dotfiles(), out_rel)
        output_path |> Path.dirname() |> File.mkdir_p!()

        case System.cmd(hd(cmd), tl(cmd)) do
          {out, 0} when out != "" ->
            File.write!(output_path, out)
            IO.puts("  #{green("✓")} #{tool["name"]} (sourced)")

          {out, _} ->
            err = out |> String.trim() |> String.split("\n") |> hd()
            err = if err == "", do: "empty output", else: err
            IO.puts("  #{red("✗")} #{tool["name"]}: #{err}")
        end
      else
        nil -> IO.puts("  #{red("✗")} #{tool["name"]}: sourced missing command/output")
      end
    end

    # Default — parallel, run completion command and write to completions dir
    results =
      default_tools
      |> Enum.map(fn tool ->
        command = tool["command"] || [tool["name"], "completion", "zsh"]

        Task.async(fn ->
          try do
            case System.cmd(hd(command), tl(command)) do
              {out, 0} when out != "" ->
                File.write!(Path.join(completions_dir, "_#{tool["name"]}"), out)
                {tool["name"], :ok}

              {out, _} ->
                err = out |> String.trim() |> String.split("\n") |> hd()
                err = if err == "", do: "empty output", else: err
                {tool["name"], {:error, err}}
            end
          rescue
            e -> {tool["name"], {:error, Exception.message(e)}}
          end
        end)
      end)
      |> Task.await_many(30_000)

    for {name, result} <- results do
      case result do
        :ok -> IO.puts("  #{green("✓")} #{name}")
        {:error, err} -> IO.puts("  #{red("✗")} #{name}: #{err}")
      end
    end
  end

  # ── Status ────────────────────────────────────────────

  defp build_manual_steps(auth) do
    []
    |> then(fn s ->
      if not Map.get(auth, :gh_ok, true) and has?("gh"),
        do: s ++ ["gh auth login"],
        else: s
    end)
    |> then(fn s ->
      if not Map.get(auth, :op_ok, true) and has?("op"),
        do:
          s ++
            ["1Password: Settings -> Developer -> CLI Integration, then 'op plugin init'"],
        else: s
    end)
  end

  # ── ZSH Completion ───────────────────────────────────

  defp zsh_completion do
    """
    #compdef upd
    _upd() {
      local -a commands
      commands=('completion:Generate shell completions')
      _arguments \\
        '(-v --verbose)'{-v,--verbose}'[Enable verbose output]' \\
        '1: :_describe "command" commands' \\
        '*:: :->args'
      case $state in
        args)
          case $words[1] in
            completion) _values 'shell' zsh ;;
          esac ;;
      esac
    }
    _upd "$@"
    """
  end
end

Upd.main(System.argv())
