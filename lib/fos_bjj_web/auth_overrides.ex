defmodule FosBjjWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # Configure UI overrides for authentication pages
  # Uses the Open Source Jiu Jitsu logo for branding

  override AshAuthentication.Phoenix.Components.Banner do
    set(:image_url, "/images/placeholder_logo.jpeg")
    set(:dark_image_url, "/images/placeholder_logo.jpeg")
    set(:image_class, "block dark:hidden h-32 w-auto")
    set(:dark_image_class, "hidden dark:block h-32 w-auto")
    set(:href_url, "/database")
  end
end
