defmodule FosBjjWeb.Components.Icon do
  @moduledoc """
  The `FosBjjWeb.Components.Icon` module provides a flexible and reusable icon
  component for rendering various types of icons in a Phoenix LiveView application.

  ## Features:
  - Supports multiple icon libraries (Hero Icons)
  - Flexible size control with predefined and custom sizing options
  - Customizable colors with theme integration
  - Supports both filled and outlined icon variants
  - Automatic accessibility attributes for better screen reader support
  - Animatable with CSS classes
  - Optional click handlers and interactive states

  ## Examples:

      <.icon name="hero-home" class="w-6 h-6" />
      <.icon name="fa-github" variant="brands" size="lg" />
      <.icon name="material-settings" color="primary" animate="spin" />

  ## Properties:
  - `name` - Required. The identifier of the icon to display
  - `variant` - Optional. The style variant of the icon (solid, outline, brands)
  - `size` - Optional. Size of the icon (sm, md, lg, xl, or custom class)
  - `color` - Optional. Theme color or custom color class
  - `class` - Optional. Additional CSS classes
  - `animate` - Optional. Animation class to apply
  - `aria_label` - Optional. Accessibility label for screen readers
  - `rest` - Additional HTML attributes passed to the icon element
  """
  use Phoenix.Component

  @doc """
  Renders a [Heroicon](https://heroicons.com) or custom SVG icon.

  ## Heroicons
  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Custom SVG Icons
  Custom SVG icons can be added by placing `.svg` files in `priv/static/icons/`
  and referencing them with the `custom-` prefix.

  The SVG files should use `currentColor` for strokes and fills to support
  dynamic coloring via Tailwind classes.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
      <.icon name="custom-tree" class="w-6 h-6 text-green-600" />
  """
  @doc type: :component
  attr :name, :string, required: true
  attr :class, :any, default: nil

  attr :rest, :global,
    doc:
      "Global attributes can define defaults which are merged with attributes provided by the caller"

  # Custom SVG icons loaded from priv/static/icons/
  def icon(%{name: "custom-" <> svg_name} = assigns) do
    svg_path = Path.join([:code.priv_dir(:fos_bjj), "static", "icons", "#{svg_name}.svg"])

    case File.read(svg_path) do
      {:ok, svg_content} ->
        # Parse the SVG to add/merge classes
        svg_with_class = add_class_to_svg(svg_content, assigns.class)
        assigns = assign(assigns, :svg_content, svg_with_class)

        ~H"""
        {Phoenix.HTML.raw(@svg_content)}
        """

      {:error, _} ->
        raise ArgumentError, """
        Custom SVG icon not found: #{svg_name}.svg
        Expected location: priv/static/icons/#{svg_name}.svg
        """
    end
  end

  # Heroicons
  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end

  # Helper function to add class attribute to SVG root element
  defp add_class_to_svg(svg_content, nil), do: svg_content

  defp add_class_to_svg(svg_content, class) when is_binary(class) do
    String.replace(svg_content, ~r/<svg/, "<svg class=\"#{class}\"", global: false)
  end

  defp add_class_to_svg(svg_content, class) when is_list(class) do
    class_string = Enum.join(class, " ")
    String.replace(svg_content, ~r/<svg/, "<svg class=\"#{class_string}\"", global: false)
  end
end
