import 'package:cooklang_dart/cooklang_dart.dart';
import 'package:test/test.dart';

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
  });
}
