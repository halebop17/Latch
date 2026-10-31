cask "latch" do
  version "1.1.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/YOUR_GITHUB_USER/latch/releases/download/v#{version}/Latch.dmg"
  name "Latch"
  desc "Menu bar keep-awake app — crow to keep your Mac awake"
  homepage "https://github.com/YOUR_GITHUB_USER/latch"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Latch.app"

  zap trash: [
    "~/Library/Application Support/Latch",
    "~/Library/Preferences/com.latch.app.plist",
    "~/Library/Saved Application State/com.latch.app.savedState",
  ]
end
