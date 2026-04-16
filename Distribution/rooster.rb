cask "rooster" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/YOUR_GITHUB_USER/rooster/releases/download/v#{version}/Rooster.dmg"
  name "Rooster"
  desc "Menu bar keep-awake app — crow to keep your Mac awake"
  homepage "https://github.com/YOUR_GITHUB_USER/rooster"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Rooster.app"

  zap trash: [
    "~/Library/Application Support/Rooster",
    "~/Library/Preferences/com.rooster.app.plist",
    "~/Library/Saved Application State/com.rooster.app.savedState",
  ]
end
