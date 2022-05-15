# cooklang-dart

A [cooklang](https://cooklang.org/) parser for Dart.

## Features

* Passes successfully the [canonical test suite](https://github.com/cooklang/spec/tree/main/tests) (v5).

## Getting started

Check the package page on [pub.dev/packages/cooklang](https://pub.dev/packages/cooklang).

## Usage

Check `example/cooklang_example.dart`:

```dart
import 'package:cooklang/cooklang.dart';

void main() {
  final content = """
>> servings: 6

Make 6 pizza balls using @tipo zero flour{820%g}, @water{533%ml}, @salt{24.6%g} and @fresh yeast{1.6%g}. Put in a #fridge for ~{2%days}.
Set #oven to max temperature and heat #pizza stone{} for about ~{40%minutes}.

Make some tomato sauce with @chopped tomato{3%cans} and @garlic{3%cloves} and @dried oregano{3%tbsp}. Put on a #pan and leave for ~{15%minutes} occasionally stirring.

Make pizzas putting some tomato sauce with #spoon on top of flattened dough. Add @fresh basil{18%leaves}, @parma ham{3%packs} and @mozzarella{3%packs}.

Put in an #oven for ~{4%minutes}.""";
  final recipe = parseFromString(content);
  print(recipe.toObject());
}

```

## Additional information
