import 'dart:convert';
import 'package:tuple/tuple.dart';

const _commentsLinePrefix = "--";
const _metadataLinePrefix = ">>";
const _metadataValueSeparator = ":";
const _prefixIngredient = '@';
const _prefixCookware = '#';
const _prefixTimer = '~';
const _prefixBlockComment = '[';
const _prefixInlineComment = '-';
const _terminatingPrefixes = [
  _prefixCookware,
  _prefixIngredient,
  _prefixTimer,
  _prefixBlockComment
];

/// Recipe metadata dictionary
typedef Metadata = Map<String, String>;

/// Recipe list of step items
typedef Step = List<StepItem>;

typedef _Node = Tuple3<String, dynamic, String>;
typedef _Amount = Tuple2<dynamic, String>;
typedef _IngredientWithOffset = Tuple2<StepIngredient, int>;
typedef _CookwareWithOffset = Tuple2<StepCookware, int>;
typedef _TimerWithOffset = Tuple2<StepTimer, int>;

/// Abstract StepItem class
abstract class StepItem {
  /// Map representation of the object
  Object toObject();
}

/// Step item containing unstructured text
class StepText implements StepItem {
  StepText(this.value);

  String type = 'text';

  /// Text value
  late String value;

  @override
  Object toObject() {
    return {'type': type, 'value': value};
  }
}

/// Step item containing ingredient definition
class StepIngredient implements StepItem {
  StepIngredient(this.name, this.quantity, this.units);

  String type = 'ingredient';

  /// Name of the ingredient
  late String name;

  /// Quantity can be string/int/double
  late dynamic quantity;

  /// Optional quantity unit (defaults to empty string)
  late String units;

  @override
  Object toObject() {
    return {'type': type, 'name': name, 'quantity': quantity, 'units': units};
  }
}

/// Step item containing cookware definition
class StepCookware implements StepItem {
  StepCookware(this.name, this.quantity);

  String type = 'cookware';

  /// Name of the cookware
  late String name;

  /// Quantity can be string/int/double
  late dynamic quantity;

  @override
  Object toObject() {
    return {'type': type, 'name': name, 'quantity': quantity};
  }
}

/// Step item containing timer definition
class StepTimer implements StepItem {
  StepTimer(this.name, this.quantity, this.units);

  String type = 'timer';

  /// Name of the timer
  late String name;

  /// Quantity can be string/int/double
  late dynamic quantity;

  late String units;

  @override
  Object toObject() {
    return {'type': type, 'quantity': quantity, 'units': units, 'name': name};
  }
}

/// Parse result containing the parsed recipe
class Recipe {
  Recipe(this.steps, this.metadata);

  late Metadata metadata;
  late List<Step> steps;

  Object toObject() {
    return {
      'metadata': metadata,
      'steps': steps.map((e) => e.map((e) => e.toObject()).toList())
    };
  }
}

/// Parses a cooklang marked up recipe and returns a Recipe object
Recipe parseFromString(String content) {
  var metadata = <String, String>{};
  var steps = <Step>[];

  LineSplitter ls = LineSplitter();
  var lines = ls.convert(content);

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmedLine = line.trim();

    if (trimmedLine.isEmpty) {
      continue;
    }

    if (line.startsWith(_commentsLinePrefix)) {
      continue;
    }
    if (line.startsWith(_metadataLinePrefix)) {
      metadata.addAll(_parseMetadataLine(
          trimmedLine.substring(_metadataLinePrefix.length)));
      continue;
    }

    final step = _parseLine(trimmedLine);
    if (step.isNotEmpty) {
      steps.add(step);
    }
  }
  return Recipe(steps, metadata);
}

Metadata _parseMetadataLine(String line) {
  var index = line.indexOf(_metadataValueSeparator);
  if (index == -1) {
    throw "invalid metadata, missing value separator";
  }
  var key = line.substring(0, index).trim();
  var value = line.substring(index + _metadataValueSeparator.length).trim();
  return {key: value};
}

