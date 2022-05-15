import 'dart:io';

import 'package:cooklang/cooklang.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('parseFromString', () {
    test('parses metadata', () {
      const content = """>> this: is a test""";
      expect(parseFromString(content).metadata, equals({"this": "is a test"}));
    });

    test('parses multiple metadata lines', () {
      const content = """
>> this: is a test
>> here: is another one
""";
      expect(parseFromString(content).metadata,
          equals({"this": "is a test", "here": "is another one"}));
    });

    test('parses correctly text', () {
      const content = 'Fry for ~potato{42%minutes}';
      expect(
          parseFromString(content)
              .steps
              .map((e) => e.map((e) => e.toObject()).toList())
              .toList(),
          equals([
            [
              {'type': 'text', 'value': 'Fry for '},
              {
                'type': 'timer',
                'quantity': 42.0,
                'units': 'minutes',
                'name': 'potato'
              }
            ]
          ]));
    });
    test('parses correctly inline comment', () {
      var content = '@thyme{2%springs} -- testing comments';
      expect(
          parseFromString(content)
              .steps
              .map((e) => e.map((e) => e.toObject()).toList())
              .toList(),
          equals([
            [
              {
                'type': 'ingredient',
                'name': 'thyme',
                'quantity': 2,
                'units': 'springs'
              },
              {'type': 'text', 'value': ' '}
            ]
          ]));
    });
  });

  group('getIngredient', () {
    test('returns ingredient and offset', () {
      const ingredient = '@kasawa{100%g}';
      final ingredientWithOffset = getIngredient(ingredient);
      final expected = StepIngredient('kasawa', 100, "g");
      final given = ingredientWithOffset.item1;
      expect(given.name, equals(expected.name));
      expect(given.quantity, equals(expected.quantity));
      expect(given.units, equals(expected.units));
    });
  });

  group('canonical tests', () {
    var contents = File('./test/canonical.yaml').readAsStringSync();
    var doc = loadYaml(contents);
    doc['tests'].forEach((name, testCase) => {
          test(name, () {
            var parseResult = parseFromString(testCase['source']);
            expect(
                parseResult.metadata, equals(testCase['result']['metadata']));
            expect(
                parseResult.steps
                    .map((e) => e.map((e) => e.toObject()).toList())
                    .toList(),
                equals(testCase['result']['steps']));
          })
        });
  });
}
