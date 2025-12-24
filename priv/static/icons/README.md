# Custom SVG Icons

This directory contains custom SVG icons that can be used throughout the FosBjj application.

## Usage

To use a custom icon in your templates or LiveViews:

```heex
<.icon name="custom-tree" class="w-6 h-6 text-green-600" />
<.icon name="custom-gi" class="w-8 h-8 text-white" />
<.icon name="custom-belt" class="w-5 h-5 text-amber-500" />
```

The icon component will automatically load the corresponding SVG file from this directory.

## Adding New Icons

1. Create a new `.svg` file in this directory with a descriptive name (e.g., `technique.svg`)
2. Use the `custom-` prefix followed by the filename (without extension) when referencing it
3. Ensure your SVG uses `currentColor` for strokes and fills to support dynamic coloring

### SVG Best Practices

**✅ Good - Uses currentColor:**
```xml
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="..." stroke="currentColor" stroke-width="2"/>
  <circle cx="12" cy="12" r="5" fill="currentColor"/>
</svg>
```

**❌ Bad - Hard-coded colors:**
```xml
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="..." stroke="#000000" stroke-width="2"/>
  <circle cx="12" cy="12" r="5" fill="#FF0000"/>
</svg>
```

### Recommended SVG Attributes

- **viewBox**: Use `"0 0 24 24"` for consistency with Heroicons
- **fill**: Set to `"none"` on the root element unless you want a filled icon
- **xmlns**: Include `xmlns="http://www.w3.org/2000/svg"`
- **stroke/fill**: Use `currentColor` to inherit text color from parent elements
- **stroke-width**: Typically `1.5` or `2` for outline icons
- **stroke-linecap/stroke-linejoin**: Use `"round"` for smoother appearance

## Styling Icons

Icons inherit the text color from their parent element and can be styled with Tailwind classes:

```heex
<!-- Size -->
<.icon name="custom-tree" class="w-4 h-4" />
<.icon name="custom-tree" class="w-6 h-6" />
<.icon name="custom-tree" class="w-12 h-12" />

<!-- Color -->
<.icon name="custom-gi" class="text-blue-600" />
<.icon name="custom-belt" class="text-amber-500" />

<!-- Animation -->
<.icon name="custom-tree" class="w-6 h-6 motion-safe:animate-spin" />

<!-- Hover effects -->
<.icon name="custom-gi" class="w-6 h-6 hover:text-blue-700 transition-colors" />
```

## Example Icons

This directory includes several BJJ-themed example icons:

- **tree.svg** - A simple tree icon (useful for technique trees)
- **gi.svg** - A BJJ gi/kimono icon
- **belt.svg** - A BJJ belt icon

Feel free to modify or replace these with your own designs!

## Finding SVG Icons

Good sources for SVG icons:
- [Heroicons](https://heroicons.com) - Already integrated via `hero-` prefix
- [Lucide](https://lucide.dev) - Clean, consistent icon set
- [Tabler Icons](https://tabler.io/icons) - Large collection of outline icons
- [SVG Repo](https://www.svgrepo.com) - Searchable collection
- Custom designs from tools like [Figma](https://figma.com) or [Inkscape](https://inkscape.org)

Remember to ensure any icons you use are properly licensed for your use case!


