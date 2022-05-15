import 'dart:convert';
import 'package:tuple/tuple.dart';

const commentsLinePrefix = "--";
const metadataLinePrefix = ">>";
const metadataValueSeparator = ":";
const prefixIngredient = '@';
const prefixCookware = '#';
const prefixTimer = '~';
const prefixBlockComment = '[';
const prefixInlineComment = '-';
const terminatingPrefixes = [
  prefixCookware,
  prefixIngredient,
  prefixTimer,
  prefixBlockComment
];

typedef Metadata = Map<String, String>;
typedef Step = List<StepItem>;
typedef Node = Tuple3<String, dynamic, String>;
typedef Amount = Tuple2<dynamic, String>;
typedef IngredientWithOffset = Tuple2<StepIngredient, int>;
typedef CookwareWithOffset = Tuple2<StepCookware, int>;
typedef TimerWithOffset = Tuple2<StepTimer, int>;

abstract class StepItem {
  Object toObject();
}

Object stepText(String value) {
  return {'type': 'text', 'value': value};
}

class StepText implements StepItem {
  StepText(this.value);

  String type = 'text';
  late String value;

  @override
  Object toObject() {
    return {'type': type, 'value': value};
  }
}

class StepIngredient implements StepItem {
  StepIngredient(this.name, this.quantity, this.units);

  String type = 'ingredient';
  late String name;
  late dynamic quantity;
  late String units;

  @override
  Object toObject() {
    return {'type': type, 'name': name, 'quantity': quantity, 'units': units};
  }
}

class StepCookware implements StepItem {
  StepCookware(this.name, this.quantity, this.quantityRaw);

  String type = 'cookware';
  late String name;
  late dynamic quantity;
  late String quantityRaw;

  @override
  Object toObject() {
    return {'type': type, 'name': name, 'quantity': quantity};
  }
}

class StepTimer implements StepItem {
  StepTimer(this.name, this.quantity, this.units);

  String type = 'timer';
  late String name;
  late dynamic quantity;

  late String units;

  @override
  Object toObject() {
    return {'type': type, 'quantity': quantity, 'units': units, 'name': name};
  }
}

class ParseResult {
  ParseResult(this.steps, this.metadata);

  late Metadata metadata;
  late List<Step> steps;
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
  var steps = <Step>[];

  LineSplitter ls = LineSplitter();
  var lines = ls.convert(content);

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmedLine = line.trim();

    if (trimmedLine.isEmpty) {
      continue;
    }

    if (line.startsWith(commentsLinePrefix)) {
      continue;
    }
    if (line.startsWith(metadataLinePrefix)) {
      metadata.addAll(
          parseMetadataLine(trimmedLine.substring(metadataLinePrefix.length)));
      continue;
    }

    final step = parseLine(trimmedLine);
    if (step.isNotEmpty) {
      steps.add(step);
    }
  }
  return ParseResult(steps, metadata);
}

Step parseLine(String line) {
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
    if (char == prefixInlineComment && lastChar == prefixInlineComment) {
      // eol comment
      if (lastIndex < i) {
        step.add(StepText(line.substring(lastIndex, i - 1)));
      }
      lastIndex = line.length;
      break;
    }
    if (terminatingPrefixes.contains(char)) {
      if (lastIndex < i) {
        step.add(StepText(line.substring(lastIndex, i)));
      }
      switch (char) {
        case prefixIngredient:
          {
            // Ingredient ahead
            var ingredientTuple = getIngredient(line.substring(i));
            skipIndex = i + ingredientTuple.item2;
            step.add(ingredientTuple.item1);
          }
          break;
        case prefixCookware:
          {
            var cookwareTuple = getCookware(line.substring(i));
            skipIndex = i + cookwareTuple.item2;
            step.add(cookwareTuple.item1);
          }
          break;
        case prefixTimer:
          {
            var timerTuple = getTimer(line.substring(i));
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

IngredientWithOffset getIngredient(String line) {
  final endIndex = getEndIndex(line);
  final rawContent = line.substring(1, endIndex);
  final node = getNode(rawContent, 'some');
  return IngredientWithOffset(
      StepIngredient(node.item1, node.item2, node.item3), endIndex);
}

CookwareWithOffset getCookware(String line) {
  final endIndex = getEndIndex(line);
  final rawContent = line.substring(1, endIndex);
  final node = getNode(rawContent, 1);
  return CookwareWithOffset(
      StepCookware(node.item1, node.item2, node.item3), endIndex);
}

TimerWithOffset getTimer(String line) {
  final endIndex = getEndIndex(line);
  final rawContent = line.substring(1, endIndex);
  final node = getNode(rawContent, 0);
  return TimerWithOffset(
      StepTimer(node.item1, node.item2, node.item3), endIndex);
}

int getEndIndex(String line) {
  var endIndex = -1;
  for (var i = 0; i < line.length; i++) {
    if (i == 0) {
      continue;
    }
    if ((terminatingPrefixes.contains(line[i])) && endIndex == -1) {
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

Node getNode(String rawContent, dynamic defaultValue) {
  final nameIndex = rawContent.indexOf("{");
  if (nameIndex == -1) {
    return Node(rawContent, defaultValue, '');
  }
  final amount = getAmount(
      rawContent.substring(nameIndex + 1, rawContent.length - 1), defaultValue);
  return Node(rawContent.substring(0, nameIndex), amount.item1, amount.item2);
}

Amount getAmount(String rawAmount, dynamic defaultValue) {
  if (rawAmount.isEmpty) {
    return Amount(defaultValue, '');
  }
  final separatorIndex = rawAmount.indexOf("%");
  if (separatorIndex == -1) {
    return Amount(getValue(rawAmount.trim(), defaultValue), '');
  }
  return Amount(
      getValue(rawAmount.substring(0, separatorIndex).trim(), defaultValue),
      rawAmount.substring(separatorIndex + 1).trim());
}

dynamic getValue(String value, dynamic defaultValue) {
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
