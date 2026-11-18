`veyro-synthetic-reel.webm` is a three-second, silent, synthetic test clip for
Chrome playback. It isn't included in the Flutter application or uploaded to
Supabase. It can be reproduced with FFmpeg:

```sh
ffmpeg -f lavfi -i 'color=c=0x7036E5:s=144x256:r=12:d=3,drawbox=x=12:y=38:w=120:h=180:color=0xcbb0ff@0.75:t=3' \
  -c:v libvpx-vp9 -an test/fixtures/veyro-synthetic-reel.webm
```
