defmodule Protobuf.Protoc.Generator.Extension do
  @moduledoc false

  alias Protobuf.Protoc.Context
  alias Protobuf.Protoc.Generator.Util

  require EEx

  @ext_postfix "PbExtension"

  EEx.function_from_file(
    :defp,
    :extension_template,
    Path.expand("./templates/extension.ex.eex", :code.priv_dir(:protobuf)),
    [:assigns]
  )

  @spec generate(Context.t(), Google.Protobuf.FileDescriptorProto.t(), %{}) ::
          nil | {module_name :: String.t(), file_contents :: String.t()}
  def generate(
        %Context{namespace: ns} = ctx,
        %Google.Protobuf.FileDescriptorProto{} = desc,
        nested_extensions
      ) do
    extends = Enum.map(desc.extension, &generate_extend(ctx, &1, _ns = ""))

    nested_extends =
      Enum.flat_map(nested_extensions, fn {ns, exts} ->
        ns = Enum.join(ns, ".")
        Enum.map(exts, &generate_extend(ctx, &1, ns))
      end)

    case extends ++ nested_extends do
      [] ->
        nil

      extends ->
        msg_name = Util.mod_name(ctx, ns ++ [Macro.camelize(@ext_postfix)])
        use_options = Util.options_to_str(%{syntax: ctx.syntax})

        {msg_name,
         Util.format(
           extension_template(module: msg_name, use_options: use_options, extends: extends)
         )}
    end
  end

  defp generate_extend(ctx, f, ns) do
    extendee = Util.type_from_type_name(ctx, f.extendee)
    f = Protobuf.Protoc.Generator.Message.get_field(ctx, f, %{}, [])

    name =
      if ns == "" do
        f.name
      else
        inspect("#{ns}.#{f.name}")
      end

    "#{extendee}, :#{name}, #{f.number}, #{f.label}: true, type: #{f.type}#{f.opts_str}"
  end

  @spec get_nested_extensions(Context.t(), [Google.Protobuf.DescriptorProto.t()], list()) ::
          list()
  def get_nested_extensions(%Context{namespace: ns} = ctx, descs, acc0 \\ []) do
    descs
    |> Enum.reject(&(&1.extension == []))
    |> Enum.reduce(acc0, fn desc, acc ->
      new_ns = ns ++ [Macro.camelize(desc.name)]
      acc = [_extension = {new_ns, desc.extension} | acc]

      if desc.nested_type == [] do
        acc
      else
        get_nested_extensions(%Context{ctx | namespace: new_ns}, desc.nested_type, acc)
      end
    end)
  end
end
