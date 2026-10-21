import 'package:langhuan/design/theme/color_model.dart';
import 'package:langhuan/features/discover/explore_model.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/search/search_model.dart';
import 'package:langhuan/features/shelf/shelf_model.dart';
import 'package:langhuan/features/sources/source_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global ChangeNotifier-backed providers (Riverpod).
final searchModelProvider =
    ChangeNotifierProvider<SearchModel>((ref) => SearchModel());
final exploreModelProvider =
    ChangeNotifierProvider<ExploreModel>((ref) => ExploreModel());
final colorModelProvider =
    ChangeNotifierProvider<ColorModel>((ref) => ColorModel());
final shelfModelProvider =
    ChangeNotifierProvider<ShelfModel>((ref) => ShelfModel());
final readModelProvider =
    ChangeNotifierProvider<ReadModel>((ref) => ReadModel());
final sourceModelProvider =
    ChangeNotifierProvider<SourceModel>((ref) => SourceModel());
