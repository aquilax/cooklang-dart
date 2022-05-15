import 'dart:convert';

const metadataLinePrefix = ">>";
const metadataValueSeparator = ":";

typedef Metadata = Map<String, String>;

class ParseResult {
  ParseResult(this.metadata);
  late Metadata metadata;
}

Metadata parseMetadataLine(String line) {
  var index = line.indexOf(metadataValueSeparator);
  if (index == -1) {
    throw "invalid metadata, missing value separator";
  }
  var key = line.substring(0, index).trim();
  var value = line.substring(index + metadataValueSeparator.length).trim();
  return {key: value};
}

ParseResult parseFromString(String content) {
  var metadata = <String, String>{};

  LineSplitter ls = LineSplitter();
  var lines = ls.convert(content);

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    if (line.startsWith(metadataLinePrefix)) {
      metadata
          .addAll(parseMetadataLine(line.substring(metadataLinePrefix.length)));
    }
  }
  return ParseResult(metadata);
}

/// Checks if you are awesome. Spoiler: you are.
class Awesome {
  bool get isAwesome => true;
}
