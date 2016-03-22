# YoutubeDownloader
A ruby script for download mp3 from Youtube. It uses the API for [Youtube](https://developers.google.com/youtube/v3/) and the API for [YoutubeInMP3](http://www.youtubeinmp3.com/api/)

## Quick start
In order to use this script you will need to have an API key enabled for Youtube. If you don't have one, you can get it in `https://console.cloud.google.com`. Remember to enable the YouTube Data API v3.

Once you get your API key you need to save it inside `~/.config/youtubedownloader/apikey`, or use the option `-k, --key=<path>` to give to the script the path where the key is stored.

## Usage
```
  Options:
      -m, --mode=<s>           Type of the download (list, video, search)
      -q, --query=<s>          What to download. For list and video should be the
                               id, for search should be a query
      -o, --out=<s>            Where the downloads will store (default: ~/Music)
      -k, --key=<s>            Path to the file with the API key (default:
                               ~/.config/youtubedownloader/apikey)
      -u, --quiet              To silence the output
      -a, --max-results=<i>    Max items to download [1, 50] (default: 25)
      -h, --help               Show this message
```
The options `-m, --mode=<s>` and `-q, --query=<s>` are required. 
* For `-m list` the query should be the id of the playlist.
* For `-m video` the query should be the id('s) of the video(s). Multiple id's should be se separeted by comma (`,`)
* For `-m search` the query can be any string. It will download the number of videos specified by `-a, --max-results=<i>` returned by that query.

### Example
* `ruby youtubedownloader.rb -m list -q PLU_mcNMHvxilbbOnWFy4v4_nxxkMQ5r7l -o ~/Music/PTX`
* `ruby youtubedownloader.rb -m video -q 6Whgn_iE5uc,BB0DU4DoPP4`
* `ruby youtubedownloader.rb -m search -q "borro cassette" -a 1`

## Bugs
* Sometimes the file does not download correctly. Retry the download can fix this.

## TO DO
* Download videos.
* Download mixes (if possible).
* Think what else to add.
* Fix de bugs.

## License

Copyright (c) 2016 David Felipe Castillo Velázquez

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Acknowledgment

Thank you to [Freddy Román](https://github.com/frcepeda/) because, although without his knowledge, gave me ideas about how to make this project.
