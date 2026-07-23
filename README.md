# yt-gui
**yt-gui** is a user-friendly desktop application for searching and downloading YouTube videos and audio. Featuring an intuitive interface, it allows you to easily select video quality, file extensions, and edit metadata (title and artist).

<img width="2158" height="1630" alt="MarkedUpImage" src="https://github.com/user-attachments/assets/c2ab3eb3-39e5-428c-b15e-1e5461a5c293" />

---

## ✨ Features

* **YouTube Search**: Search for videos directly using keywords within the app.
* **URL Parsing**: Paste a video URL to automatically fetch video details and options.
* **Flexible Download Options**:
  * **File Extension Selection**: Choose between MP4, MP3, etc. based on your needs.
  * **Quality & Resolution**: Select target resolution, such as 1080p (30fps).
  * **Metadata Editing**: Customize title and artist tags before downloading.
  * **Thumbnail Saving**: Option to download and save the video thumbnail image together.
* **Process Log**: Built-in log viewer to monitor download status and progress in real time.

---

## 🚀 How to Use

1. **Search or Input URL**
   * Enter keywords in the top search bar and click **Search**, or paste a video URL into the bottom field and click **Parse**.
2. **Configure Download Settings**
   * In the "Download Options" pop-up modal, customize:
     * Title / Artist
     * Save thumbnail (checkbox)
     * File extension (e.g., MP4)
     * Video/Audio quality (e.g., 1080p)
3. **Download**
   * Click the **Download** button in the bottom right corner to begin the process.

---

## 🛠 Tech Stack

* **GUI Framework**: SwiftUI
* **Backend Utilities**: `yt-dlp` / `ffmpeg` / `deno`

---

## ⚠️ Disclaimer

* This tool is intended for personal use and for downloading content you have the legal right or permission to access.
* Please respect YouTube's Terms of Service and applicable copyright laws. Downloading copyrighted material without permission is prohibited.

---

## 📄 License

[AGPL License](LICENSE)
