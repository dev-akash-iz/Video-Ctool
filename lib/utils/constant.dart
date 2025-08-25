// ignore_for_file: constant_identifier_names

const Map<String, String> LANGUAGE_NAME = {
  "afr": "Afrikaans",
  "alb": "Albanian",
  "amh": "Amharic",
  "ara": "Arabic",
  "arm": "Armenian",
  "aze": "Azerbaijani",
  "baq": "Basque",
  "bel": "Belarusian",
  "ben": "Bengali",
  "bos": "Bosnian",
  "bul": "Bulgarian",
  "bur": "Burmese",
  "cat": "Catalan",
  "chi": "Chinese",
  "zho": "Chinese",
  "hrv": "Croatian",
  "cze": "Czech",
  "ces": "Czech",
  "dan": "Danish",
  "dut": "Dutch",
  "nld": "Dutch",
  "eng": "English",
  "epo": "Esperanto",
  "est": "Estonian",
  "fin": "Finnish",
  "fre": "French",
  "fra": "French",
  "glg": "Galician",
  "geo": "Georgian",
  "kat": "Georgian",
  "ger": "German",
  "deu": "German",
  "gre": "Greek",
  "ell": "Greek",
  "guj": "Gujarati",
  "heb": "Hebrew",
  "hin": "Hindi",
  "hun": "Hungarian",
  "ice": "Icelandic",
  "isl": "Icelandic",
  "ind": "Indonesian",
  "ita": "Italian",
  "jpn": "Japanese",
  "kan": "Kannada",
  "kaz": "Kazakh",
  "khm": "Khmer",
  "kor": "Korean",
  "kur": "Kurdish",
  "lao": "Lao",
  "lat": "Latin",
  "lav": "Latvian",
  "lit": "Lithuanian",
  "mac": "Macedonian",
  "mkd": "Macedonian",
  "mal": "Malayalam",
  "may": "Malay",
  "msa": "Malay",
  "mni": "Manipuri",
  "mar": "Marathi",
  "mon": "Mongolian",
  "nep": "Nepali",
  "nor": "Norwegian",
  "ori": "Oriya",
  "pan": "Punjabi",
  "per": "Persian",
  "fas": "Persian",
  "pol": "Polish",
  "por": "Portuguese",
  "pus": "Pashto",
  "rum": "Romanian",
  "ron": "Romanian",
  "rus": "Russian",
  "scc": "Serbian",
  "srp": "Serbian",
  "sin": "Sinhala",
  "slk": "Slovak",
  "slv": "Slovenian",
  "som": "Somali",
  "spa": "Spanish",
  "swa": "Swahili",
  "swe": "Swedish",
  "tam": "Tamil",
  "tel": "Telugu",
  "tha": "Thai",
  "tib": "Tibetan",
  "tur": "Turkish",
  "ukr": "Ukrainian",
  "urd": "Urdu",
  "uzb": "Uzbek",
  "vie": "Vietnamese",
  "wel": "Welsh",
  "yid": "Yiddish",
};

const String SPACE = '   ';

const List<double> GENERAL_BPP_RANGE = [
  0.03, // Extremely efficient (e.g., AV1 at low bitrate)
  0.05, // Common for H.264, H.265, VP9 at lower bitrates
  0.08, // Medium quality across various codecs
  0.1, // Good balance of quality and efficiency
  0.15, // Higher quality, used for MPEG-4, VP9, high-bitrate H.264
  0.2, // Approaching lossless for some codecs
  0.25, // Very high quality, MPEG-2, unoptimized encodes
  0.3, // Near lossless or inefficient encoding
  0.35, // High-bitrate MPEG-2, archival quality
];

const Map<String, List<double>> CODEC_BPP_RANGES = {
  "h264": [
    0.05,
    0.08,
    0.1,
    0.15,
    0.2
  ], // Common H.264 range from low to high quality
  "h265": [0.04, 0.06, 0.08, 0.1, 0.12], // H.265 (HEVC) is more efficient
  "vp9": [0.05, 0.07, 0.09, 0.12, 0.15], // VP9 range
  "av1": [0.03, 0.04, 0.06, 0.08, 0.1], // AV1 (most efficient)
  "mpeg4": [0.12, 0.15, 0.18, 0.2, 0.25], // MPEG-4 (older, less efficient)
  "mpeg2": [0.18, 0.2, 0.25, 0.3, 0.35], // MPEG-2 (least efficient)
};

const Map<String, bool> LIST_EXTENSION = {
  // Video extensions
  ".mp4": true,
  ".mkv": true,
  ".mov": true,
  ".avi": true,
  ".wmv": true,
  ".flv": true,
  ".webm": true,
  ".mpeg": true,
  ".mpg": true,
  ".3gp": true,
  ".m4v": true,
  ".ts": true,

  //Audio extensions
  ".mp3": true,
  ".wav": true,
  ".aac": true,
  ".flac": true,
  ".ogg": true,
  ".wma": true,
  ".m4a": true,
  ".opus": true,
  ".alac": true,
  ".aiff": true,
  ".amr": true,
};

final SLASH_CODE = '/'.codeUnitAt(0);
final DOT_CODE = '.'.codeUnitAt(0);
