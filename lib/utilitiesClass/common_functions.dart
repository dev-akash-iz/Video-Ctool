const Map<String, String> languageNames = {
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

String getLanguageName(String? code) {
  if (code == null || code.isEmpty) {
    return "Unknown";
  }
  return languageNames[code] ?? code;
}

String formatDuration(dynamic duration) {
  double seconds = double.tryParse(duration.toString()) ?? 0.0;
  int totalSeconds = seconds.round(); // Convert to nearest whole number
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int secs = totalSeconds % 60;

  // Build formatted output dynamically
  List<String> parts = [];
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}m');
  if (secs > 0 || parts.isEmpty) parts.add('${secs}s');

  return parts.join(" "); // Example: "1h 23m 10s"
}