Step _parseLine(String line) {
  var skipIndex = 0;
  var lastIndex = skipIndex;
  var step = <StepItem>[];
  var lastChar = '';

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (skipIndex > i) {
      lastChar = char;
      continue;
    }
    if (char == _prefixInlineComment && lastChar == _prefixInlineComment) {
      // eol comment
      if (lastIndex < i) {
        step.add(StepText(line.substring(lastIndex, i - 1)));
      }
      lastIndex = line.length;
      break;
    }
    if (_terminatingPrefixes.contains(char)) {
      if (lastIndex < i) {
        step.add(StepText(line.substring(lastIndex, i)));
      }
      switch (char) {
        case _prefixIngredient:
          {
            // Ingredient ahead
            var ingredientTuple = _getIngredient(line.substring(i));
            skipIndex = i + ingredientTuple.item2;
            step.add(ingredientTuple.item1);
          }
          break;
        case _prefixCookware:
          {
            var cookwareTuple = _getCookware(line.substring(i));
            skipIndex = i + cookwareTuple.item2;
            step.add(cookwareTuple.item1);
          }
          break;
        case _prefixTimer:
          {
            var timerTuple = _getTimer(line.substring(i));
            skipIndex = i + timerTuple.item2;
            lastIndex = skipIndex;
            step.add(timerTuple.item1);
          }
          break;
        default:
          {
            throw "Not implemented";
          }
      }
      lastIndex = skipIndex;
    }
    lastChar = char;
  }
  if (lastIndex < line.length) {
    step.add(StepText(line.substring(lastIndex)));
  }
  return step;
}

_IngredientWithOffset _getIngredient(String line) {
  final endIndex = _getEndIndex(line);
  final rawContent = line.substring(1, endIndex);
  final node = _getNode(rawContent, 'some');
  return _IngredientWithOffset(
      StepIngredient(node.item1, node.item2, node.item3), endIndex);
}

_CookwareWithOffset _getCookware(String line) {
  final endIndex = _getEndIndex(line);
  final rawContent = line.substring(1, endIndex);
  final node = _getNode(rawContent, 1);
  return _CookwareWithOffset(StepCookware(node.item1, node.item2), endIndex);
}

_TimerWithOffset _getTimer(String line) {
  final endIndex = _getEndIndex(line);
  final rawContent = line.substring(1, endIndex);
  final node = _getNode(rawContent, 0);
  return _TimerWithOffset(
      StepTimer(node.item1, node.item2, node.item3), endIndex);
}

int _getEndIndex(String line) {
  var endIndex = -1;
  for (var i = 0; i < line.length; i++) {
    if (i == 0) {
      continue;
    }
    if ((_terminatingPrefixes.contains(line[i])) && endIndex == -1) {
      break;
    }
    if (line[i] == '}') {
      endIndex = i + 1;
      break;
    }
  }
  if (endIndex == -1) {
    endIndex = line.indexOf(' ');
    if (endIndex == -1) {
      endIndex = line.length;
    }
  }
  return endIndex;
}

_Node _getNode(String rawContent, dynamic defaultValue) {
  final nameIndex = rawContent.indexOf("{");
  if (nameIndex == -1) {
    return _Node(rawContent, defaultValue, '');
  }
  final amount = _getAmount(
      rawContent.substring(nameIndex + 1, rawContent.length - 1), defaultValue);
  return _Node(rawContent.substring(0, nameIndex), amount.item1, amount.item2);
}

_Amount _getAmount(String rawAmount, dynamic defaultValue) {
  if (rawAmount.isEmpty) {
    return _Amount(defaultValue, '');
  }
  final separatorIndex = rawAmount.indexOf("%");
  if (separatorIndex == -1) {
    return _Amount(_getValue(rawAmount.trim(), defaultValue), '');
  }
  return _Amount(
      _getValue(rawAmount.substring(0, separatorIndex).trim(), defaultValue),
      rawAmount.substring(separatorIndex + 1).trim());
}

dynamic _getValue(String value, dynamic defaultValue) {
  final d = double.tryParse(value);
  if (d != null) {
    return d;
  }
  final n = int.tryParse(value);
  if (n != null) {
    return n;
  }
  if (value.contains('/') && value[0] != '0') {
    final fra = value.split('/');
    return int.parse(fra[0]) / int.parse(fra[1]);
  }
  if (value.trim() == '') {
    return defaultValue;
  }
  return value;
}
