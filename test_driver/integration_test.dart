// Driver for running an integration-test target in profile mode via
// `flutter drive` (plain `flutter test` can't do --profile). Used for the reader
// perf benchmark (see test_perf/reader_perf_test.dart):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=test_perf/reader_perf_test.dart --profile -d <device>
//   (or: make perf DEVICE=<id>)
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
