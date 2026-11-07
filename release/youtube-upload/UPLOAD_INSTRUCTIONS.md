# YouTube upload: CareBridge AI demo

## Files in this folder

| File | What it is |
|---|---|
| `carebridge-demo.mp4` | The video, identical to `docs/demo/carebridge-demo.mp4`. 1280×800 H.264 with mono AAC narration, 3:24, 8.2 MB. SHA-256 `433fd33fa32790e65d0b1a2e8c99d22a06a2cee8e680395d9da6f358ee7c153f` |
| `captions.srt` | English subtitles, 21 cues. The narration was generated from these same lines. |
| `title.txt` | Title (85 characters; YouTube allows 100) |
| `description.txt` | Description, including tested environment, limitations, links and chapters |
| `tags.txt` | Tags (280 characters; YouTube allows 500) |

There is no thumbnail in this package. You're providing your own.

## Checked before handover (2026-11-05)

- The whole file decodes with AVFoundation: 1,204 video frames, 204.15 s of audio, and the reader finished with status "completed".
- Every caption window contains speech (RMS 1,538–3,199), with no clipping (peak 30,334 of 32,767).
- The video has a 1280×800 frame (16:10). YouTube shows thin side bars in a 16:9 player, which is normal.
- No credentials, local paths or personal data. All data shown is synthetic. Only the app viewport is recorded, with no browser address bar.

## Upload steps

1. Open https://studio.youtube.com and sign in to the channel you want to use.
2. Click **Create → Upload videos** and choose `carebridge-demo.mp4`.
3. **Details:**
   - Title: paste `title.txt`.
   - Description: paste `description.txt`. Once the Developer Community article is live, add its URL under LINKS.
   - Thumbnail: upload your own.
   - Audience: **No, it's not made for kids**.
   - **Show more → Tags:** paste `tags.txt`.
   - **Show more → Language:** English.
   - Category: *Science & Technology*.
   - **Altered or synthetic content:** answer **Yes**, because the narration is a synthetic voice.
4. **Video elements → Add subtitles → Upload file → With timing**, then choose `captions.srt` (English).
5. **Visibility:** **Public**. The contest bonus is for a video showing the project in action; Unlisted might not count, so Public is safer.
6. Publish, then copy the video URL. Paste it into:
   - the Open Exchange draft (**YouTube URL** field): https://openexchange.intersystems.com/portal/products/CareBridge-AI/edit
   - the README "Demo video" line, if you want (or ask me to do it).
